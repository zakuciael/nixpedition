package provider

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/hashicorp/terraform-plugin-framework/attr"
	"github.com/hashicorp/terraform-plugin-framework/diag"
	"github.com/hashicorp/terraform-plugin-framework/path"
	"github.com/hashicorp/terraform-plugin-framework/resource"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/planmodifier"
	"github.com/hashicorp/terraform-plugin-framework/resource/schema/stringplanmodifier"
	"github.com/hashicorp/terraform-plugin-framework/types"

	"github.com/zakuciael/nixpedition/terraform-provider-email/internal/ovh"
)

var _ resource.Resource = &ovhProDKIMResource{}
var _ resource.ResourceWithModifyPlan = &ovhProDKIMResource{}
var _ resource.ResourceWithImportState = &ovhProDKIMResource{}

func NewOVHProDKIMResource() resource.Resource {
	return &ovhProDKIMResource{}
}

type ovhProDKIMResource struct {
	clients *EmailClients
}

type ovhProDKIMModel struct {
	ID            types.String `tfsdk:"id"`
	Service       types.String `tfsdk:"service"`
	Domain        types.String `tfsdk:"domain"`
	SelectorNames types.List   `tfsdk:"selector_names"`
	Selectors     types.List   `tfsdk:"selectors"`
}

var selectorAttrTypes = map[string]attr.Type{
	"selector":        types.StringType,
	"type":            types.StringType,
	"content":         types.StringType,
	"status":          types.StringType,
	"customer_record": types.StringType,
	"cname_is_valid":  types.BoolType,
}

func (r *ovhProDKIMResource) Metadata(_ context.Context, req resource.MetadataRequest, resp *resource.MetadataResponse) {
	resp.TypeName = req.ProviderTypeName + "_ovh_pro_dkim"
}

func (r *ovhProDKIMResource) Schema(_ context.Context, _ resource.SchemaRequest, resp *resource.SchemaResponse) {
	resp.Schema = schema.Schema{
		MarkdownDescription: "Ensures OVH Email Pro DKIM selectors/keys exist and exports CNAME targets for DNS. Selectors are created with `autoEnableDKIM` so OVH enables signing after it validates the published CNAMEs.",
		Attributes: map[string]schema.Attribute{
			"id": schema.StringAttribute{
				Computed:            true,
				MarkdownDescription: "`{service}/{domain}`.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.UseStateForUnknown(),
				},
			},
			"service": schema.StringAttribute{
				Optional:            true,
				Computed:            true,
				MarkdownDescription: "Email Pro service name (e.g. `emailpro-xx123456-1`). Auto-discovered from `domain` when omitted.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"domain": schema.StringAttribute{
				Required:            true,
				MarkdownDescription: "Domain attached to the Email Pro service.",
				PlanModifiers: []planmodifier.String{
					stringplanmodifier.RequiresReplace(),
				},
			},
			"selector_names": schema.ListAttribute{
				Computed:            true,
				ElementType:         types.StringType,
				MarkdownDescription: "Expected DKIM selector names from OVH `dkimSelector` (known at plan time, even before keys exist).",
			},
			"selectors": schema.ListAttribute{
				Computed:            true,
				MarkdownDescription: "Full DKIM selector records (targets known after apply).",
				ElementType:         types.ObjectType{AttrTypes: selectorAttrTypes},
			},
		},
	}
}

func (r *ovhProDKIMResource) Configure(_ context.Context, req resource.ConfigureRequest, resp *resource.ConfigureResponse) {
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

// ModifyPlan resolves service + selector_names during planning so consumers can
// for_each over selector_names without waiting for apply.
func (r *ovhProDKIMResource) ModifyPlan(ctx context.Context, req resource.ModifyPlanRequest, resp *resource.ModifyPlanResponse) {
	if req.Plan.Raw.IsNull() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing OVH credentials", err.Error())
		return
	}

	var plan ovhProDKIMModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}

	service, err := r.resolveService(ctx, plan)
	if err != nil {
		resp.Diagnostics.AddError("Failed to resolve Email Pro service", err.Error())
		return
	}
	domain := plan.Domain.ValueString()

	names, err := r.clients.OVH.ListExpectedDKIMSelectorNames(ctx, service, domain)
	if err != nil {
		resp.Diagnostics.AddError("Failed to list DKIM selector names", err.Error())
		return
	}
	if len(names) == 0 {
		resp.Diagnostics.AddError("No DKIM selectors", fmt.Sprintf("Email Pro returned no expected selector names for %s (GET .../dkimSelector)", domain))
		return
	}

	nameValues := make([]attr.Value, 0, len(names))
	for _, name := range names {
		nameValues = append(nameValues, types.StringValue(name))
	}
	nameList, diags := types.ListValue(types.StringType, nameValues)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}

	plan.Service = types.StringValue(service)
	plan.SelectorNames = nameList
	plan.ID = types.StringValue(service + "/" + domain)
	// selectors stay unknown until apply (targets not available until keys exist)
	if plan.Selectors.IsNull() || plan.Selectors.IsUnknown() {
		plan.Selectors = types.ListUnknown(types.ObjectType{AttrTypes: selectorAttrTypes})
	}

	resp.Diagnostics.Append(resp.Plan.Set(ctx, &plan)...)
}

func (r *ovhProDKIMResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
	var plan ovhProDKIMModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing OVH credentials", err.Error())
		return
	}

	service, err := r.resolveService(ctx, plan)
	if err != nil {
		resp.Diagnostics.AddError("Failed to resolve Email Pro service", err.Error())
		return
	}
	domain := plan.Domain.ValueString()

	if err := r.ensureSelectors(ctx, service, domain); err != nil {
		resp.Diagnostics.AddError("Failed to ensure DKIM selectors", err.Error())
		return
	}

	selectors, err := r.readSelectors(ctx, service, domain)
	if err != nil {
		resp.Diagnostics.AddError("Failed to read DKIM selectors", err.Error())
		return
	}

	state, diags := r.toModel(ctx, service, domain, selectors)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	resp.Diagnostics.Append(resp.State.Set(ctx, &state)...)
}

func (r *ovhProDKIMResource) Read(ctx context.Context, req resource.ReadRequest, resp *resource.ReadResponse) {
	var state ovhProDKIMModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing OVH credentials", err.Error())
		return
	}

	service := state.Service.ValueString()
	domain := state.Domain.ValueString()
	if service == "" || domain == "" {
		if parts := strings.SplitN(state.ID.ValueString(), "/", 2); len(parts) == 2 {
			service, domain = parts[0], parts[1]
		}
	}

	selectors, err := r.readSelectors(ctx, service, domain)
	if err != nil {
		resp.Diagnostics.AddError("Failed to read DKIM selectors", err.Error())
		return
	}
	if len(selectors) == 0 {
		resp.State.RemoveResource(ctx)
		return
	}

	next, diags := r.toModel(ctx, service, domain, selectors)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	resp.Diagnostics.Append(resp.State.Set(ctx, &next)...)
}

func (r *ovhProDKIMResource) Update(ctx context.Context, req resource.UpdateRequest, resp *resource.UpdateResponse) {
	var plan ovhProDKIMModel
	var state ovhProDKIMModel
	resp.Diagnostics.Append(req.Plan.Get(ctx, &plan)...)
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing OVH credentials", err.Error())
		return
	}

	service := state.Service.ValueString()
	if !plan.Service.IsNull() && !plan.Service.IsUnknown() && plan.Service.ValueString() != "" {
		service = plan.Service.ValueString()
	}
	domain := plan.Domain.ValueString()

	if err := r.ensureSelectors(ctx, service, domain); err != nil {
		resp.Diagnostics.AddError("Failed to ensure DKIM selectors", err.Error())
		return
	}

	selectors, err := r.readSelectors(ctx, service, domain)
	if err != nil {
		resp.Diagnostics.AddError("Failed to read DKIM selectors", err.Error())
		return
	}

	next, diags := r.toModel(ctx, service, domain, selectors)
	resp.Diagnostics.Append(diags...)
	if resp.Diagnostics.HasError() {
		return
	}
	resp.Diagnostics.Append(resp.State.Set(ctx, &next)...)
}

func (r *ovhProDKIMResource) Delete(ctx context.Context, req resource.DeleteRequest, resp *resource.DeleteResponse) {
	var state ovhProDKIMModel
	resp.Diagnostics.Append(req.State.Get(ctx, &state)...)
	if resp.Diagnostics.HasError() {
		return
	}
	if err := r.requireClient(); err != nil {
		resp.Diagnostics.AddError("Missing OVH credentials", err.Error())
		return
	}

	service := state.Service.ValueString()
	domain := state.Domain.ValueString()

	names, err := r.clients.OVH.ListDKIMSelectorNames(ctx, service, domain)
	if err != nil {
		resp.Diagnostics.AddError("Failed to list DKIM selectors", err.Error())
		return
	}

	for _, name := range names {
		sel, err := r.clients.OVH.GetDKIMSelector(ctx, service, domain, name)
		if err != nil {
			resp.Diagnostics.AddError("Failed to get DKIM selector "+name, err.Error())
			return
		}
		if sel == nil {
			continue
		}
		if sel.Status == "inProduction" {
			if err := r.clients.OVH.DisableDKIMSelector(ctx, service, domain, name); err != nil {
				resp.Diagnostics.AddError("Failed to disable DKIM selector "+name, err.Error())
				return
			}
			deadline := time.Now().Add(2 * time.Minute)
			for time.Now().Before(deadline) {
				sel, err = r.clients.OVH.GetDKIMSelector(ctx, service, domain, name)
				if err != nil {
					resp.Diagnostics.AddError("Failed to refresh DKIM selector "+name, err.Error())
					return
				}
				if sel == nil || sel.Status == "ready" || strings.EqualFold(sel.Status, "waitingRecord") {
					break
				}
				time.Sleep(2 * time.Second)
			}
		}
		if err := r.clients.OVH.DeleteDKIMSelector(ctx, service, domain, name); err != nil {
			resp.Diagnostics.AddError("Failed to delete DKIM selector "+name, err.Error())
			return
		}
	}
}

func (r *ovhProDKIMResource) ImportState(ctx context.Context, req resource.ImportStateRequest, resp *resource.ImportStateResponse) {
	parts := strings.SplitN(req.ID, "/", 2)
	if len(parts) != 2 {
		resp.Diagnostics.AddError("Invalid import ID", "Expected `{service}/{domain}`")
		return
	}
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("id"), req.ID)...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("service"), parts[0])...)
	resp.Diagnostics.Append(resp.State.SetAttribute(ctx, path.Root("domain"), parts[1])...)
}

func (r *ovhProDKIMResource) requireClient() error {
	if r.clients == nil || r.clients.OVH == nil {
		return fmt.Errorf("provider attributes ovh_client_id and ovh_client_secret are required for email_ovh_pro_dkim")
	}
	return nil
}

func (r *ovhProDKIMResource) resolveService(ctx context.Context, plan ovhProDKIMModel) (string, error) {
	if !plan.Service.IsNull() && !plan.Service.IsUnknown() && plan.Service.ValueString() != "" {
		return plan.Service.ValueString(), nil
	}
	return r.clients.OVH.FindServiceForDomain(ctx, plan.Domain.ValueString())
}

func (r *ovhProDKIMResource) ensureSelectors(ctx context.Context, service, domain string) error {
	names, err := r.clients.OVH.ListExpectedDKIMSelectorNames(ctx, service, domain)
	if err != nil {
		return err
	}
	if len(names) == 0 {
		return fmt.Errorf("Email Pro returned no expected DKIM selector names for %s", domain)
	}

	for _, name := range names {
		sel, err := r.clients.OVH.GetDKIMSelector(ctx, service, domain, name)
		if err != nil {
			return err
		}
		if sel == nil {
			if err := r.clients.OVH.CreateDKIMSelector(ctx, service, domain, name); err != nil {
				return fmt.Errorf("create %s: %w", name, err)
			}
		}
		if _, err := r.clients.OVH.WaitForDKIMSelector(ctx, service, domain, name, 2*time.Minute); err != nil {
			return err
		}
	}
	return nil
}

func (r *ovhProDKIMResource) readSelectors(ctx context.Context, service, domain string) ([]ovh.DKIMSelector, error) {
	// Prefer expected names so plan/apply stay aligned before keys exist; fall
	// back to created names if dkimSelector is empty (should not happen).
	names, err := r.clients.OVH.ListExpectedDKIMSelectorNames(ctx, service, domain)
	if err != nil {
		return nil, err
	}
	if len(names) == 0 {
		names, err = r.clients.OVH.ListDKIMSelectorNames(ctx, service, domain)
		if err != nil {
			return nil, err
		}
	}
	out := make([]ovh.DKIMSelector, 0, len(names))
	for _, name := range names {
		sel, err := r.clients.OVH.GetDKIMSelector(ctx, service, domain, name)
		if err != nil {
			return nil, err
		}
		if sel == nil {
			continue
		}
		out = append(out, *sel)
	}
	return out, nil
}

func (r *ovhProDKIMResource) toModel(ctx context.Context, service, domain string, selectors []ovh.DKIMSelector) (ovhProDKIMModel, diag.Diagnostics) {
	var diags diag.Diagnostics

	nameValues := make([]attr.Value, 0, len(selectors))
	objs := make([]attr.Value, 0, len(selectors))
	for _, sel := range selectors {
		nameValues = append(nameValues, types.StringValue(sel.SelectorName))

		recordType := sel.RecordType
		if recordType == "" {
			recordType = "CNAME"
		}
		obj, d := types.ObjectValue(selectorAttrTypes, map[string]attr.Value{
			"selector":        types.StringValue(sel.SelectorName),
			"type":            types.StringValue(recordType),
			"content":         types.StringValue(sel.TargetRecord),
			"status":          types.StringValue(sel.Status),
			"customer_record": types.StringValue(sel.CustomerRecord),
			"cname_is_valid":  types.BoolValue(sel.CnameIsValid),
		})
		diags.Append(d...)
		objs = append(objs, obj)
	}

	nameList, d := types.ListValue(types.StringType, nameValues)
	diags.Append(d...)
	list, d := types.ListValue(types.ObjectType{AttrTypes: selectorAttrTypes}, objs)
	diags.Append(d...)

	return ovhProDKIMModel{
		ID:            types.StringValue(service + "/" + domain),
		Service:       types.StringValue(service),
		Domain:        types.StringValue(domain),
		SelectorNames: nameList,
		Selectors:     list,
	}, diags
}
