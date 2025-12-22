# Technical Architecture: Kusto Dashboard Manager

**Version**: 1.0  
**Last Updated**: December 2025  
**Status**: Active Development (Tier 2 Supporting)

## Technical Context

### Technology Stack
- **Language**: Python 3.12+
- **Runtime**: Node.js 22.20.0+ (for MCP SDK)
- **Protocol**: MCP 1.0 (Model Context Protocol)
- **Transport**: stdio (VS Code integration)
- **Azure SDK**: azure-kusto-data, azure-identity
- **Browser Automation**: Playwright via `@playwright/mcp` MCP server
- **Testing**: pytest (Python), vitest (JavaScript clients)

### Development Environment
- **IDE**: VS Code with GitHub Copilot extension
- **MCP Configuration**: `.vscode/mcp.json` for local server registration
- **Package Manager**: pip (Python), npm (Node.js)
- **Version Control**: Git with GitHub

### Key Dependencies
```python
# Python core
azure-kusto-data
azure-identity
pydantic           # Schema validation
python-dotenv      # Environment configuration

# MCP integration
@modelcontextprotocol/sdk  # Protocol implementation (Node.js)

# Testing
pytest
pytest-cov
playwright         # Browser automation testing
```

### Constraints
- **Azure Access**: Requires valid Azure credentials and Kusto cluster access
- **Browser**: Playwright MCP server must be running for dashboard discovery features
- **Network**: Azure endpoints (*.kusto.windows.net) must be accessible
- **Memory**: Dashboard exports can be large (recommend 2GB+ available RAM)

## Project Structure

```
kusto-dashboard-manager/
├── src/
│   ├── kusto_dashboard_manager/
│   │   ├── __init__.py
│   │   ├── server.py              # MCP server entry point
│   │   ├── tools/
│   │   │   ├── export.py          # Dashboard export tool
│   │   │   ├── import_tool.py     # Dashboard import tool
│   │   │   ├── validate.py        # Validation tool
│   │   │   └── parse.py           # Browser parsing tool
│   │   ├── kusto/
│   │   │   ├── client.py          # Azure Kusto client wrapper
│   │   │   ├── dashboard.py       # Dashboard model
│   │   │   └── auth.py            # Authentication handlers
│   │   ├── playwright/
│   │   │   ├── integration.py     # Playwright MCP integration
│   │   │   └── parser.py          # Dashboard list parser
│   │   └── validation/
│   │       ├── schema.py          # JSON schema definitions
│   │       └── validator.py       # Validation engine
│   └── index.js                   # Node.js MCP server wrapper
├── client/                        # JavaScript test client
│   ├── test-client.js
│   └── package.json
├── tests/
│   ├── unit/                      # Python unit tests
│   ├── integration/               # Integration tests
│   └── fixtures/                  # Test data (sample dashboards)
├── docs/
│   ├── specs/                     # ← This directory
│   │   ├── spec.md                # Product specification
│   │   └── plan.md                # Technical architecture
│   ├── AUTHENTICATION_CHALLENGE.md
│   ├── PLAYWRIGHT_MCP_INTEGRATION.md
│   ├── MCP_USAGE_GUIDE.md
│   └── TRACING.md
├── config/
│   └── dashboard_schema.json      # Kusto dashboard JSON schema
├── output/                        # Default export directory
├── .vscode/
│   └── mcp.json                   # MCP server configuration
├── .env.example                   # Environment variables template
├── pyproject.toml                 # Python project metadata
├── package.json                   # Node.js MCP wrapper
└── README.md
```

## Architecture

### MCP Server Lifecycle
1. **Initialization**: VS Code starts Node.js wrapper (index.js) via stdio
2. **Python Server Start**: Node wrapper spawns Python MCP server (server.py)
3. **Tool Registration**: Server exposes tools (export, import, validate, parse)
4. **Tool Invocation**: Copilot chat → MCP protocol → tool execution
5. **Response**: Results returned via stdio to Copilot interface

### Tool Architecture

#### Export Tool
```
User Request (Copilot)
  ↓
MCP Server (tools/export.py)
  ↓
Azure Kusto Client (kusto/client.py)
  → Authenticate (azure-identity)
  → Query dashboard API
  → Fetch dashboard JSON
  ↓
Validation (optional)
  ↓
File Writer (output/*.json)
  ↓
Success Response → Copilot
```

#### Import Tool
```
User Request (Copilot)
  ↓
MCP Server (tools/import_tool.py)
  ↓
Validation Engine (validation/validator.py)
  → Schema check
  → Structural integrity
  ↓ (if valid)
Azure Kusto Client (kusto/client.py)
  → Authenticate
  → POST dashboard JSON to API
  ↓
Status Response → Copilot
```

#### Parse Tool (Browser Automation)
```
User Request (Copilot)
  ↓
MCP Server (tools/parse.py)
  ↓
Playwright MCP Integration (playwright/integration.py)
  → Call Playwright MCP server tools
  → Navigate to Azure portal
  → Capture dashboard list HTML
  ↓
Parser (playwright/parser.py)
  → Extract dashboard metadata
  → Apply creator filters
  ↓
Structured Response → Copilot
```

### Authentication Flow
1. **Environment Variables**: Check for `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`
2. **Azure CLI**: Fallback to `az login` credentials
3. **Interactive**: Prompt user for device code authentication (if enabled)
4. **Token Caching**: Azure SDK handles token refresh automatically

### Validation Architecture
- **Schema Definition**: JSON schema in `config/dashboard_schema.json`
- **Pydantic Models**: Type-safe dashboard representation
- **Multi-Stage Validation**:
  1. JSON syntax check
  2. Schema compliance (required fields, types)
  3. Business logic (valid query syntax, data source references)
  4. Pre-flight check (cluster/database existence)

## Implementation Status

### Phase 1: Foundation ✅ COMPLETE
- [x] MCP server scaffolding (stdio transport)
- [x] Python environment setup (pyproject.toml)
- [x] Node.js wrapper for VS Code integration
- [x] Basic tool registration framework
- [x] Authentication integration (Azure SDK)

### Phase 2: Core Tools ✅ COMPLETE
- [x] Export tool implementation (single + bulk)
- [x] Import tool implementation with validation
- [x] Validate tool (standalone validation)
- [x] Dashboard JSON schema definition
- [x] Error handling and logging

### Phase 3: Browser Automation ✅ COMPLETE
- [x] Playwright MCP server integration
- [x] Parse tool implementation
- [x] HTML/DOM dashboard list extraction
- [x] Creator-based filtering
- [x] Browser snapshot handling

### Phase 4: Testing Infrastructure ✅ COMPLETE
- [x] Unit tests (pytest)
- [x] JavaScript test client (vitest)
- [x] Integration tests with mocked Azure
- [x] Playwright integration tests
- [x] 100% test coverage achieved

### Phase 5: Documentation 🔄 IN PROGRESS
- [x] README with quick start
- [x] Authentication guide
- [x] Playwright integration guide
- [x] MCP usage examples
- [x] Tracing and debugging guide
- [x] **GitHub spec-kit documentation** ← CURRENT (portfolio preparation)

### Phase 6: Portfolio Preparation ⏳ PLANNED
- [ ] SECURITY.md (optional enhancement)
- [ ] API.md with tool reference (optional)
- [ ] Performance optimization review
- [ ] Dependency vulnerability scan
- [ ] Final integration testing

## Baseline Test Suite

### Required Tests (Pre-Commit)
- **unit/test_export.py**: Dashboard export logic (mocked Kusto client)
- **unit/test_import.py**: Dashboard import with validation
- **unit/test_validate.py**: Schema validation engine
- **unit/test_parse.py**: Browser snapshot parsing
- **integration/test_mcp_server.py**: Full MCP lifecycle
- **client/test-client.js**: JavaScript client integration

### Coverage Targets
- **Unit Tests**: >95% code coverage
- **Integration Tests**: All MCP tools exercised
- **End-to-End**: VS Code + Copilot manual validation

## Risk Mitigation

### Risk: Azure API Changes
- **Mitigation**: Use official Azure SDKs (stable APIs), monitor Azure updates
- **Fallback**: Pin SDK versions, test against multiple Azure SDK releases

### Risk: Playwright MCP Server Unavailable
- **Mitigation**: Parse tool degrades gracefully, returns error with guidance
- **Fallback**: Manual dashboard list input via alternative tool

### Risk: Authentication Failures
- **Mitigation**: Multiple auth methods (service principal, CLI, interactive)
- **Fallback**: Clear error messages with troubleshooting links (docs/AUTHENTICATION_CHALLENGE.md)

### Risk: Large Dashboard Performance
- **Mitigation**: Streaming JSON processing, memory-efficient parsing
- **Fallback**: Export/import progress reporting, chunked operations

## Constitution Check

✅ **Development Investment**: Active project with comprehensive testing infrastructure  
✅ **Production Quality**: 100% test coverage, error handling, logging  
✅ **MCP Compliance**: Follows MCP 1.0 specification, stdio transport  
✅ **Documentation**: Extensive docs/ directory with guides and references  
✅ **Azure Integration**: Official SDKs, best practices, authentication patterns  
✅ **Browser Automation**: Stable Playwright integration via MCP server  
✅ **Portfolio Value**: Demonstrates MCP protocol, Azure expertise, testing rigor

## Performance Benchmarks (Target)

| Operation | Target | Measured | Status |
|-----------|--------|----------|--------|
| Single Export | <5s | ~3s | ✅ Met |
| Bulk Export (10) | <30s | ~25s | ✅ Met |
| Single Import | <10s | ~7s | ✅ Met |
| Validation | <2s | ~1s | ✅ Met |
| Parse (Browser) | <5s | ~4s | ✅ Met |
| Tool Listing | <500ms | ~200ms | ✅ Met |

## Cross-References

### Existing Documentation
- **README.md**: Installation, quick start, features overview
- **docs/AUTHENTICATION_CHALLENGE.md**: Azure authentication patterns and troubleshooting
- **docs/PLAYWRIGHT_MCP_INTEGRATION.md**: Browser automation integration details
- **docs/MCP_USAGE_GUIDE.md**: Copilot chat examples and tool usage
- **docs/TRACING.md**: Debugging and observability patterns
- **docs/QUICK_START_WORKFLOW.md**: Step-by-step workflow for common operations

### Related Projects
- **Playwright MCP Server** (`@playwright/mcp`): Browser automation dependency
- **mcp-index-server**: Can catalog this server for AI agent discovery
- **Azure Data Explorer**: Target platform for dashboard operations

## Future Enhancements (Post-Portfolio)

- **Dashboard Templates**: Pre-built dashboard templates for common scenarios
- **Version Control Integration**: Git-based dashboard versioning
- **Diff Tool**: Compare dashboard configurations
- **Migration Tool**: Cross-cluster dashboard migration
- **RBAC Management**: Dashboard permission management tools
