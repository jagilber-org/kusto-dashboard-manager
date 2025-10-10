# Test Clients for kusto-dashboard-manager MCP Server

## Quick Start

### JavaScript Clients (Recommended)
```bash
# Install dependencies
npm install

# Test kusto-dashboard-manager MCP server
npm run test:kusto

# Test Playwright MCP server (validates SDK)
npm run test:playwright

# Debug mode
npm run test:kusto:debug
```

### Python Clients
```bash
# Install dependencies
pip install -r requirements.txt

# Test with simple Python client
python test_mcp_client.py
```

## 📚 Complete Documentation

See **[CLIENT_TESTING.md](./CLIENT_TESTING.md)** for:
- Complete client inventory and status
- MCP protocol details (newline JSON vs Content-Length)
- **Playwright snapshot YAML format specification**
- Test results and recommendations
- Known issues and troubleshooting

## Working Test Clients

✅ **test-js-kusto.js** - JavaScript client for kusto-dashboard-manager  
✅ **test-js-playwright.js** - JavaScript client for Playwright MCP  
✅ **test_mcp_client.py** - Python client for kusto-dashboard-manager

## SDK Reference Files (python-mcp-client-sdk-20251010-092718/)

The following files are SDK examples and should NOT be modified:
- working-py-mcp-client.py  - Full-featured MCP client example
- simple-py-mcp-client.py   - Simplified MCP client example
- basic-py-mcp-client.py    - Basic MCP client example
- py-mcp-client.py          - Minimal client stub

## External Resources

- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [MCP JavaScript SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [Playwright MCP](https://github.com/microsoft/playwright-mcp)
