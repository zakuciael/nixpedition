package cloudflare

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const apiBase = "https://api.cloudflare.com/client/v4"

type Client struct {
	token      string
	httpClient *http.Client
}

func NewClient(token string) *Client {
	return &Client{
		token: token,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

type dmarcReportsResult struct {
	Enabled   *bool  `json:"enabled"`
	RuaPrefix string `json:"rua_prefix"`
}

type apiResponse struct {
	Success bool               `json:"success"`
	Errors  []apiError         `json:"errors"`
	Result  dmarcReportsResult `json:"result"`
}

type apiError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type DMARCReports struct {
	Enabled   bool
	RuaPrefix string
}

func (c *Client) GetDMARCReports(ctx context.Context, zoneID string) (*DMARCReports, error) {
	var resp apiResponse
	if err := c.do(ctx, http.MethodGet, "/zones/"+zoneID+"/email/auth/dmarc-reports", nil, &resp); err != nil {
		return nil, err
	}
	return &DMARCReports{
		Enabled:   resp.Result.Enabled != nil && *resp.Result.Enabled,
		RuaPrefix: resp.Result.RuaPrefix,
	}, nil
}

func (c *Client) ConfigureDMARCReports(ctx context.Context, zoneID string, enabled bool) (*DMARCReports, error) {
	body := map[string]any{
		"enabled":     enabled,
		"skip_wizard": true,
	}
	var resp apiResponse
	if err := c.do(ctx, http.MethodPatch, "/zones/"+zoneID+"/email/auth/dmarc-reports", body, &resp); err != nil {
		return nil, err
	}
	return &DMARCReports{
		Enabled:   resp.Result.Enabled != nil && *resp.Result.Enabled,
		RuaPrefix: resp.Result.RuaPrefix,
	}, nil
}

func (c *Client) do(ctx context.Context, method, path string, body any, out *apiResponse) error {
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(b)
	}

	req, err := http.NewRequestWithContext(ctx, method, apiBase+path, reader)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+c.token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	res, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	data, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}

	if err := json.Unmarshal(data, out); err != nil {
		return fmt.Errorf("decode cloudflare response (%d): %w; body=%s", res.StatusCode, err, truncate(data))
	}

	if res.StatusCode >= 400 || !out.Success {
		if len(out.Errors) > 0 {
			return fmt.Errorf("cloudflare API %s %s: %s", method, path, out.Errors[0].Message)
		}
		return fmt.Errorf("cloudflare API %s %s failed with status %d: %s", method, path, res.StatusCode, truncate(data))
	}

	return nil
}

func truncate(b []byte) string {
	const max = 512
	if len(b) <= max {
		return string(b)
	}
	return string(b[:max]) + "..."
}
