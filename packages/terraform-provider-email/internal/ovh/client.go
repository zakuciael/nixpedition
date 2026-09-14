package ovh

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Client struct {
	endpoint     string
	clientID     string
	clientSecret string
	httpClient   *http.Client
	token        string
	tokenExpiry  time.Time
}

func NewClient(endpoint, clientID, clientSecret string) *Client {
	if endpoint == "" {
		endpoint = "ovh-eu"
	}
	return &Client{
		endpoint:     endpoint,
		clientID:     clientID,
		clientSecret: clientSecret,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

func (c *Client) apiBase() string {
	switch c.endpoint {
	case "ovh-ca":
		return "https://ca.api.ovh.com/v1"
	case "ovh-us":
		return "https://api.us.ovhcloud.com/v1"
	default:
		return "https://eu.api.ovh.com/v1"
	}
}

func (c *Client) tokenURL() string {
	switch c.endpoint {
	case "ovh-ca":
		return "https://ca.ovh.com/auth/oauth2/token"
	case "ovh-us":
		return "https://us.ovhcloud.com/auth/oauth2/token"
	default:
		return "https://www.ovh.com/auth/oauth2/token"
	}
}

type DKIMSelector struct {
	SelectorName   string `json:"selectorName"`
	TargetRecord   string `json:"targetRecord"`
	CustomerRecord string `json:"customerRecord"`
	RecordType     string `json:"recordType"`
	Status         string `json:"status"`
	CnameIsValid   bool   `json:"cnameIsValid"`
}

func (c *Client) ListServices(ctx context.Context) ([]string, error) {
	var services []string
	if err := c.do(ctx, http.MethodGet, "/email/pro", nil, &services); err != nil {
		return nil, err
	}
	return services, nil
}

func (c *Client) ListDomains(ctx context.Context, service string) ([]string, error) {
	var domains []string
	path := "/email/pro/" + url.PathEscape(service) + "/domain"
	if err := c.do(ctx, http.MethodGet, path, nil, &domains); err != nil {
		return nil, err
	}
	return domains, nil
}

func (c *Client) FindServiceForDomain(ctx context.Context, domain string) (string, error) {
	services, err := c.ListServices(ctx)
	if err != nil {
		return "", err
	}
	for _, service := range services {
		domains, err := c.ListDomains(ctx, service)
		if err != nil {
			return "", err
		}
		for _, d := range domains {
			if d == domain {
				return service, nil
			}
		}
	}
	return "", fmt.Errorf("no Email Pro service found for domain %q", domain)
}

// ListExpectedDKIMSelectorNames returns the selector names Email Pro attributes
// to a domain before any keys exist (GET .../dkimSelector).
// Use this for plan-time for_each keys and for deciding which selectors to create.
func (c *Client) ListExpectedDKIMSelectorNames(ctx context.Context, service, domain string) ([]string, error) {
	var names []string
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkimSelector", url.PathEscape(service), url.PathEscape(domain))
	if err := c.do(ctx, http.MethodGet, path, nil, &names); err != nil {
		return nil, err
	}
	return names, nil
}

// ListDKIMSelectorNames returns selectors that already have keys created
// (GET .../dkim). Empty until CreateDKIMSelector has been called.
func (c *Client) ListDKIMSelectorNames(ctx context.Context, service, domain string) ([]string, error) {
	var names []string
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkim", url.PathEscape(service), url.PathEscape(domain))
	if err := c.do(ctx, http.MethodGet, path, nil, &names); err != nil {
		return nil, err
	}
	return names, nil
}

func (c *Client) GetDKIMSelector(ctx context.Context, service, domain, selector string) (*DKIMSelector, error) {
	var out DKIMSelector
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkim/%s", url.PathEscape(service), url.PathEscape(domain), url.PathEscape(selector))
	code, err := c.doStatus(ctx, http.MethodGet, path, nil, &out)
	if err != nil {
		return nil, err
	}
	if code == http.StatusNotFound {
		return nil, nil
	}
	if out.SelectorName == "" {
		out.SelectorName = selector
	}
	if out.RecordType == "" {
		out.RecordType = "CNAME"
	}
	return &out, nil
}

func (c *Client) CreateDKIMSelector(ctx context.Context, service, domain, selector string) error {
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkim", url.PathEscape(service), url.PathEscape(domain))
	body := map[string]any{
		// Hand DNS validation + enable off to OVH once CNAMEs are published
		// (configureDkim stays false: DNS is managed in Cloudflare, not OVH).
		"autoEnableDKIM": true,
		"configureDkim":  false,
		"selectorName":   selector,
	}
	return c.do(ctx, http.MethodPost, path, body, nil)
}

func (c *Client) DisableDKIMSelector(ctx context.Context, service, domain, selector string) error {
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkim/%s/disable", url.PathEscape(service), url.PathEscape(domain), url.PathEscape(selector))
	return c.do(ctx, http.MethodPost, path, nil, nil)
}

func (c *Client) DeleteDKIMSelector(ctx context.Context, service, domain, selector string) error {
	path := fmt.Sprintf("/email/pro/%s/domain/%s/dkim/%s", url.PathEscape(service), url.PathEscape(domain), url.PathEscape(selector))
	code, err := c.doStatus(ctx, http.MethodDelete, path, nil, nil)
	if err != nil {
		return err
	}
	if code == http.StatusNotFound {
		return nil
	}
	return nil
}

func (c *Client) WaitForDKIMSelector(ctx context.Context, service, domain, selector string, timeout time.Duration) (*DKIMSelector, error) {
	deadline := time.Now().Add(timeout)
	for {
		sel, err := c.GetDKIMSelector(ctx, service, domain, selector)
		if err != nil {
			return nil, err
		}
		if sel != nil && sel.TargetRecord != "" {
			return sel, nil
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("timed out waiting for DKIM selector %q", selector)
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(2 * time.Second):
		}
	}
}

func (c *Client) ensureToken(ctx context.Context) error {
	if c.token != "" && time.Now().Before(c.tokenExpiry.Add(-30*time.Second)) {
		return nil
	}

	form := url.Values{}
	form.Set("grant_type", "client_credentials")
	form.Set("client_id", c.clientID)
	form.Set("client_secret", c.clientSecret)
	form.Set("scope", "all")

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.tokenURL(), strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if res.StatusCode >= 400 {
		return fmt.Errorf("ovh oauth token request failed (%d): %s", res.StatusCode, truncate(data))
	}

	var token struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(data, &token); err != nil {
		return fmt.Errorf("decode ovh oauth response: %w", err)
	}
	if token.AccessToken == "" {
		return fmt.Errorf("ovh oauth response missing access_token")
	}

	c.token = token.AccessToken
	expires := token.ExpiresIn
	if expires <= 0 {
		expires = 3600
	}
	c.tokenExpiry = time.Now().Add(time.Duration(expires) * time.Second)
	return nil
}

func (c *Client) do(ctx context.Context, method, path string, body any, out any) error {
	code, err := c.doStatus(ctx, method, path, body, out)
	if err != nil {
		return err
	}
	if code == http.StatusNotFound {
		return fmt.Errorf("ovh API %s %s: not found", method, path)
	}
	return nil
}

func (c *Client) doStatus(ctx context.Context, method, path string, body any, out any) (int, error) {
	if err := c.ensureToken(ctx); err != nil {
		return 0, err
	}

	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, err
		}
		reader = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.apiBase()+path, reader)
	if err != nil {
		return 0, err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	res, err := c.httpClient.Do(req)
	if err != nil {
		return 0, err
	}
	defer res.Body.Close()

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return res.StatusCode, err
	}

	if res.StatusCode == http.StatusNotFound {
		return res.StatusCode, nil
	}

	if res.StatusCode >= 400 {
		return res.StatusCode, fmt.Errorf("ovh API %s %s failed (%d): %s", method, path, res.StatusCode, truncate(data))
	}

	if out != nil && len(data) > 0 && string(data) != "null" {
		if err := json.Unmarshal(data, out); err != nil {
			return res.StatusCode, fmt.Errorf("decode ovh response: %w; body=%s", err, truncate(data))
		}
	}

	return res.StatusCode, nil
}

func truncate(b []byte) string {
	const max = 512
	if len(b) <= max {
		return string(b)
	}
	return string(b[:max]) + "..."
}
