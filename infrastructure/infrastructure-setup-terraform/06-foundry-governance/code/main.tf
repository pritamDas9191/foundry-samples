########## Which built-in policies to assign, with which parameters.
########## An empty list means "don't assign that policy" — never an allow-list
########## policy with an empty list, which with Deny would block everything.

locals {
  builtin = "/providers/Microsoft.Authorization/policyDefinitions"

  planned = concat(
    # Agents: kinds and hosted-agent container images
    length(var.agents.allowed_agent_kinds) == 0 ? [] : [{
      key          = "agent-kinds-allow"
      display_name = "Agents: only allowed agent kinds"
      policy_id    = "85455646-5d02-433e-a42d-265151140427"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect            = { value = var.agents.effect }
        allowedAgentKinds = { value = var.agents.allowed_agent_kinds }
      })
    }],
    length(var.agents.denied_agent_kinds) == 0 ? [] : [{
      key          = "agent-kinds-deny"
      display_name = "Agents: no denied agent kinds"
      policy_id    = "b6ca2367-8597-4a3f-ab19-48f58d6d9278"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect           = { value = var.agents.effect }
        deniedAgentKinds = { value = var.agents.denied_agent_kinds }
      })
    }],
    length(var.agents.allowed_container_images) == 0 ? [] : [{
      key          = "agent-images-allow"
      display_name = "Hosted agents: only allowed container images"
      policy_id    = "d0d9ac6c-628b-46c1-a177-eb22b12ce588"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect                 = { value = var.agents.effect }
        allowedContainerImages = { value = var.agents.allowed_container_images }
      })
    }],
    length(var.agents.denied_container_images) == 0 ? [] : [{
      key          = "agent-images-deny"
      display_name = "Hosted agents: no denied container images"
      policy_id    = "215c2c77-3afb-4f55-be2f-709b60dc8d53"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect                = { value = var.agents.effect }
        deniedContainerImages = { value = var.agents.denied_container_images }
      })
    }],

    # Models
    length(var.models.allowed_publishers) == 0 && length(var.models.allowed_asset_ids) == 0 ? [] : [{
      key          = "models-approved"
      display_name = "Models: only approved models"
      policy_id    = "aafe3651-cb78-4f68-9f81-e7e41509110f"
      version      = "1.*.*"
      parameters = jsonencode({
        effect            = { value = var.models.effect }
        allowedPublishers = { value = var.models.allowed_publishers }
        allowedAssetIds   = { value = var.models.allowed_asset_ids }
      })
    }],
    !var.models.deny_preview_models && !var.models.only_allow_direct_from_azure ? [] : [{
      key          = "models-eligibility"
      display_name = "Models: meet eligibility (no preview, direct from Azure)"
      policy_id    = "8791d062-ba96-4c34-b604-8538f7e30ca0"
      version      = "1.*.*"
      parameters = jsonencode({
        effect                   = { value = var.models.effect }
        denyPreviewModels        = { value = var.models.deny_preview_models }
        onlyAllowDirectFromAzure = { value = var.models.only_allow_direct_from_azure }
      })
    }],

    # Tools (agents and toolboxes)
    length(concat(var.tools.approved_tool_types, var.tools.approved_mcp_endpoints, var.tools.approved_mcp_connectors)) == 0 ? [] : [{
      key          = "tools-approved"
      display_name = "Tools: only approved tools and MCP servers"
      policy_id    = "e7352ad2-6c86-4a07-9573-47f67b557ba8"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect                = { value = var.tools.effect }
        approvedToolTypes     = { value = var.tools.approved_tool_types }
        approvedMcpEndpoints  = { value = var.tools.approved_mcp_endpoints }
        approvedMcpConnectors = { value = var.tools.approved_mcp_connectors }
      })
    }],
    length(concat(var.tools.denied_tool_types, var.tools.denied_mcp_endpoints, var.tools.denied_mcp_connectors)) == 0 ? [] : [{
      key          = "tools-denied"
      display_name = "Tools: no denied tools or MCP servers"
      policy_id    = "7740c22b-07ef-4bac-9f5a-e38d188f80b7"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect              = { value = var.tools.effect }
        deniedToolTypes     = { value = var.tools.denied_tool_types }
        deniedMcpEndpoints  = { value = var.tools.denied_mcp_endpoints }
        deniedMcpConnectors = { value = var.tools.denied_mcp_connectors }
      })
    }],

    # Agent safety (audit-only)
    !var.safety.enabled ? [] : [{
      key          = "agent-prompt-filter"
      display_name = "Safety: agents keep the ${var.safety.filter_name} prompt filter on"
      policy_id    = "9224c1cc-34fc-44f1-ad08-5c4b079c9ce6"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect                   = { value = var.safety.effect }
        filterName               = { value = var.safety.filter_name }
        entityKind               = { value = var.safety.entity_kinds }
        allowedEnabledForPrompt  = { value = ["true"] }
        allowedBlockingForPrompt = { value = ["true"] }
      })
    }],

    # Hosted-agent egress, plus checks on the RAI policies that carry the egress rules
    !local.egress_enabled ? [] : [{
      key          = "agent-egress"
      display_name = "Egress: hosted agents use an enforced RAI egress allow-list"
      policy_id    = "d279dbb1-e60e-4ca0-8c2f-cc7a0f46166b"
      version      = "1.*.*-preview"
      parameters = jsonencode({
        effect                = { value = var.egress.effect }
        permittedDestinations = { value = var.egress.permitted_destinations }
        deniedDestinations    = { value = var.egress.denied_destinations }
        allowedActionTypes    = { value = var.egress.allowed_action_types }
      })
    }],
    !local.egress_enabled || !var.egress.rai_policy_controls ? [] : [
      {
        key          = "rai-egress-baseline"
        display_name = "Egress: RAI policies meet the egress baseline"
        policy_id    = "0cfd954d-079f-447f-91bf-89889e9d1de0"
        version      = "1.*.*-preview"
        parameters = jsonencode({
          effect                = { value = var.egress.effect }
          permittedDestinations = { value = var.egress.permitted_destinations }
          deniedDestinations    = { value = var.egress.denied_destinations }
          allowedActionTypes    = { value = var.egress.allowed_action_types }
        })
      },
      {
        key          = "rai-egress-headers"
        display_name = "Egress: RAI policy headers use references and HTTPS"
        policy_id    = "29be091c-88f9-419b-8ad9-82ce5dc452d3"
        version      = "1.*.*-preview"
        parameters = jsonencode({
          effect = { value = var.egress.effect }
        })
      },
      {
        key          = "rai-egress-rewrites"
        display_name = "Egress: RAI policy rewrites stay on permitted hosts"
        policy_id    = "64a15c51-9797-4d6b-93a5-16b19e7de23b"
        version      = "1.*.*-preview"
        parameters = jsonencode({
          effect                = { value = var.egress.effect }
          permittedDestinations = { value = var.egress.permitted_destinations }
          deniedDestinations    = { value = var.egress.denied_destinations }
        })
      },
    ],
  )

  egress_enabled = coalesce(var.egress.enabled, length(var.egress.permitted_destinations) > 0)

  # Agent-kind policies stay direct assignments even in initiative mode: the Foundry
  # create-agent experience only detects them up front when they're assigned directly.
  direct_only_keys   = ["agent-kinds-allow", "agent-kinds-deny"]
  initiative_members = [for a in local.planned : a if !contains(local.direct_only_keys, a.key)]
  use_initiative     = var.initiative.enabled && length(local.initiative_members) > 0
  initiative_name    = coalesce(var.initiative.name, "${var.assignment_prefix}-foundry-governance")
  initiative_title   = coalesce(var.initiative.display_name, "Initiative: Foundry agents, models, tools and egress (${var.display_name_prefix})")
  direct_plan        = local.use_initiative && !var.initiative.assign_individually ? [for a in local.planned : a if contains(local.direct_only_keys, a.key)] : local.planned
  direct             = { for a in local.direct_plan : a.key => merge(a, { initiative = false }) }
  initiative_single  = local.use_initiative ? { (local.initiative_name) = { key = local.initiative_name, display_name = local.initiative_title, initiative = true, parameters = null } } : {}

  # One entry per assignment: direct controls plus, optionally, the initiative.
  assignments = merge(local.direct, local.initiative_single)
  description = "Assigned by the Microsoft Foundry governance template (06-foundry-governance)."
  metadata    = jsonencode({ source = "foundry-samples/06-foundry-governance" })
}

########## Optional custom initiative bundling the planned controls (except agent kinds).
########## Members keep their own parameter values, so the initiative is self-contained.

resource "azurerm_policy_set_definition" "governance" {
  count = local.use_initiative ? 1 : 0

  name         = local.initiative_name
  policy_type  = "Custom"
  display_name = local.initiative_title
  description  = "Microsoft Foundry governance controls bundled by the 06-foundry-governance template."
  metadata     = jsonencode({ category = "Cognitive Services", source = "foundry-samples/06-foundry-governance" })

  dynamic "policy_definition_reference" {
    for_each = local.initiative_members
    content {
      reference_id         = policy_definition_reference.value.key
      policy_definition_id = "${local.builtin}/${policy_definition_reference.value.policy_id}"
      version              = policy_definition_reference.value.version
      parameter_values     = policy_definition_reference.value.parameters
    }
  }
}

locals {
  assignment_policy_id = {
    for k, a in local.assignments : k => (
      a.initiative ? azurerm_policy_set_definition.governance[0].id : "${local.builtin}/${a.policy_id}"
    )
  }
  assignment_display_name = {
    for k, a in local.assignments : k => (
      a.initiative ? a.display_name : "${a.display_name} (${var.display_name_prefix})"
    )
  }
  assignment_name = {
    for k, a in local.assignments : k => (a.initiative ? k : "${var.assignment_prefix}-${k}")
  }
}

########## Scope — narrowest wins: Foundry resources, then a resource group, then the subscription.

locals {
  scope_kind = length(var.foundry_resource_ids) > 0 ? "foundry_resource" : (var.resource_group_name == null ? "subscription" : "resource_group")

  # One entry per (Foundry resource, control).
  foundry_resource_assignments = {
    for pair in setproduct(var.foundry_resource_ids, keys(local.assignments)) :
    "${pair[0]}|${pair[1]}" => { resource_id = pair[0], key = pair[1] }
  }
}

data "azurerm_subscription" "current" {}

data "azurerm_resource_group" "target" {
  count = local.scope_kind == "resource_group" ? 1 : 0
  name  = var.resource_group_name
}

########## Assignments — subscription scope (default)

resource "azurerm_subscription_policy_assignment" "this" {
  for_each = local.scope_kind == "subscription" ? local.assignments : {}

  name                 = local.assignment_name[each.key]
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = local.assignment_policy_id[each.key]
  display_name         = local.assignment_display_name[each.key]
  description          = local.description
  enforce              = var.enforce
  not_scopes           = var.not_scopes
  parameters           = each.value.parameters
  metadata             = local.metadata
}

########## Assignments — resource group scope (resource_group_name set)

resource "azurerm_resource_group_policy_assignment" "this" {
  for_each = local.scope_kind == "resource_group" ? local.assignments : {}

  name                 = local.assignment_name[each.key]
  resource_group_id    = data.azurerm_resource_group.target[0].id
  policy_definition_id = local.assignment_policy_id[each.key]
  display_name         = local.assignment_display_name[each.key]
  description          = local.description
  enforce              = var.enforce
  not_scopes           = var.not_scopes
  parameters           = each.value.parameters
  metadata             = local.metadata
}

########## Assignments — Foundry resource scope (foundry_resource_ids set)

resource "azurerm_resource_policy_assignment" "this" {
  for_each = local.scope_kind == "foundry_resource" ? local.foundry_resource_assignments : {}

  name                 = local.assignment_name[each.value.key]
  resource_id          = each.value.resource_id
  policy_definition_id = local.assignment_policy_id[each.value.key]
  display_name         = local.assignment_display_name[each.value.key]
  description          = local.description
  enforce              = var.enforce
  not_scopes           = var.not_scopes
  parameters           = local.assignments[each.value.key].parameters
  metadata             = local.metadata
}
