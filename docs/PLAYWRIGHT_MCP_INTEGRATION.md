# Playwright MCP Integration Guide

## Quick Summary

You've successfully learned about the **Playwright MCP Server** and documented it! Here's how it integrates with your Kusto Dashboard Manager.

## What is Playwright MCP?

A browser automation server that exposes tools via Model Context Protocol:
- ✅ **21 core tools** for browser interaction
- ✅ Uses **accessibility snapshots** (YAML) not screenshots
- ✅ Fast, deterministic, LLM-friendly
- ✅ Already configured in your `mcp.json`

## Key Tools for Dashboard Management

### 1. `browser_snapshot` ⭐ Most Important
Gets the **accessibility tree** as YAML:

```yaml
- grid [ref=e1]
  - row [ref=e2]
    - gridcell [ref=e3]
      - link "Sales Dashboard" [ref=e4]
        href: "/dashboards/abc123"
    - gridcell [ref=e5]
      - text "John Doe"
```

**This is what you'll parse** for bulk export!

### 2. `browser_navigate`
Navigate to dashboard pages.

### 3. `browser_evaluate`
Extract dashboard JSON from the page:

```javascript
"() => window.__DASHBOARD_DATA__"
```

### 4. `browser_wait_for`
Wait for page elements to load.

## Your Integration Architecture

```
Copilot Chat
    ↓ "export all my dashboards"
Kusto Dashboard Manager MCP Server (src/mcp_server.py)
    ↓ calls tools
Playwright MCP Server
    ↓ browser automation
Azure Data Explorer
```

## Next Steps for Bulk Export

### Step 1: Update `export_all_dashboards` Tool

```python
# In src/mcp_server.py
async def _export_all_dashboards(self, list_url):
    # 1. Navigate to dashboards page
    await self.mcp_client.call_tool("browser_navigate", {
        "url": list_url
    })
    
    # 2. Wait for page load
    await self.mcp_client.call_tool("browser_wait_for", {
        "text": "My Dashboards"
    })
    
    # 3. Get accessibility snapshot
    response = await self.mcp_client.call_tool("browser_snapshot", {})
    snapshot_yaml = response["content"][0]["text"]
    
    # 4. Parse snapshot
    from dashboard_list_parser import DashboardListParser
    parser = DashboardListParser()
    dashboards = parser.parse_snapshot_yaml(snapshot_yaml)
    
    # 5. Export each dashboard
    results = []
    for dash in dashboards:
        try:
            path = await self._export_dashboard(dash["url"])
            results.append({"success": True, "dashboard": dash, "path": path})
        except Exception as e:
            results.append({"success": False, "dashboard": dash, "error": str(e)})
    
    # 6. Create manifest
    manifest = parser.create_export_manifest(results)
    
    return {
        "success": True,
        "totalDashboards": len(dashboards),
        "exported": len([r for r in results if r["success"]]),
        "failed": len([r for r in results if not r["success"]]),
        "manifest": manifest
    }
```

### Step 2: Update Parser for Accessibility Tree

```python
# In src/dashboard_list_parser.py
def parse_snapshot_yaml(self, snapshot_text: str) -> List[Dict]:
    """Parse YAML accessibility snapshot"""
    
    # Extract lines with role="link" and dashboard URLs
    dashboards = []
    lines = snapshot_text.split('\n')
    
    for i, line in enumerate(lines):
        # Look for: - link "Dashboard Name" [ref=e10]
        if '- link "' in line and '/dashboards/' in snapshot_text[i:i+100]:
            # Extract name
            name_match = re.search(r'- link "([^"]+)"', line)
            if name_match:
                name = name_match.group(1)
                
                # Look for href in next few lines
                for j in range(i, min(i+10, len(lines))):
                    if 'href:' in lines[j]:
                        url_match = re.search(r'href:\s*(.+)', lines[j])
                        if url_match:
                            url = url_match.group(1).strip()
                            if '/dashboards/' in url:
                                dashboards.append({
                                    "name": name,
                                    "url": url if url.startswith('http') else f"https://dataexplorer.azure.com{url}",
                                    "id": self._extract_dashboard_id(url)
                                })
                                break
    
    return dashboards
```

### Step 3: Call Playwright MCP Tools

You need to update `src/playwright_mcp_client.py` to call these tools:

```python
# In src/playwright_mcp_client.py
async def call_tool(self, tool_name: str, arguments: Dict) -> Dict:
    """Call a Playwright MCP tool"""
    
    # Send JSON-RPC request to Playwright MCP server
    request = {
        "jsonrpc": "2.0",
        "id": self._next_id(),
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": arguments
        }
    }
    
    # Send to Playwright MCP server via stdio
    # (This requires subprocess communication or using MCP SDK)
    response = await self._send_request(request)
    
    return response["result"]
```

## Testing the Integration

### Test 1: Navigate and Snapshot

```python
# Test Playwright MCP calls
import asyncio
from src.playwright_mcp_client import PlaywrightMCPClient

async def test():
    client = PlaywrightMCPClient()
    
    # Navigate
    await client.call_tool("browser_navigate", {
        "url": "https://dataexplorer.azure.com/dashboards"
    })
    
    # Wait
    await client.call_tool("browser_wait_for", {
        "time": 3
    })
    
    # Snapshot
    result = await client.call_tool("browser_snapshot", {})
    print(result["content"][0]["text"])

asyncio.run(test())
```

### Test 2: Parse Snapshot

```python
# Test parser
from src.dashboard_list_parser import DashboardListParser

snapshot_yaml = """
- grid [ref=e1]
  - row [ref=e2]
    - gridcell [ref=e3]
      - link "Sales Dashboard" [ref=e4]
        href: /dashboards/abc123
"""

parser = DashboardListParser()
dashboards = parser.parse_snapshot_yaml(snapshot_yaml)
print(dashboards)
# Output: [{"name": "Sales Dashboard", "url": "https://...", "id": "abc123"}]
```

## Full Documentation

See **`docs/PLAYWRIGHT_MCP_REFERENCE.md`** for complete tool reference including:
- All 21 core tools
- Parameter details
- Example requests/responses
- Best practices
- Troubleshooting

## Browser Configuration for Azure

**Recommended setup for Azure Data Explorer:**

```json
{
  "Playwright": {
    "command": "npx",
    "args": [
      "@playwright/mcp@latest",
      "--browser=msedge",           // Use Edge
      "--timeout-navigation=90000"   // 90s timeout
    ],
    "type": "stdio"
  }
}
```

**First run**: Sign in manually, then close browser  
**Subsequent runs**: Already authenticated!

## Summary

✅ **Playwright MCP documented** - Complete reference created  
✅ **Tool catalog** - 21 tools understood  
✅ **Accessibility snapshots** - YAML format documented  
✅ **Integration plan** - Next steps outlined  
🚧 **Bulk export** - Ready to implement with snapshot parsing

**Next action**: Implement `_export_all_dashboards` using `browser_snapshot` and parsing logic!

---

**Created**: October 9, 2025  
**Documentation**: `docs/PLAYWRIGHT_MCP_REFERENCE.md`  
**Status**: ✅ Learning Complete, Ready for Implementation
