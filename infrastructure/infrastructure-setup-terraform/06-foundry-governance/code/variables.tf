variable "subscription_id" {
  description = "Subscription to assign the policies in."
  type        = string
}

variable "resource_group_name" {
  description = "Optional. Resource group in the subscription to scope the assignments to. null = whole subscription. Ignored when foundry_resource_ids is set."
  type        = string
  default     = null
}

variable "foundry_resource_ids" {
  description = "Optional. Full resource IDs of Foundry resources (Microsoft.CognitiveServices/accounts). When set, every control is assigned at each of these resources instead of the subscription or resource group. Recommended for tool policies: each assignment can evaluate only a limited number of agents and toolboxes."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.foundry_resource_ids : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.CognitiveServices/accounts/[^/]+$", id))])
    error_message = "foundry_resource_ids must be full Foundry resource IDs: /subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>."
  }
}

variable "assignment_prefix" {
  description = "Prefix for assignment names (<prefix>-<control>)."
  type        = string
  default     = "fg"

  validation {
    condition     = length(var.assignment_prefix) >= 1 && length(var.assignment_prefix) <= 10
    error_message = "assignment_prefix must be 1-10 characters."
  }
}

variable "display_name_prefix" {
  description = "Label appended to assignment display names, for example \"Tools: only approved tools (Contoso)\". Display names lead with the area so they stay readable when Foundry truncates them."
  type        = string
  default     = "Foundry governance"
}

variable "enforce" {
  description = "true enforces the effects. false = DoNotEnforce: evaluate and report compliance without blocking."
  type        = bool
  default     = true
}

variable "not_scopes" {
  description = "Resource IDs inside the scope to exclude."
  type        = list(string)
  default     = []
}

variable "agents" {
  description = "Agent kind and hosted-agent container image controls. Empty list = policy not assigned."
  type = object({
    effect                   = optional(string, "Audit")
    allowed_agent_kinds      = optional(list(string), [])
    denied_agent_kinds       = optional(list(string), [])
    allowed_container_images = optional(list(string), [])
    denied_container_images  = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.agents.effect)
    error_message = "agents.effect must be Audit, Deny or Disabled."
  }
}

variable "models" {
  description = "Model deployment controls. Approved-models policy is assigned if publishers or asset IDs are set; eligibility if either flag is true."
  type = object({
    effect                       = optional(string, "Audit")
    allowed_publishers           = optional(list(string), [])
    allowed_asset_ids            = optional(list(string), [])
    deny_preview_models          = optional(bool, false)
    only_allow_direct_from_azure = optional(bool, false)
  })
  default = {}

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.models.effect)
    error_message = "models.effect must be Audit, Deny or Disabled."
  }
}

variable "tools" {
  description = "Tool controls, evaluated when a toolbox or a prompt agent (Responses API, without the Copilot harness) is saved; hosted agents are governed through the toolboxes they call. Use tool type catalog values. Adding \"mcp\" to approved_tool_types approves every MCP server. MCP endpoint patterns allow at most one \"*\"."
  type = object({
    effect                  = optional(string, "Audit")
    approved_tool_types     = optional(list(string), [])
    approved_mcp_endpoints  = optional(list(string), [])
    approved_mcp_connectors = optional(list(string), [])
    denied_tool_types       = optional(list(string), [])
    denied_mcp_endpoints    = optional(list(string), [])
    denied_mcp_connectors   = optional(list(string), [])
  })
  default = {}

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.tools.effect)
    error_message = "tools.effect must be Audit, Deny or Disabled."
  }

  validation {
    condition     = alltrue([for e in concat(var.tools.approved_mcp_endpoints, var.tools.denied_mcp_endpoints) : length(regexall("\\*", e)) <= 1])
    error_message = "MCP endpoint patterns support at most one \"*\" wildcard, for example \"https://mcp.contoso.com/*\"."
  }
}

variable "safety" {
  description = "Agent safety (audit-only): agents keep a required prompt content filter enabled and blocking."
  type = object({
    enabled      = optional(bool, false)
    effect       = optional(string, "Audit")
    filter_name  = optional(string, "Jailbreak")
    entity_kinds = optional(list(string), ["prompt", "hosted"])
  })
  default = {}

  validation {
    condition     = contains(["Audit", "Disabled"], var.safety.effect)
    error_message = "safety.effect must be Audit or Disabled (the policy doesn't support Deny)."
  }

  validation {
    condition     = contains(["Jailbreak", "Indirect Attack", "Indirect Attack Spotlighting", "Profanity"], var.safety.filter_name)
    error_message = "safety.filter_name must be Jailbreak, Indirect Attack, Indirect Attack Spotlighting or Profanity."
  }
}

variable "egress" {
  description = "Hosted-agent egress controls: hosted agents must reference an RAI policy whose egress section is Enforced, default Deny and only permits traffic to permitted_destinations (host, host/path or host/path/*; up to 100 entries). effect is the Azure Policy effect, not the RAI egress mode. Assigned when permitted_destinations is set (or enabled = true; an empty list then permits no traffic-permitting rules)."
  type = object({
    effect                 = optional(string, "Audit")
    enabled                = optional(bool)
    permitted_destinations = optional(list(string), [])
    denied_destinations    = optional(list(string), [])
    allowed_action_types   = optional(list(string), ["Allow", "Deny", "Transform", "Rewrite"])
    rai_policy_controls    = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.egress.effect)
    error_message = "egress.effect must be Audit, Deny or Disabled."
  }

  validation {
    condition     = alltrue([for a in var.egress.allowed_action_types : contains(["Allow", "Deny", "Transform", "Rewrite"], a)])
    error_message = "egress.allowed_action_types may only contain Allow, Deny, Transform and Rewrite."
  }

  validation {
    condition     = alltrue([for d in concat(var.egress.permitted_destinations, var.egress.denied_destinations) : length(regexall("[:?#@ ]", d)) == 0])
    error_message = "Egress destinations are host, host/path or host/path/* — no schemes, ports, queries, fragments or spaces."
  }

  validation {
    condition     = length(var.egress.permitted_destinations) <= 100 && length(var.egress.denied_destinations) <= 100
    error_message = "egress.permitted_destinations and egress.denied_destinations support up to 100 entries each."
  }
}

variable "initiative" {
  description = "Bundle the planned controls into one custom initiative (policy set definition) and assign that instead of separate policies (agent-kind policies stay direct). assign_individually = true also keeps every control as its own assignment."
  type = object({
    enabled             = optional(bool, false)
    name                = optional(string)
    display_name        = optional(string)
    assign_individually = optional(bool, false)
  })
  default = {}
}
