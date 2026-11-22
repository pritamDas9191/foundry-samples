// =============================================================================
// Microsoft Foundry governance – built-in Azure Policy controls for Foundry
// agents, models, tools, hosted-agent egress and agent safety, assigned as code
// (individually, or bundled into one custom initiative).
//
// Deploy at subscription scope:
//   az deployment sub create --location <region> --template-file main.bicep \
//     --parameters audit-baseline.bicepparam
//
// Deploy to one resource group (set resourceGroupName):
//   az deployment sub create --location <region> --template-file main.bicep \
//     --parameters audit-baseline.bicepparam resourceGroupName=<resource-group>
//
// Deploy to specific Foundry resources (recommended for tool policies; set
// foundryResourceIds to the full resource IDs of the Foundry resources).
//
// Rule of thumb: an empty list means "don't assign that policy". The template
// never assigns an allow-list policy with an empty list, because with Deny
// that would block every agent, model or tool.
// =============================================================================

targetScope = 'subscription'

metadata description = 'Assigns Microsoft Foundry built-in Azure Policy controls for agents, models, tools, hosted-agent egress and agent safety at subscription, resource group or Foundry resource scope, individually or as one custom initiative.'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

@description('Effect for controls that can block requests.')
type effect = 'Audit' | 'Deny' | 'Disabled'

@description('Agent kind and hosted-agent container image controls.')
type agentControls = {
  @description('Audit (default), Deny or Disabled.')
  effect: effect?

  @description('Only these agent kinds are allowed, for example ["prompt", "hosted", "workflow"]. Empty = not assigned.')
  allowedAgentKinds: string[]?

  @description('These agent kinds are denied, for example ["external"]. Empty = not assigned.')
  deniedAgentKinds: string[]?

  @description('Hosted agents may only use these images, for example ["contoso.azurecr.io/*"]. Empty = not assigned.')
  allowedContainerImages: string[]?

  @description('Hosted agents may not use these images, for example ["docker.io/*"]. Empty = not assigned.')
  deniedContainerImages: string[]?
}

@description('Model deployment controls.')
type modelControls = {
  @description('Audit (default), Deny or Disabled.')
  effect: effect?

  @description('Approved model publishers, for example ["OpenAI", "Microsoft"]. Use the publisher name from the model card.')
  allowedPublishers: string[]?

  @description('Approved model asset IDs or prefixes, for example ["azureml://registries/azure-openai/models/gpt-4.1/"]. Matched with "contains".')
  allowedAssetIds: string[]?

  @description('Block models whose lifecycle status is Preview.')
  denyPreviewModels: bool?

  @description('Only allow models that are distributed directly from Azure.')
  onlyAllowDirectFromAzure: bool?
}

@description('Tool controls, evaluated when a toolbox or a prompt agent (Responses API, without the Copilot harness) is saved. Hosted agents are governed through the toolboxes they call.')
type toolControls = {
  @description('Audit (default), Deny or Disabled.')
  effect: effect?

  @description('Approved tool types from the Foundry tool type catalog, for example ["file_search", "code_interpreter", "web_search"]. Adding "mcp" approves every MCP server.')
  approvedToolTypes: string[]?

  @description('Approved MCP server URLs or patterns, including toolbox MCP endpoints your agents call. Case-insensitive; at most one "*" per value, for example "https://learn.microsoft.com/api/mcp*".')
  approvedMcpEndpoints: string[]?

  @description('Approved MCP connector IDs.')
  approvedMcpConnectors: string[]?

  @description('Denied tool types, for example ["browser_automation", "computer_use"].')
  deniedToolTypes: string[]?

  @description('Denied MCP server URLs, for example ["https://mcp.example.com/*"].')
  deniedMcpEndpoints: string[]?

  @description('Denied MCP connector IDs.')
  deniedMcpConnectors: string[]?
}

@description('Agent safety: audit that agents keep a required prompt content filter on. Audit-only.')
type safetyControls = {
  @description('Assign the agent prompt content filter policy. Default: false.')
  enabled: bool?

  @description('Audit (default) or Disabled. This policy does not support Deny.')
  effect: ('Audit' | 'Disabled')?

  @description('Prompt content filter that must be enabled and blocking. Default: Jailbreak.')
  filterName: ('Jailbreak' | 'Indirect Attack' | 'Indirect Attack Spotlighting' | 'Profanity')?

  @description('Agent entity kinds evaluated by the policy. Default: ["prompt", "hosted"].')
  entityKinds: string[]?
}

@description('Hosted-agent egress controls, plus the matching checks on the RAI policies that carry the egress rules.')
type egressControls = {
  @description('Audit (default), Deny or Disabled. Applies to all egress policies. This is the Azure Policy effect, not the RAI egress mode: the policies always require the RAI egress mode to be Enforced.')
  effect: effect?

  @description('Assign the egress policies. Default: true when permittedDestinations is set. Set true with an empty list to permit no traffic-permitting rules at all (an empty list never means unrestricted).')
  enabled: bool?

  @description('Destinations that traffic-permitting egress rules may cover: host, host/path or host/path/*, for example ["api.contoso.com/public/*", "*.contoso.com/public/*"]. No schemes, ports, queries or fragments. Up to 100 entries.')
  @maxLength(100)
  permittedDestinations: string[]?

  @description('Destinations excluded even if they fall inside a permitted one, for example ["api.contoso.com/admin/*"]. A permission never overrides a denial. Up to 100 entries.')
  @maxLength(100)
  deniedDestinations: string[]?

  @description('Egress rule actions developers may use. Default: Allow, Deny, Transform, Rewrite.')
  allowedActionTypes: ('Allow' | 'Deny' | 'Transform' | 'Rewrite')[]?

  @description('Also check the RAI policy resources themselves (baseline, header safety, rewrite targets) when they are created or updated. Default: true.')
  raiPolicyControls: bool?
}

@description('Bundle the planned controls into one custom initiative (policy set) and assign that instead of individual policies. Agent-kind policies always stay direct assignments.')
type initiativeOptions = {
  @description('Default: false (assign each policy separately).')
  enabled: bool?

  @description('Initiative (policy set definition) name. Default: <assignmentPrefix>-foundry-governance.')
  name: string?

  @description('Initiative display name. Default: "Initiative: Foundry agents, models, tools and egress (<displayNamePrefix>)".')
  displayName: string?

  @description('Also assign every control individually, alongside the initiative. Default: false.')
  assignIndividually: bool?
}

@description('One planned policy assignment.')
type plannedAssignment = {
  key: string
  displayName: string
  policyDefinitionId: string
  @description('Major-version selector: 1.*.*-preview for preview built-ins, 1.*.* for GA built-ins.')
  definitionVersion: string
  parameters: object
}

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Optional. Resource group in this subscription to scope the assignments to. Empty = whole subscription. Ignored when foundryResourceIds is set.')
param resourceGroupName string = ''

@description('Optional. Full resource IDs of Foundry resources (Microsoft.CognitiveServices/accounts) in this subscription. When set, every control is assigned at each of these resources instead of the subscription or resource group. Recommended for tool policies: each assignment can evaluate only a limited number of agents and toolboxes.')
param foundryResourceIds string[] = []

@description('Prefix for assignment names (<prefix>-<control>).')
@minLength(1)
@maxLength(10)
param assignmentPrefix string = 'fg'

@description('Label appended to assignment display names, for example "Tools: only approved tools (Contoso)". Display names lead with the area so they stay readable when Foundry truncates them.')
param displayNamePrefix string = 'Foundry governance'

@description('Default enforces the effects. DoNotEnforce evaluates and reports compliance without blocking (what-if mode).')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Resource IDs inside the scope to exclude, for example a sandbox resource group or Foundry account.')
param notScopes string[] = []

@description('Agent kind and hosted-agent container image controls.')
param agents agentControls = {}

@description('Model deployment controls.')
param models modelControls = {}

@description('Tool controls for toolboxes and prompt agents.')
param tools toolControls = {}

@description('Agent safety (audit-only) controls.')
param safety safetyControls = {}

@description('Hosted-agent egress controls.')
param egress egressControls = {}

@description('Assign everything as one custom initiative instead of separate policy assignments.')
param initiative initiativeOptions = {}

// ---------------------------------------------------------------------------
// Rules: which built-in policies to assign, with which parameters
// ---------------------------------------------------------------------------

func builtIn(policyId string) string => '/providers/Microsoft.Authorization/policyDefinitions/${policyId}'

func listOrEmpty(value string[]?) string[] => value ?? []

func agentAssignments(c agentControls) plannedAssignment[] => concat(
  empty(listOrEmpty(c.?allowedAgentKinds))
    ? []
    : [
        {
          key: 'agent-kinds-allow'
          displayName: 'Agents: only allowed agent kinds'
          policyDefinitionId: builtIn('85455646-5d02-433e-a42d-265151140427')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            allowedAgentKinds: { value: listOrEmpty(c.?allowedAgentKinds) }
          }
        }
      ],
  empty(listOrEmpty(c.?deniedAgentKinds))
    ? []
    : [
        {
          key: 'agent-kinds-deny'
          displayName: 'Agents: no denied agent kinds'
          policyDefinitionId: builtIn('b6ca2367-8597-4a3f-ab19-48f58d6d9278')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            deniedAgentKinds: { value: listOrEmpty(c.?deniedAgentKinds) }
          }
        }
      ],
  empty(listOrEmpty(c.?allowedContainerImages))
    ? []
    : [
        {
          key: 'agent-images-allow'
          displayName: 'Hosted agents: only allowed container images'
          policyDefinitionId: builtIn('d0d9ac6c-628b-46c1-a177-eb22b12ce588')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            allowedContainerImages: { value: listOrEmpty(c.?allowedContainerImages) }
          }
        }
      ],
  empty(listOrEmpty(c.?deniedContainerImages))
    ? []
    : [
        {
          key: 'agent-images-deny'
          displayName: 'Hosted agents: no denied container images'
          policyDefinitionId: builtIn('215c2c77-3afb-4f55-be2f-709b60dc8d53')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            deniedContainerImages: { value: listOrEmpty(c.?deniedContainerImages) }
          }
        }
      ]
)

func modelAssignments(c modelControls) plannedAssignment[] => concat(
  empty(listOrEmpty(c.?allowedPublishers)) && empty(listOrEmpty(c.?allowedAssetIds))
    ? []
    : [
        {
          key: 'models-approved'
          displayName: 'Models: only approved models'
          policyDefinitionId: builtIn('aafe3651-cb78-4f68-9f81-e7e41509110f')
          definitionVersion: '1.*.*'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            allowedPublishers: { value: listOrEmpty(c.?allowedPublishers) }
            allowedAssetIds: { value: listOrEmpty(c.?allowedAssetIds) }
          }
        }
      ],
  !(c.?denyPreviewModels ?? false) && !(c.?onlyAllowDirectFromAzure ?? false)
    ? []
    : [
        {
          key: 'models-eligibility'
          displayName: 'Models: meet eligibility (no preview, direct from Azure)'
          policyDefinitionId: builtIn('8791d062-ba96-4c34-b604-8538f7e30ca0')
          definitionVersion: '1.*.*'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            denyPreviewModels: { value: c.?denyPreviewModels ?? false }
            onlyAllowDirectFromAzure: { value: c.?onlyAllowDirectFromAzure ?? false }
          }
        }
      ]
)

func toolAssignments(c toolControls) plannedAssignment[] => concat(
  empty(listOrEmpty(c.?approvedToolTypes)) && empty(listOrEmpty(c.?approvedMcpEndpoints)) && empty(listOrEmpty(c.?approvedMcpConnectors))
    ? []
    : [
        {
          key: 'tools-approved'
          displayName: 'Tools: only approved tools and MCP servers'
          policyDefinitionId: builtIn('e7352ad2-6c86-4a07-9573-47f67b557ba8')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            approvedToolTypes: { value: listOrEmpty(c.?approvedToolTypes) }
            approvedMcpEndpoints: { value: listOrEmpty(c.?approvedMcpEndpoints) }
            approvedMcpConnectors: { value: listOrEmpty(c.?approvedMcpConnectors) }
          }
        }
      ],
  empty(listOrEmpty(c.?deniedToolTypes)) && empty(listOrEmpty(c.?deniedMcpEndpoints)) && empty(listOrEmpty(c.?deniedMcpConnectors))
    ? []
    : [
        {
          key: 'tools-denied'
          displayName: 'Tools: no denied tools or MCP servers'
          policyDefinitionId: builtIn('7740c22b-07ef-4bac-9f5a-e38d188f80b7')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            deniedToolTypes: { value: listOrEmpty(c.?deniedToolTypes) }
            deniedMcpEndpoints: { value: listOrEmpty(c.?deniedMcpEndpoints) }
            deniedMcpConnectors: { value: listOrEmpty(c.?deniedMcpConnectors) }
          }
        }
      ]
)

func safetyAssignments(c safetyControls) plannedAssignment[] => !(c.?enabled ?? false)
  ? []
  : [
      {
        key: 'agent-prompt-filter'
        displayName: 'Safety: agents keep the ${c.?filterName ?? 'Jailbreak'} prompt filter on'
        policyDefinitionId: builtIn('9224c1cc-34fc-44f1-ad08-5c4b079c9ce6')
        definitionVersion: '1.*.*-preview'
        parameters: {
          effect: { value: c.?effect ?? 'Audit' }
          filterName: { value: c.?filterName ?? 'Jailbreak' }
          entityKind: { value: c.?entityKinds ?? ['prompt', 'hosted'] }
          allowedEnabledForPrompt: { value: ['true'] }
          allowedBlockingForPrompt: { value: ['true'] }
        }
      }
    ]

func egressEnabled(c egressControls) bool => c.?enabled ?? !empty(listOrEmpty(c.?permittedDestinations))

func egressAssignments(c egressControls) plannedAssignment[] => !egressEnabled(c)
  ? []
  : concat(
      [
        {
          key: 'agent-egress'
          displayName: 'Egress: hosted agents use an enforced RAI egress allow-list'
          policyDefinitionId: builtIn('d279dbb1-e60e-4ca0-8c2f-cc7a0f46166b')
          definitionVersion: '1.*.*-preview'
          parameters: {
            effect: { value: c.?effect ?? 'Audit' }
            permittedDestinations: { value: listOrEmpty(c.?permittedDestinations) }
            deniedDestinations: { value: listOrEmpty(c.?deniedDestinations) }
            allowedActionTypes: { value: c.?allowedActionTypes ?? ['Allow', 'Deny', 'Transform', 'Rewrite'] }
          }
        }
      ],
      !(c.?raiPolicyControls ?? true)
        ? []
        : [
            {
              key: 'rai-egress-baseline'
              displayName: 'Egress: RAI policies meet the egress baseline'
              policyDefinitionId: builtIn('0cfd954d-079f-447f-91bf-89889e9d1de0')
              definitionVersion: '1.*.*-preview'
              parameters: {
                effect: { value: c.?effect ?? 'Audit' }
                permittedDestinations: { value: listOrEmpty(c.?permittedDestinations) }
                deniedDestinations: { value: listOrEmpty(c.?deniedDestinations) }
                allowedActionTypes: { value: c.?allowedActionTypes ?? ['Allow', 'Deny', 'Transform', 'Rewrite'] }
              }
            }
            {
              key: 'rai-egress-headers'
              displayName: 'Egress: RAI policy headers use references and HTTPS'
              policyDefinitionId: builtIn('29be091c-88f9-419b-8ad9-82ce5dc452d3')
              definitionVersion: '1.*.*-preview'
              parameters: {
                effect: { value: c.?effect ?? 'Audit' }
              }
            }
            {
              key: 'rai-egress-rewrites'
              displayName: 'Egress: RAI policy rewrites stay on permitted hosts'
              policyDefinitionId: builtIn('64a15c51-9797-4d6b-93a5-16b19e7de23b')
              definitionVersion: '1.*.*-preview'
              parameters: {
                effect: { value: c.?effect ?? 'Audit' }
                permittedDestinations: { value: listOrEmpty(c.?permittedDestinations) }
                deniedDestinations: { value: listOrEmpty(c.?deniedDestinations) }
              }
            }
          ]
    )

var plan = concat(
  agentAssignments(agents),
  modelAssignments(models),
  toolAssignments(tools),
  safetyAssignments(safety),
  egressAssignments(egress)
)

// Agent-kind policies stay as direct assignments even in initiative mode: the Foundry
// create-agent experience only detects them up front when they're assigned directly.
var directOnlyKeys = [
  'agent-kinds-allow'
  'agent-kinds-deny'
]
var initiativeMembers = filter(plan, a => !contains(directOnlyKeys, a.key))
var useInitiative = (initiative.?enabled ?? false) && !empty(initiativeMembers)
var initiativeName = initiative.?name ?? '${assignmentPrefix}-foundry-governance'
var directPlan = useInitiative && !(initiative.?assignIndividually ?? false)
  ? filter(plan, a => contains(directOnlyKeys, a.key))
  : plan
var initiativeDisplayName = initiative.?displayName ?? 'Initiative: Foundry agents, models, tools and egress (${displayNamePrefix})'

// Members keep their own parameter values, so the initiative is self-contained.
resource governanceInitiative 'Microsoft.Authorization/policySetDefinitions@2025-03-01' = if (useInitiative) {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: initiativeDisplayName
    description: 'Microsoft Foundry governance controls bundled by the 06-foundry-governance template.'
    metadata: {
      category: 'Cognitive Services'
      source: 'foundry-samples/06-foundry-governance'
    }
    policyDefinitions: [
      for a in initiativeMembers: {
        policyDefinitionReferenceId: a.key
        policyDefinitionId: a.policyDefinitionId
        definitionVersion: a.definitionVersion
        parameters: a.parameters
      }
    ]
  }
}

var individualAssignments = [
  for a in directPlan: {
    name: '${assignmentPrefix}-${a.key}'
    properties: {
      displayName: '${a.displayName} (${displayNamePrefix})'
      description: 'Assigned by the Microsoft Foundry governance template (06-foundry-governance).'
      policyDefinitionId: a.policyDefinitionId
      definitionVersion: a.definitionVersion
      enforcementMode: enforcementMode
      notScopes: notScopes
      parameters: a.parameters
      metadata: {
        source: 'foundry-samples/06-foundry-governance'
      }
    }
  }
]

var initiativeAssignment = !useInitiative
  ? []
  : [
      {
        name: initiativeName
        properties: {
          displayName: initiativeDisplayName
          description: 'Assigned by the Microsoft Foundry governance template (06-foundry-governance).'
          policyDefinitionId: subscriptionResourceId('Microsoft.Authorization/policySetDefinitions', initiativeName)
          enforcementMode: enforcementMode
          notScopes: notScopes
          metadata: {
            source: 'foundry-samples/06-foundry-governance'
          }
        }
      }
    ]

var assignmentDefinitions = concat(individualAssignments, initiativeAssignment)

// Narrowest scope wins: Foundry resources, then a resource group, then the subscription.
var scopeKind = !empty(foundryResourceIds) ? 'foundryResource' : (!empty(resourceGroupName) ? 'resourceGroup' : 'subscription')

// ---------------------------------------------------------------------------
// Assignments
// ---------------------------------------------------------------------------

resource subscriptionAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for a in (scopeKind == 'subscription' ? assignmentDefinitions : []): {
    name: a.name
    properties: a.properties
    dependsOn: [
      governanceInitiative
    ]
  }
]

// Bicep needs a module to deploy to a different scope than the file's targetScope.
module resourceGroupAssignments 'modules/assign-to-resource-group.bicep' = if (scopeKind == 'resourceGroup') {
  name: '${assignmentPrefix}-foundry-governance'
  scope: resourceGroup(empty(resourceGroupName) ? 'unused' : resourceGroupName)
  params: {
    assignments: assignmentDefinitions
  }
  dependsOn: [
    governanceInitiative
  ]
}

module foundryResourceAssignments 'modules/assign-to-foundry-resource.bicep' = [
  for (id, i) in foundryResourceIds: {
    name: '${assignmentPrefix}-foundry-governance-${i}'
    scope: resourceGroup(split(id, '/')[2], split(id, '/')[4])
    params: {
      foundryResourceName: last(split(id, '/'))
      assignments: assignmentDefinitions
    }
    dependsOn: [
      governanceInitiative
    ]
  }
]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

@description('Scopes the policies were assigned to.')
output scopes string[] = scopeKind == 'foundryResource'
  ? foundryResourceIds
  : [scopeKind == 'resourceGroup' ? '${subscription().id}/resourceGroups/${resourceGroupName}' : subscription().id]

@description('Custom initiative resource ID, when initiative.enabled is true.')
output initiativeId string = useInitiative ? governanceInitiative.id : ''

@description('Controls assigned directly.')
output directControls array = [for a in directPlan: a.key]

@description('Controls bundled in the initiative (empty when initiative.enabled is false).')
output initiativeControls array = useInitiative ? map(initiativeMembers, a => a.key) : []

@description('Assignments that were created or updated.')
output assignments array = [
  for a in assignmentDefinitions: {
    name: a.name
    displayName: a.properties.displayName
    policyDefinitionId: a.properties.policyDefinitionId
  }
]
