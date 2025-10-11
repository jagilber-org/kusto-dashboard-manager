# MCP Orchestration Examples

This directory contains examples of how to orchestrate calls between multiple MCP servers from a single client.

## Understanding MCP Architecture

### MCP Servers Cannot Call Each Other Directly ❌

```
MCP Server A --X--> MCP Server B  ❌ NOT POSSIBLE
```

MCP servers run in isolated processes and communicate only via stdio with their parent client. They cannot make network calls or spawn other MCP clients.

### Orchestration via Client ✅

```
         Client (Orchestrator)
            ├─→ MCP Server A
            │   (returns data)
            └─→ MCP Server B
                (uses data from A)
```

A client can:
1. Connect to multiple MCP servers simultaneously
2. Call tools on Server A
3. Take the results
4. Pass them to Server B
5. Combine results as needed

## Example: Dashboard Export Workflow

### The Challenge

We need to:
1. **Navigate to dashboard page** (requires Playwright MCP for browser automation)
2. **Take accessibility snapshot** (requires Playwright MCP)
3. **Parse the snapshot** (requires Kusto Dashboard Manager MCP)

### The Solution: Client Orchestration

Our test clients demonstrate three approaches:

## 1. Simple Single-Server Client ✅

**Files**: `test-js-kusto.js`, `test_mcp_client.py`

Tests a single MCP server with mock data:

```javascript
// Connect to Kusto Dashboard Manager only
client.connect(kustoServer);

// Call with sample data
client.callTool('parse_dashboards_from_snapshot', {
  snapshot_yaml: SAMPLE_YAML,
  creatorFilter: 'Jason Gilbertson'
});
```

**Use case**: Unit testing, verifying MCP server functionality

## 2. Multi-Server Orchestrator ✅ NEW!

**Files**: `test-orchestrator.js`, `test_orchestrator.py`

Coordinates between TWO MCP servers:

```javascript
// Connect to BOTH servers
await orchestrator.connectPlaywright();
await orchestrator.connectKusto();

// Step 1: Call Playwright MCP
const snapshot = await playwrightClient.callTool(
  'mcp_playwright_browser_navigate',
  { url: 'https://dataexplorer.azure.com/dashboards' }
);

// Step 2: Wait for load
await sleep(8000);

// Step 3: Call Playwright MCP again
const snapshotResult = await playwrightClient.callTool(
  'mcp_playwright_browser_snapshot',
  {}
);

// Step 4: Extract YAML from Playwright result
const yaml = snapshotResult.content[0].text.raw;

// Step 5: Call Kusto MCP with Playwright's data
const dashboards = await kustoClient.callTool(
  'parse_dashboards_from_snapshot',
  { snapshot_yaml: yaml, creatorFilter: 'Jason Gilbertson' }
);

// Result: List of dashboards! 🎉
```

**Use case**: End-to-end testing, automation scripts, CI/CD pipelines

## 3. VS Code Copilot Orchestration ✅

**Environment**: VS Code with GitHub Copilot

Copilot automatically orchestrates between servers based on your request:

```
User: "Export all my dashboards by Jason Gilbertson"

Copilot thinks:
  1. Need to navigate → @playwright
  2. Need to snapshot → @playwright
  3. Need to parse → @kusto-dashboard-manager

Copilot executes:
  → Call @playwright navigate(url)
  → Call @playwright wait(8 seconds)
  → Call @playwright snapshot()
  → Extract YAML from result
  → Call @kusto-dashboard-manager parse_dashboards_from_snapshot(yaml, creator)
  → Return combined results to user
```

**Use case**: Interactive development, natural language queries

## Running the Orchestrator Examples

### JavaScript Orchestrator

```bash
cd client
npm install
npm run test:orchestrator
```

**Expected output**:
```
🚀 MCP Orchestrator - Demonstrating Multi-Server Coordination

🎭 Connecting to Playwright MCP server...
✅ Connected to Playwright MCP
📊 Connecting to Kusto Dashboard Manager MCP server...
✅ Connected to Kusto Dashboard Manager MCP

============================================================
📋 Getting Dashboard List
============================================================

🌐 Step 1: Navigate to dashboards page (Playwright)...
⏳ Step 2: Wait for page to load...
📸 Step 3: Take accessibility snapshot (Playwright)...
✅ Got snapshot (45231 chars)

🔍 Step 4: Parse dashboards (Kusto)...

============================================================
✅ Results
============================================================
Found: 23 dashboards
Dashboards:
  1. armprod
     Creator: Jason Gilbertson
     URL: https://dataexplorer.azure.com/dashboards/...
  2. Analytics Dashboard
     Creator: Jason Gilbertson
     URL: https://dataexplorer.azure.com/dashboards/...
  ...
```

### Python Orchestrator

```bash
python client/test_orchestrator.py
```

Same workflow, Python implementation.

## Key Takeaways

### ✅ DO: Use Client Orchestration

- Your test clients can call multiple MCP servers
- VS Code Copilot orchestrates between servers automatically
- Write orchestration scripts for automation

### ❌ DON'T: Try to Call MCP Servers from MCP Servers

- MCP servers are isolated (stdio only)
- No network access, no subprocess spawning
- Follow the MCP protocol design

### 💡 Best Practices

1. **Single Responsibility**: Each MCP server does one thing well
   - Playwright MCP: Browser automation
   - Kusto Dashboard Manager: Dashboard parsing/management

2. **Client as Orchestrator**: Let the client coordinate
   - Test clients for automation
   - VS Code Copilot for interactive use

3. **Pass Data Between Servers**: Use client as intermediary
   - Server A returns data
   - Client extracts what's needed
   - Client passes to Server B

## Architecture Comparison

### ❌ What We Initially Tried (Broken)

```
VS Code MCP Framework
  → Kusto Dashboard Manager MCP Server
    → PlaywrightMCPClient (subprocess) ❌
      → @playwright/mcp (new process) ❌
        → No browser access! ❌
```

**Problem**: MCP server tried to spawn another MCP server

### ✅ What Works (Current Implementation)

```
VS Code / Copilot (Orchestrator)
  ├─→ Playwright MCP Server
  │   └─→ Browser automation
  └─→ Kusto Dashboard Manager MCP Server
      └─→ Dashboard parsing
```

**Solution**: Client orchestrates between servers

### ✅ What Also Works (Custom Client)

```
Your Custom Client (test-orchestrator.js)
  ├─→ Playwright MCP Server
  │   └─→ Browser automation
  └─→ Kusto Dashboard Manager MCP Server
      └─→ Dashboard parsing
```

**Benefit**: Full control, automation, testing

## Next Steps

1. **Test the orchestrator**: Run `npm run test:orchestrator`
2. **Study the code**: See how client coordinates between servers
3. **Create custom workflows**: Build your own orchestration scripts
4. **Use in VS Code**: Let Copilot do the orchestration automatically

## Questions?

See also:
- [CLIENT_TESTING.md](CLIENT_TESTING.md) - Complete testing guide
- [../docs/MCP_ARCHITECTURE_ISSUE.md](../docs/MCP_ARCHITECTURE_ISSUE.md) - Architecture details
- [../TESTING_SUMMARY.md](../TESTING_SUMMARY.md) - Test results

**TL;DR**: Yes, clients can call multiple MCP servers! That's exactly how it's designed to work. 🎉
