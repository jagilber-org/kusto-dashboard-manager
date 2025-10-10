# Dashboard Extraction Findings

**Date:** October 9, 2025  
**Dashboard:** armprod  
**Dashboard ID:** `03e8f08f-8111-40f4-9f58-270678db9782`  
**URL:** `https://dataexplorer.azure.com/dashboards/03e8f08f-8111-40f4-9f58-270678db9782`

## Key Findings

### 1. Dashboard Structure
- **Title:** armprod
- **Creator:** Jason Gilbertson
- **Created:** 11/3/2020
- **Last Accessed:** 1 day ago
- **Tile Visible:** "arm operations-v240709" with 200 rows of data

### 2. URL Pattern
```
https://dataexplorer.azure.com/dashboards/{dashboard-id}
```

Query parameters include:
- `p-_startTime=24hours`
- `p-_endTime=now`
- `p-_subscription=all`
- `p-_resourceUri=all`
- `p-_resourceTypes=all`
- `p-_resourceGroup=all`
- `p-_limit=v-200`

### 3. JavaScript Investigation Results
No dashboard data found in common JavaScript locations:
- ❌ `window.__INITIAL_STATE__` - not present
- ❌ `window.__APP_STATE__` - not present  
- ❌ `window.__DASHBOARD_DATA__` - not present
- ❌ localStorage with 'dashboard' keys - empty
- ❌ sessionStorage with 'dashboard' keys - empty

**Conclusion:** Dashboard data is NOT embedded in the HTML/JS. It must be fetched via API calls.

### 4. ✅ DISCOVERED API ENDPOINT

Using `performance.getEntriesByType('resource')` to analyze network requests, found the actual dashboard JSON API:

**Working API Pattern:**
```
GET https://dashboards.kusto.windows.net/dashboards/{dashboard-id}
```

**Confirmed Example:**
```
https://dashboards.kusto.windows.net/dashboards/03e8f08f-8111-40f4-9f58-270678db9782
```

**Request Details:**
- Type: fetch
- Duration: 447.7ms
- Authentication: Browser session cookies (already authenticated)

**Discovery Method:**
```javascript
// Executed in browser console via browser_evaluate
const entries = performance.getEntriesByType('resource');
const dashboardApi = entries.find(e => e.name.includes('/dashboards/') && e.initiatorType === 'fetch');
// Result: https://dashboards.kusto.windows.net/dashboards/03e8f08f-8111-40f4-9f58-270678db9782
```

##5. Azure Kusto Dashboard MCP Tools

**IMPORTANT DISCOVERY:** Azure already provides MCP tools for dashboard management!

The `@modelcontextprotocol/server-azure` package includes Kusto Dashboard tools:
- `mcp_kusto-dashboa_export_dashboard` - Export single dashboard to JSON
- `mcp_kusto-dashboa_import_dashboard` - Import dashboard from JSON
- `mcp_kusto-dashboa_export_all_dashboards` - Bulk export all dashboards by current user
- `mcp_kusto-dashboa_validate_dashboard` - Validate dashboard JSON

### Why We Can't Use MCP Dashboard Tools Directly

**Authentication Issue:** These tools require Azure authentication that works in a Node.js MCP server context, but:
1. We're automating via Playwright browser (already authenticated via browser session)
2. MCP tools use Azure SDK authentication (Service Principal, Managed Identity, etc.)
3. Browser cookies/tokens ≠ Azure SDK credentials

**Our Approach:** Use Playwright MCP to automate the browser (leveraging existing auth), then potentially format output to match Azure MCP tool schemas.

## Next Steps

### Option A: Use Azure Kusto Dashboard MCP Tools (Recommended if Auth Works)
**Status:** Investigate authentication compatibility
1. Check if Azure MCP tools can use browser session tokens
2. If yes, replace our automation with direct API calls
3. Benefit: Native JSON export/import, validation built-in

### Option B: Continue Browser Automation + API Extraction (Current Path)
**Status:** In progress - need network capture
1. ✅ Navigate to dashboard page
2. ✅ Capture page snapshot (accessibility tree)
3. 🔄 **CURRENT TASK:** Intercept network request to find dashboard JSON endpoint
4. Use `browser_evaluate` to make XHR/fetch request to dashboard API
5. Extract full dashboard JSON definition
6. Save to file for analysis

### Recommended Hybrid Approach:
1. Use Playwright to get dashboard list (browser auth)
2. Extract dashboard IDs with creator filtering (our parser)
3. Call Azure MCP export tools directly with dashboard IDs (if auth works)
4. Fallback to API extraction if MCP tools unavailable

## Code Strategy

### Current Implementation
```python
# Phase 1: List Dashboards (browser automation)
playwright_client.navigate("https://dataexplorer.azure.com/dashboards")
snapshot = playwright_client.snapshot()
dashboards = parse_dashboard_list(snapshot, creator=creator)

# Phase 2: Extract Dashboard (TO BE IMPLEMENTED)
for dashboard in dashboards:
    playwright_client.navigate(dashboard.url)
    # Option 1: Find API endpoint via network capture
    # Option 2: Use browser_evaluate to call internal API
    # Option 3: Try Azure MCP tools if auth configured
    dashboard_json = extract_dashboard_definition(dashboard.id)
    save_dashboard(dashboard_json)
```

### Integration with Azure MCP Tools (If Available)
```python
# If Azure MCP tools work with our auth:
from azure_mcp_client import export_dashboard

for dashboard in dashboards:
    try:
        # Direct API call via Azure MCP
        dashboard_json = export_dashboard(dashboard.id)
        save_dashboard(dashboard_json)
    except AuthenticationError:
        # Fallback to browser automation
        dashboard_json = extract_via_browser(dashboard.id)
        save_dashboard(dashboard_json)
```

## Investigation Tasks

### Immediate (Phase 1, Step 4 continuation):
1. ✅ Navigate to dashboard page
2. ✅ Identify dashboard ID from URL
3. 🔄 **NEXT:** Use browser developer tools/network tab to find API endpoint
   - Check Network tab for XHR/Fetch requests
   - Look for requests to `/api/dashboards/` or similar
   - Capture full request URL and response structure

### Short-term:
4. Test extraction method (API call via browser_evaluate)
5. Verify JSON structure matches Azure Kusto Dashboard schema
6. Document dashboard JSON format

### Long-term:
7. Implement bulk export with creator filtering
8. Add validation against Azure Kusto Dashboard schema
9. Test import functionality
10. Create manifest for exported dashboards

## References
- Azure Data Explorer Dashboards: https://dataexplorer.azure.com/dashboards
- Azure MCP Tools: @modelcontextprotocol/server-azure
- Dashboard Parser: `src/dashboard_list_parser.py`
- Environment Config: `src/env_config.py`
