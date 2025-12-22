# Product Specification: Kusto Dashboard Manager

**Version**: 1.0  
**Status**: Active Development  
**Project Type**: MCP Server - Azure Integration (Tier 2 Supporting)

## Overview

Kusto Dashboard Manager is an MCP (Model Context Protocol) server that enables programmatic management of Azure Data Explorer (Kusto) dashboards through VS Code and GitHub Copilot integration. The project leverages browser automation via Playwright MCP server to provide reliable dashboard export, import, validation, and parsing capabilities.

**Portfolio Context**: Tier 2 Supporting project demonstrating MCP protocol integration patterns, browser automation workflows, and Azure service interaction. Complements flagship MCP servers with specialized Azure Data Explorer dashboard management.

## User Scenarios

### US-001: Dashboard Export via AI Assistant [P1]
**As a** data engineer using GitHub Copilot  
**I want** to export Azure Data Explorer dashboards to JSON files  
**So that** I can version control dashboard configurations and migrate them between environments

**Given** I have access to Azure Data Explorer dashboards  
**When** I request dashboard export through Copilot chat  
**Then** the MCP server exports dashboard JSON with full configuration  
**And** files are saved to specified output directory with metadata

### US-002: Bulk Dashboard Import [P1]
**As a** DevOps engineer  
**I want** to import multiple dashboard JSON files back into Azure Data Explorer  
**So that** I can quickly restore or replicate dashboard configurations

**Given** I have validated dashboard JSON files  
**When** I trigger bulk import through MCP tools  
**Then** all dashboards are created/updated in target Kusto cluster  
**And** import status is reported for each dashboard

### US-003: Dashboard Validation Before Import [P2]
**As a** platform engineer  
**I want** to validate dashboard JSON structure before import  
**So that** I can catch configuration errors early and prevent failed deployments

**Given** I have dashboard JSON files  
**When** I run validation through MCP tools  
**Then** schema validation reports any structural issues  
**And** suggestions for fixes are provided

### US-004: Dashboard Discovery via Browser Automation [P2]
**As a** dashboard administrator  
**I want** to extract dashboard lists from Azure portal via automated browsing  
**So that** I can discover available dashboards without manual portal navigation

**Given** Playwright MCP server is available  
**When** I request dashboard parsing from browser snapshots  
**Then** dashboard metadata is extracted with creator information  
**And** results support creator-based filtering

### US-005: VS Code Integrated Dashboard Workflow [P3]
**As a** developer using VS Code  
**I want** seamless dashboard management through Copilot chat  
**So that** I can manage dashboards without leaving my development environment

**Given** Kusto Dashboard Manager MCP server is configured in VS Code  
**When** I interact via Copilot chat commands  
**Then** dashboard operations execute with natural language prompts  
**And** results appear directly in chat interface

## Functional Requirements

### FR-001: MCP Protocol Compliance
- Implement standard MCP server lifecycle (initialization, tool registration, shutdown)
- Expose tools via `tools/list` and handle `tools/call` operations
- Support stdio transport for VS Code integration
- Return structured responses per MCP specification

### FR-002: Dashboard Export Operations
- Export single dashboards to JSON with full configuration
- Support bulk export of multiple dashboards
- Preserve dashboard metadata (creator, timestamps, sharing settings)
- Handle authentication to Azure Data Explorer

### FR-003: Dashboard Import Operations
- Import dashboard JSON files into Azure Data Explorer
- Validate dashboard structure before import
- Support overwrite and merge strategies
- Report import success/failure status per dashboard

### FR-004: Validation Engine
- Schema validation against Azure Data Explorer dashboard format
- Structural integrity checks (required fields, valid values)
- Cross-reference validation (query references, data source IDs)
- Provide actionable error messages

### FR-005: Browser Automation Integration
- Integrate with Playwright MCP server for automated browsing
- Parse dashboard lists from browser snapshots
- Extract dashboard metadata from HTML/DOM
- Support creator-based filtering

### FR-006: Authentication & Authorization
- Support Azure authentication mechanisms (service principal, interactive)
- Handle token refresh for long-running operations
- Respect Azure RBAC permissions for dashboard access
- Secure credential storage patterns

## Success Criteria

### SC-001: Export Accuracy
- **Target**: 100% fidelity in dashboard export (all configuration preserved)
- **Measurement**: Round-trip test (export → import → verify identical)
- **Validation**: Automated tests with sample dashboards

### SC-002: Import Reliability
- **Target**: >95% success rate for valid dashboard imports
- **Measurement**: Import success tracking across test suite
- **Validation**: 100% test coverage for import operations

### SC-003: Validation Effectiveness
- **Target**: Catch 100% of schema violations before import
- **Measurement**: Zero failed imports due to preventable validation errors
- **Validation**: Test with known-invalid dashboard configurations

### SC-004: Browser Automation Stability
- **Target**: >90% success rate for dashboard list parsing
- **Measurement**: Successful extraction from Playwright snapshots
- **Validation**: Integration tests with mocked browser responses

### SC-005: MCP Integration Quality
- **Target**: Seamless VS Code/Copilot integration with <2s response times
- **Measurement**: Tool invocation latency, error rates
- **Validation**: Manual testing in VS Code with Copilot

## Performance Requirements

### PR-001: Export Performance
- Single dashboard export: <5 seconds
- Bulk export (10 dashboards): <30 seconds
- Large dashboard (100+ tiles): <10 seconds export

### PR-002: Import Performance
- Single dashboard import: <10 seconds
- Validation only: <2 seconds per dashboard
- Bulk import (10 dashboards): <2 minutes

### PR-003: Response Latency
- MCP tool listing: <500ms
- Tool invocation acknowledgment: <100ms
- Browser automation parsing: <5 seconds

## Security Requirements

### SR-001: Credential Protection
- No plaintext credential storage
- Support secure credential providers (Azure Key Vault, environment variables)
- Automatic credential rotation support

### SR-002: Dashboard Access Control
- Respect Azure RBAC permissions
- No privilege escalation attempts
- Audit logging for dashboard modifications

### SR-003: Data Privacy
- No logging of sensitive dashboard data (queries, data samples)
- Secure transmission of dashboard JSON
- Support for data redaction in exports

## Compliance Requirements

### CR-001: Azure Standards
- Follow Azure SDK best practices
- Use official Azure client libraries
- Implement retry policies per Azure guidance

### CR-002: MCP Specification
- Comply with MCP 1.0 protocol specification
- Use standard transport (stdio) for VS Code
- Implement recommended error handling patterns

## Integration Points

### Depends On
- **Playwright MCP server** (`@playwright/mcp@latest`): Browser automation for dashboard discovery
- **Azure SDK for Python**: Azure Data Explorer client libraries
- **MCP SDK** (`@modelcontextprotocol/sdk`): Protocol implementation

### Integrates With
- **VS Code + GitHub Copilot**: Primary user interface
- **Azure Data Explorer**: Target platform for dashboard operations
- **mcp-index-server**: Can be indexed for AI agent discovery (optional)

## Technical Constraints

- **Python 3.12+**: Minimum runtime version
- **Node.js 22.20.0+**: Required for MCP SDK compatibility
- **Network**: Azure endpoints must be accessible
- **Browser**: Playwright requires chromium/webkit for automation

## Cross-References

- README.md: Installation and quick start
- docs/AUTHENTICATION_CHALLENGE.md: Azure authentication patterns
- docs/PLAYWRIGHT_MCP_INTEGRATION.md: Browser automation integration
- docs/MCP_USAGE_GUIDE.md: Tool usage examples
- docs/TRACING.md: Debugging and observability
