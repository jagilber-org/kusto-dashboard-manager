# Kusto Dashboard Manager

> **Portfolio Project** | [View Full Portfolio](https://github.com/jagilber-org) | [Specifications](docs/specs/)

An MCP (Model Context Protocol) server for exporting and importing Azure Data Explorer (Kusto) dashboards via VS Code and GitHub Copilot integration with Playwright browser automation.

[![Python](https://img.shields.io/badge/python-3.12%2B-blue)](https://www.python.org/)
[![MCP](https://img.shields.io/badge/MCP-1.0-blue)](https://modelcontextprotocol.io/)
[![Node.js](https://img.shields.io/badge/node.js-22.20.0%2B-green)](https://nodejs.org/)
[![Tests](https://img.shields.io/badge/tests-100%25%20passing-brightgreen)](client/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

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

### MCP Integration Overview

```text
┌──────────────────────────────────────────────────────────────────┐
│                        VS Code / GitHub Copilot                   │
│                      (MCP Client / Orchestrator)                  │
└──────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴──────────────────┐
            │                                    │
            ▼                                    ▼
┌────────────────────────┐          ┌────────────────────────┐
│   Playwright MCP       │          │ Kusto Dashboard Manager│
│   Server (Node.js)     │          │   MCP Server (Python)  │
│                        │          │                        │
│  Tools:                │          │  Tools:                │
│  - navigate            │          │  - parse_dashboards    │
│  - snapshot            │          │  - export_dashboard    │
│  - click               │          │  - import_dashboard    │
│  - screenshot          │          │  - validate_dashboard  │
│  - wait_for            │          │  - export_all          │
└────────────────────────┘          └────────────────────────┘
            │                                    │
            ▼                                    ▼
      ┌──────────┐                    ┌──────────────────┐
      │ Chromium │                    │ Dashboard Parser │
      │ Browser  │                    │ (Regex + YAML)   │
      └──────────┘                    └──────────────────┘
```

### Key Design Principles

1. **Isolated MCP Servers**
   - Each MCP server runs in a separate process
   - Servers communicate via stdio (JSON-RPC protocol)
   - **No direct server-to-server communication**
   - VS Code/Copilot orchestrates all cross-server calls

2. **Client Orchestration**
   - User makes request via Copilot Chat
   - Copilot determines which tools to call and in what order
   - Copilot passes data between servers as needed
   - Example: Playwright snapshot → Copilot → Kusto parser

3. **Browser Automation**
   - Playwright MCP handles all browser interactions
   - Kusto Dashboard Manager never touches browser directly
   - Accessibility snapshots provide structured YAML representation

### Component Details

#### 1. MCP Server (`src/mcp_server.py`)

- **Protocol**: JSON-RPC 2.0 over stdio
- **Transport**: Newline-delimited JSON or Content-Length framing
- **Tools**: 5 tools exposed to Copilot
- **Logging**: File-based only (stdout reserved for JSON-RPC)
- **Error Handling**: Proper MCP error responses

#### 2. Dashboard Export (`src/dashboard_export.py`)

- **Input**: Playwright accessibility snapshot (YAML)
- **Parsing**: Regex-based extraction of dashboard metadata
- **Output**: List of dashboard objects (URL, name, creator, date)
- **Filtering**: Creator-based filtering support

#### 3. Dashboard Import (`src/dashboard_import.py`)

- **Input**: Dashboard JSON file
- **Validation**: Schema validation before import
- **Method**: JavaScript injection via Playwright
- **Verification**: Optional post-import check

#### 4. Tracing (`src/tracer.py`)

- **Critical Fix**: No stdout logging (prevents JSON-RPC corruption)
- **File-based**: All logs written to `logs/` directory
- **Format**: Timestamped entries with log level
- **Usage**: Debug MCP server issues without disrupting protocol

### Data Flow: Bulk Export

```text
User Request (Copilot Chat)
    │
    │ "Export all dashboards by Jason Gilbertson"
    │
    ▼
Copilot Determines Workflow
    │
    ├─► Step 1: @playwright navigate (https://dataexplorer.azure.com/dashboards)
    │       └─► Playwright MCP: Opens browser, navigates
    │
    ├─► Step 2: @playwright wait (8 seconds)
    │       └─► Playwright MCP: Waits for page load
    │
    ├─► Step 3: @playwright snapshot
    │       └─► Playwright MCP: Captures accessibility tree as YAML
    │       └─► Returns: snapshot_yaml (raw YAML text)
    │
    └─► Step 4: @kusto-dashboard-manager export_all_dashboards
            └─► Parameters:
                - snapshot_yaml: (from Step 3)
                - creator_filter: "Jason Gilbertson"
            └─► Processing:
                - Parse YAML with regex
                - Extract: URL, name, creator, date
                - Filter by creator
                - Return list of matching dashboards
            └─► Returns: [{url, name, creator, last_modified}, ...]
```

### Non-Standard YAML Format

The Playwright accessibility snapshot uses a **non-standard YAML format** that cannot be parsed by standard YAML libraries. See [CLIENT_TESTING.md](client/CLIENT_TESTING.md) for details.

**Key characteristics**:

- Indentation-based structure
- `/url:`, `/name:`, `rowheader`, `text` tags
- Date format: `MM/DD/YYYY, HH:MM AM/PM`
- No proper YAML key-value pairs

**Example**:

```yaml
- row "Sales Analytics Dashboard" (creator: John Doe):
  - cell "Sales Analytics Dashboard":
    - link "Sales Analytics Dashboard":
      /url: /dashboards/12345-67890-abcdef
      /name: Sales Analytics Dashboard
    - text "John Doe":
      rowheader "John Doe"
    - text "01/15/2024, 3:45 PM"
```

### Protocol Details

**JSON-RPC 2.0 Message Format**:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "export_all_dashboards",
    "arguments": {
      "snapshot_yaml": "...",
      "creator_filter": "Jason Gilbertson"
    }
  }
}
```

**Response Format**:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "[{\"url\": \"...\", \"name\": \"...\"}]"
      }
    ]
  }
}
```

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
