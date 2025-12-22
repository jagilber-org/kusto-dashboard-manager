# Testing Guide

Complete testing procedures and test client documentation for Kusto Dashboard Manager.

This guide covers:
- Test suite overview and pass rates
- Running JavaScript and Python tests
- Test client details and usage
- Debugging and troubleshooting tests
- Test data examples and workflows

---

## Testing

### Test Suite Overview

The project includes comprehensive test clients achieving **100% pass rates**:

| Client | Type | Pass Rate | Tests | Runtime |
|--------|------|-----------|-------|---------|
| `test-js-kusto.js` | JavaScript | ✅ 100% | 3/3 | ~750ms |
| `test-js-playwright.js` | JavaScript | ✅ 100% | 7/7 | ~2.5s |
| `test_mcp_client.py` | Python | ✅ 100% | 3/3 | ~1.4s |

### Running Tests

**JavaScript Tests (requires Node.js 22.20.0+)**:

```bash
cd client

# Install dependencies
npm install

# Test Kusto Dashboard Manager MCP server
npm run test:kusto

# Test Playwright MCP server integration
npm run test:playwright

# Debug mode (with detailed output)
npm run test:kusto:debug
npm run test:playwright:debug
```

**Python Tests**:

```bash
# Test Kusto Dashboard Manager MCP server
python client/test_mcp_client.py
```

### Test Client Details

#### test-js-kusto.js

JavaScript MCP SDK client for testing `kusto-dashboard-manager`:

- **Tests**: Connection, Tool Discovery (5 tools), Parse Dashboards
- **Protocol**: Content-Length framing via `StdioClientTransport`
- **Features**: Comprehensive error handling, pretty output formatting

#### test-js-playwright.js

JavaScript client validating MCP SDK with official Playwright MCP:

- **Tests**: Connection, navigation, snapshot, screenshot, click, etc.
- **Purpose**: Validates MCP SDK functionality with production MCP server

#### test_mcp_client.py

Standalone Python client with direct JSON-RPC implementation:

- **Tests**: Connection, Tool Discovery, Parse Dashboards
- **Protocol**: Newline-delimited JSON (simpler than Content-Length)
- **Features**: Async subprocess management, ~200 lines of code

### Documentation

For detailed testing information, see:

- **[CLIENT_TESTING.md](client/CLIENT_TESTING.md)**: Comprehensive testing guide
  - Client inventory and status
  - MCP protocol details
  - **Playwright snapshot YAML format specification**
  - Test recommendations and troubleshooting

- **[TESTING_SUMMARY.md](TESTING_SUMMARY.md)**: Complete test results
  - Executive summary
  - All issues found and fixed
  - Performance metrics
  - Recommendations for next steps
