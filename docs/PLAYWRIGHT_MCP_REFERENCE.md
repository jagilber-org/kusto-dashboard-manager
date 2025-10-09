# Playwright MCP Server - Complete Reference

## Overview

The **Playwright MCP Server** provides browser automation capabilities through the Model Context Protocol. It enables LLMs to interact with web pages using **structured accessibility snapshots** instead of screenshots, making it fast, deterministic, and LLM-friendly.

## Key Features

- ✅ **Fast & Lightweight**: Uses Playwright's accessibility tree, not pixel-based input
- ✅ **LLM-Friendly**: Operates on structured data (YAML), no vision models needed
- ✅ **Deterministic**: Avoids ambiguity common with screenshot-based approaches
- ✅ **Cross-Browser**: Supports Chromium, Firefox, and WebKit
- ✅ **Persistent Sessions**: Can maintain logged-in state across sessions

## Installation

```bash
# Auto-installed via npx (recommended)
npx @playwright/mcp@latest

# Or install globally
npm install -g @playwright/mcp
```

## Configuration in VS Code

Your `mcp.json` already includes:

```json
{
  "servers": {
    "Playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "type": "stdio"
    }
  }
}
```

### Common Configuration Options

Add arguments to customize behavior:

```json
{
  "servers": {
    "Playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest",
        "--browser=msedge",          // Use Edge browser
        "--headless",                // Run headless
        "--timeout-action=10000",    // 10s action timeout
        "--user-data-dir=C:/path"    // Persistent profile
      ],
      "type": "stdio"
    }
  }
}
```

## Available Tools

### Core Automation (Always Available)

#### 1. `browser_navigate`
Navigate to a URL.

**Parameters:**
- `url` (string, required): The URL to navigate to

**Example:**
```javascript
{
  "name": "browser_navigate",
  "arguments": {
    "url": "https://dataexplorer.azure.com/dashboards"
  }
}
```

#### 2. `browser_snapshot`
**⭐ MOST IMPORTANT TOOL** - Capture accessibility snapshot of the page.

**Returns**: YAML-formatted accessibility tree with:
- All interactive elements
- Text content
- Roles (button, link, textbox, etc.)
- Element references (`ref=e1`, `ref=e2`, etc.)

**Example Response:**
```yaml
- generic [ref=e1]
  - heading "Dashboard Manager" [ref=e2]
  - button "Export" [ref=e3]
  - link "Settings" [ref=e4]
  - textbox "Search dashboards" [ref=e5]
```

**Usage:**
```javascript
{
  "name": "browser_snapshot",
  "arguments": {}
}
```

#### 3. `browser_click`
Click an element.

**Parameters:**
- `element` (string, required): Human-readable element description
- `ref` (string, required): Element reference from snapshot (e.g., "e3")
- `doubleClick` (boolean, optional): Perform double-click
- `button` (string, optional): "left" (default), "right", "middle"
- `modifiers` (array, optional): ["Alt", "Control", "Shift"]

**Example:**
```javascript
{
  "name": "browser_click",
  "arguments": {
    "element": "Export button",
    "ref": "e3"
  }
}
```

#### 4. `browser_type`
Type text into an input field.

**Parameters:**
- `element` (string, required): Element description
- `ref` (string, required): Element reference from snapshot
- `text` (string, required): Text to type
- `submit` (boolean, optional): Press Enter after typing
- `slowly` (boolean, optional): Type character-by-character

**Example:**
```javascript
{
  "name": "browser_type",
  "arguments": {
    "element": "Search box",
    "ref": "e5",
    "text": "My Dashboard",
    "submit": true
  }
}
```

#### 5. `browser_fill_form`
Fill multiple form fields at once.

**Parameters:**
- `fields` (array, required): Array of field objects

**Example:**
```javascript
{
  "name": "browser_fill_form",
  "arguments": {
    "fields": [
      {
        "name": "Username field",
        "type": "textbox",
        "ref": "e10",
        "value": "user@example.com"
      },
      {
        "name": "Remember me checkbox",
        "type": "checkbox",
        "ref": "e11",
        "value": "true"
      }
    ]
  }
}
```

#### 6. `browser_hover`
Hover over an element.

**Parameters:**
- `element` (string, required): Element description
- `ref` (string, required): Element reference

#### 7. `browser_drag`
Drag and drop between elements.

**Parameters:**
- `startElement` (string, required): Source element description
- `startRef` (string, required): Source element reference
- `endElement` (string, required): Target element description
- `endRef` (string, required): Target element reference

#### 8. `browser_select_option`
Select dropdown option.

**Parameters:**
- `element` (string, required): Dropdown description
- `ref` (string, required): Dropdown reference
- `values` (array, required): Values to select

#### 9. `browser_press_key`
Press a keyboard key.

**Parameters:**
- `key` (string, required): Key name (e.g., "Enter", "ArrowDown", "Escape")

#### 10. `browser_wait_for`
Wait for conditions.

**Parameters:**
- `time` (number, optional): Seconds to wait
- `text` (string, optional): Text to wait for (appears)
- `textGone` (string, optional): Text to wait for (disappears)

**Example:**
```javascript
{
  "name": "browser_wait_for",
  "arguments": {
    "text": "Export complete"
  }
}
```

#### 11. `browser_evaluate`
Execute JavaScript on page or element.

**Parameters:**
- `function` (string, required): JavaScript function
- `element` (string, optional): Element description
- `ref` (string, optional): Element reference

**Example:**
```javascript
{
  "name": "browser_evaluate",
  "arguments": {
    "function": "() => document.title"
  }
}
```

#### 12. `browser_console_messages`
Get console messages.

**Parameters:**
- `onlyErrors` (boolean, optional): Only return errors

#### 13. `browser_network_requests`
Get all network requests since page load.

**Returns**: List of URLs requested.

#### 14. `browser_take_screenshot`
Take a screenshot (PNG or JPEG).

**Parameters:**
- `type` (string, optional): "png" (default) or "jpeg"
- `filename` (string, optional): Output filename
- `element` (string, optional): Element description (for element screenshot)
- `ref` (string, optional): Element reference
- `fullPage` (boolean, optional): Capture full scrollable page

#### 15. `browser_navigate_back`
Go back to previous page.

#### 16. `browser_close`
Close the browser/page.

#### 17. `browser_resize`
Resize browser window.

**Parameters:**
- `width` (number, required): Width in pixels
- `height` (number, required): Height in pixels

### Tab Management

#### `browser_tabs`
Manage browser tabs.

**Parameters:**
- `action` (string, required): "list", "new", "close", "select"
- `index` (number, optional): Tab index (for close/select)

**Examples:**
```javascript
// List all tabs
{ "name": "browser_tabs", "arguments": { "action": "list" } }

// Open new tab
{ "name": "browser_tabs", "arguments": { "action": "new" } }

// Close tab 2
{ "name": "browser_tabs", "arguments": { "action": "close", "index": 2 } }

// Switch to tab 1
{ "name": "browser_tabs", "arguments": { "action": "select", "index": 1 } }
```

### File Upload

#### `browser_file_upload`
Upload files to file input.

**Parameters:**
- `paths` (array, optional): Absolute paths to files

### Dialog Handling

#### `browser_handle_dialog`
Handle JavaScript dialogs (alert, confirm, prompt).

**Parameters:**
- `accept` (boolean, required): Accept or reject
- `promptText` (string, optional): Text for prompt dialog

## Accessibility Snapshot Format

When you call `browser_snapshot`, you get a **YAML accessibility tree**:

### Structure Example

```yaml
- Page URL: https://dataexplorer.azure.com/dashboards
- Page Title: Azure Data Explorer - Dashboards
- Page Snapshot:
  - banner [ref=e1]
    - heading "Azure Data Explorer" [ref=e2]
    - button "Sign in" [ref=e3]
  - main [ref=e4]
    - heading "My Dashboards" [ref=e5]
    - grid [ref=e6]
      - row [ref=e7]
        - gridcell [ref=e8]
          - link "Sales Dashboard" [ref=e9]
        - gridcell [ref=e10]
          - text "Created: 2025-10-01"
      - row [ref=e11]
        - gridcell [ref=e12]
          - link "Service Health" [ref=e13]
        - gridcell [ref=e14]
          - text "Created: 2025-09-15"
    - button "New Dashboard" [ref=e15]
```

### Understanding References

- **`[ref=e1]`**: Unique element reference for interaction
- **`[active]`**: Currently focused element
- **Roles**: button, link, textbox, heading, grid, row, etc.
- **Text**: Visible text content or accessible names

## Browser Configuration Options

### Command-Line Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--browser` | Browser to use | `--browser=msedge` |
| `--headless` | Run headless | `--headless` |
| `--user-data-dir` | Profile directory | `--user-data-dir=C:/profile` |
| `--timeout-action` | Action timeout (ms) | `--timeout-action=10000` |
| `--timeout-navigation` | Navigation timeout (ms) | `--timeout-navigation=60000` |
| `--viewport-size` | Window size | `--viewport-size=1920x1080` |
| `--device` | Emulate device | `--device="iPhone 15"` |
| `--ignore-https-errors` | Ignore SSL errors | `--ignore-https-errors` |
| `--isolated` | In-memory profile | `--isolated` |
| `--storage-state` | Load cookies/storage | `--storage-state=auth.json` |

### Browser Types

- `chromium` - Chromium (default)
- `chrome` - Google Chrome
- `msedge` - Microsoft Edge ⭐ (recommended for work accounts)
- `firefox` - Firefox
- `webkit` - WebKit (Safari engine)

### Persistent Profile Locations

**Windows:**
```
%USERPROFILE%\AppData\Local\ms-playwright\mcp-{browser}-profile
```

**macOS:**
```
~/Library/Caches/ms-playwright/mcp-{browser}-profile
```

**Linux:**
```
~/.cache/ms-playwright/mcp-{browser}-profile
```

## Advanced Features

### Using Edge with Work Profile

For Azure Data Explorer (requires Microsoft authentication):

```json
{
  "Playwright": {
    "command": "npx",
    "args": [
      "@playwright/mcp@latest",
      "--browser=msedge"
    ],
    "type": "stdio"
  }
}
```

**First run**: Browser opens, you sign in, close browser.
**Subsequent runs**: Already authenticated!

### Saving Session State

```json
{
  "args": [
    "@playwright/mcp@latest",
    "--save-session",
    "--output-dir=C:/playwright-sessions"
  ]
}
```

Saves:
- Session files
- Storage state
- Optionally: trace, video, screenshots

### Isolated Mode (Testing)

```json
{
  "args": [
    "@playwright/mcp@latest",
    "--isolated",
    "--storage-state=auth.json"
  ]
}
```

- Ephemeral profile (in-memory)
- Load initial auth from file
- Discarded on close

## Best Practices for Kusto Dashboard Manager

### 1. Dashboard Export Workflow

```
1. browser_navigate → Dashboard URL
2. browser_wait_for → Wait for "Dashboard" text
3. browser_snapshot → Get page structure
4. browser_evaluate → Extract dashboard JSON
5. Save JSON to file
```

### 2. Dashboard List Parsing

```
1. browser_navigate → https://dataexplorer.azure.com/dashboards
2. browser_wait_for → Wait for dashboard list
3. browser_snapshot → Capture accessibility tree
4. Parse YAML for:
   - Dashboard names
   - Dashboard links (URLs)
   - Creator information (if available)
5. Filter by creator
6. Export each dashboard
```

### 3. Error Handling

Always wrap in try/catch and handle:
- Navigation timeouts
- Missing elements
- Network errors
- Authentication failures

### 4. Element Selection Strategy

**Priority order:**
1. Use `browser_snapshot` to get current page structure
2. Find element by role and text: `button "Export" [ref=e3]`
3. Use the `ref` value for interactions
4. Avoid hardcoding `ref` values (they change!)

## Integration with Kusto Dashboard Manager

### How Your MCP Server Uses Playwright MCP

```python
# Your MCP server (src/mcp_server.py)
async def _export_dashboard(url, output_path):
    # 1. Call Playwright MCP: browser_navigate
    await playwright_client.navigate(url)
    
    # 2. Call Playwright MCP: browser_wait_for
    await playwright_client.wait_for(text="Dashboard")
    
    # 3. Call Playwright MCP: browser_snapshot
    snapshot = await playwright_client.snapshot()
    
    # 4. Call Playwright MCP: browser_evaluate
    dashboard_json = await playwright_client.evaluate(
        "() => window.__DASHBOARD_DATA__"
    )
    
    # 5. Save to file
    with open(output_path, 'w') as f:
        json.dump(dashboard_json, f, indent=2)
```

### Communication Flow

```
VS Code Copilot
    ↓ JSON-RPC (stdio)
Kusto Dashboard Manager MCP Server (Python)
    ↓ JSON-RPC (stdio)
Playwright MCP Server (Node.js)
    ↓ Playwright API
Browser (Edge/Chrome/Firefox)
    ↓ HTTP/WebSocket
Azure Data Explorer Website
```

## Troubleshooting

### Browser Not Installed

**Error:** `Executable doesn't exist at C:\...\ms-playwright\...`

**Solution:**
```json
{
  "name": "browser_install",
  "arguments": {}
}
```

Or run manually:
```bash
npx playwright install chromium
npx playwright install msedge
```

### Authentication Issues

**Problem:** Not logged into Azure Data Explorer

**Solutions:**
1. Use Edge with persistent profile (`--browser=msedge`)
2. Run headed first time (omit `--headless`)
3. Manually log in, then close browser
4. Future runs will be authenticated

### Timeouts

**Default Timeouts:**
- Action timeout: 5,000ms (5s)
- Navigation timeout: 60,000ms (60s)

**Increase timeouts:**
```json
{
  "args": [
    "@playwright/mcp@latest",
    "--timeout-action=15000",      // 15s
    "--timeout-navigation=120000"  // 2m
  ]
}
```

### Snapshot Too Large

If accessibility snapshot is huge, filter in your code:
- Focus on specific sections
- Remove hidden elements
- Extract only needed data

## Performance Tips

1. **Reuse browser sessions**: Don't close/reopen for each operation
2. **Use persistent profiles**: Faster startup, keeps auth
3. **Headed vs Headless**: Headed is slower but easier to debug
4. **Network filtering**: Block unnecessary resources with `--blocked-origins`

## Security Considerations

1. **Credentials**: Use `--secrets` file for sensitive data
2. **Storage state**: Keep `auth.json` files secure
3. **Isolated mode**: Use for untrusted operations
4. **Profile location**: Be aware of where cookies are stored

## Examples for Common Tasks

### Example 1: Navigate and Extract Text

```javascript
// 1. Navigate
{ "name": "browser_navigate", "arguments": { "url": "https://example.com" } }

// 2. Get snapshot
{ "name": "browser_snapshot", "arguments": {} }

// Response shows: heading "Welcome" [ref=e5]

// 3. Extract text
{
  "name": "browser_evaluate",
  "arguments": {
    "element": "Welcome heading",
    "ref": "e5",
    "function": "(element) => element.textContent"
  }
}
```

### Example 2: Fill Form and Submit

```javascript
// 1. Get snapshot to find fields
{ "name": "browser_snapshot", "arguments": {} }

// Response shows:
//   textbox "Email" [ref=e10]
//   textbox "Password" [ref=e11]
//   button "Sign in" [ref=e12]

// 2. Fill form
{
  "name": "browser_fill_form",
  "arguments": {
    "fields": [
      { "name": "Email", "type": "textbox", "ref": "e10", "value": "user@example.com" },
      { "name": "Password", "type": "textbox", "ref": "e11", "value": "secret" }
    ]
  }
}

// 3. Click submit
{ "name": "browser_click", "arguments": { "element": "Sign in button", "ref": "e12" } }

// 4. Wait for success
{ "name": "browser_wait_for", "arguments": { "text": "Welcome back" } }
```

### Example 3: Parse Grid Data

```javascript
// 1. Navigate to page with grid
{ "name": "browser_navigate", "arguments": { "url": "https://app.com/data" } }

// 2. Get snapshot
{ "name": "browser_snapshot", "arguments": {} }

// Snapshot shows:
// - grid [ref=e1]
//   - row [ref=e2]
//     - gridcell [ref=e3]: "Item 1"
//     - gridcell [ref=e4]: "100"
//   - row [ref=e5]
//     - gridcell [ref=e6]: "Item 2"
//     - gridcell [ref=e7]: "200"

// 3. Extract all row data
{
  "name": "browser_evaluate",
  "arguments": {
    "function": `() => {
      const rows = Array.from(document.querySelectorAll('[role="row"]'));
      return rows.map(row => {
        const cells = Array.from(row.querySelectorAll('[role="gridcell"]'));
        return cells.map(cell => cell.textContent.trim());
      });
    }`
  }
}
```

## Resources

- **Official Docs**: https://github.com/microsoft/playwright-mcp
- **NPM Package**: https://www.npmjs.com/package/@playwright/mcp
- **Playwright Docs**: https://playwright.dev/docs/intro
- **MCP Specification**: https://modelcontextprotocol.io/

## Quick Reference Card

| Task | Tool | Key Parameters |
|------|------|----------------|
| Navigate | `browser_navigate` | `url` |
| Get page structure | `browser_snapshot` | none |
| Click element | `browser_click` | `element`, `ref` |
| Type text | `browser_type` | `element`, `ref`, `text` |
| Fill form | `browser_fill_form` | `fields[]` |
| Wait for element | `browser_wait_for` | `text` or `textGone` |
| Run JavaScript | `browser_evaluate` | `function` |
| Take screenshot | `browser_take_screenshot` | `filename`, `fullPage` |
| Manage tabs | `browser_tabs` | `action`, `index` |
| Handle dialogs | `browser_handle_dialog` | `accept`, `promptText` |

---

**Last Updated**: October 9, 2025  
**Playwright MCP Version**: 0.0.41  
**Status**: ✅ Complete Reference
