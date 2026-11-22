output "scopes" {
  description = "Scopes the policies were assigned to."
  value = (
    local.scope_kind == "foundry_resource" ? var.foundry_resource_ids :
    local.scope_kind == "resource_group" ? [data.azurerm_resource_group.target[0].id] :
    [data.azurerm_subscription.current.id]
  )
}

output "assignments" {
  description = "Policy assignments created, keyed by control (and by Foundry resource ID when foundry_resource_ids is set)."
  value = merge(
    { for k, a in azurerm_subscription_policy_assignment.this : k => { id = a.id, display_name = a.display_name } },
    { for k, a in azurerm_resource_group_policy_assignment.this : k => { id = a.id, display_name = a.display_name } },
    { for k, a in azurerm_resource_policy_assignment.this : k => { id = a.id, display_name = a.display_name } },
  )
}

output "initiative_id" {
  description = "Custom initiative ID, when initiative.enabled is true."
  value       = local.use_initiative ? azurerm_policy_set_definition.governance[0].id : null
}

output "direct_controls" {
  description = "Controls assigned directly."
  value       = [for a in local.direct_plan : a.key]
}

output "initiative_controls" {
  description = "Controls bundled in the initiative (empty when initiative.enabled is false)."
  value       = local.use_initiative ? [for a in local.initiative_members : a.key] : []
}
