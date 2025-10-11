# Playwright MCP Server - Key Learnings & Best Practices

## Critical Discovery: Temp File Behavior

### Problem
When using Playwright MCP's browser automation to download files:
- Files are saved to a **temporary location** that gets cleaned up
- Location: `%LOCALAPPDATA%\Temp\playwright-mcp-output\{timestamp}\dashboard-undefined.json`
- Files are **automatically deleted** when browser or MCP connections close
- Generic filename: `dashboard-undefined.json` (not the actual dashboard name)

### Solution
**Copy files from temp location BEFORE closing browser/MCP connections:**

```powershell
# Search for recently downloaded files
$playwrightOutputPath = "$env:LOCALAPPDATA\Temp\playwright-mcp-output"

$files = Get-ChildItem -Path $playwrightOutputPath -Recurse -Filter "dashboard-undefined.json" -File |
  Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-15) } |
  Sort-Object LastWriteTime -Descending

if ($files) {
  $file = $files | Select-Object -First 1
  $jsonContent = Get-Content $file.FullName -Raw
  $json = $jsonContent | ConvertFrom-Json

  # Verify content matches expected (e.g., dashboard ID)
  if ($json.id -eq $expectedDashboardId) {
    # Copy to permanent location with proper name
    Copy-Item $file.FullName -Destination $targetPath
  }
}
```

**Key Points:**
1. Search within 15 seconds of download trigger
2. Verify file contents match expected (e.g., check ID/name in JSON)
3. Copy with proper filename to permanent location
4. **Must happen BEFORE** closing browser or MCP connections
5. Use `LastWriteTime` filter to find recent files only

---

## Dynamic UI References

### Problem
Accessibility tree references (e.g., `e204`, `e677`) change on every page state:
- Refs are only valid for the current browser snapshot
- Hardcoded refs will break on next page load or interaction
- Different for every user and session

### Solution
**Always get fresh snapshot before clicking:**

```javascript
// ❌ Bad: Hardcoded ref
await playwrightClient.callTool({
  name: 'browser_click',
  arguments: { ref: 'e204' }  // Will fail!
});

// ✅ Good: Get fresh snapshot, extract ref, use immediately
const snapshotResponse = await playwrightClient.callTool({
  name: 'browser_snapshot',
  arguments: {}
});

const snapshot = snapshotResponse.content[0].text;
const buttonRef = extractRefFromSnapshot(snapshot, 'Additional options', 'button');

await playwrightClient.callTool({
  name: 'browser_click',
  arguments: { ref: buttonRef }
});
```

**Pattern for Finding Refs:**

```javascript
function findButtonRef(snapshot, contextText, buttonLabel) {
  const lines = snapshot.split('\n');

  // 1. Find context (e.g., row with dashboard name)
  const contextLineIndex = lines.findIndex(line => line.includes(contextText));

  // 2. Search forward from context for button
  for (let i = contextLineIndex; i < Math.min(contextLineIndex + 20, lines.length); i++) {
    const line = lines[i];
    if (line.includes(`button "${buttonLabel}"`) || line.includes(`[name="${buttonLabel}"]`)) {
      const match = line.match(/\[ref=([a-z0-9]+)\]/i);
      if (match) {
        return match[1];  // Return ref like "e204"
      }
    }
  }

  throw new Error(`Button "${buttonLabel}" not found near "${contextText}"`);
}

// Usage
const ref = findButtonRef(snapshot, 'armprod', 'Additional options');
await click({ ref: ref });
```

**Key Points:**
1. Never hardcode refs
2. Always get fresh snapshot before interactions
3. Search for element by role/name/context
4. Extract ref from snapshot
5. Use ref immediately (it expires on next state change)
6. Handle ref not found gracefully

---

## Browser Authentication Sessions

### Problem
Azure Data Explorer requires authentication:
- Direct API calls (JavaScript `fetch()`) fail with 401 errors
- Browser session cookies not inherited by fetch API
- Authentication is browser-specific

### Solution
**Use browser automation, not direct API:**

```javascript
// ❌ Bad: Direct API (fails with 401)
const response = await fetch('https://dataexplorer.azure.com/api/dashboards');
// Error: 401 Unauthorized

// ✅ Good: Browser automation (authenticated session)
await playwrightClient.callTool({
  name: 'browser_navigate',
  arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
});

// Browser uses existing authenticated session
const snapshot = await playwrightClient.callTool({
  name: 'browser_snapshot',
  arguments: {}
});
```

**Best Practices:**
1. Use browser navigation for authenticated resources
2. Leverage browser's existing session cookies
3. Don't try to extract cookies for fetch API (security restrictions)
4. Use accessibility snapshots or JavaScript evaluation to extract data
5. Ensure user is logged in before automation starts

---

## Page Load Timing

### Problem
Pages (especially dashboard lists) take time to load:
- Immediate snapshot captures incomplete page
- Dynamic content loaded after initial render
- Dashboards fetched asynchronously

### Solution
**Wait for page load before capturing snapshot:**

```javascript
// Navigate
await playwrightClient.callTool({
  name: 'browser_navigate',
  arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
});

// ❌ Bad: Immediate snapshot (incomplete)
const snapshot = await playwrightClient.callTool({
  name: 'browser_snapshot',
  arguments: {}
});

// ✅ Good: Wait for specific content
await playwrightClient.callTool({
  name: 'browser_wait_for',
  arguments: {
    text: 'My Dashboards',  // Or other expected content
    timeout: 30000  // 30 seconds max
  }
});

// Or: Wait fixed time (less reliable)
await new Promise(resolve => setTimeout(resolve, 8000));

// Now snapshot is complete
const snapshot = await playwrightClient.callTool({
  name: 'browser_snapshot',
  arguments: {}
});
```

**Recommended Wait Times:**
- Simple pages: 3-5 seconds
- Dashboard list pages: 8-10 seconds
- Complex interactive pages: 10-15 seconds
- Or use `browser_wait_for` with specific text/element

**Key Points:**
1. Always wait after navigation
2. Use `browser_wait_for` with specific content when possible
3. Fixed timeouts as fallback
4. Check snapshot contains expected content before proceeding

---

## File Naming Best Practices

### Problem
Content-derived names often contain problematic characters:
- Spaces: "batch account"
- Special chars: "logs/summary"
- Case sensitivity issues

### Solution
**Sanitize names for filesystem compatibility:**

```javascript
function sanitizeFileName(name) {
  return name
    .replace(/\s+/g, '-')           // spaces → dashes
    .replace(/[/\\:*?"<>|]/g, '-')  // special chars → dashes
    .replace(/-+/g, '-')            // multiple dashes → single
    .replace(/^-|-$/g, '')          // trim leading/trailing dashes
    .toLowerCase();                 // lowercase for consistency
}

// Examples:
// "batch account" → "batch-account"
// "logs/summary" → "logs-summary"
// "My Dashboard!" → "my-dashboard"
```

**Key Points:**
1. Replace spaces with dashes (not underscores)
2. Remove or replace special characters
3. Consider lowercase for consistency
4. Avoid leading/trailing dashes
5. Keep names short and readable

---

## JSON Pretty-Printing

### Problem
Downloaded JSON is often minified (single line):
- Hard to read
- Difficult to diff in git
- No indentation

### Solution
**Pretty-print JSON before saving:**

```powershell
# PowerShell approach
$json = $jsonContent | ConvertFrom-Json
$prettyJson = $json | ConvertTo-Json -Depth 100
$prettyJson | Set-Content -Path $targetFile -Encoding UTF8
```

```javascript
// JavaScript approach
const json = JSON.parse(jsonContent);
const prettyJson = JSON.stringify(json, null, 2);
fs.writeFileSync(targetFile, prettyJson, 'utf8');
```

**Trade-offs:**
- File size increase: ~30-40%
- Much better readability
- Better for git diffs
- Easier manual inspection
- Better for version control

**Recommended:**
- Use `-Depth 100` (PowerShell) or 2-space indent (JavaScript)
- Always UTF-8 encoding
- Consider gzip compression for storage if size matters

---

## MCP Server Orchestration

### Architecture
MCP servers **cannot call each other directly**. Client orchestrates all cross-server operations.

```
Client (JavaScript/Python)
    ├─► MCP Server 1 (Playwright)
    ├─► MCP Server 2 (Custom Parser)
    └─► MCP Server 3 (PowerShell)
```

### Pattern
```javascript
// Client orchestrates sequence
const playwrightClient = new MCPClient('playwright');
const parserClient = new MCPClient('parser');
const powershellClient = new MCPClient('powershell');

// Step 1: Get data from Server 1
const snapshot = await playwrightClient.callTool({
  name: 'browser_snapshot',
  arguments: {}
});

// Step 2: Process with Server 2 (pass data from Step 1)
const parsed = await parserClient.callTool({
  name: 'parse_snapshot',
  arguments: { snapshot_yaml: snapshot.content[0].text }
});

// Step 3: Use results with Server 3
const result = await powershellClient.callTool({
  name: 'format_json',
  arguments: { json: parsed.content[0].text }
});
```

**Key Points:**
1. Client is the orchestrator
2. Data flows through client between servers
3. Servers are stateless (no inter-server communication)
4. Client manages sequence and error handling
5. Each server focuses on its specific capability

---

## Error Handling

### Common Errors

**1. Element Not Found**
```javascript
try {
  const ref = findButtonRef(snapshot, dashboardName);
  await click({ ref: ref });
} catch (error) {
  console.error(`Button not found for "${dashboardName}": ${error.message}`);
  // Fallback or skip this item
}
```

**2. Timeout Waiting for Content**
```javascript
try {
  await playwrightClient.callTool({
    name: 'browser_wait_for',
    arguments: { text: 'Expected Text', timeout: 30000 }
  });
} catch (error) {
  console.warn('Timeout waiting for content, proceeding anyway');
  // May need to retry or abort
}
```

**3. File Not Found in Temp**
```powershell
$files = Get-ChildItem ... -ErrorAction SilentlyContinue

if (-not $files) {
  Write-Warning "File not found in temp directory"
  Write-Host "Expected location: $playwrightOutputPath"
  Write-Host "Wait longer or check download triggered successfully"
  return $null
}
```

**4. Dashboard ID Mismatch**
```javascript
if (json.id !== expectedDashboardId) {
  console.warn(`Dashboard ID mismatch: expected ${expectedDashboardId}, got ${json.id}`);
  // Skip or retry
  continue;
}
```

---

## Performance Considerations

### Metrics from Production Use
- **Average time per dashboard**: ~10.6 seconds
- **Breakdown**:
  - Find button ref: ~1 second
  - Click ellipsis: ~1 second
  - Click download: ~1 second
  - Wait for download: ~3 seconds
  - Find in temp: ~2 seconds
  - Copy and format: ~2 seconds
- **Total for 27 dashboards**: ~4.8 minutes

### Optimization Tips

1. **Reuse Browser Session**
   ```javascript
   // ✅ Good: One browser session for all operations
   await navigate(dashboardListPage);
   for (const dashboard of dashboards) {
     await exportDashboard(dashboard);  // Same browser
   }

   // ❌ Bad: New browser for each dashboard
   for (const dashboard of dashboards) {
     await navigate(dashboardPage);  // Restart browser each time
     await exportDashboard(dashboard);
     await closeBrowser();
   }
   ```

2. **Batch Snapshots**
   ```javascript
   // Get one snapshot, extract all refs
   const snapshot = await browser_snapshot();
   const refs = dashboards.map(d => findButtonRef(snapshot, d.name));

   // Use refs (valid for current page state)
   for (let i = 0; i < refs.length; i++) {
     await click({ ref: refs[i] });
     // ... export dashboard ...
   }
   ```

3. **Parallel Operations** (when safe)
   ```javascript
   // Safe: Read multiple files in parallel
   const jsonPromises = files.map(f => readFile(f));
   const jsons = await Promise.all(jsonPromises);

   // Unsafe: Browser clicks (sequential only)
   for (const dashboard of dashboards) {
     await click(...);  // Must wait
   }
   ```

4. **Timeouts**
   - Use minimum safe timeouts
   - 3 seconds for downloads (not 10)
   - 15 seconds for temp file search (not 60)
   - Avoid unnecessary waits

---

## Testing Strategies

### Unit Testing MCP Tools
```javascript
describe('Playwright MCP Integration', () => {
  it('should navigate to URL', async () => {
    const result = await playwrightClient.callTool({
      name: 'browser_navigate',
      arguments: { url: 'https://example.com' }
    });
    expect(result.content[0].text).toContain('Navigated');
  });

  it('should capture snapshot', async () => {
    const result = await playwrightClient.callTool({
      name: 'browser_snapshot',
      arguments: {}
    });
    expect(result.content[0].text).toContain('Page Snapshot');
  });
});
```

### Integration Testing
```javascript
describe('Dashboard Export E2E', () => {
  it('should export dashboard successfully', async () => {
    // Navigate
    await navigate('https://dataexplorer.azure.com/dashboards');

    // Wait
    await waitFor({ text: 'My Dashboards' });

    // Snapshot
    const snapshot = await getSnapshot();

    // Parse
    const dashboards = await parseDashboards(snapshot);

    // Export
    const result = await exportDashboard(dashboards[0]);

    // Verify
    expect(result.filePath).toExist();
    expect(result.json.id).toEqual(dashboards[0].id);
  });
});
```

### Manual Testing Checklist
- [ ] Browser opens successfully
- [ ] Page loads completely
- [ ] Snapshot contains expected content
- [ ] Button refs found correctly
- [ ] Clicks trigger expected actions
- [ ] Files download to temp location
- [ ] Files copied before cleanup
- [ ] Final output files valid

---

## Summary of Best Practices

1. **Temp Files**: Copy BEFORE closing browser/MCP
2. **Dynamic Refs**: Always get fresh snapshot, never hardcode
3. **Authentication**: Use browser automation, not direct API
4. **Page Load**: Wait 8-10 seconds for dashboard lists
5. **File Naming**: Sanitize names (spaces → dashes)
6. **JSON Format**: Pretty-print with 2-space indent
7. **Orchestration**: Client coordinates, servers are stateless
8. **Error Handling**: Try-catch with clear messages
9. **Performance**: Reuse browser, minimize waits
10. **Testing**: Unit + integration + manual verification

---

## Code Templates

### Complete Export Workflow
```javascript
// 1. Initialize MCP clients
const playwright = new MCPClient('playwright');
const parser = new MCPClient('parser');
const powershell = new MCPClient('powershell');

// 2. Navigate and wait
await playwright.callTool({
  name: 'browser_navigate',
  arguments: { url: 'https://dataexplorer.azure.com/dashboards' }
});

await new Promise(resolve => setTimeout(resolve, 8000));

// 3. Get snapshot
const snapshotResponse = await playwright.callTool({
  name: 'browser_snapshot',
  arguments: {}
});

const snapshot = snapshotResponse.content[0].text;

// 4. Parse dashboards
const parseResponse = await parser.callTool({
  name: 'parse_dashboards_from_snapshot',
  arguments: { snapshot_yaml: snapshot, creatorFilter: 'Your Name' }
});

const dashboards = JSON.parse(parseResponse.content[0].text);

// 5. Export each dashboard
for (const dashboard of dashboards) {
  // 5a. Find button ref
  const buttonRef = findButtonRef(snapshot, dashboard.name);

  // 5b. Click ellipsis
  await playwright.callTool({
    name: 'browser_click',
    arguments: { ref: buttonRef }
  });

  // 5c. Get fresh snapshot for menu
  const menuSnapshot = await playwright.callTool({
    name: 'browser_snapshot',
    arguments: {}
  });

  // 5d. Find download button ref
  const downloadRef = findDownloadRef(menuSnapshot.content[0].text);

  // 5e. Click download
  await playwright.callTool({
    name: 'browser_click',
    arguments: { ref: downloadRef }
  });

  // 5f. Wait for download
  await new Promise(resolve => setTimeout(resolve, 3000));

  // 5g. Copy from temp with PowerShell
  const copyScript = `
    $playwrightPath = "$env:LOCALAPPDATA\\Temp\\playwright-mcp-output"
    $files = Get-ChildItem -Path $playwrightPath -Recurse -Filter "dashboard-*.json" -File |
      Where-Object { $_.LastWriteTime -gt (Get-Date).AddSeconds(-15) } |
      Sort-Object LastWriteTime -Descending

    if ($files) {
      $file = $files | Select-Object -First 1
      $json = Get-Content $file.FullName -Raw | ConvertFrom-Json

      if ($json.id -eq "${dashboard.id}") {
        $prettyJson = $json | ConvertTo-Json -Depth 100
        $targetPath = "output/dashboards/${dashboard.name.replace(/\s+/g, '-')}.json"
        $prettyJson | Set-Content -Path $targetPath -Encoding UTF8
        Write-Host "Copied: $targetPath"
      }
    }
  `;

  await powershell.callTool({
    name: 'run_powershell',
    arguments: {
      command: copyScript,
      working_directory: process.cwd(),
      timeout_seconds: 30,
      confirmed: true
    }
  });
}

// 6. Close browser (cleanup happens automatically)
await playwright.callTool({
  name: 'browser_close',
  arguments: {}
});

console.log('Export complete!');
```

---

**Document Version**: 1.0
**Last Updated**: October 11, 2025
**Based on**: Production dashboard export implementation (27 dashboards, 100% success)
