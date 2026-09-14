package provider

import (
	"context"

	"github.com/hashicorp/terraform-plugin-framework/datasource"
	"github.com/hashicorp/terraform-plugin-framework/provider"
	"github.com/hashicorp/terraform-plugin-framework/provider/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/zakuciael/nixpedition/terraform-provider-email/internal/cloudflare"
	"github.com/zakuciael/nixpedition/terraform-provider-email/internal/ovh"
)

func New(version string) func() provider.Provider {
	return func() provider.Provider {
		return &emailProvider{version: version}
	}
}

type emailProvider struct {
	version string
}

type emailProviderModel struct {
	CloudflareAPIToken types.String `tfsdk:"cloudflare_api_token"`
	OVHEndpoint        types.String `tfsdk:"ovh_endpoint"`
	OVHClientID        types.String `tfsdk:"ovh_client_id"`
	OVHClientSecret    types.String `tfsdk:"ovh_client_secret"`
}

type EmailClients struct {
	Cloudflare *cloudflare.Client
	OVH        *ovh.Client
}

func (p *emailProvider) Metadata(_ context.Context, _ provider.MetadataRequest, resp *provider.MetadataResponse) {
	resp.TypeName = "email"
	resp.Version = p.version
}

func (p *emailProvider) Schema(_ context.Context, _ provider.SchemaRequest, resp *provider.SchemaResponse) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Manage Cloudflare DMARC Management and OVH Email Pro DKIM.",
		Attributes: map[string]schema.Attribute{
			"cloudflare_api_token": schema.StringAttribute{
				MarkdownDescription: "Cloudflare API token with Email Security DMARC Reports permissions.",
				Optional:            true,
				Sensitive:           true,
			},
			"ovh_endpoint": schema.StringAttribute{
				MarkdownDescription: "OVH API endpoint. One of `ovh-eu`, `ovh-ca`, `ovh-us`. Defaults to `ovh-eu`.",
				Optional:            true,
			},
			"ovh_client_id": schema.StringAttribute{
				MarkdownDescription: "OVH OAuth2 client ID (service account).",
				Optional:            true,
				Sensitive:           true,
			},
			"ovh_client_secret": schema.StringAttribute{
				MarkdownDescription: "OVH OAuth2 client secret (service account).",
				Optional:            true,
				Sensitive:           true,
			},
		},
	}
}

func (p *emailProvider) Configure(ctx context.Context, req provider.ConfigureRequest, resp *provider.ConfigureResponse) {
	var config emailProviderModel
	resp.Diagnostics.Append(req.Config.Get(ctx, &config)...)
	if resp.Diagnostics.HasError() {
		return
	}

	clients := &EmailClients{}

	if !config.CloudflareAPIToken.IsNull() && !config.CloudflareAPIToken.IsUnknown() && config.CloudflareAPIToken.ValueString() != "" {
		clients.Cloudflare = cloudflare.NewClient(config.CloudflareAPIToken.ValueString())
	}

	clientID := config.OVHClientID.ValueString()
	clientSecret := config.OVHClientSecret.ValueString()
	if clientID != "" && clientSecret != "" {
		clients.OVH = ovh.NewClient(config.OVHEndpoint.ValueString(), clientID, clientSecret)
	}

	resp.DataSourceData = clients
	resp.ResourceData = clients
}

func (p *emailProvider) Resources(_ context.Context) []func() resource.Resource {
	return []func() resource.Resource{
		NewCloudflareDMARCReportsResource,
		NewOVHProDKIMResource,
	}
}

func (p *emailProvider) DataSources(_ context.Context) []func() datasource.DataSource {
	return nil
}
