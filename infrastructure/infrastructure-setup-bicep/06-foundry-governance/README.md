---
description: Assign Microsoft Foundry built-in Azure Policy controls for agents, models, tools, hosted-agent egress and agent safety at subscription, resource group or Foundry resource scope, individually or as one custom initiative.
page_type: sample
products:
- azure
- azure-resource-manager
- azure-policy
urlFragment: foundry-governance-builtin-policies
languages:
- bicep
- json
---

# Govern Microsoft Foundry agents, models, tools and egress with Azure Policy

Microsoft Foundry ships **built-in Azure Policy definitions** that Foundry itself evaluates whenever an agent, toolbox, model deployment or RAI policy is created or updated. This sample assigns them as code, so you can decide — for a whole subscription, a resource group or specific Foundry resources — which:

- **agent kinds** can be created, and which **container images** hosted agents may run;
- **models** can be deployed (approved publishers or model IDs, no preview models, only direct-from-Azure models);
- **tools and MCP servers** toolboxes and prompt agents may be saved with;
- **outbound destinations** hosted agents may reach (egress), and how the RAI policies that carry those egress rules must be written;
- **safety settings** agents must keep (audit only).

Assign the controls one by one (default) or bundled into **one custom initiative** (`initiative.enabled = true`).

Start in **Audit** to see what would be affected, then switch the controls you're confident about to **Deny**.

> These built-ins use the Azure Policy resource-provider mode `Microsoft.CognitiveServices.Data`. In this mode only built-in definitions can be assigned — custom definitions aren't supported yet. For custom rules on Azure resources (connections, account kinds, authentication), see [`05-custom-policy-definitions`](../05-custom-policy-definitions/).

## Controls

| Area | Control | Built-in policy | Effects | Assigned when |
|---|---|---|---|---|
| Agents | Only allowed agent kinds | [85455646-5d02-433e-a42d-265151140427][p-kinds-allow] (preview) | Audit, Deny, Disabled | `agents.allowedAgentKinds` is set |
| Agents | No denied agent kinds | [b6ca2367-8597-4a3f-ab19-48f58d6d9278][p-kinds-deny] (preview) | Audit, Deny, Disabled | `agents.deniedAgentKinds` is set |
| Hosted agents | Only allowed container images | [d0d9ac6c-628b-46c1-a177-eb22b12ce588][p-images-allow] (preview) | Audit, Deny, Disabled | `agents.allowedContainerImages` is set |
| Hosted agents | No denied container images | [215c2c77-3afb-4f55-be2f-709b60dc8d53][p-images-deny] (preview) | Audit, Deny, Disabled | `agents.deniedContainerImages` is set |
| Models | Only approved models (publisher **or** asset ID) | [aafe3651-cb78-4f68-9f81-e7e41509110f][p-models] ([source][g-models]) | Audit, Deny, Disabled | `models.allowedPublishers` or `models.allowedAssetIds` is set |
| Models | Eligibility: no preview models, only direct from Azure | [8791d062-ba96-4c34-b604-8538f7e30ca0][p-elig] ([source][g-elig]) | Audit, Deny, Disabled | `models.denyPreviewModels` or `models.onlyAllowDirectFromAzure` is `true` |
| Tools | Only approved tools (type **or** MCP endpoint **or** MCP connector) | [e7352ad2-6c86-4a07-9573-47f67b557ba8][p-tools-allow] (preview, [source][g-tools-allow]) | Audit, Deny, Disabled | any `tools.approved*` list is set |
| Tools | No denied tools | [7740c22b-07ef-4bac-9f5a-e38d188f80b7][p-tools-deny] (preview, [source][g-tools-deny]) | Audit, Deny, Disabled | any `tools.denied*` list is set |
| Safety | Agents keep a prompt content filter (default **Jailbreak**) enabled and blocking | [9224c1cc-34fc-44f1-ad08-5c4b079c9ce6][p-safety] (preview, [source][g-safety]) | Audit, Disabled | `safety.enabled` is `true` |
| Egress | Hosted agents reference an RAI policy whose egress section is **Enforced**, default **Deny**, and only allows permitted destinations | [d279dbb1-e60e-4ca0-8c2f-cc7a0f46166b][p-egress] (preview) | Audit, Deny, Disabled | `egress.permittedDestinations` is set (or `egress.enabled` is `true`) |
| Egress (RAI policy) | RAI policies with an egress section use the baseline (Enforced, default Deny, permitted FQDN sources) | [0cfd954d-079f-447f-91bf-89889e9d1de0][p-rai-baseline] (preview) | Audit, Deny, Disabled | egress is assigned and `egress.raiPolicyControls` isn't `false` |
| Egress (RAI policy) | Egress headers use safe operations, secret / managed-identity references and HTTPS | [29be091c-88f9-419b-8ad9-82ce5dc452d3][p-rai-headers] (preview) | Audit, Deny, Disabled | same |
| Egress (RAI policy) | Rewrite targets stay inside permitted destinations | [64a15c51-9797-4d6b-93a5-16b19e7de23b][p-rai-rewrites] (preview) | Audit, Deny, Disabled | same |

What each control evaluates:

- **Tools** — saved **toolboxes** and **prompt agents** that use the Responses API without the [Microsoft Copilot harness](https://learn.microsoft.com/azure/foundry/agents/how-to/use-tools-skills-copilot-harness). Hosted agents run your own code, which the policy doesn't inspect: govern their Foundry tool access through the toolboxes they call (a non-compliant toolbox doesn't block hosted-agent creation). The policies check configurations when they're saved; to restrict which tools can actually **run**, also set [project tool controls](#runtime-tool-access-project-tool-controls).
- **Egress** — new **hosted agent** versions (the RAI policy they resolve to) and the RAI policies themselves. The three *RAI policy* controls are Azure Resource Manager policies (mode `All`) on `Microsoft.CognitiveServices/accounts/raiPolicies`, so they act on every RAI policy create or update. Prompt agents that use the Copilot harness have runtime egress controls but aren't covered by these policies. Azure Policy governance for egress is in **preview in Canada Central, Spain Central and Korea Central**; runtime egress enforcement itself is generally available (except Transform rules).
- **Agent kinds, container images and safety** — agents when they're created or updated.
- **Models** — model deployments, including the models that [model router](https://learn.microsoft.com/azure/foundry/how-to/model-router-policy) can route to.

**More built-in policies for Foundry** (not assigned by this sample — see the [Foundry built-in policy index](https://learn.microsoft.com/azure/ai-services/policy-reference)):

- Agent multi-severity content filters (Hate, Sexual, Violence, Self-harm): [595f98a5-b562-4ab6-b9c8-2ff9f39a3f7c][p-agent-multi].
- Model deployment guardrails — the **[Preview]: Guardrail for Cognitive Services Deployments** initiative [5207647b-3e83-4e28-b836-c382cb5e2a2e][p-guardrail-initiative] (prompt, completion and multi-severity content filters, filter mode).
- Platform security for the Foundry resource: disable key access [71ef260a-8f18-47b7-abcb-62d0673d94dc][p-localauth], restrict network access [037eea7a-bd0a-46c5-9a66-03aea78705d3][p-network], use Private Link [d6759c02-b87f-42b7-892e-71b3f471d782][p-privatelink], customer-managed keys [67121cc7-ff39-4ab8-b7e3-95b84dab487d][p-cmk], diagnostic logs [1b4d1c4e-934c-4703-944c-27c82c06bebb][p-diag].

## Quick start

Prerequisites:

- Azure CLI with Bicep.
- **Owner** or **Resource Policy Contributor** on the target subscription, resource group or Foundry resource (to create policy assignments).
- Permission to create deployments at **subscription** scope (`Microsoft.Resources/deployments/write`, for example Contributor on the subscription). `main.bicep` is a subscription-scope template, even when you target one resource group. If you only have rights on a resource group, use the Terraform version or ask a subscription admin to deploy.

1. Copy `audit-baseline.bicepparam` and replace the example values (`contoso.azurecr.io`, publishers, tool types, MCP URLs) with your own.
2. Preview and deploy in Audit mode:

   ```bash
   # Whole subscription
   az deployment sub what-if --location <region> --template-file main.bicep --parameters audit-baseline.bicepparam
   az deployment sub create  --location <region> --template-file main.bicep --parameters audit-baseline.bicepparam

   # One resource group (for example a pilot team)
   az deployment sub create --location <region> --template-file main.bicep \
     --parameters audit-baseline.bicepparam resourceGroupName=<resource-group>

   # Specific Foundry resources (recommended for tool policies)
   az deployment sub create --location <region> --template-file main.bicep \
     --parameters audit-baseline.bicepparam \
     foundryResourceIds='["/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>"]'
   ```

   **Pick the narrowest scope that covers what you govern.** Each assignment can evaluate only a limited number of agents and toolboxes, so a subscription-wide assignment can leave some unevaluated; assign at each Foundry resource whenever you can. Don't scope egress below the Foundry resource: RAI policies live on the resource, not in projects.

   Add `initiative='{"enabled": true}'` to the command (or set `param initiative` in the parameter file) to assign everything as one custom initiative.

3. Wait for the assignments to take effect — up to **30 minutes** for tool, agent and model controls and **30–60 minutes** for hosted-agent egress. The same wait applies every time you change an assignment, including Audit → Deny. Then check **Azure Policy › Compliance** and the Foundry portal **Manage › Govern** page. Compliance reporting runs separately and can take up to **12 hours**; it also reports agents, toolboxes and deployments that existed before you assigned the policies.
4. Verify before you enforce: in a test project, save a compliant and a non-compliant toolbox (or prompt agent), RAI policy and **new** hosted agent version, and confirm the results in compliance. Re-submitting an unchanged agent definition can return the existing version and isn't a new evaluation.
5. When you're happy with the impact, deploy `enforce.bicepparam` (Deny) the same way, wait again, and repeat the checks — non-compliant saves should now fail with an error that names the assignment. `enforcementMode=DoNotEnforce` turns off blocking for every control at once; it isn't the same as the `Audit` effect.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `resourceGroupName` | `''` | Resource group in the subscription to scope to. Empty = whole subscription. Ignored when `foundryResourceIds` is set. |
| `foundryResourceIds` | `[]` | Full resource IDs of Foundry resources (`Microsoft.CognitiveServices/accounts`) to assign every control at, instead of the subscription or resource group. Recommended for tool policies. Use resources in the deployment subscription when `initiative.enabled` is `true`. |
| `assignmentPrefix` | `fg` | Assignment names are `<prefix>-<control>`, for example `fg-tools-approved`. |
| `displayNamePrefix` | `Foundry governance` | Label appended to every display name, for example `Tools: only approved tools and MCP servers (Contoso)`. Names lead with the area (`Agents:`, `Hosted agents:`, `Models:`, `Tools:`, `Egress:`, `Safety:`) so they stay readable when Foundry truncates them. |
| `enforcementMode` | `Default` | `DoNotEnforce` reports compliance without blocking. |
| `notScopes` | `[]` | Resource IDs inside the scope to exclude, for example a sandbox resource group or Foundry resource. Applies to every assignment. |
| `agents` | `{}` | `effect`, `allowedAgentKinds`, `deniedAgentKinds`, `allowedContainerImages`, `deniedContainerImages` |
| `models` | `{}` | `effect`, `allowedPublishers`, `allowedAssetIds`, `denyPreviewModels`, `onlyAllowDirectFromAzure` |
| `tools` | `{}` | `effect`, `approvedToolTypes`, `approvedMcpEndpoints`, `approvedMcpConnectors`, `deniedToolTypes`, `deniedMcpEndpoints`, `deniedMcpConnectors` |
| `safety` | `{}` | `enabled` (`false`), `effect` (`Audit`), `filterName` (`Jailbreak`), `entityKinds` (`["prompt", "hosted"]`) |
| `egress` | `{}` | `effect`, `enabled` (default: `true` when `permittedDestinations` is set), `permittedDestinations` and `deniedDestinations` (up to 100 each), `allowedActionTypes` (all four), `raiPolicyControls` (`true`) |
| `initiative` | `{}` | `enabled` (`false`), `name` (`<prefix>-foundry-governance`), `displayName` (`Initiative: Foundry agents, models, tools and egress (<displayNamePrefix>)`), `assignIndividually` (`false`: also assign every control on its own) |

Every `effect` defaults to `Audit`. **An empty list means the policy isn't assigned** — the template never assigns an allow-list with an empty list, because with Deny that blocks everything. The one exception is egress: set `egress.enabled: true` with an empty `permittedDestinations` to require hosted agents to have no traffic-permitting egress rules at all — for egress an empty list never means unrestricted.

## Examples

### Tools

| Goal | `tools` value | Notes |
|---|---|---|
| Built-in tools only, no MCP | `{ effect: 'Deny', approvedToolTypes: ['file_search', 'code_interpreter', 'web_search'] }` | Every MCP server and any other tool type is non-compliant. |
| Built-in tools plus approved MCP servers | `{ effect: 'Deny', approvedToolTypes: ['file_search', 'web_search'], approvedMcpEndpoints: ['https://learn.microsoft.com/api/mcp*', 'https://mcp.contoso.com/*'] }` | Don't add `mcp` to `approvedToolTypes` — that approves **every** MCP server by type. |
| Agents that call a toolbox over MCP | add the toolbox's MCP endpoint, for example `approvedMcpEndpoints: ['https://contoso-foundry.services.ai.azure.com/api/projects/*']` | The toolbox endpoint is approved separately from the tools inside it. The host suffix differs per cloud. |
| Approved MCP connectors | `{ effect: 'Deny', approvedMcpConnectors: ['<connector-id>'] }` | Matches connector-based MCP tools. |
| Block specific tool types | `{ effect: 'Deny', deniedToolTypes: ['browser_automation', 'computer_use'] }` | Uses the separate *denied tools* policy; everything else stays allowed. |
| Block one MCP server | `{ effect: 'Deny', deniedMcpEndpoints: ['https://mcp.untrusted.example.com/*'] }` | |

**Tool type catalog** — valid values for `approvedToolTypes` / `deniedToolTypes` (a reference list, not a recommendation; availability varies by API version, model and agent or toolbox integration):

`a2a`, `azure_ai_search`, `azure_function`, `bing_custom_search`, `bing_grounding`, `browser_automation`, `code_interpreter`, `computer_use`, `custom`, `fabric_dataagent`, `fabric_iq`, `file_search`, `function`, `image_generation`, `mcp`, `memory_search`, `openapi`, `reminder`, `sharepoint_grounding`, `shell`, `toolbox_search`, `web_search`, `work_iq`

### Agents

- Only prompt and workflow agents: `agents: { effect: 'Deny', allowedAgentKinds: ['prompt', 'workflow'] }`
- Hosted agents only from your registry: `agents: { effect: 'Deny', allowedContainerImages: ['contoso.azurecr.io/*'] }`

### Models

- Only OpenAI and Microsoft models: `models: { effect: 'Deny', allowedPublishers: ['OpenAI', 'Microsoft'] }`
- Only specific models: `models: { effect: 'Deny', allowedAssetIds: ['azureml://registries/azure-openai/models/gpt-4.1/'] }` — matched with *contains*; the trailing `/` stops `gpt-4.1` from also matching `gpt-4.1-mini`.
- No preview models: `models: { effect: 'Deny', denyPreviewModels: true }`

### Egress

- Hosted agents may call one API's public paths, never its admin paths:
  `egress: { effect: 'Deny', permittedDestinations: ['api.contoso.com/public/*'], deniedDestinations: ['api.contoso.com/admin/*'] }`
- Destination format is `host`, `host/path` or `host/path/*` — never a URL (`api.contoso.com/public/*`, not `https://api.contoso.com/public/*`); no ports, queries or fragments.

  | Value | Covers |
  |---|---|
  | `api.contoso.com` | the host and all its paths |
  | `api.contoso.com/public/item` | that path only, not its children |
  | `api.contoso.com/public/*` | that path subtree, not `/admin/` |
  | `*.contoso.com/public/*` | that subtree on `contoso.com` and its subdomains, not `contoso.com.example.net` |

  Hosts are case-insensitive. Hosted-agent checks treat permitted **paths** as case-sensitive (`/public/ITEM` doesn't satisfy `/public/item`); RAI-policy checks ignore path case.
- A permission never overrides a denial, and a broad Allow rule that overlaps a denied subtree is non-compliant even if another rule denies that subtree — write narrower rules. A Rewrite target must also be a permitted destination.
- The matching RAI policy (Foundry resource child `raiPolicies`, API `2026-05-15-preview` or later) that passes all four egress checks:

  ```json
  "egressPolicy": {
    "mode": "Enforced",
    "defaultAction": "Deny",
    "rules": [
      { "name": "allow-public-api", "ruleType": "Fqdn", "match": { "host": "api.contoso.com", "path": "/public/*" }, "action": { "actionType": "Allow" } },
      { "name": "allow-telemetry", "ruleType": "Fqdn", "match": { "host": "eastus2-3.in.applicationinsights.azure.com" }, "action": { "actionType": "Allow" } }
    ]
  }
  ```

  The telemetry rule needs `*.in.applicationinsights.azure.com` in `permittedDestinations` (as in the provided parameter files). Reference the RAI policy from the hosted agent with `rai_config.rai_policy_name` set to its full resource ID. See [Add guardrails to a hosted agent](https://learn.microsoft.com/azure/foundry/agents/how-to/add-hosted-agent-guardrails#network-egress-controls) for the full rule schema.
- Credential-bearing header rules (Set or Insert) must use a secret or managed-identity reference, not a literal value, and a credential-bearing Rewrite must use HTTPS. See [Inject secret-backed headers](https://learn.microsoft.com/azure/foundry/agents/how-to/configure-hosted-agent-secret-references).

### One initiative instead of separate assignments

`initiative: { enabled: true, name: 'contoso-foundry-governance', displayName: 'Contoso Foundry governance' }` creates a custom initiative at subscription scope containing every planned control (with its parameter values) and assigns it once. Agent-kind policies stay separate assignments (see [Things to know](#things-to-know)). Add `assignIndividually: true` to keep every control as its own assignment as well, so each one shows up separately in Foundry **Manage › Govern**. Combine it with built-in initiatives such as **[Preview]: Guardrail for Cognitive Services Deployments** [5207647b-3e83-4e28-b836-c382cb5e2a2e][p-guardrail-initiative], **EU AI Act 2024/1689** or **NIST AI RMF v1.0**.

## Runtime tool access: project tool controls

The tool policies decide which tool configurations can be **saved**. Which tools an agent can actually **run** is decided by the Foundry project's `toolControls` property — a separate runtime allow-list that this template doesn't set:

| Configuration | Save (create or update) a toolbox or prompt agent | Run a tool |
|---|---|---|
| Tool policy, `Audit` | allowed, mismatches reported | project tool controls decide (not set = not restricted) |
| Tool policy, `Deny` | non-compliant saves blocked | project tool controls decide (not set = not restricted) |
| Project tool controls only | allowed, not checked | only `allowedTools` run |

Keep the two lists aligned. A tool the policy approves but the project doesn't list saves fine and then fails at run time. Project tool controls have no audit mode, apply to existing agent versions too, and take several minutes to propagate — try the full list in a test project first. Each update **replaces** the list:

```bash
PROJECT_URL="https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<foundry-resource>/projects/<project>?api-version=2026-09-15-preview"
az rest --method get --url "$PROJECT_URL" --query properties.toolControls   # read the current list first

az rest --method patch --url "$PROJECT_URL" --headers "Content-Type=application/json" --body '{
  "properties": { "toolControls": { "defaultAction": "Deny", "allowedTools": [
    { "type": "file_search" },
    { "type": "code_interpreter" },
    { "type": "mcp", "serverUrl": "https://learn.microsoft.com/api/mcp" }
  ] } } }'
```

MCP entries need a concrete `serverUrl` or `connectorId` (no wildcards, no bare `{"type": "mcp"}`). For a toolbox reached over MCP, list the toolbox endpoint, its tools and every MCP endpoint those tools use. For the ETag-safe update and the Terraform (`azapi_update_resource`) version, see [Govern tools in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/control-plane/govern-tools?pivots=programming-language-rest#configure-project-tool-controls).

## Finding the values to use

| Need | Where to look |
|---|---|
| Foundry projects in scope | Azure Resource Graph: `resources \| where type =~ 'microsoft.cognitiveservices/accounts/projects'` |
| Agent kinds and tools in use | `GET https://<resource>.services.ai.azure.com/api/projects/<project>/agents?api-version=v1` — `versions.latest.definition.kind` and `.tools[].type` / `.server_url` |
| Toolbox tools | `GET https://<resource>.services.ai.azure.com/api/projects/<project>/toolboxes?api-version=v1` |
| Egress destinations in use | `GET .../accounts/<resource>/raiPolicies?api-version=2026-05-15-preview` — `properties.egressPolicy.rules[].match` (`host`, `path`) |
| Runtime tool allow-list | `GET .../accounts/<resource>/projects/<project>?api-version=2026-09-15-preview` — `properties.toolControls` |
| Model publishers and asset IDs | Model card in the Foundry model catalog, or the `model.publisher` / asset ID of existing deployments. Matching isn't case-sensitive. |

## Things to know

1. **Allow-lists are OR rules; assignments are AND.** Within one assignment, a tool passes if its type **or** its MCP endpoint **or** its connector is approved, and a model passes if its publisher **or** asset ID matches. Across assignments, a request must pass **every** enforced Deny assignment that applies — one assignment can't override another's denial.
2. **Matching.** MCP endpoints and container images are case-insensitive patterns with **at most one `*`** (`https://mcp.contoso.com/*` works, `https://*.contoso.com/*` doesn't; no regular expressions). Publishers use exact, case-insensitive match; asset IDs use *contains*. Use the narrowest pattern you can.
3. **Use catalog tool types.** Policy values are matched literally — pick them from the [tool type catalog](#tools). Approving `mcp` by type is much broader than approving individual MCP endpoints or connectors.
4. **Three settings, three meanings.** The policy `effect` decides whether a non-compliant save is audited or denied. The assignment `enforcementMode` (`DoNotEnforce`) switches off enforcement for the whole assignment — it isn't the same as `Audit`. The RAI policy's `egressPolicy.mode` decides whether the **runtime** egress proxy blocks or only logs. Setting the Azure Policy effect to `Audit` or `Disabled` never changes runtime egress or project tool controls, and the egress policies always require `egressPolicy.mode` to be `Enforced`.
5. **The safety policy audits configuration; it doesn't apply filters** and only supports Audit/Disabled. Configure guardrails in Foundry.
6. **Exceptions.** There are no custom non-compliance messages — Foundry shows the assignment display name, so keep `displayNamePrefix` clear. Exclude whole resources with `notScopes` or an [Azure Policy exemption](https://learn.microsoft.com/azure/governance/policy/concepts/exemption-structure); individual agents, toolboxes or tools can't be exempted.
7. **Assign agent-kind policies directly**, not wrapped in your own initiative, so the Foundry create-agent experience can detect them up front. Initiative mode does this for you.
8. **What a blocked request looks like.** A blocked model deployment fails with `InvalidResourceProperties` and a message that names the policy assignment and the failed condition. Blocked RAI-policy writes return an Azure Policy error naming the assignment. Agent and toolbox saves are rejected by Foundry with a policy error that references the assignment. A runtime egress block is different: the sandbox proxy returns `403` to the agent's outbound request.
9. **Preview controls roll out gradually.** Agent, container-image, tool, egress and safety controls are in preview; egress governance is available in Canada Central, Spain Central and Korea Central. Until Deny is active in your region, Foundry still reports non-compliant agents and toolboxes but doesn't block the save, so confirm a Deny test in a sandbox before relying on it. If a non-compliant toolbox still saves more than 30 minutes after an enforced Deny assignment, capture the assignment and definition IDs, the target resource ID and the request, and contact support. Model-deployment and RAI-policy controls block the deployment or RAI-policy write itself once the assignment has taken effect.
10. **Only new versions are admitted or denied.** Existing agent and toolbox versions are immutable: a new Deny assignment doesn't rewrite them, delete them or stop running sessions — they're reported as non-compliant instead. Fix the configuration and create a new compliant version. A configuration that passed before can be denied as a new version after you tighten the parameters.
11. **Model router** needs `Microsoft` in `allowedPublishers` (or its asset ID) in addition to the publishers of every model it routes to.
12. **Egress rule hosts should be exact.** Wildcards are fine in `permittedDestinations`, but in testing an `Allow`, `Transform` or `Rewrite` rule whose `match.host` contains `*` was reported non-compliant by both the hosted-agent and the RAI-policy baseline checks. List each host (for example the regional Application Insights ingestion host) explicitly.
13. **No RAI policy = non-compliant.** A hosted agent without `rai_config`, or one that points at a RAI policy without an egress section (for example `Microsoft.DefaultV2`), fails the egress check. Assigning the policies doesn't create or attach an RAI policy — agent authors attach a compliant one before they create the version. The RAI policy is resolved when a session starts, so changing its rules affects new sessions without a new agent version.
14. **Egress governance isn't a network firewall** for arbitrary calls from hosted-agent code; combine it with [network isolation](https://learn.microsoft.com/azure/foundry/agents/how-to/virtual-networks).

## Change or roll back

Bicep deployments are **incremental**: taking a control out of your parameter file, or changing `assignmentPrefix` or the scope, does **not** delete the assignment that's already there.

- Keep the **same controls** in your audit and enforce parameter files (as the provided profiles do). Switching back to the audit file then sets every assignment back to Audit.
- To turn one control off, set its `effect` to `Disabled` and redeploy, or delete the assignment (see [Clean up](#clean-up)).
- To have removed controls deleted automatically, deploy as a [deployment stack](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks):

  ```bash
  az stack sub create --name foundry-governance --location <region> \
    --template-file main.bicep --parameters audit-baseline.bicepparam \
    --action-on-unmanage deleteResources --deny-settings-mode none
  ```

Terraform tracks the assignments in its state and deletes removed ones on `apply`.

## Coming soon

- Custom Azure Policy definitions for Foundry agents, tools and models.

## Clean up

```bash
# <scope>: the subscription, resource group or Foundry resource ID you deployed to
az policy assignment list --scope <scope> --query "[?starts_with(name, 'fg-')].name" -o tsv |
  xargs -I{} az policy assignment delete --name {} --scope <scope>

# Initiative mode: also delete the custom initiative (after its assignments)
az policy set-definition delete --name fg-foundry-governance
```

Deleting the assignments doesn't change RAI policies or project tool controls.

## Learn more

- [Govern tools in Microsoft Foundry](https://learn.microsoft.com/azure/foundry/control-plane/govern-tools)
- [Govern hosted agent egress with Azure Policy](https://learn.microsoft.com/azure/foundry/agents/how-to/govern-hosted-agent-egress-azure-policy)
- [Add guardrails to a hosted agent (egress rules)](https://learn.microsoft.com/azure/foundry/agents/how-to/add-hosted-agent-guardrails#network-egress-controls)
- [Built-in policies for model deployment](https://learn.microsoft.com/azure/foundry/how-to/model-deployment-policy)
- [Govern model router deployments with Azure Policy](https://learn.microsoft.com/azure/foundry/how-to/model-router-policy)
- [Create custom policies for Microsoft Foundry](https://learn.microsoft.com/azure/foundry/how-to/custom-policy-definition)
- [Azure Policy resource provider modes](https://learn.microsoft.com/azure/governance/policy/concepts/definition-structure-basics#mode)

[p-kinds-allow]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F85455646-5d02-433e-a42d-265151140427
[p-kinds-deny]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Fb6ca2367-8597-4a3f-ab19-48f58d6d9278
[p-images-allow]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Fd0d9ac6c-628b-46c1-a177-eb22b12ce588
[p-images-deny]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F215c2c77-3afb-4f55-be2f-709b60dc8d53
[p-models]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Faafe3651-cb78-4f68-9f81-e7e41509110f
[p-elig]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F8791d062-ba96-4c34-b604-8538f7e30ca0
[p-tools-allow]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Fe7352ad2-6c86-4a07-9573-47f67b557ba8
[p-tools-deny]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F7740c22b-07ef-4bac-9f5a-e38d188f80b7
[p-safety]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F9224c1cc-34fc-44f1-ad08-5c4b079c9ce6
[p-egress]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Fd279dbb1-e60e-4ca0-8c2f-cc7a0f46166b
[p-rai-baseline]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F0cfd954d-079f-447f-91bf-89889e9d1de0
[p-rai-headers]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F29be091c-88f9-419b-8ad9-82ce5dc452d3
[p-rai-rewrites]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F64a15c51-9797-4d6b-93a5-16b19e7de23b
[p-agent-multi]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F595f98a5-b562-4ab6-b9c8-2ff9f39a3f7c
[p-guardrail-initiative]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicySetDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicySetDefinitions%2F5207647b-3e83-4e28-b836-c382cb5e2a2e
[p-localauth]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F71ef260a-8f18-47b7-abcb-62d0673d94dc
[p-network]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F037eea7a-bd0a-46c5-9a66-03aea78705d3
[p-privatelink]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2Fd6759c02-b87f-42b7-892e-71b3f471d782
[p-cmk]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F67121cc7-ff39-4ab8-b7e3-95b84dab487d
[p-diag]: https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyDetailBlade/definitionId/%2Fproviders%2FMicrosoft.Authorization%2FpolicyDefinitions%2F1b4d1c4e-934c-4703-944c-27c82c06bebb
[g-models]: https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Cognitive%20Services/AllowDeployRegistryModels_Audit.json
[g-elig]: https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Cognitive%20Services/AllowDeploymentModelEligibility_Audit.json
[g-tools-allow]: https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Cognitive%20Services/AllowAgentAndToolboxTools_Audit.json
[g-tools-deny]: https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Cognitive%20Services/DenyAgentAndToolboxTools_Audit.json
[g-safety]: https://github.com/Azure/azure-policy/blob/master/built-in-policies/policyDefinitions/Cognitive%20Services/AllowAgentPromptControl_Audit.json

`Tags: Azure Policy, Governance, Microsoft.CognitiveServices`
