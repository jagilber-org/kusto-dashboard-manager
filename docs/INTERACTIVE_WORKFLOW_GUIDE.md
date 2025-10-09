# Interactive Playwright MCP Workflow Guide

## Overview
This guide walks through the MCP-native approach for exploring and automating Azure Data Explorer dashboard exports using `browser_snapshot` and accessibility tree navigation.

## Prerequisites
1. ✅ Tracing enabled (run `scripts\enable-playwright-tracing.ps1`)
2. ✅ VS Code restarted to reload MCP config
3. ✅ Logged into Azure Data Explorer in your browser
4. ✅ Copilot Chat open

## Workflow Steps

### Phase 1: Initial Navigation & Authentication

#### Step 1: Navigate to Dashboards Page

**Prompt for Copilot Chat:**
```
Using the Playwright MCP browser_navigate tool, navigate to:
https://dataexplorer.azure.com/dashboards

Wait for the page to load completely.
```

**Expected Result:**
- Browser opens to dashboards page
- Should use existing auth session if already logged in
- Trace file created in `traces/` directory

---

#### Step 2: Capture Initial Snapshot

**Prompt for Copilot Chat:**
```
Using browser_snapshot, capture the accessibility tree of the current page.
Save the YAML output to docs/snapshots/dashboards-list-initial.yaml
```

**What to Look For:**
```yaml
- grid/table with dashboard entries
- Each row should have:
  - link with dashboard name
  - text showing creator
  - text showing last modified date
```

**Analysis Tasks:**
1. Identify the grid/table structure
2. Find dashboard link elements and their `ref` values
3. Note the pattern for creator information
4. Identify any pagination or filtering controls

---

### Phase 2: Explore Dashboard List Structure

#### Step 3: Analyze Grid Structure

**Prompt for Copilot Chat:**
```
Analyze the YAML snapshot from docs/snapshots/dashboards-list-initial.yaml:

1. Find all elements with role="gridcell" or role="row"
2. Identify dashboard name links (look for href containing '/dashboards/')
3. Extract the pattern for:
   - Dashboard name
   - Creator/owner
   - Last modified date
   - Dashboard URL/ID

Create a structured summary in docs/snapshots/dashboard-structure-analysis.md
```

**Expected Findings:**
```yaml
Example structure:
- row [ref=e10]
  - gridcell [ref=e11]
    - link "My Dashboard Name" href="/dashboards/abc123" [ref=e12]
  - gridcell [ref=e13]
    - text "John Doe" [ref=e14]
  - gridcell [ref=e15]
    - text "2025-10-08" [ref=e16]
```

---

#### Step 4: Test Click on First Dashboard

**Prompt for Copilot Chat:**
```
Using browser_click, click on the first dashboard link found in the snapshot.
Use the ref value identified in the analysis.

After clicking, use browser_snapshot to capture the dashboard view.
Save to docs/snapshots/dashboard-view-single.yaml
```

**What Happens:**
- Navigates to individual dashboard page
- Dashboard visualization loads
- Snapshot captures dashboard structure

---

### Phase 3: Extract Dashboard Definition

#### Step 5: Find Dashboard Definition in JavaScript

**Prompt for Copilot Chat:**
```
Using browser_evaluate, execute this JavaScript to find the dashboard definition:

function() {
  // Check for dashboard object in window
  if (window.dashboard) return window.dashboard;
  if (window.dashboardDefinition) return window.dashboardDefinition;
  
  // Check for React/Redux state
  const state = document.getElementById('__NEXT_DATA__') || 
                document.getElementById('__REDUX_STATE__');
  if (state) return JSON.parse(state.textContent);
  
  // Last resort: inspect all window properties
  return Object.keys(window).filter(k => k.toLowerCase().includes('dashboard'));
}

Save the result to docs/snapshots/dashboard-definition-keys.json
```

**Goal:** Find where Azure Data Explorer stores the dashboard JSON definition

---

#### Step 6: Extract Full Dashboard JSON

**Prompt for Copilot Chat:**
```
Based on the keys found, use browser_evaluate to extract the complete dashboard definition.
Try these patterns:

1. window.dashboardDefinition
2. window.__INITIAL_STATE__.dashboard
3. Network tab inspection for API calls

Save the complete dashboard JSON to docs/snapshots/dashboard-example.json
```

**Validation:**
- JSON should contain dashboard tiles/widgets
- Should have layout information
- Should include data source connections

---

### Phase 4: Navigate Back and Iterate

#### Step 7: Return to Dashboard List

**Prompt for Copilot Chat:**
```
Using browser_navigate, go back to:
https://dataexplorer.azure.com/dashboards

Capture another snapshot to confirm we're back at the list view.
```

---

#### Step 8: Build Dashboard Extraction Pattern

**Prompt for Copilot Chat:**
```
Create a Python function in src/dashboard_list_parser.py that:

1. Parses the YAML snapshot from Step 2
2. Extracts all dashboard entries with:
   - Dashboard name
   - Creator
   - Dashboard URL/ID
   - Last modified
3. Returns a list of dashboard metadata dictionaries

Use the structure patterns identified in Step 3.
```

---

### Phase 5: Automation Planning

#### Step 9: Design Bulk Export Workflow

Based on the exploration, document the automation sequence:

```python
# Pseudo-code for export_all_dashboards tool

1. browser_navigate("https://dataexplorer.azure.com/dashboards")
2. snapshot = browser_snapshot()
3. dashboards = parse_snapshot_yaml(snapshot)
4. dashboards_filtered = filter_by_creator(dashboards, creator_name)

5. For each dashboard in dashboards_filtered:
   a. browser_navigate(dashboard.url)
   b. browser_wait_for("dashboard loaded")
   c. definition = browser_evaluate("() => window.dashboardDefinition")
   d. save_to_file(f"output/{sanitize(dashboard.name)}.json", definition)
   e. update_progress(dashboard.name)

6. generate_manifest(exported_dashboards)
```

---

## Trace Analysis

### View Trace Files

After each session, view traces:

```powershell
# List trace files
Get-ChildItem .\traces\*.zip

# View specific trace
npx playwright show-trace .\traces\trace-2025-10-09.zip
```

### Trace Viewer Features:
- 📸 Screenshots at each step
- 🎬 Action timeline
- 🌐 Network requests
- 📊 Console logs
- 🔍 Selector inspection

---

## Troubleshooting

### Authentication Issues

If auth is required:

**Prompt:**
```
The page shows a login screen. 
Use browser_snapshot to identify the login button.
Click it and wait for Microsoft authentication to complete.
```

### Elements Not Found

**Prompt:**
```
The expected elements are not in the snapshot.
Use browser_wait_for with a longer timeout:

Wait for text "Dashboards" to appear (30 seconds timeout).
Then capture another snapshot.
```

### JavaScript Evaluation Errors

**Prompt:**
```
The browser_evaluate returned an error.
Use browser_evaluate to run:

function() {
  return {
    title: document.title,
    readyState: document.readyState,
    hasWindow: typeof window !== 'undefined',
    windowKeys: Object.keys(window).slice(0, 20)
  };
}

This will help debug what's available in the page context.
```

---

## Output Files Generated

### Snapshots (for analysis)
- `docs/snapshots/dashboards-list-initial.yaml` - Dashboard list page
- `docs/snapshots/dashboard-view-single.yaml` - Single dashboard view
- `docs/snapshots/dashboard-structure-analysis.md` - Structure documentation
- `docs/snapshots/dashboard-definition-keys.json` - Available JS keys
- `docs/snapshots/dashboard-example.json` - Sample dashboard JSON

### Traces (for debugging)
- `traces/*.zip` - Playwright trace files
- `traces/*.json` - Session state files

### Code (implementation)
- `src/dashboard_list_parser.py` - YAML parsing logic
- `src/playwright_mcp_client.py` - MCP client (call_tool method)
- `src/mcp_server.py` - export_all_dashboards implementation

---

## Success Criteria

✅ Can navigate to dashboards page with existing auth
✅ Can capture and parse YAML snapshots
✅ Can identify dashboard links and metadata in snapshot
✅ Can click individual dashboard and navigate
✅ Can extract dashboard JSON definition via browser_evaluate
✅ Can return to list and repeat for multiple dashboards
✅ Traces capture all steps for debugging

---

## Next Steps After Exploration

Once you have working patterns:

1. **Implement Parser**: `src/dashboard_list_parser.py`
   - YAML parsing
   - Dashboard metadata extraction
   - Filtering by creator

2. **Implement MCP Client**: `src/playwright_mcp_client.py`
   - JSON-RPC communication
   - Tool invocation
   - Error handling

3. **Implement Export Tool**: `src/mcp_server.py`
   - export_all_dashboards tool
   - Progress tracking
   - Manifest generation

4. **Test End-to-End**: Via Copilot Chat
   - Run full bulk export
   - Verify all files created
   - Check manifest accuracy

---

## Prompt Templates

### Quick Navigation
```
Navigate to <URL> and capture snapshot
```

### Element Interaction
```
In the snapshot at docs/snapshots/<file>.yaml, find the <element description> 
and click it using browser_click
```

### Data Extraction
```
Use browser_evaluate to run this function and save to <output-file>:
<javascript function>
```

### Wait and Retry
```
Wait for <condition> to appear, then <action>
```

---

## Tips for Effective Exploration

1. **Small Steps**: One operation per prompt for clarity
2. **Save Everything**: Snapshots are cheap, save liberally
3. **Document Patterns**: Note patterns in separate markdown files
4. **Use Traces**: When stuck, review trace files for insights
5. **Iterate**: If something doesn't work, try different selectors/approaches
6. **Stay Focused**: Complete one phase before moving to next

Ready to start? Run the tracing setup script first! 🚀
