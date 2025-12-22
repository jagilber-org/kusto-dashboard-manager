# Architecture Guide

Complete architecture documentation for Kusto Dashboard Manager MCP server.

This guide covers:
- MCP integration overview and component interaction
- Key design principles (isolated servers, client orchestration, browser automation)
- Component details (MCP server, dashboard export/import, tracing)
- Data flow for bulk export workflow
- Non-standard YAML format handling
- Protocol details (JSON-RPC 2.0 message format)

---

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
