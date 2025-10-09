# Playwright MCP Integration - Reference Guide

**Version**: 1.0.0  
**Last Updated**: 2025-10-09  
**Authority**: Subordinate to Project Constitution  

## Overview

This document provides comprehensive reference information for integrating with the Playwright MCP Server in the Kusto Dashboard Manager project.

## Playwright MCP Server Configuration

### VS Code MCP Configuration

The Playwright MCP server is configured in your `mcp.json`:

```json
{
  "servers": {
    "Playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "type": "stdio"
    },
    "kusto-dashboard-manager": {
      "command": "python",
      "args": ["-m", "src.mcp_server"],
      "cwd": "c:/github/jagilber/kusto-dashboard-manager",
      "type": "stdio"
    }
  }
}
```

### Recommended Configuration for Azure Data Explorer

For working with Azure Data Explorer dashboards, use these settings:

```json
{
  "servers": {
    "Playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser=msedge",
        "--timeout-navigation=90000",
        "--timeout-action=10000"
      ],
      "type": "stdio"
    }
  }
}
```

**Key Arguments:**
- `--browser=msedge`: Use Microsoft Edge for work profile authentication
- `--timeout-navigation=90000`: 90-second navigation timeout
- `--timeout-action=10000`: 10-second action timeout

## Available Playwright MCP Tools

### Core Automation Tools

#### 1. browser_navigate
Navigate to a URL.

**Parameters:**
- `url` (string, required): The URL to navigate to

**Python Example:**
```python
await playwright_client.call_tool("browser_navigate", {
    "url": "https://dataexplorer.azure.com/dashboards"
})
```

**Use Cases:**
- Navigate to dashboard list page
- Navigate to specific dashboard URL
- Navigate to import/export pages

---

#### 2. browser_snapshot ⭐ CRITICAL FOR BULK EXPORT
Capture accessibility snapshot of the current page as YAML.

**Parameters:** None

**Returns:** YAML accessibility tree with element references

**Python Example:**
```python
result = await playwright_client.call_tool("browser_snapshot", {})
snapshot_yaml = result["content"][0]["text"]
```

**Sample Output:**
```yaml
- Page URL: https://dataexplorer.azure.com/dashboards
- Page Title: Azure Data Explorer - Dashboards
- Page Snapshot:
  - banner [ref=e1]
    - heading "Azure Data Explorer" [ref=e2]
  - main [ref=e3]
    - heading "My Dashboards" [ref=e4]
    - grid [ref=e5]
      - row [ref=e6]
        - gridcell [ref=e7]
          - link "Sales Dashboard" [ref=e8]
            href: /dashboards/abc123
        - gridcell [ref=e9]
          - text "Created: 2025-10-01"
      - row [ref=e10]
        - gridcell [ref=e11]
          - link "Service Health" [ref=e12]
            href: /dashboards/def456
```

**Use Cases:**
- **Primary use**: Parse dashboard list for bulk export
- Get page structure before interactions
- Verify page loaded correctly
- Extract dashboard names and URLs
- Find creator information in grid cells

---

#### 3. browser_click
Click an element on the page.

**Parameters:**
- `element` (string, required): Human-readable element description
- `ref` (string, required): Element reference from snapshot (e.g., "e3")
- `doubleClick` (boolean, optional): Perform double-click
- `button` (string, optional): "left" (default), "right", "middle"
- `modifiers` (array, optional): ["Alt", "Control", "Shift", "Meta"]

**Python Example:**
```python
# First get snapshot to find element reference
snapshot = await playwright_client.call_tool("browser_snapshot", {})

# Parse snapshot to find: button "Export" [ref=e10]

# Click the button
await playwright_client.call_tool("browser_click", {
    "element": "Export button",
    "ref": "e10"
})
```

**Use Cases:**
- Click export buttons
- Click dashboard links
- Click navigation menu items

---

#### 4. browser_evaluate
Execute JavaScript on the page or element.

**Parameters:**
- `function` (string, required): JavaScript function as string
- `element` (string, optional): Element description
- `ref` (string, optional): Element reference

**Python Examples:**
```python
# Extract dashboard JSON from page
dashboard_data = await playwright_client.call_tool("browser_evaluate", {
    "function": "() => window.__DASHBOARD_DATA__"
})

# Get document title
title = await playwright_client.call_tool("browser_evaluate", {
    "function": "() => document.title"
})

# Extract data from specific element
data = await playwright_client.call_tool("browser_evaluate", {
    "element": "Dashboard content",
    "ref": "e5",
    "function": "(element) => element.dataset.dashboard"
})
```

**Use Cases:**
- **Primary use**: Extract dashboard JSON from page
- Get computed styles
- Access window variables
- Query DOM for specific data
- Verify page state

---

#### 5. browser_wait_for
Wait for text to appear/disappear or time to pass.

**Parameters:**
- `time` (number, optional): Seconds to wait
- `text` (string, optional): Text to wait for (appears)
- `textGone` (string, optional): Text to wait for (disappears)

**Python Examples:**
```python
# Wait for specific text
await playwright_client.call_tool("browser_wait_for", {
    "text": "Dashboard loaded"
})

# Wait for loading spinner to disappear
await playwright_client.call_tool("browser_wait_for", {
    "textGone": "Loading..."
})

# Wait fixed time
await playwright_client.call_tool("browser_wait_for", {
    "time": 3
})
```

**Use Cases:**
- Wait for page load
- Wait for dashboard rendering
- Wait for export completion
- Synchronize with slow network

---

#### 6. browser_type
Type text into an input field.

**Parameters:**
- `element` (string, required): Element description
- `ref` (string, required): Element reference from snapshot
- `text` (string, required): Text to type
- `submit` (boolean, optional): Press Enter after typing
- `slowly` (boolean, optional): Type character-by-character

**Python Example:**
```python
await playwright_client.call_tool("browser_type", {
    "element": "Search box",
    "ref": "e5",
    "text": "My Dashboard",
    "submit": True
})
```

**Use Cases:**
- Search for dashboards
- Filter dashboard lists
- Enter text in forms

---

#### 7. browser_fill_form
Fill multiple form fields at once.

**Parameters:**
- `fields` (array, required): Array of field objects

**Field Object:**
- `name` (string): Field name
- `type` (string): "textbox", "checkbox", "radio", "combobox", "slider"
- `ref` (string): Element reference
- `value` (string): Value to fill

**Python Example:**
```python
await playwright_client.call_tool("browser_fill_form", {
    "fields": [
        {
            "name": "Dashboard name",
            "type": "textbox",
            "ref": "e10",
            "value": "My New Dashboard"
        },
        {
            "name": "Public checkbox",
            "type": "checkbox",
            "ref": "e11",
            "value": "true"
        }
    ]
})
```

**Use Cases:**
- Fill import forms
- Configure dashboard settings
- Set search filters

---

#### 8. browser_console_messages
Get console messages from the page.

**Parameters:**
- `onlyErrors` (boolean, optional): Only return error messages

**Python Example:**
```python
messages = await playwright_client.call_tool("browser_console_messages", {
    "onlyErrors": True
})
```

**Use Cases:**
- Debug JavaScript errors
- Monitor dashboard load errors
- Capture warnings

---

#### 9. browser_network_requests
Get all network requests since page load.

**Parameters:** None

**Python Example:**
```python
requests = await playwright_client.call_tool("browser_network_requests", {})
```

**Use Cases:**
- Verify API calls
- Debug network issues
- Monitor data fetching

---

#### 10. browser_take_screenshot
Take a screenshot of the page or element.

**Parameters:**
- `type` (string, optional): "png" (default) or "jpeg"
- `filename` (string, optional): Output filename
- `element` (string, optional): Element description
- `ref` (string, optional): Element reference
- `fullPage` (boolean, optional): Capture full scrollable page

**Python Example:**
```python
await playwright_client.call_tool("browser_take_screenshot", {
    "filename": "dashboard-export.png",
    "fullPage": True
})
```

**Use Cases:**
- Debugging visual issues
- Documentation
- Error reporting

---

#### 11. browser_tabs
Manage browser tabs.

**Parameters:**
- `action` (string, required): "list", "new", "close", "select"
- `index` (number, optional): Tab index (for close/select)

**Python Examples:**
```python
# List all tabs
tabs = await playwright_client.call_tool("browser_tabs", {
    "action": "list"
})

# Open new tab
await playwright_client.call_tool("browser_tabs", {
    "action": "new"
})

# Switch to tab
await playwright_client.call_tool("browser_tabs", {
    "action": "select",
    "index": 1
})

# Close current tab
await playwright_client.call_tool("browser_tabs", {
    "action": "close"
})
```

---

#### 12. browser_close
Close the browser.

**Parameters:** None

**Python Example:**
```python
await playwright_client.call_tool("browser_close", {})
```

---

## Integration Patterns

### Pattern 1: Navigate and Extract Dashboard JSON

```python
async def export_dashboard(self, url: str, output_path: str):
    """Export a single dashboard"""
    try:
        # 1. Navigate to dashboard
        await self.playwright_client.call_tool("browser_navigate", {
            "url": url
        })
        
        # 2. Wait for dashboard to load
        await self.playwright_client.call_tool("browser_wait_for", {
            "text": "Dashboard"
        })
        
        # 3. Extract dashboard JSON
        result = await self.playwright_client.call_tool("browser_evaluate", {
            "function": "() => window.__DASHBOARD_DATA__"
        })
        
        dashboard_data = result["content"][0]["text"]
        
        # 4. Save to file
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(dashboard_data, f, indent=2)
        
        return output_path
        
    except Exception as e:
        self.logger.error(f"Dashboard export failed: {e}")
        raise
```

---

### Pattern 2: Parse Dashboard List for Bulk Export ⭐

```python
async def export_all_dashboards(self, list_url: str):
    """Export all dashboards from list page"""
    try:
        # 1. Navigate to dashboards list
        await self.playwright_client.call_tool("browser_navigate", {
            "url": list_url
        })
        
        # 2. Wait for page load
        await self.playwright_client.call_tool("browser_wait_for", {
            "text": "My Dashboards"
        })
        
        # 3. Get accessibility snapshot
        result = await self.playwright_client.call_tool("browser_snapshot", {})
        snapshot_yaml = result["content"][0]["text"]
        
        # 4. Parse snapshot for dashboard links
        from dashboard_list_parser import DashboardListParser
        parser = DashboardListParser()
        dashboards = parser.parse_snapshot_yaml(snapshot_yaml)
        
        # 5. Export each dashboard
        results = []
        for dash in dashboards:
            try:
                path = await self.export_dashboard(dash["url"])
                results.append({
                    "success": True,
                    "dashboard": dash,
                    "path": path
                })
            except Exception as e:
                results.append({
                    "success": False,
                    "dashboard": dash,
                    "error": str(e)
                })
        
        # 6. Create manifest
        manifest = {
            "exportedAt": datetime.utcnow().isoformat(),
            "totalDashboards": len(dashboards),
            "exported": len([r for r in results if r["success"]]),
            "failed": len([r for r in results if not r["success"]]),
            "results": results
        }
        
        return manifest
        
    except Exception as e:
        self.logger.error(f"Bulk export failed: {e}")
        raise
```

---

### Pattern 3: Error Handling with Retry

```python
async def call_tool_with_retry(self, tool_name: str, arguments: dict, max_retries: int = 3):
    """Call Playwright tool with automatic retry"""
    for attempt in range(max_retries):
        try:
            return await self.playwright_client.call_tool(tool_name, arguments)
        except TimeoutError as e:
            if attempt < max_retries - 1:
                self.logger.warning(f"Attempt {attempt + 1} failed, retrying...")
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
            else:
                raise
        except Exception as e:
            self.logger.error(f"Tool call failed: {e}")
            raise
```

---

## Parsing Accessibility Snapshots

### Understanding the YAML Structure

Playwright's `browser_snapshot` returns a hierarchical YAML structure:

```yaml
- Page URL: https://example.com
- Page Title: Example Page
- Page Snapshot:
  - banner [ref=e1]
    - heading "Site Title" [ref=e2]
  - main [ref=e3]
    - grid [ref=e4]
      - row [ref=e5]
        - gridcell [ref=e6]
          - link "Item Name" [ref=e7]
            href: /item/123
```

**Key Elements:**
- **Roles**: banner, heading, main, grid, row, gridcell, link, button, textbox
- **References**: `[ref=e1]` - unique identifiers for interaction
- **Attributes**: Properties like `href`, `value`, `aria-label`
- **Text**: Visible text content or accessible names

### Parsing Dashboard Lists

```python
import re
from typing import List, Dict

def parse_dashboard_list(snapshot_yaml: str) -> List[Dict]:
    """Parse dashboard list from accessibility snapshot"""
    dashboards = []
    lines = snapshot_yaml.split('\n')
    
    for i, line in enumerate(lines):
        # Look for dashboard links in grid
        if '- link "' in line and 'gridcell' in '\n'.join(lines[max(0, i-5):i]):
            # Extract dashboard name
            name_match = re.search(r'- link "([^"]+)"', line)
            if not name_match:
                continue
            
            dashboard_name = name_match.group(1)
            
            # Look for href in next few lines
            for j in range(i, min(i + 10, len(lines))):
                if 'href:' in lines[j]:
                    url_match = re.search(r'href:\s*(.+)', lines[j])
                    if url_match:
                        url = url_match.group(1).strip()
                        
                        # Only process dashboard URLs
                        if '/dashboards/' in url:
                            # Make absolute URL if needed
                            if not url.startswith('http'):
                                url = f"https://dataexplorer.azure.com{url}"
                            
                            dashboards.append({
                                "name": dashboard_name,
                                "url": url,
                                "id": url.split('/')[-1].split('?')[0]
                            })
                            break
    
    return dashboards
```

---

## Best Practices

### 1. Always Get Snapshot Before Interacting

```python
# ✅ GOOD: Get snapshot first
snapshot = await call_tool("browser_snapshot", {})
# Parse to find: button "Export" [ref=e10]
await call_tool("browser_click", {"element": "Export", "ref": "e10"})

# ❌ BAD: Hardcode element references
await call_tool("browser_click", {"ref": "e10"})  # Will break if page changes!
```

### 2. Wait for Page Load

```python
# Navigate
await call_tool("browser_navigate", {"url": url})

# Wait for specific text
await call_tool("browser_wait_for", {"text": "Dashboard"})

# Now safe to interact
snapshot = await call_tool("browser_snapshot", {})
```

### 3. Handle Multiple Extraction Methods

```python
# Try primary method
try:
    data = await call_tool("browser_evaluate", {
        "function": "() => window.__DASHBOARD_DATA__"
    })
except:
    # Fallback method
    data = await call_tool("browser_evaluate", {
        "function": "() => JSON.parse(document.querySelector('[data-dashboard]').dataset.dashboard)"
    })
```

### 4. Use Structured Error Context

```python
try:
    result = await call_tool("browser_navigate", {"url": url})
except Exception as e:
    context = {
        "tool": "browser_navigate",
        "url": url,
        "error": str(e),
        "timestamp": datetime.utcnow().isoformat()
    }
    logger.error("Navigation failed", extra=context)
    raise
```

---

## Troubleshooting

### Issue: Navigation Timeouts

**Symptom:** `browser_navigate` times out

**Solutions:**
1. Increase timeout: `--timeout-navigation=120000`
2. Check network connectivity
3. Verify URL is accessible
4. Try with `browser_wait_for` after navigation

### Issue: Element Not Found

**Symptom:** Click fails with "element not found"

**Solutions:**
1. Get fresh snapshot before clicking
2. Verify element reference is current
3. Check page has fully loaded
4. Use `browser_wait_for` for dynamic content

### Issue: JavaScript Evaluation Fails

**Symptom:** `browser_evaluate` returns undefined or error

**Solutions:**
1. Verify JavaScript syntax
2. Check variable exists in page context
3. Try alternative data extraction methods
4. Inspect page with `browser_console_messages`

---

## Performance Considerations

### Optimization Tips

1. **Reuse browser sessions** - Don't close/reopen for each operation
2. **Use persistent profiles** - Faster startup, maintains authentication
3. **Batch operations** - Group related actions
4. **Parallel exports** - Export multiple dashboards concurrently
5. **Cache snapshots** - Reuse snapshot data when possible

### Expected Performance

- **Single dashboard export**: <30 seconds
- **Bulk export (10 dashboards)**: <5 minutes
- **Dashboard list snapshot**: <5 seconds
- **Page navigation**: <10 seconds

---

## Security Considerations

### Authentication

- Use Edge browser with work profile for Azure AD authentication
- Don't store credentials in code
- Use persistent profile to maintain logged-in state
- Clear sensitive data from logs

### Data Protection

- Be careful with dashboard JSON (may contain sensitive queries)
- Don't log full dashboard content
- Sanitize URLs in logs
- Use secure file permissions for exports

---

## Additional Resources

### Documentation Files

- **Complete Reference**: `docs/PLAYWRIGHT_MCP_REFERENCE.md` (17KB, all 21 tools)
- **Integration Guide**: `docs/PLAYWRIGHT_MCP_INTEGRATION.md` (7KB, code examples)
- **Learning Summary**: `docs/PLAYWRIGHT_MCP_LEARNING_SUMMARY.md` (11KB, overview)

### External Resources

- **Official Docs**: https://github.com/microsoft/playwright-mcp
- **NPM Package**: https://www.npmjs.com/package/@playwright/mcp
- **Playwright API**: https://playwright.dev/docs/intro
- **MCP Specification**: https://modelcontextprotocol.io/

---

**Last Updated**: October 9, 2025  
**Status**: ✅ Production Ready  
**Playwright MCP Version**: 0.0.41
