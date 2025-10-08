# MCP Index Server Bootstrapper & Initialization Guide

## Overview

The MCP Index Server includes a **bootstrap system** that provides security gating for mutation operations and structured onboarding guidance for new agents/users.

**Last Updated**: October 8, 2025  
**Server Version**: 1.2.3  
**Catalog Count**: 112 instructions  
**Tool Count**: 37 tools

---

## Bootstrap System Components

### 1. Bootstrap Status & Security Gating

The bootstrap system controls access to mutation operations through a confirmation mechanism:

#### `bootstrap/status` - Check Bootstrap State
Returns the current bootstrap configuration:

```json
{
  "status": {
    "referenceMode": false,      // Read-only mode flag
    "confirmed": true,            // Bootstrap confirmed
    "requireConfirmation": false, // Confirmation required
    "nonBootstrapInstructions": true  // Instructions loaded
  },
  "gatedReason": null  // Why mutations are gated (if applicable)
}
```

**Our Current Status**: ✅ Confirmed, mutations allowed

#### `bootstrap/request` - Request Confirmation Token
Requests a human confirmation bootstrap token for enabling guarded mutations:

- **Purpose**: Obtain authorization token for mutation operations
- **Required**: `rationale` (explanation of why mutations are needed)
- **Returns**: Token (hash persisted, raw returned once)
- **Use Case**: First-time setup, security validation

#### `bootstrap/confirmFinalize` - Submit Token
Finalizes bootstrap by submitting the issued token:

- **Required**: `token` (from bootstrap/request)
- **Purpose**: Enable guarded mutations
- **Use Case**: Completing bootstrap authorization

---

## Initialization Workflow

### Recommended Initialization Sequence

```
1. initialize → Connect to MCP Index Server
2. tools/list → Enumerate available tools
3. help/overview → Get structured onboarding guidance
4. bootstrap/status → Check authorization state
5. instructions/dispatch (action=list) → Browse catalog
6. Begin using tools based on needs
```

### PowerShell Example

```powershell
# 1. Initialize connection (handled by VS Code MCP integration)

# 2. Check health
$health = Invoke-MCPTool -Server "mcp-index-server" -Tool "health/check"
Write-Host "Server Status: $($health.status) - Version: $($health.version)"

# 3. Get onboarding guidance
$help = Invoke-MCPTool -Server "mcp-index-server" -Tool "help/overview"
$help.sections | ForEach-Object {
    Write-Host "`n[$($_.title)]"
    Write-Host $_.content
}

# 4. Check bootstrap status
$bootstrap = Invoke-MCPTool -Server "mcp-index-server" -Tool "bootstrap/status"
if ($bootstrap.status.confirmed) {
    Write-Host "✅ Bootstrap confirmed - Mutations allowed"
} else {
    Write-Host "⚠️ Bootstrap required for mutations"
}

# 5. Get tool inventory
$tools = Invoke-MCPTool -Server "mcp-index-server" -Tool "meta/tools"
Write-Host "`nAvailable Tools: $($tools.tools.Count)"

# 6. List catalog instructions
$catalog = Invoke-MCPTool -Server "mcp-index-server" -Tool "instructions/dispatch" -Params @{action="list"}
Write-Host "`nCatalog Size: $($catalog.items.Count) instructions"
```

---

## Help System - `help/overview`

The help/overview tool provides structured onboarding guidance with these sections:

### 1. Welcome
Overview of the governance-aware instruction catalog and MCP tools.

### 2. Tool Discovery Flow
Recommended sequence for discovering capabilities:

```
initialize → tools/call meta/tools → tools/call help/overview
→ instructions/dispatch (action=list)
→ instructions/governanceHash
→ instructions/health
```

**Next Actions**:
- Call `meta/tools` for capabilities
- Call `help/overview` for guidance
- List catalog via `instructions/dispatch {action:list}`

### 3. Lifecycle Tiers
Instructions progress through quality tiers:

| Tier | Purpose | Governance |
|------|---------|------------|
| **P0** | Local experimental, workspace-specific | Minimal |
| **P1** | Indexed baseline, canonical | Required |
| **P2+** | Refined, broader consumption | Enhanced |

**Key Points**:
- P0: Rapid iteration, not shareable
- P1: Versioned, governance-compliant
- Denylist prevents governance/spec ingestion (recursion protection)

### 4. Promotion Checklist
Before promoting P0 → P1 (indexed):

- ✅ **Clarity**: Concise title + semantic summary
- ✅ **Accuracy**: Verified against current repo state
- ✅ **Value**: Non-duplicative & materially helpful
- ✅ **Maintainability**: Minimal volatile references
- ✅ **Classification**: Assigned priorityTier & classification
- ✅ **Owner**: Owner + review cadence set
- ✅ **ChangeLog**: Initialized if version > 1

**Next Actions**:
- Run `prompt/review` for large bodies
- Run `integrity/verify`
- Submit via `instructions/add`

### 5. Mutation Safety
- All write operations require `MCP_ENABLE_MUTATION=1`
- Without it, mutation tools return disabled errors
- Read-only safety by default

### 6. Recursion Safeguards
- Loader denylist excludes governance/spec seeds
- `instructions/health` exposes `recursionRisk` metric
- Expected value: `recursionRisk=none`

### 7. Suggested Next Steps
```
1. Fetch meta/tools and record stable tools
2. List catalog entries (instructions/dispatch list)
3. Track usage for relevant instructions (usage/track)
4. Draft local P0 improvements in separate directory
5. Evaluate with prompt/review & integrity/verify
6. Promote via instructions/add (with mutation enabled)
7. Monitor drift via instructions/health and governanceHash
```

---

## Tool Categories (37 Total)

### 🔧 Core System Tools (4)
- `health/check` ✅ - Server health & version
- `feature/status` ⚠️ - Feature flags
- `metrics/snapshot` ✅ - Performance metrics
- `meta/tools` ✅ - Tool inventory

### 📋 Instruction Management (13)
- `instructions/dispatch` ✅ - **Primary interface** (list, get, search, export, query)
- `instructions/search` ✅ - Text search
- `instructions/add` ⚠️ 🔄 - Add instruction
- `instructions/remove` ⚠️ 🔄 - Delete instructions
- `instructions/import` ⚠️ 🔄 - Bulk import
- `instructions/reload` ⚠️ 🔄 - Reload from disk
- `instructions/groom` ⚠️ 🔄 - Maintenance
- `instructions/enrich` ⚠️ 🔄 - Normalize governance
- `instructions/repair` ⚠️ 🔄 - Fix hash drift
- `instructions/governanceHash` ✅ - Governance state
- `instructions/governanceUpdate` ⚠️ 🔄 - Update governance
- `instructions/health` ⚠️ - Drift detection
- `instructions/diagnostics` ⚠️ - Debug catalog

### 🔍 Data Integrity (2)
- `integrity/verify` ✅ - Hash verification
- `gates/evaluate` ✅ - Quality gates

### 📊 Usage Analytics (3)
- `usage/track` ✅ - Track usage
- `usage/hotset` ✅ - Popular instructions
- `usage/flush` ⚠️ 🔄 - Persist usage data

### 💬 Feedback Management (6)
- `feedback/list` ✅ - List feedback
- `feedback/get` ✅ - Get feedback
- `feedback/stats` ✅ - Feedback analytics
- `feedback/health` ✅ - System health
- `feedback/submit` ⚠️ 🔄 - Submit feedback
- `feedback/update` ⚠️ 🔄 - Update feedback

### 🛠 Diagnostic Tools (4)
- `diagnostics/block` ⚠️ - CPU stress test
- `diagnostics/memoryPressure` ⚠️ - Memory test
- `diagnostics/microtaskFlood` ⚠️ - Event loop test
- `diagnostics/handshake` ⚠️ - Connectivity test

### 📝 Quality Tools (1)
- `prompt/review` ✅ - Prompt analysis

### 🔗 Integration Tools (3)
- `graph/export` ⚠️ - Relationship graph
- `manifest/status` ⚠️ - Manifest state
- `manifest/refresh` ⚠️ 🔄 - Rebuild manifest
- `manifest/repair` ⚠️ 🔄 - Fix manifest drift

**Legend**:
- ✅ Stable (production-ready)
- ⚠️ Unstable (subject to change)
- 🔄 Mutation (modifies state)

---

## Security & Safety

### Mutation Control
- **Environment Variable**: `MCP_ENABLE_MUTATION=1` required
- **Default**: Read-only mode (safe by default)
- **Gating**: Bootstrap confirmation mechanism
- **Protection**: All mutations fail without authorization

### Recursion Protection
- **Denylist**: Governance/spec files excluded from ingestion
- **Metric**: `recursionRisk` exposed in `instructions/health`
- **Expected**: `recursionRisk=none`
- **Purpose**: Prevent self-referential instruction loops

### Quality Gates
- **integrity/verify**: Hash verification
- **gates/evaluate**: Policy compliance
- **prompt/review**: Content quality analysis
- **instructions/health**: Drift detection

---

## Common Workflows

### 1. First-Time Setup
```powershell
# Check bootstrap status
$status = Invoke-MCPTool -Tool "bootstrap/status"

# If not confirmed, request token
if (!$status.status.confirmed) {
    $token = Invoke-MCPTool -Tool "bootstrap/request" -Params @{
        rationale = "Setting up Kusto Dashboard Manager project"
    }
    
    # Confirm with token
    Invoke-MCPTool -Tool "bootstrap/confirmFinalize" -Params @{
        token = $token.token
    }
}
```

### 2. Discover Capabilities
```powershell
# Get complete tool inventory
$tools = Invoke-MCPTool -Tool "meta/tools"

# Filter stable tools
$stableTools = $tools.tools | Where-Object { $_.isStable -eq $true }

# Filter mutation tools
$mutationTools = $tools.tools | Where-Object { $_.isMutation -eq $true }
```

### 3. Search & Retrieve Instructions
```powershell
# Search for relevant instructions
$results = Invoke-MCPTool -Tool "instructions/dispatch" -Params @{
    action = "search"
    q = "PowerShell testing"
}

# Get specific instruction
$instruction = Invoke-MCPTool -Tool "instructions/dispatch" -Params @{
    action = "get"
    id = "powershell-testing-pester-guidelines"
}
```

### 4. Monitor Health & Integrity
```powershell
# Check catalog health
$health = Invoke-MCPTool -Tool "instructions/health"

# Verify integrity
$integrity = Invoke-MCPTool -Tool "integrity/verify"

# Get governance state
$governance = Invoke-MCPTool -Tool "instructions/governanceHash"

# Check for drift
if ($health.drift.changed.length -gt 0) {
    Write-Warning "Detected $($health.drift.changed.length) changed instructions"
}
```

### 5. Track Usage & Analytics
```powershell
# Track instruction usage
Invoke-MCPTool -Tool "usage/track" -Params @{id = "instruction-id"}

# Get popular instructions
$popular = Invoke-MCPTool -Tool "usage/hotset" -Params @{limit = 10}

# Get feedback statistics
$feedback = Invoke-MCPTool -Tool "feedback/stats"
```

---

## Current Project Status

### Bootstrap Status
```
✅ referenceMode: false (not read-only)
✅ confirmed: true (bootstrap confirmed)
✅ requireConfirmation: false (no confirmation needed)
✅ nonBootstrapInstructions: true (catalog loaded)
```

**Result**: Fully initialized, mutations allowed, ready for use

### Catalog Information
- **Total Instructions**: 112
- **Catalog Hash**: `b05912862a79f81e7a050b4b546fd0ff0cf5e8869c80026c09589ad347a148b5`
- **Tool Count**: 37 (15 stable, 22 unstable)
- **Primary Tools Used**: `instructions/search`, `instructions/dispatch`

---

## Integration with Kusto Dashboard Manager

### How We've Used MCP Index Server

1. **Discovery Phase** (Completed):
   - Searched for "spec-driven-new-project-setup-guide"
   - Retrieved "project-instruction-architecture-spec-driven"
   - Retrieved "mcp-servers-integration-guide"

2. **Application Phase** (Completed):
   - Applied GitHub Spec-Kit methodology
   - Created constitutional framework
   - Built comprehensive specifications
   - Established MCP integration patterns

3. **Documentation Phase** (Completed):
   - Created `MCP_INDEX_SERVER_USAGE.md`
   - Created `PROJECT_SETUP_SUMMARY.md`
   - Created this bootstrapper guide

### Recommended Usage Going Forward

```powershell
# When starting new features
$instructions = Invoke-MCPTool -Tool "instructions/search" -Params @{
    keywords = @("PowerShell", "testing", "Pester")
}

# Track which instructions you use
foreach ($inst in $instructions.results) {
    Invoke-MCPTool -Tool "usage/track" -Params @{id = $inst.instructionId}
}

# Submit feedback on instructions
Invoke-MCPTool -Tool "feedback/submit" -Params @{
    type = "feature-request"
    severity = "low"
    title = "Request for Kusto-specific instructions"
    description = "Would be helpful to have instructions for Kusto/KQL patterns"
}
```

---

## Resources

### Documentation
- **Complete Tool Inventory**: See instruction `mcp-index-server-complete-tool-inventory-2025`
- **Help System**: Use `help/overview` for latest guidance
- **Health Monitoring**: Regular `health/check` and `instructions/health`

### Best Practices
- Use **stable tools** (✅) for production workflows
- Use `instructions/dispatch` as primary interface
- Run `integrity/verify` regularly
- Monitor metrics with `metrics/snapshot`
- Collect feedback for continuous improvement

### Safety
- Diagnostic tools are for development only (⚠️ performance impact)
- Always use `dryRun` mode for destructive operations
- Verify with read-only tools before mutations
- Monitor metrics after bulk operations

---

## Summary

The MCP Index Server bootstrapper provides:

1. ✅ **Security Gating**: Bootstrap confirmation for mutations
2. ✅ **Structured Onboarding**: `help/overview` for new users
3. ✅ **Tool Discovery**: `meta/tools` for capability assessment
4. ✅ **Lifecycle Management**: P0 → P1 promotion workflow
5. ✅ **Quality Assurance**: Integrity verification and gates
6. ✅ **Safety Defaults**: Read-only by default, explicit mutation control

**Current Project Status**: ✅ Fully bootstrapped, ready for implementation phase

**Next Steps**: Begin Task 1.1 (Core Module Setup) using discovered instructions as guidance.
