# Python Migration Plan

## Decision: Convert from PowerShell to Python

**Rationale**: Working Python MCP client already exists and handles JSON-RPC/stdio communication correctly. Converting to Python is faster and more reliable than implementing MCP protocol from scratch in PowerShell.

---

## Migration Strategy

### Phase 1: Core Infrastructure (1-2 hours)

1. **MCP Client Integration**
   - ✅ Copy working Python MCP client (`working-py-mcp-client.py`)
   - Extract and adapt the MCP communication layer
   - Create reusable MCP client class for Playwright server

2. **Project Structure**
   ```
   src/
   ├── kusto_dashboard_manager.py    # Main CLI
   ├── mcp_client.py                 # MCP protocol client
   ├── browser_manager.py            # Browser automation via Playwright MCP
   ├── dashboard_export.py           # Export logic
   ├── dashboard_import.py           # Import logic
   ├── config.py                     # Configuration management
   └── utils.py                      # Logging & utilities
   ```

3. **Dependencies**
   - Python 3.12+ ✅ (already installed)
   - No external packages needed (uses subprocess + json stdlib)
   - Optional: `asyncio` for async operations

### Phase 2: Convert Modules (2-3 hours)

#### Module Conversion Priority

1. **mcp_client.py** (NEW - extracted from working client)
   - `MCPClient` class with Content-Length framing
   - `initialize()`, `list_tools()`, `call_tool()` methods
   - Connection management (start/stop MCP server process)

2. **browser_manager.py** (Convert from BrowserManager.psm1)
   - Use MCP client to call Playwright tools
   - `launch_browser()`, `navigate()`, `click()`, `get_text()`, `close()`
   - Browser state management

3. **config.py** (Convert from Configuration.psm1)
   - Simple dict-based configuration
   - Environment support (dev/staging/prod)
   - Validation

4. **dashboard_export.py** (Convert from Export-KustoDashboard.psm1)
   - Dashboard URL parsing
   - Browser automation for export
   - JSON file output

5. **dashboard_import.py** (Convert from Import-KustoDashboard.psm1)
   - JSON file validation
   - Browser automation for import
   - Import verification

6. **kusto_dashboard_manager.py** (Convert from KustoDashboardManager.ps1)
   - CLI argument parsing (argparse)
   - Action routing (export/import/validate)
   - User-friendly output

### Phase 3: Testing (1 hour)

1. **Unit Tests** (pytest)
   - Convert existing Pester tests to pytest
   - Mock MCP client calls
   - Test each module in isolation

2. **Integration Tests**
   - Real Playwright MCP server connection
   - End-to-end export/import workflows

3. **Manual Validation**
   - Test with real Kusto dashboard
   - Verify JSON output format
   - Confirm import success

---

## Implementation Steps

### Step 1: Create Python MCP Client Wrapper

```python
class PlaywrightMCPClient:
    """Wrapper around MCP client specifically for Playwright server."""
    
    def __init__(self):
        self.client = WorkingPyMCPClient()
        self.connected = False
    
    async def connect(self):
        """Start Playwright MCP server and establish connection."""
        server_cmd = ['npx', '@playwright/mcp@latest']
        self.connected = await self.client.connect(server_cmd)
        return self.connected
    
    async def launch_browser(self, browser='edge', headless=False):
        """Launch browser via Playwright MCP."""
        result = await self.client.call_tool('browser_launch', {
            'browser': browser,
            'headless': headless
        })
        return result
    
    async def navigate(self, url):
        """Navigate to URL."""
        return await self.client.call_tool('browser_navigate', {'url': url})
    
    # ... other browser operations
```

### Step 2: Create CLI Interface

```python
# kusto_dashboard_manager.py
import argparse
import asyncio
from dashboard_export import export_dashboard
from dashboard_import import import_dashboard

async def main():
    parser = argparse.ArgumentParser(description='Kusto Dashboard Manager')
    parser.add_argument('action', choices=['export', 'import', 'validate'])
    parser.add_argument('--dashboard-url', help='Dashboard URL')
    parser.add_argument('--output-path', help='Output file path')
    parser.add_argument('--definition-path', help='Dashboard definition file')
    parser.add_argument('--browser', default='edge', choices=['edge', 'chrome', 'firefox'])
    parser.add_argument('--headless', action='store_true', help='Run in headless mode')
    
    args = parser.parse_args()
    
    if args.action == 'export':
        await export_dashboard(args.dashboard_url, args.output_path, 
                               args.browser, args.headless)
    elif args.action == 'import':
        await import_dashboard(args.dashboard_url, args.definition_path,
                               args.browser, args.headless)
    # ... etc

if __name__ == '__main__':
    asyncio.run(main())
```

### Step 3: Convert Business Logic

Convert each PowerShell module to equivalent Python module, maintaining:
- Same function signatures (adapted to Python conventions)
- Same validation logic
- Same error handling
- Improved with Python features (type hints, async/await, context managers)

---

## Advantages of Python Approach

✅ **Working MCP client already exists** - No protocol implementation needed  
✅ **Async/await native support** - Better for I/O operations  
✅ **Rich ecosystem** - pytest, type hints, better JSON handling  
✅ **Cross-platform** - Works on Windows/Linux/Mac  
✅ **Simpler deployment** - Single .py file or simple package  
✅ **Better error handling** - Try/except more natural than PowerShell  
✅ **Type safety** - Optional type hints for better IDE support  

## What We Keep

✅ **All business logic** - Export/Import algorithms unchanged  
✅ **All test cases** - Convert to pytest format  
✅ **Documentation** - Minor updates for Python syntax  
✅ **Project structure** - Same modular design  
✅ **Git history** - Maintain commit history  

## Timeline

- **Phase 1 (MCP Client)**: 1-2 hours
- **Phase 2 (Convert Modules)**: 2-3 hours  
- **Phase 3 (Testing)**: 1 hour
- **Total**: **4-6 hours** to fully functional Python version

---

## Migration Tracking

### Completed
- ✅ Copy working Python MCP client
- ✅ Validate Python installation (3.12.10)

### Next Steps
1. Extract MCP client wrapper class
2. Create project structure
3. Convert Configuration module
4. Convert BrowserManager module
5. Convert Export/Import modules
6. Create CLI
7. Write tests
8. Update documentation

---

## Rollback Plan

If Python migration fails:
- PowerShell code remains intact
- Can revert to implementing MCP protocol in PowerShell
- All business logic preserved in PowerShell modules

## Success Criteria

- ✅ Export dashboard to JSON works
- ✅ Import dashboard from JSON works
- ✅ Validate JSON schema works
- ✅ CLI matches PowerShell version functionality
- ✅ All tests passing
- ✅ Documentation updated

---

**Status**: Ready to begin Phase 1  
**Next Action**: Extract MCP client wrapper and create Python project structure
