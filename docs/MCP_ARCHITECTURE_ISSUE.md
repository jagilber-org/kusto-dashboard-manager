# MCP Server Architecture Issue

## Problem

The `kusto-dashboard-manager` MCP server currently spawns its own Playwright subprocess via `PlaywrightMCPClient`. When running as an MCP server invoked by VS Code, this doesn't work because:

1. The subprocess doesn't have access to an active browser
2. VS Code already has a Playwright MCP server running
3. Our server can't easily call another MCP server (Playwright) from within an MCP server context

## Current Flow (Broken)

```
VS Code MCP Framework
  → kusto-dashboard-manager MCP Server
    → PlaywrightMCPClient (subprocess)
      → @playwright/mcp (new process)
        → ❌ No browser! (subprocess isolation)
```

## Solutions

### Option A: Two-Step Manual Process (Recommended for now)

1. User manually navigates using Playwright MCP:
   ```
   Call mcp_playwright_browser_navigate(url="https://dataexplorer.azure.com/dashboards")
   Wait 8 seconds
   Call mcp_playwright_browser_snapshot()
   ```

2. User copies snapshot to our tool:
   ```
   Call new tool: parse_dashboard_snapshot(snapshot_yaml=<paste>)
   ```

### Option B: Refactor to Standalone CLI Only

Remove MCP server entirely, only provide standalone Python scripts:
```
python export_all.py
```

### Option C: MCP Client-to-Client Communication (Complex)

Implement MCP client within our MCP server to call Playwright MCP server. Requires:
- Understanding VS Code's MCP routing
- Implementing MCP client protocol
- Managing nested async contexts

## Recommendation

**Implement Option A immediately**: Create a `parse_dashboard_snapshot` tool that accepts the YAML snapshot text as input. This way:

1. User navigates with Playwright MCP (`mcp_playwright_browser_navigate`)
2. User captures snapshot (`mcp_playwright_browser_snapshot`)
3. User passes snapshot to our tool (`mcp_kusto-dashboa_parse_and_export`)

This separates concerns and works within MCP's single-server-per-request model.

## Implementation

Add new tool to `mcp_server.py`:

```python
async def _parse_and_export_from_snapshot(self, snapshot_yaml: str, creator_filter: str = None) -> Dict:
    """Parse dashboard list from snapshot YAML and export"""
    # Parse the YAML snapshot text
    dashboards = []
    self._parse_raw_snapshot_text(snapshot_yaml, dashboards)
    
    # Filter by creator
    if creator_filter:
        dashboards = [d for d in dashboards if creator_filter.lower() in d.get("creator", "").lower()]
    
    # Export each dashboard (this still needs browser access!)
    # ... but we can return the list and let user export individually
    
    return {
        "dashboards_found": len(dashboards),
        "dashboards": dashboards
    }
```

This gets us the dashboard list, then user can call `export_dashboard` for each one.
