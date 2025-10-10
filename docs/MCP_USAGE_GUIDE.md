# Using Kusto Dashboard Manager with VS Code MCP

## The Problem

The `kusto-dashboard-manager` MCP server cannot directly control the browser because:
1. When called through VS Code MCP, it runs as a subprocess
2. The subprocess tries to spawn its own Playwright instance
3. That Playwright instance doesn't have access to the browser VS Code is managing
4. Result: `snapshot()` returns `null` and exports fail

## The Solution: Two-Step Process

Use the Playwright MCP tools directly, then pass the snapshot to our parser.

### Step 1: Navigate and Capture Snapshot

```javascript
// Navigate to dashboards page
Call: mcp_playwright_browser_navigate
  url: "https://dataexplorer.azure.com/dashboards"

// Wait for page to load (important!)
Wait 8-10 seconds

// Capture the page snapshot
Call: mcp_playwright_browser_snapshot
```

This will return a YAML snapshot like:
```yaml
- row "armprod about 2 hours ago 11/3/2020 Jason Gilbertson" [ref=e191]:
  - rowheader "armprod" [ref=e192]:
    - link "armprod" [ref=e193] [cursor=pointer]:
      - /url: /dashboards/03e8f08f-8111-40f4-9f58-270678db9782
  ...
```

### Step 2: Parse Dashboards from Snapshot

**After restarting VS Code or reloading MCP:**

```javascript
Call: mcp_kusto-dashboa_parse_dashboards_from_snapshot
  snapshot_yaml: "<paste the entire YAML from step 1>"
  creatorFilter: "Jason Gilbertson"  // optional
```

This will return:
```json
{
  "success": true,
  "total_found": 23,
  "dashboards": [
    {
      "url": "https://dataexplorer.azure.com/dashboards/03e8f08f-8111-40f4-9f58-270678db9782",
      "name": "armprod",
      "creator": "Jason Gilbertson"
    },
    ...
  ]
}
```

### Step 3: Export Individual Dashboards

For each dashboard URL from step 2:

```javascript
Call: mcp_kusto-dashboa_export_dashboard
  url: "https://dataexplorer.azure.com/dashboards/03e8f08f-8111-40f4-9f58-270678db9782"
  outputPath: "optional/custom/path.json"
```

## Why This Works

- **Playwright** MCP handles browser automation (navigation, snapshots)
- **Kusto Dashboard Manager** MCP handles parsing and data extraction
- No subprocess conflict because each MCP server does what it does best
- You (the user) coordinate between the two servers

## Alternative: Use Standalone Script

For bulk export without MCP complexity:

```powershell
cd c:\github\jagilber\kusto-dashboard-manager
python export_all_standalone.py
```

This runs everything in one process with its own Playwright instance.

## Root Cause Summary

MCP servers can't easily call other MCP servers. When our server tries to spawn Playwright as a subprocess, that subprocess can't access VS Code's browser instance. The solution is manual coordination: you call Playwright MCP, capture data, then pass that data to our MCP server for processing.
