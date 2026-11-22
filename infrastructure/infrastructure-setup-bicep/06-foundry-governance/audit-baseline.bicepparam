// Audit baseline: assign every control in Audit mode. Nothing is blocked;
// non-compliant agents, models, tools and egress rules show up in Azure Policy compliance
// and in Foundry (Manage > Govern) so you can see the impact first.
//
// Replace the example values (contoso, publishers, tool types) with your own
// before deploying. Keep the same controls in both profiles: switching from
// enforce back to this file then sets every assignment back to Audit.
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
  effect: 'Audit'
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
  effect: 'Audit'
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
  effect: 'Audit'
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
  filterName: 'Jailbreak'
}

// Hosted-agent egress: hosted agents must reference an RAI policy whose egress
// section is Enforced, default Deny, and only permits traffic to these
// destinations (host, host/path or host/path/*; no https://). The RAI policies
// themselves are checked too (raiPolicyControls). Keep the Application Insights
// entry if your hosted agents send telemetry; their RAI policy then allows the
// exact regional ingestion host, for example eastus2-3.in.applicationinsights.azure.com.
param egress = {
  effect: 'Audit'
  permittedDestinations: [
    'api.contoso.com/public/*'
    '*.in.applicationinsights.azure.com'
  ]
  deniedDestinations: [
    'api.contoso.com/admin/*'
  ]
}
