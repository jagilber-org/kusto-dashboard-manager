# Troubleshooting Guide

Complete troubleshooting procedures and debug information for Kusto Dashboard Manager.

This guide covers:
- Common issues and solutions
- Debug mode and logging
- Known limitations
- Getting help

---

## Troubleshooting

### Common Issues

#### 1. MCP tools not appearing in Copilot

**Problem**: `@kusto-dashboard-manager` or `@playwright` not available in Copilot Chat.

**Solution**:

1. Verify `.vscode/settings.json` has correct MCP configuration
2. Reload VS Code window: `Ctrl+Shift+P` → "Developer: Reload Window"
3. Check Copilot output panel for MCP server startup errors
4. Verify Python/Node.js are in PATH

#### 2. MCP server fails to start

**Problem**: Error in Copilot output: "Failed to start MCP server".

**Solution**:

```bash
# Test server manually
python -u src/mcp_server.py

# Should see initialization message in logs/mcp_server.log
# Check for errors in logs/

# Common issues:
# - Missing dependencies: pip install -r requirements.txt
# - Wrong Python version: Use Python 3.12+
# - Syntax errors: Check recent code changes
```

#### 3. Dashboard parsing returns empty results

**Problem**: `parse_dashboards_from_snapshot` returns `[]`.

**Solution**:

- Ensure you waited long enough for page load (8+ seconds)
- Verify you're logged into Azure Data Explorer
- Check snapshot YAML contains dashboard rows
- Try without creator filter first to see all dashboards
- Review logs in `logs/dashboard_export.log`

#### 4. "Invalid JSON-RPC response" error

**Problem**: MCP client reports protocol errors.

**Solution**:

- **Most common cause**: Logging to stdout in MCP server
- Check `src/tracer.py` has NO stdout handlers
- Verify all `print()` statements removed from MCP server
- Review recent code changes that might write to stdout

#### 5. Browser automation fails

**Problem**: Playwright MCP reports navigation errors.

**Solution**:

```bash
# Verify Playwright MCP is installed
npx @playwright/mcp@latest --version

# Test Playwright MCP manually
npx @playwright/mcp@latest

# Should start server, then test with:
# {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
```

#### 6. Creator filter not working

**Problem**: Dashboards by other creators included in results.

**Solution**:

- Creator matching is **case-sensitive**
- Use exact name as it appears in dashboard list
- Example: "Jason Gilbertson" not "jason gilbertson"
- Check logs for actual creator names found

### Debug Mode

**Enable file-based logging**:

All logs are automatically written to `logs/` directory:

- `logs/mcp_server.log` - MCP server operations
- `logs/dashboard_export.log` - Dashboard parsing
- `logs/dashboard_import.log` - Dashboard import
- `logs/dashboard_validate.log` - Validation

**Increase log verbosity** (edit `src/tracer.py`):

```python
# Change INFO to DEBUG
file_handler.setLevel(logging.DEBUG)
```

**Test clients for debugging**:

```bash
# JavaScript client (most verbose)
cd client
npm run test:kusto:debug

# Python client
python client/test_mcp_client.py
```

### Known Limitations

1. **No direct server-to-server communication**: By MCP protocol design, servers cannot call each other
2. **Non-standard YAML parsing**: Playwright snapshots use custom format, requires regex parsing
3. **Authentication**: Must be logged into Azure Data Explorer in browser before exporting
4. **Single-threaded**: One MCP request at a time (async within requests)

### Getting Help

If you're still stuck:

1. Check [CLIENT_TESTING.md](client/CLIENT_TESTING.md) for detailed testing guide
2. Review [MCP_ARCHITECTURE_ISSUE.md](docs/MCP_ARCHITECTURE_ISSUE.md) for architecture details
3. Check [TESTING_SUMMARY.md](TESTING_SUMMARY.md) for known issues and fixes
4. Open a GitHub issue with:
   - Error message
   - Relevant log files from `logs/`
   - Steps to reproduce
   - VS Code and Copilot versions
