// Enforce: block non-compliant agents, models, tools and hosted-agent egress (Deny).
// Agent safety stays Audit — that policy doesn't support Deny.
//
// Start with audit-baseline.bicepparam, review compliance, then switch to this
// profile. Tip: deploy with enforcementMode = 'DoNotEnforce' first to check the
// assignments without blocking anyone.
//
// Replace the example values (contoso, publishers, tool types) with your own.
using 'main.bicep'

param assignmentPrefix = 'fg'
param enforcementMode = 'Default'

// Recommended for tool policies: assign at each Foundry resource instead of the
// whole subscription (each assignment can evaluate only a limited number of
// agents and toolboxes). Leave unset to assign at the subscription, or pass
// resourceGroupName=<resource-group> on the command line.
// param foundryResourceIds = [
//   '/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>'
// ]

param agents = {
  effect: 'Deny'
  allowedAgentKinds: [
    'prompt'
    'hosted'
    'workflow'
  ]
  allowedContainerImages: [
    'contoso.azurecr.io/*'
  ]
}

param models = {
  effect: 'Deny'
  allowedPublishers: [
    'OpenAI'
    'Microsoft'
  ]
  denyPreviewModels: true
}

// Evaluated when a toolbox or a prompt agent (Responses API, without the
// Copilot harness) is saved. Use values from the tool type catalog in the
// README. Don't add 'mcp' to approvedToolTypes: it approves every MCP server.
// If agents call a toolbox over MCP, also approve the toolbox's MCP endpoint.
param tools = {
  effect: 'Deny'
  approvedToolTypes: [
    'web_search'
    'file_search'
    'code_interpreter'
    'azure_ai_search'
    'function'
  ]
  approvedMcpEndpoints: [
    'https://learn.microsoft.com/api/mcp*'
  ]
  deniedToolTypes: [
    'browser_automation'
    'computer_use'
  ]
}

param safety = {
  enabled: true
  effect: 'Audit'
  filterName: 'Jailbreak'
}

// Hosted-agent egress: hosted agents must reference an RAI policy whose egress
// section is Enforced, default Deny, and only permits traffic to these
// destinations (host, host/path or host/path/*; no https://). The RAI policies
// themselves are checked too (raiPolicyControls). Keep the Application Insights
// entry if your hosted agents send telemetry; their RAI policy then allows the
// exact regional ingestion host, for example eastus2-3.in.applicationinsights.azure.com.
param egress = {
  effect: 'Deny'
  permittedDestinations: [
    'api.contoso.com/public/*'
    '*.in.applicationinsights.azure.com'
  ]
  deniedDestinations: [
    'api.contoso.com/admin/*'
  ]
}
