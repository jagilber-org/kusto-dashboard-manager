# Quick Start: Interactive Playwright MCP Workflow

## ✅ Setup Complete!

Your configuration is ready:
- ✅ Tracing enabled in `mcp.json`
- ✅ Output directory: `c:/github/jagilber/kusto-dashboard-manager/traces`
- ✅ Snapshots directory: `docs/snapshots/`
- ✅ Playwright MCP server configured

## 🔄 Next Step: Restart VS Code

**You must restart VS Code Insiders to reload the MCP configuration.**

After restart, the Playwright MCP server will automatically save:
- **Trace files**: `traces/*.zip` - View with `npx playwright show-trace <file>.zip`
- **Session state**: `traces/*.json` - Browser state for resuming

---

## 📋 Phase 1: Navigate and Capture Dashboard List

### Step 1: Navigate to Dashboards

**Copy this prompt into Copilot Chat:**

```
Using the Playwright MCP browser_navigate tool, navigate to:
https://dataexplorer.azure.com/dashboards

Wait for the page to load completely.
```

**Expected:** Browser opens, uses your existing Azure auth session.

---

### Step 2: Capture Dashboard List Snapshot

**Copy this prompt into Copilot Chat:**

```
Using browser_snapshot, capture the accessibility tree of the current page.
Save the complete YAML output to:
c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboards-list.yaml
```

**Expected:** Creates `dashboards-list.yaml` with structure like:

```yaml
- generic [ref=e1]
  - heading "Dashboards" [ref=e2]
  - grid [ref=e10]
    - row [ref=e11]
      - gridcell [ref=e12]
        - link "Dashboard Name" href="/dashboards/abc123" [ref=e13]
      - gridcell [ref=e14]
        - text "Creator Name" [ref=e15]
```

---

### Step 3: Analyze the Structure

**Copy this prompt into Copilot Chat:**

```
Analyze the YAML file at docs/snapshots/dashboards-list.yaml:

1. Find all elements with role="link" that have href containing "/dashboards/"
2. For each dashboard link, identify:
   - Dashboard name (link text)
   - Dashboard URL/ID (href attribute)
   - Creator name (nearby text in same row)
   - Last modified date (if visible)

Create a summary document at:
c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboard-structure.md

Include:
- The YAML structure pattern for a single dashboard row
- XPath-like pattern to extract dashboard data
- Any challenges or ambiguities found
```

**Expected:** Documentation of how to parse dashboard entries from YAML.

---

## 📋 Phase 2: Test Single Dashboard Extraction

### Step 4: Click First Dashboard

**Copy this prompt into Copilot Chat:**

```
Based on the analysis in docs/snapshots/dashboard-structure.md:

1. Find the FIRST dashboard link in docs/snapshots/dashboards-list.yaml
2. Use browser_click with the link's ref value to navigate to that dashboard
3. Wait for the page to load
4. Capture a new snapshot and save to:
   c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/single-dashboard-view.yaml
```

**Expected:** 
- Navigates to individual dashboard
- Captures dashboard view structure
- File saved with dashboard layout/widgets

---

### Step 5: Extract Dashboard Definition

**Copy this prompt into Copilot Chat:**

```
Using browser_evaluate, run this JavaScript function to find the dashboard JSON:

function() {
  // Try common locations for dashboard data
  const locations = [
    () => window.dashboard,
    () => window.dashboardDefinition,
    () => window.__INITIAL_STATE__,
    () => window.__NEXT_DATA__,
    () => {
      // Find React root data
      const root = document.querySelector('[data-reactroot]');
      if (root) {
        const key = Object.keys(root).find(k => k.startsWith('__reactInternalInstance'));
        return root[key]?.return?.memoizedState;
      }
    }
  ];
  
  for (const getter of locations) {
    try {
      const result = getter();
      if (result && typeof result === 'object') {
        return { found: true, location: getter.toString(), data: result };
      }
    } catch (e) {
      continue;
    }
  }
  
  return { 
    found: false, 
    windowKeys: Object.keys(window).filter(k => 
      k.toLowerCase().includes('dash') || 
      k.toLowerCase().includes('react') ||
      k.toLowerCase().includes('state')
    )
  };
}

Save the result to:
c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboard-js-exploration.json
```

**Expected:** 
- JSON showing where dashboard data is stored
- Either the actual dashboard definition OR hints about where to find it

---

### Step 6: Extract Full Dashboard JSON

**Once you know where the data is (from Step 5), run this:**

```
Using browser_evaluate, extract the complete dashboard definition using the
location identified in docs/snapshots/dashboard-js-exploration.json

Save the complete dashboard JSON to:
c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboard-example.json

This should include:
- Dashboard metadata (name, id, description)
- All tiles/widgets with queries
- Layout information
- Data source connections
```

**Expected:** Complete dashboard JSON suitable for export/import.

---

## 📋 Phase 3: Return and Parse Pattern

### Step 7: Navigate Back to List

**Copy this prompt into Copilot Chat:**

```
Using browser_navigate, go back to the dashboard list:
https://dataexplorer.azure.com/dashboards

Capture another snapshot to confirm we're back at the list view.
Save to: c:/github/jagilber/kusto-dashboard-manager/docs/snapshots/dashboards-list-return.yaml
```

---

### Step 8: Build Parser Function

**Copy this prompt into Copilot Chat:**

```
Based on the structure documented in docs/snapshots/dashboard-structure.md,
implement the parse_snapshot_yaml() function in:
src/dashboard_list_parser.py

The function should:
1. Load and parse YAML from browser_snapshot output
2. Find all dashboard entries (links with href="/dashboards/...")
3. Extract for each:
   - name: Dashboard name from link text
   - url: Full URL to dashboard
   - id: Dashboard ID from URL
   - creator: Creator name from adjacent gridcell
   - modified: Last modified date (if available)
4. Return list of dictionaries

Include error handling for malformed YAML.
Add comprehensive docstring with example input/output.
```

---

## 🎯 Success Criteria

After completing these steps, you'll have:

✅ `docs/snapshots/dashboards-list.yaml` - Dashboard list structure
✅ `docs/snapshots/dashboard-structure.md` - Pattern documentation  
✅ `docs/snapshots/single-dashboard-view.yaml` - Individual dashboard structure
✅ `docs/snapshots/dashboard-js-exploration.json` - JS data location findings
✅ `docs/snapshots/dashboard-example.json` - Complete dashboard export example
✅ `src/dashboard_list_parser.py` - YAML parsing implementation
✅ `traces/*.zip` - Trace files for debugging

---

## 🐛 Troubleshooting

### Authentication Required

If you see a login screen:

```
The page shows authentication required.
Use browser_snapshot to find the login button.
Click it and complete authentication.
Then return to Step 1.
```

### Elements Not Found

If snapshot doesn't show expected elements:

```
Use browser_wait_for to wait 30 seconds for text "Dashboards" to appear.
Then capture snapshot again.
```

### JavaScript Evaluation Errors

If browser_evaluate returns undefined:

```
Use browser_evaluate to inspect what's available:

function() {
  return {
    title: document.title,
    url: window.location.href,
    hasWindow: typeof window !== 'undefined',
    reactRoot: !!document.querySelector('[data-reactroot]'),
    windowKeys: Object.keys(window).slice(0, 50)
  };
}

Save output to docs/snapshots/page-debug.json for analysis.
```

---

## 📊 View Traces

After your session:

```powershell
# List all trace files
Get-ChildItem .\traces\*.zip | Select-Object Name, Length, LastWriteTime

# View the latest trace
$latest = Get-ChildItem .\traces\*.zip | Sort-Object LastWriteTime -Descending | Select-Object -First 1
npx playwright show-trace $latest.FullName
```

The trace viewer shows:
- 📸 Screenshots at each action
- 🎬 Timeline of all operations  
- 🌐 Network requests
- 📊 Console logs
- 🔍 Element selectors

---

## 🚀 Next Steps

Once you have working patterns from this exploration:

1. **Implement MCP Client** - `src/playwright_mcp_client.py`
   - JSON-RPC communication with Playwright MCP
   - Tool invocation wrapper methods
   - Error handling and retries

2. **Complete Export Tool** - `src/mcp_server.py`
   - `export_all_dashboards` implementation
   - Uses parser to get dashboard list
   - Loops through and extracts each
   - Generates manifest

3. **Test End-to-End** - Via Copilot Chat
   - Call your MCP tool: `export_all_dashboards`
   - Verify all files created
   - Check manifest accuracy

---

## 💡 Tips

- **Save everything** - Snapshots are cheap, traces are invaluable
- **One step at a time** - Don't combine multiple operations
- **Document patterns** - Note what works for future reference
- **Use traces** - When confused, open trace file to see what happened
- **Iterate** - First attempt rarely perfect, adjust and retry

Ready to start? **Restart VS Code first!** 🎉
