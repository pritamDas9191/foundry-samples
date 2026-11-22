// Creates the given policy assignments on one Foundry resource
// (Microsoft.CognitiveServices/accounts) in this resource group.
// main.bicep calls this once per entry in foundryResourceIds.

targetScope = 'resourceGroup'

@description('Name of the Foundry resource.')
param foundryResourceName string

@description('Assignments to create: [{ name, properties }], built by main.bicep.')
param assignments array

resource foundryResource 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryResourceName
}

resource policyAssignments 'Microsoft.Authorization/policyAssignments@2024-04-01' = [
  for a in assignments: {
    name: a.name
    scope: foundryResource
    properties: a.properties
  }
]
