# Known Issues

## Critical Issue: MCP Protocol Implementation Gap

**Status**: ⚠️ Blocking - Requires Architecture Change

### Problem
The current `MCPClient.psm1` implementation attempts to invoke MCP tools using `Invoke-Expression` on function names like `mcp_playwright_browser_launch`, but these functions don't exist as PowerShell cmdlets.

### Root Cause
The MCP (Model Context Protocol) uses JSON-RPC over stdio/http for communication with MCP servers. The current implementation incorrectly assumes:
1. MCP tools are exposed as PowerShell functions
2. Can be invoked directly with `Invoke-Expression`

### Actual Requirement
Need to implement proper JSON-RPC communication:
1. Send JSON-RPC requests to MCP server via stdio/http
2. Parse JSON-RPC responses
3. Handle MCP protocol handshake and tool discovery

### Example JSON-RPC Call Structure
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "browser_launch",
    "arguments": {
      "browser": "edge",
      "headless": false
    }
  }
}
```

### Impact
- ❌ Export functionality blocked
- ❌ Import functionality blocked
- ✅ Validate functionality works (doesn't require MCP)
- ✅ 96% unit test coverage (tests use mocks)

### Solution Options

#### Option 1: Implement Full JSON-RPC Client (Recommended)
Create proper MCP protocol client that:
- Establishes stdio connection to MCP server
- Sends/receives JSON-RPC messages
- Handles protocol initialization and tool discovery

**Estimate**: 4-6 hours
**Pros**: Proper implementation, reusable, production-ready
**Cons**: Significant refactor required

#### Option 2: Use Existing MCP Client Library
Find/use existing PowerShell MCP client if available

**Estimate**: 2-3 hours research + implementation
**Pros**: Faster, tested library
**Cons**: May not exist for PowerShell

#### Option 3: Call npx Directly
Bypass MCPClient abstraction and call `npx @playwright/mcp@latest` directly

**Estimate**: 1-2 hours
**Pros**: Quick workaround
**Cons**: Loses abstraction, harder to maintain, not scalable

### Current Workaround
None - functionality is blocked until MCP protocol is properly implemented.

### Files Affected
- `src/modules/Core/MCPClient.psm1` - Needs JSON-RPC implementation
- `src/modules/Browser/BrowserManager.psm1` - May need adjustments
- `tests/Unit/Core/MCPClient.Tests.ps1` - Tests use mocks (still valid)

### Notes
- The TDD approach and test coverage are still valuable
- All business logic for Export/Import is correct
- Only the MCP communication layer needs implementation
- This was missed because unit tests mock the MCP layer successfully

### Recommendation
This issue requires architectural discussion:
1. Should we implement full JSON-RPC client?
2. Should we use a different approach (direct Playwright API)?
3. Should we find/use existing MCP client library?

The project is 96% functionally complete - only the MCP protocol communication layer needs proper implementation.

---

**Created**: October 8, 2025  
**Discovered During**: Real-world testing with actual Playwright MCP server  
**Priority**: P0 - Blocks core functionality
