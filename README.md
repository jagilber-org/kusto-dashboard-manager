# Kusto Dashboard Manager

> **Portfolio Project** | [View Full Portfolio](https://github.com/jagilber-org) | [Specifications](docs/specs/)

An MCP (Model Context Protocol) server for exporting and importing Azure Data Explorer (Kusto) dashboards via VS Code and GitHub Copilot integration with Playwright browser automation.

[![Python](https://img.shields.io/badge/python-3.12%2B-blue)](https://www.python.org/)
[![MCP](https://img.shields.io/badge/MCP-1.0-blue)](https://modelcontextprotocol.io/)
[![Node.js](https://img.shields.io/badge/node.js-22.20.0%2B-green)](https://nodejs.org/)
[![Tests](https://img.shields.io/badge/tests-100%25%20passing-brightgreen)](client/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Portfolio Context

This project is part of the [jagilber-org portfolio](https://github.com/jagilber-org), demonstrating real-world Azure integration and dashboard automation patterns.

**Cross-Project Integration**:
- Uses **powershell-mcp-server** for KQL generation and Azure operations
- Integrates with **chrome-screenshot-sanitizer** for Azure Portal documentation
- Leverages **obfuscate-mcp-server** for sensitive Kusto query sanitization
- Reference implementation for Azure Kusto Data Explorer automation

**Portfolio Highlights**:
- Production-ready Azure Kusto integration with 25+ dashboard templates
- Real-world MCP tools for Azure services (Kusto, ARM, subscriptions)
- Grafana dashboard generation and management automation
- Comprehensive testing patterns for Azure integrations
- Enterprise query optimization and validation workflows

[View Full Portfolio](https://github.com/jagilber-org) | [Integration Examples](https://github.com/jagilber-org#cross-project-integration)

## 📚 Documentation

### Specifications

- **[Product Specification](docs/specs/spec.md)** - User scenarios, functional requirements, success criteria, integration points
- **[Technical Plan](docs/specs/plan.md)** - Architecture, implementation phases, performance benchmarks

### Project Documentation

- [Full Documentation Index](docs/) - Comprehensive guides and references
## Features

- **VS Code Integration**: Works seamlessly with GitHub Copilot via MCP protocol
- **Export Dashboards**: Export Azure Data Explorer dashboards to JSON files with bulk export support
- **Import Dashboards**: Import dashboard JSON files back into Azure Data Explorer
- **Validate**: Validate dashboard JSON file structure before import
- **Parse Dashboards**: Extract dashboard list from Playwright browser snapshots with creator filtering
- **Browser Automation**: Integrates with Playwright MCP server for reliable browser automation
- **100% Test Coverage**: Comprehensive test suite with JavaScript and Python clients

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [MCP Tools](#mcp-tools)
- [Testing](#testing)
- [Architecture](#architecture)
- [Development](#development)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Prerequisites

- **Python 3.12** or higher
- **Node.js 22.20.0** or higher
- **VS Code** with GitHub Copilot extension
- **Playwright MCP server** (`@playwright/mcp@latest`)
- Azure Data Explorer account with dashboard access

### Setup in VS Code

1. **Clone the repository**:

   ```bash
   git clone https://github.com/jagilber/kusto-dashboard-manager.git
   cd kusto-dashboard-manager
   ```

2. **Install Python dependencies**:

   ```bash
   pip install -r requirements.txt
   ```

3. **Install Playwright MCP server** (if not already installed):

   ```bash
   npx @playwright/mcp@latest
   ```

4. **Configure VS Code MCP settings** (`.vscode/settings.json`):

   ```json
   {
     "github.copilot.chat.mcp.enabled": true,
     "github.copilot.chat.mcp.servers": {
       "playwright": {
         "command": "npx",
         "args": ["@playwright/mcp@latest"]
       },
       "kusto-dashboard-manager": {
         "command": "python",
         "args": ["-u", "src/mcp_server.py"]
       }
     }
   }
   ```

5. **Reload VS Code window**:
   - Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS)
   - Type "Developer: Reload Window"
   - Press Enter

6. **Verify MCP servers are running**:
   - Open GitHub Copilot Chat
   - Type `@workspace` and you should see tools from both servers

## 📚 Documentation

### Specifications

- **[Product Specification](docs/specs/spec.md)** - User scenarios, functional requirements, success criteria, integration points
- **[Technical Plan](docs/specs/plan.md)** - Architecture, implementation phases, performance benchmarks

### Project Documentation

- [Full Documentation Index](docs/) - Comprehensive guides and references
## Quick Start

### Using GitHub Copilot Chat (Recommended)

The easiest way to use the tool is through natural language in Copilot Chat:

```
Export all my dashboards by John Doe
```

Copilot will automatically:

1. Navigate to your Azure Data Explorer dashboards page
2. Capture a snapshot of the dashboard list
3. Parse the snapshot to find dashboards by the specified creator
4. Return the list of matching dashboards

### Manual Workflow (for testing)

You can also call the MCP tools manually:

1. **Get dashboard snapshot** (using Playwright MCP):

   ```
   @playwright navigate to https://dataexplorer.azure.com/dashboards
   @playwright wait 8 seconds
   @playwright snapshot
   ```

2. **Parse dashboards** (using Kusto Dashboard Manager):

   ```
   @kusto-dashboard-manager parse_dashboards_from_snapshot
   Pass the snapshot raw YAML from previous step
   Filter by creator: John Doe
   ```

### Export Individual Dashboard

To export a specific dashboard to JSON:

```
@kusto-dashboard-manager export_dashboard
URL: https://dataexplorer.azure.com/dashboards/12345
```

## MCP Tools

The MCP server exposes 5 tools that can be called via GitHub Copilot or programmatically:

### 1. parse_dashboards_from_snapshot

Parse dashboard information from a Playwright browser snapshot (YAML format).

**Parameters**:

- `snapshot_yaml` (string, required): Raw YAML snapshot from Playwright MCP's accessibility snapshot
- `creator_filter` (string, optional): Filter dashboards by creator name (e.g., "John Doe")

**Returns**: List of dashboard objects with URL, name, creator, and last_modified

**Example via Copilot**:

```
Parse the snapshot and show me all dashboards by John Doe
```

### 2. export_dashboard

Export a single Azure Data Explorer dashboard to JSON format.

**Parameters**:

- `dashboard_url` (string, required): URL of the dashboard to export
- `output_file` (string, optional): Path to save JSON file

**Returns**: Dashboard JSON or file path

**Example via Copilot**:

```
@kusto-dashboard-manager export this dashboard: https://dataexplorer.azure.com/dashboards/my-dashboard
```

### 3. import_dashboard

Import a dashboard from a JSON file into Azure Data Explorer.

**Parameters**:

- `json_file` (string, required): Path to dashboard JSON file

**Returns**: Success confirmation

**Example via Copilot**:

```
@kusto-dashboard-manager import the dashboard from dashboard.json
```

### 4. validate_dashboard

Validate a dashboard JSON file structure without importing.

**Parameters**:

- `json_file` (string, required): Path to dashboard JSON file

**Returns**: Validation result (success/failure with errors)

**Example via Copilot**:

```
@kusto-dashboard-manager validate dashboard.json
```

### 5. export_all_dashboards

Export all dashboards matching criteria (typically used after parsing snapshot).

**Parameters**:

- `snapshot_yaml` (string, required): Raw YAML snapshot from Playwright MCP
- `creator_filter` (string, optional): Filter dashboards by creator name
- `output_dir` (string, optional): Directory to save JSON files

**Returns**: List of exported dashboard file paths

**Example via Copilot**:

```
Export all dashboards by John Doe to the exports/ folder
```

### Workflow: Bulk Export

The typical workflow for exporting multiple dashboards:

1. **Navigate to dashboards** (Playwright MCP):

   ```
   @playwright navigate to https://dataexplorer.azure.com/dashboards
   ```

2. **Wait for page load** (Playwright MCP):

   ```
   @playwright wait 8 seconds
   ```

3. **Capture snapshot** (Playwright MCP):

   ```
   @playwright snapshot
   ```

4. **Export all dashboards** (Kusto Dashboard Manager):

   ```
   @kusto-dashboard-manager export_all_dashboards
   Pass snapshot YAML from step 3
   Filter by creator: John Doe
   Output directory: exports/
   ```

Or simply ask Copilot in natural language:

```
Export all my Azure Data Explorer dashboards by John Doe
```

## Testing

### Quick Test Commands

**JavaScript Tests** (requires Node.js 22.20.0+):
`ash
cd client && npm install

# Test Kusto Dashboard Manager
npm run test:kusto

# Test Playwright MCP integration
npm run test:playwright

# Debug mode
npm run test:kusto:debug
`

**Python Tests**:
`ash
python client/test_mcp_client.py
`

### Test Results Summary

| Client | Type | Pass Rate | Tests | Runtime |
|--------|------|-----------|-------|---------|
| 	est-js-kusto.js | JavaScript | ✅ 100% | 3/3 | ~750ms |
| 	est-js-playwright.js | JavaScript | ✅ 100% | 7/7 | ~2.5s |
| 	est_mcp_client.py | Python | ✅ 100% | 3/3 | ~1.4s |

**📖 See: [docs/TESTING.md](docs/TESTING.md)** for comprehensive testing guide including:
- Test client details and features
- MCP protocol details
- Playwright snapshot YAML format specification
- Test recommendations and troubleshooting

## Development

### Project Structure

```text
kusto-dashboard-manager/
├── src/
│   ├── __init__.py                    # Package initialization
│   ├── mcp_server.py                  # MCP server main entry point
│   ├── dashboard_export.py            # Dashboard parsing and export logic
│   ├── dashboard_import.py            # Dashboard import functionality
│   ├── dashboard_validate.py         # Dashboard JSON validation
│   └── tracer.py                      # File-based logging/tracing
├── client/
│   ├── test-js-kusto.js              # JavaScript MCP SDK test client
│   ├── test-js-playwright.js         # Playwright MCP validation client
│   ├── test_mcp_client.py            # Python direct JSON-RPC client
│   ├── package.json                  # npm configuration
│   ├── CLIENT_TESTING.md             # Comprehensive testing guide
│   └── README.md                     # Quick start for test clients
├── docs/
│   ├── MCP_ARCHITECTURE_ISSUE.md     # MCP architecture explanation
│   ├── MCP_USAGE_GUIDE.md            # Usage patterns and examples
│   └── TRACING.md                    # Logging and tracing guide
├── logs/                             # Log files (gitignored)
├── .vscode/
│   └── settings.json                 # VS Code MCP configuration
├── requirements.txt                  # Python dependencies
├── TESTING_SUMMARY.md                # Complete test results
└── README.md                         # This file
```

### Setting Up Development Environment

1. **Clone and install**:

   ```bash
   git clone https://github.com/jagilber/kusto-dashboard-manager.git
   cd kusto-dashboard-manager
   pip install -r requirements.txt
   ```

2. **Configure VS Code MCP** (add to `.vscode/settings.json`):

   ```json
   {
     "github.copilot.chat.mcp.enabled": true,
     "github.copilot.chat.mcp.servers": {
       "playwright": {
         "command": "npx",
         "args": ["@playwright/mcp@latest"]
       },
       "kusto-dashboard-manager": {
         "command": "python",
         "args": ["-u", "src/mcp_server.py"]
       }
     }
   }
   ```

3. **Run tests**:

   ```bash
   # JavaScript tests
   cd client && npm install && npm run test:kusto

   # Python tests
   python client/test_mcp_client.py
   ```

4. **Test in VS Code**:
   - Reload window (Ctrl+Shift+P → "Developer: Reload Window")
   - Open Copilot Chat
   - Try: `Export all dashboards by John Doe`

## Architecture

### Quick Overview

`	ext
VS Code / GitHub Copilot
         │
    ┌────┴─────┐
    │          │
Playwright   Kusto Dashboard
MCP Server   Manager MCP
(Node.js)    (Python)
`

**Key Principles**:
- Isolated MCP servers (separate processes)
- Client orchestration (VS Code/Copilot coordinates all calls)
- Browser automation via Playwright MCP only

**📖 See: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** for complete architecture including:
- Detailed component diagrams and data flow
- MCP integration patterns
- Protocol specifications (JSON-RPC 2.0)
- Non-standard YAML format details
- Design principles and limitations

## Troubleshooting

### Common Issues Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| MCP tools not appearing | Reload VS Code window |
| Server fails to start | Check logs/mcp_server.log |
| Empty parse results | Wait 8+ seconds for page load, check Azure login |
| JSON-RPC errors | Check for stdout logging in code |
| Browser automation fails | Verify Playwright MCP installation |

### Debug Logging

All logs automatically written to logs/ directory:
- logs/mcp_server.log - MCP server operations
- logs/dashboard_export.log - Dashboard parsing
- logs/dashboard_import.log - Dashboard import
- logs/dashboard_validate.log - Validation

**📖 See: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** for detailed troubleshooting including:
- Complete issue descriptions and solutions
- Debug mode configuration
- Known limitations
- Getting help resources

## Contributing

Contributions are welcome! Please follow these guidelines:

### Development Workflow

1. **Fork the repository**

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/my-new-feature
   ```

3. **Make your changes**:
   - Write code following existing style (PEP 8)
   - **CRITICAL**: Never use `print()` or log to stdout in MCP server (corrupts JSON-RPC)
   - Add tests for new functionality
   - Update documentation

4. **Run tests**:

   ```bash
   # JavaScript tests
   cd client && npm run test:kusto

   # Python tests
   python client/test_mcp_client.py
   ```

5. **Commit changes**:

   ```bash
   git commit -am "feat: Add new feature description"
   ```

6. **Push to your fork**:

   ```bash
   git push origin feature/my-new-feature
   ```

7. **Create Pull Request**

### Code Style

- **Follow PEP 8** style guidelines
- **Use type hints** where possible
- **Write docstrings** for all public functions (Google style)
- **Never log to stdout** in MCP server code (use `src/tracer.py` file logging)
- **Keep functions focused** and testable
- **Handle errors gracefully** with proper MCP error responses

### Testing Requirements

- All new MCP tools must include test cases in test clients
- Test both success and failure scenarios
- Update test clients (`test-js-kusto.js`, `test_mcp_client.py`)
- Ensure 100% pass rate before submitting PR

### Documentation Requirements

- Update [README.md](README.md) for new features
- Update [CLIENT_TESTING.md](client/CLIENT_TESTING.md) for test changes
- Add inline comments for complex logic (especially regex parsing)
- Include usage examples in tool descriptions

### MCP-Specific Guidelines

1. **Tool Descriptions**: Be clear about Copilot orchestration requirements
2. **Parameter Validation**: Validate all inputs before processing
3. **Error Responses**: Return proper MCP error objects
4. **Logging**: Use file-based logging only (never stdout)
5. **Testing**: Test with both JavaScript SDK and Python direct clients

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Model Context Protocol**: [MCP Specification](https://modelcontextprotocol.io/)
- **Playwright MCP**: [@playwright/mcp](https://www.npmjs.com/package/@playwright/mcp) official MCP server
- **JavaScript MCP SDK**: [@modelcontextprotocol/sdk](https://github.com/modelcontextprotocol/sdk)
- **Azure Data Explorer**: Microsoft's big data analytics platform
- **VS Code MCP Integration**: GitHub Copilot MCP support

## Support

For questions, issues, or feature requests:

- **Issues**: [GitHub Issues](https://github.com/jagilber/kusto-dashboard-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jagilber/kusto-dashboard-manager/discussions)
- **Documentation**:
  - [CLIENT_TESTING.md](client/CLIENT_TESTING.md) - Testing guide
  - [TESTING_SUMMARY.md](TESTING_SUMMARY.md) - Test results
  - [MCP_ARCHITECTURE_ISSUE.md](docs/MCP_ARCHITECTURE_ISSUE.md) - Architecture details

## Changelog

### Version 2.0.0 (October 2025) - JavaScript Client & Bulk Export

**Major Features**:

- ✅ **JavaScript MCP client for bulk export** (`client/export-all-dashboards.mjs`)
- ✅ **Automated dashboard export from list page** (27 dashboards exported successfully)
- ✅ **PowerShell MCP integration** for file operations and JSON formatting
- ✅ **Dash-separated filenames** (e.g., `batch-account.json`)
- ✅ **Pretty-printed JSON output** (ConvertTo-Json -Depth 100)
- ✅ **Temp file handling** (copy from playwright-mcp-output before cleanup)
- ✅ **Dashboard ID verification** (prevents file mismatches)
- ✅ **Creator filtering** (includes both named creators and '--' for old dashboards)
- ✅ **Comprehensive Playwright MCP documentation** (`docs/PLAYWRIGHT_MCP_LEARNINGS.md`)

**Implementation Details**:

- Export workflow: List page → Click ellipsis → Download → Copy from temp → Pretty-print
- Average time: ~10.6 seconds per dashboard
- Success rate: 100% (27/27 dashboards)
- Total runtime: ~4.8 minutes for complete export

**Key Discoveries**:

- 🔍 Playwright MCP downloads to temp location (auto-deleted on browser close)
- 🔍 Must copy files BEFORE closing browser/MCP connections
- 🔍 Accessibility tree refs are dynamic (never hardcode)
- 🔍 Old dashboards show '--' as creator (not assigned)

**Bug Fixes**:

- 🐛 Fixed file disappearance (copy from temp before cleanup)
- 🐛 Fixed filename spaces (replace with dashes)
- 🐛 Fixed JSON formatting (pretty-print with proper indentation)
- 🐛 Fixed missing old dashboards (include '--' creator filter)

**Documentation**:

- 📚 `docs/DASHBOARD_EXPORT_COMPLETE.md` - Complete export project summary
- 📚 `docs/PLAYWRIGHT_MCP_LEARNINGS.md` - Best practices and patterns
- 📚 Updated `.gitignore` to exclude `output/dashboards/*.json`

### Version 1.0.0 (October 2024) - PowerShell & MCP Server

**Major Features**:

- ✅ MCP server with 5 tools for dashboard management
- ✅ VS Code + GitHub Copilot integration
- ✅ Playwright MCP integration for browser automation
- ✅ Bulk dashboard export with creator filtering
- ✅ Dashboard import/export/validate functionality
- ✅ Accessibility snapshot parsing (non-standard YAML)
- ✅ Comprehensive test suite (100% pass rate)
- ✅ File-based logging and tracing

**Bug Fixes**:

- 🐛 Fixed stdout logging corruption in MCP server
- 🐛 Fixed invalid date format in tracer
- 🐛 Fixed dashboard parsing loop logic
- 🐛 Added "type": "module" to package.json

**Known Limitations**:

- Requires manual Azure login before export
- Creator filtering is case-sensitive
- Non-standard YAML format requires regex parsing (no library support)
- No direct server-to-server communication (by MCP protocol design)

**Future Enhancements**:

- ~~Batch export to individual JSON files~~ ✅ **Completed in v2.0.0**
- Dashboard diff/merge capabilities
- Export/import dashboard permissions
- Dashboard versioning and history
- CI/CD integration examples
- Manifest file generation with dashboard metadata

---

**Made with ❤️ for Azure Data Explorer users and MCP enthusiasts**
