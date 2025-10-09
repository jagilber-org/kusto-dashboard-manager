# Kusto Dashboard Manager - MCP Server Configuration

This document explains how to configure and use the Kusto Dashboard Manager as an MCP server in VS Code.

## Overview

The Kusto Dashboard Manager is now available as an **MCP (Model Context Protocol) server**, allowing you to manage Azure Data Explorer dashboards directly from VS Code Copilot.

## Architecture

```
VS Code Copilot
    ↓ (MCP Protocol)
Kusto Dashboard Manager (MCP Server)
    ↓ (calls)
Playwright MCP Server
    ↓ (browser automation)
Azure Data Explorer Web UI
```

## Configuration

### 1. Add to VS Code MCP Configuration

Edit your VS Code MCP config file at:
- **Windows**: `%APPDATA%\Code - Insiders\User\mcp.json`
- **Mac/Linux**: `~/.config/Code - Insiders/User/mcp.json`

Add this entry to the `"servers"` object:

```json
{
  "servers": {
    "kusto-dashboard-manager": {
      "command": "python",
      "args": [
        "-m",
        "src.mcp_server"
      ],
      "cwd": "c:/github/jagilber/kusto-dashboard-manager",
      "type": "stdio"
    },
    "Playwright": {
      "command": "npx",
      "args": [
        "@playwright/mcp@latest"
      ],
      "type": "stdio"
    }
  }
}
```

**Note**: Both servers are required. The Kusto Dashboard Manager calls Playwright MCP for browser automation.

### 2. Install Dependencies

```powershell
# Python dependencies
pip install -r requirements.txt

# Playwright MCP (auto-installed via npx)
# No manual installation needed
```

### 3. Reload VS Code

After updating `mcp.json`:
1. Press `Ctrl+Shift+P` (Windows) or `Cmd+Shift+P` (Mac)
2. Run: **Developer: Reload Window**

## Available Tools

### 1. `export_dashboard`
Export an Azure Data Explorer dashboard to JSON.

**Parameters:**
- `url` (required): Dashboard URL (e.g., `https://dataexplorer.azure.com/dashboards/abc123`)
- `outputPath` (optional): Custom output path (default: auto-generated in `exports/`)

**Example Copilot prompt:**
```
Export the dashboard at https://dataexplorer.azure.com/dashboards/abc123
```

### 2. `import_dashboard`
Import a dashboard from JSON file.

**Parameters:**
- `url` (required): Target dashboard URL or base URL
- `jsonPath` (required): Path to JSON file
- `force` (optional): Force overwrite if exists (default: false)

**Example Copilot prompt:**
```
Import dashboard from exports/my-dashboard.json to https://dataexplorer.azure.com/dashboards
```

### 3. `validate_dashboard`
Validate dashboard JSON without importing.

**Parameters:**
- `jsonPath` (required): Path to JSON file

**Example Copilot prompt:**
```
Validate the dashboard JSON at exports/my-dashboard.json
```

### 4. `export_all_dashboards`
Export all dashboards created by current user (bulk export).

**Parameters:**
- `listUrl` (optional): Dashboards list URL (default: `https://dataexplorer.azure.com/dashboards`)

**Example Copilot prompt:**
```
Export all my dashboards from Azure Data Explorer
```

**Note**: This feature is under development and requires dashboard list parsing implementation.

## Usage Examples

### Using Copilot Chat

1. Open VS Code Copilot Chat
2. Type your request naturally:

```
@workspace export the dashboard at https://dataexplorer.azure.com/dashboards/abc123 to exports/backup.json
```

```
@workspace validate my dashboard JSON at exports/my-dashboard.json
```

```
@workspace import dashboard from exports/my-dashboard.json
```

### Using MCP Tools Directly

You can also invoke tools programmatically if building your own MCP client:

```json
{
  "method": "tools/call",
  "params": {
    "name": "export_dashboard",
    "arguments": {
      "url": "https://dataexplorer.azure.com/dashboards/abc123",
      "outputPath": "exports/my-dashboard.json"
    }
  }
}
```

## Bulk Export Workflow

To export all your dashboards:

1. **Use Copilot**: 
   ```
   Export all my dashboards from Azure Data Explorer
   ```

2. **Manual workflow** (see `scripts/bulk_export.py`):
   - Navigate to dashboards page via Playwright MCP
   - Capture accessibility snapshot
   - Parse dashboard list
   - Export each dashboard
   - Generate manifest

## Troubleshooting

### Server Not Appearing in Copilot

1. Check `mcp.json` syntax (valid JSON)
2. Verify `cwd` path is correct
3. Ensure Python is in PATH
4. Reload VS Code window

### Import/Export Failures

1. Check browser is authenticated (use Edge with work profile)
2. Verify dashboard URL format
3. Check network connectivity
4. Review logs in workspace

### Playwright MCP Not Working

1. Ensure Playwright server is configured in `mcp.json`
2. Run `npx @playwright/mcp@latest` manually to test
3. Check for browser installation issues

## Configuration Files

- **`mcp.json`**: VS Code MCP server configuration
- **`.env`**: Environment variables (API keys, credentials)
- **`config/settings.json`**: Dashboard manager settings

## Next Steps

1. ✅ MCP server configured in VS Code
2. ✅ Test export/import via Copilot
3. 🚧 Implement bulk export with dashboard list parsing
4. 🚧 Add creator filtering for bulk operations
5. 🚧 Add dashboard search/filter capabilities

## Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- [Playwright MCP Documentation](https://github.com/playwright/playwright-mcp)
- [VS Code MCP Integration](https://code.visualstudio.com/docs/copilot/mcp)

---

**Status**: MCP server architecture complete, ready for testing
