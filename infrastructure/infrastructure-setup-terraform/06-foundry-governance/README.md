# Govern Microsoft Foundry agents, models, tools and egress with Azure Policy (Terraform)

Terraform version of [`06-foundry-governance`](../../infrastructure-setup-bicep/06-foundry-governance/). It assigns Microsoft Foundry **built-in Azure Policy definitions** — evaluated by Foundry whenever an agent, toolbox, model deployment or RAI policy is created or updated — at **subscription**, **resource group** or **Foundry resource** scope, either one by one or bundled into one custom initiative.

See the Bicep README for the full [controls table](../../infrastructure-setup-bicep/06-foundry-governance/README.md#controls) (including what each control evaluates), [examples and the tool type catalog](../../infrastructure-setup-bicep/06-foundry-governance/README.md#examples), [runtime project tool controls](../../infrastructure-setup-bicep/06-foundry-governance/README.md#runtime-tool-access-project-tool-controls) and [things to know](../../infrastructure-setup-bicep/06-foundry-governance/README.md#things-to-know). The variables mirror the Bicep parameters in snake_case.

## Quick start

Prerequisites: Terraform 1.10+, Azure CLI signed in, and **Owner** or **Resource Policy Contributor** on the target scope (subscription, resource group or Foundry resource).

```bash
cd code
cp audit-baseline.tfvars my.tfvars   # replace subscription_id and the example values
terraform init
terraform plan  -var-file=my.tfvars
terraform apply -var-file=my.tfvars
```

- Set `foundry_resource_ids` to assign at specific Foundry resources (recommended for tool policies: each assignment can evaluate only a limited number of agents and toolboxes), or `resource_group_name = "<resource-group>"` for one resource group. Unset, the assignments cover the whole subscription.
- Wait up to 30 minutes for assignments to take effect (30–60 minutes for hosted-agent egress), after every change including Audit → Deny. Compliance reporting can take up to 12 hours.
- Verify a compliant and a non-compliant save of a toolbox or prompt agent, an RAI policy and a **new** hosted-agent version, then apply `enforce.tfvars` (Deny) and repeat. `enforce = false` (DoNotEnforce) switches off blocking for every assignment; it isn't the same as the `Audit` effect.

## Variables

| Variable | Default | Description |
|---|---|---|
| `subscription_id` | — | Subscription to assign in. |
| `resource_group_name` | `null` | Resource group to scope to. `null` = whole subscription. Ignored when `foundry_resource_ids` is set. |
| `foundry_resource_ids` | `[]` | Full Foundry resource IDs (`Microsoft.CognitiveServices/accounts`) to assign every control at. Recommended for tool policies. |
| `assignment_prefix` | `fg` | Assignment names are `<prefix>-<control>`. |
| `display_name_prefix` | `Foundry governance` | Label appended to every display name (`Tools: only approved tools and MCP servers (<label>)`); names lead with the area so they stay readable when truncated. |
| `enforce` | `true` | `false` = DoNotEnforce (report only). |
| `not_scopes` | `[]` | Resource IDs inside the scope to exclude. |
| `agents` | `{}` | `effect`, `allowed_agent_kinds`, `denied_agent_kinds`, `allowed_container_images`, `denied_container_images` |
| `models` | `{}` | `effect`, `allowed_publishers`, `allowed_asset_ids`, `deny_preview_models`, `only_allow_direct_from_azure` |
| `tools` | `{}` | `effect`, `approved_tool_types`, `approved_mcp_endpoints`, `approved_mcp_connectors`, `denied_tool_types`, `denied_mcp_endpoints`, `denied_mcp_connectors` (MCP patterns: at most one `*`) |
| `safety` | `{}` | `enabled` (`false`), `effect` (`Audit`), `filter_name` (`Jailbreak`), `entity_kinds` (`["prompt", "hosted"]`) |
| `egress` | `{}` | `effect`, `enabled` (default: `true` when `permitted_destinations` is set), `permitted_destinations` and `denied_destinations` (up to 100 each), `allowed_action_types` (all four), `rai_policy_controls` (`true`) |
| `initiative` | `{}` | `enabled` (`false`), `name` (`<prefix>-foundry-governance`), `display_name` (`Initiative: Foundry agents, models, tools and egress (<label>)`), `assign_individually` (`false`) |

Every `effect` defaults to `Audit`. **An empty list means the policy isn't assigned** — never an allow-list with an empty list, which with Deny blocks everything. Egress is the exception: `enabled = true` with no `permitted_destinations` requires hosted agents to have no traffic-permitting egress rules — for egress an empty list never means unrestricted.

### Scope, egress and initiative example

```hcl
foundry_resource_ids = [
  "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>",
]

egress = {
  effect                 = "Deny"
  permitted_destinations = ["api.contoso.com/public/*", "*.in.applicationinsights.azure.com"]
  denied_destinations    = ["api.contoso.com/admin/*"]
}

initiative = {
  enabled      = true
  name         = "contoso-foundry-governance"
  display_name = "Contoso Foundry governance"
}
```

With `initiative.enabled = true`, every control except the agent-kind policies goes into one `azurerm_policy_set_definition` (subscription scope, member parameter values inlined) with a single assignment; agent-kind policies stay direct assignments so the Foundry create-agent experience can detect them. `assign_individually = true` also keeps every control as its own assignment. Outputs `direct_controls`, `initiative_controls` and `initiative_id` show the split.

## Notes

- Assignments use `azurerm_subscription_policy_assignment`, `azurerm_resource_group_policy_assignment` or `azurerm_resource_policy_assignment` (one per Foundry resource and control). These resources don't expose a definition version; Azure fills in the major-version selector (`1.*.*-preview` for preview built-ins, `1.*.*` for GA), and `terraform plan` stays clean on re-runs.
- Parameters are passed as JSON, so the assignment matches what the Azure portal and Foundry create.
- Initiative members pin the same major-version selectors through `policy_definition_reference.version`. The initiative is defined in `subscription_id`, so with `initiative.enabled` use Foundry resources in that subscription.
- This module manages Azure Policy only. Project runtime tool controls (`toolControls`) are a separate setting; the [Govern tools](https://learn.microsoft.com/azure/foundry/control-plane/govern-tools?pivots=terraform#update-project-tool-controls-with-terraform) article has an `azapi_update_resource` example.
- Removing a control from your `tfvars` deletes its assignment on the next `apply`; switching `initiative.enabled` replaces the individual assignments with the initiative (or back).

`Tags: Azure Policy, Governance, Microsoft.CognitiveServices`
