package provider

import (
	"context"
	"fmt"

	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/booldefault"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/types"
)

func NewCloudflareDMARCReportsResource() resource.Resource {
	return &cloudflareDMARCReportsResource{}
}

type cloudflareDMARCReportsResource struct {
	clients *EmailClients
}

type cloudflareDMARCReportsModel struct {
	ID        types.String `tfsdk:"id"`
	ZoneID    types.String `tfsdk:"zone_id"`
	Enabled   types.Bool   `tfsdk:"enabled"`
	RuaPrefix types.String `tfsdk:"rua_prefix"`
}

func (r *cloudflareDMARCReportsResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_cloudflare_dmarc_reports"
}

func (r *cloudflareDMARCReportsResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Manages Cloudflare DMARC Management for a zone and exports the RUA prefix.",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "Zone ID.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"zone_id": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Cloudflare zone ID.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"enabled": schema.BoolAttribute{
				Optional:            true,
				Computed:            true,
				Default:             booldefault.StaticBool(true),
				MarkdownDescription: "Whether DMARC Management is enabled for the zone.",
			},
			"rua_prefix": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "32-char hex prefix for `mailto:{prefix}@dmarc-reports.cloudflare.net`.",
			},
		},
	}
}

func (r *cloudflareDMARCReportsResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
	if req.ProviderData == nil {
		return
	}
	clients, ok := req.ProviderData.(*EmailClients)
	if !ok {
		resp.Diagnostics.AddError("Unexpected provider data", fmt.Sprintf("expected *EmailClients, got %T", req.ProviderData))
		return
	}
	r.clients = clients
}

func (r *cloudflareDMARCReportsResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan cloudflareDMARCReportsModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing Cloudflare credentials", err.Error())
		return
	}

	zoneID := plan.ZoneID.ValueString()
	enabled := plan.Enabled.ValueBool()

	result, err := r.clients.Cloudflare.ConfigureDMARCReports(ctx, zoneID, enabled)
	if err != nil {
		resp.Diagnostics.AddError("Failed to configure DMARC reports", err.Error())
		return
	}
	if result.RuaPrefix == "" {
		got, err := r.clients.Cloudflare.GetDMARCReports(ctx, zoneID)
		if err != nil {
			resp.Diagnostics.AddError("Failed to read DMARC reports", err.Error())
			return
		}
		result = got
	}
	if result.RuaPrefix == "" {
		resp.Diagnostics.AddError("Missing RUA prefix", "Cloudflare did not return rua_prefix for this zone")
		return
	}

	plan.ID = types.StringValue(zoneID)
	plan.Enabled = types.BoolValue(result.Enabled)
	plan.RuaPrefix = types.StringValue(result.RuaPrefix)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *cloudflareDMARCReportsResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state cloudflareDMARCReportsModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing Cloudflare credentials", err.Error())
		return
	}

	result, err := r.clients.Cloudflare.GetDMARCReports(ctx, state.ZoneID.ValueString())
	if err != nil {
		resp.Diagnostics.AddError("Failed to read DMARC reports", err.Error())
		return
	}

	state.ID = types.StringValue(state.ZoneID.ValueString())
	state.Enabled = types.BoolValue(result.Enabled)
	state.RuaPrefix = types.StringValue(result.RuaPrefix)
	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *cloudflareDMARCReportsResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan cloudflareDMARCReportsModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing Cloudflare credentials", err.Error())
		return
	}

	result, err := r.clients.Cloudflare.ConfigureDMARCReports(ctx, plan.ZoneID.ValueString(), plan.Enabled.ValueBool())
	if err != nil {
		resp.Diagnostics.AddError("Failed to update DMARC reports", err.Error())
		return
	}
	if result.RuaPrefix == "" {
		got, err := r.clients.Cloudflare.GetDMARCReports(ctx, plan.ZoneID.ValueString())
		if err != nil {
			resp.Diagnostics.AddError("Failed to read DMARC reports", err.Error())
			return
		}
		result = got
	}

	plan.ID = types.StringValue(plan.ZoneID.ValueString())
	plan.Enabled = types.BoolValue(result.Enabled)
	plan.RuaPrefix = types.StringValue(result.RuaPrefix)
	resp.Diagnostics.Append(resp.State.Set(ctx, &plan)...)
}

func (r *cloudflareDMARCReportsResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state cloudflareDMARCReportsModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing Cloudflare credentials", err.Error())
		return
	}

	if _, err := r.clients.Cloudflare.ConfigureDMARCReports(ctx, state.ZoneID.ValueString(), false); err != nil {
		resp.Diagnostics.AddError("Failed to disable DMARC reports", err.Error())
		return
	}
}

func (r *cloudflareDMARCReportsResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	resource.ImportStatePassthroughID(ctx, path.Root("zone_id"), req, resp)
}

func (r *cloudflareDMARCReportsResource) requireClient() error {
	if r.clients == nil || r.clients.Cloudflare == nil {
		return fmt.Errorf("provider attribute cloudflare_api_token is required for email_cloudflare_dmarc_reports")
	}
	return nil
}
