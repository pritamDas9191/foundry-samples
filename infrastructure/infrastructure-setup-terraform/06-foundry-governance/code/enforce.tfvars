# Enforce: block non-compliant agents, models, tools and hosted-agent egress (Deny).
# Agent safety stays Audit — that policy doesn't support Deny.
# Tip: run with enforce = false first to check the assignments without blocking anyone.
# Replace the example values (subscription, contoso, publishers, tool types).

subscription_id     = "<subscription-id>"
resource_group_name = null # or "<resource-group>"
assignment_prefix   = "fg"
enforce             = true

# Recommended for tool policies: assign at each Foundry resource instead of the
# whole subscription (each assignment can evaluate only a limited number of
# agents and toolboxes). Takes precedence over resource_group_name.
# foundry_resource_ids = [
#   "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>",
# ]

agents = {
  effect                   = "Deny"
  allowed_agent_kinds      = ["prompt", "hosted", "workflow"]
  allowed_container_images = ["contoso.azurecr.io/*"]
}

models = {
  effect              = "Deny"
  allowed_publishers  = ["OpenAI", "Microsoft"]
  deny_preview_models = true
}

# Evaluated when a toolbox or a prompt agent (Responses API, without the Copilot
# harness) is saved. Use values from the tool type catalog in the Bicep README.
# Don't add "mcp" to approved_tool_types: it approves every MCP server. If agents
# call a toolbox over MCP, also approve the toolbox's MCP endpoint.
tools = {
  effect                 = "Deny"
  approved_tool_types    = ["web_search", "file_search", "code_interpreter", "azure_ai_search", "function"]
  approved_mcp_endpoints = ["https://learn.microsoft.com/api/mcp*"]
  denied_tool_types      = ["browser_automation", "computer_use"]
}

safety = {
  enabled     = true
  effect      = "Audit"
  filter_name = "Jailbreak"
}

# Hosted-agent egress: hosted agents must reference an RAI policy whose egress
# section is Enforced, default Deny and only permits traffic to these destinations
# (host, host/path or host/path/*; no https://). The RAI policies themselves are
# checked too (rai_policy_controls). Keep the Application Insights entry if your
# hosted agents send telemetry; their RAI policy then allows the exact regional
# ingestion host, for example eastus2-3.in.applicationinsights.azure.com.
egress = {
  effect = "Deny"
  permitted_destinations = [
    "api.contoso.com/public/*",
    "*.in.applicationinsights.azure.com",
  ]
  denied_destinations = [
    "api.contoso.com/admin/*",
  ]
}
