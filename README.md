# Kusto Dashboard Manager

A PowerShell-based console application for managing Azure Data Explorer (Kusto) dashboards through automated import/export operations.

## Overview

This tool automates the management of Kusto dashboards hosted at https://dataexplorer.azure.com/dashboards using:
- **PowerShell Core**: Console application framework
- **Playwright**: Web automation for dashboard operations
- **Microsoft Edge**: Browser with work profile authentication
- **MCP Servers**: Integration with Azure, Playwright, and PowerShell MCP servers

## Features

- **Dashboard Export**: Extract dashboard definitions and configurations
- **Dashboard Import**: Upload and configure dashboards programmatically
- **Batch Operations**: Process multiple dashboards efficiently
- **Work Profile Support**: Authenticate using Microsoft Edge work profiles
- **Format Conversion**: Support multiple dashboard formats

## Prerequisites

- Windows 10/11 or Windows Server 2019+
- PowerShell 7.4+
- Microsoft Edge browser
- Work profile configured in Edge
- VS Code with MCP server support

## Project Structure

```
kusto-dashboard-manager/
├── .instructions/           # Project governance and architectural principles
│   ├── constitution.md      # Immutable development principles
│   └── project-instructions.md
├── specs/                   # Feature specifications (spec-driven development)
│   └── 001-dashboard-manager/
│       ├── spec.md          # Feature specification
│       ├── plan.md          # Implementation plan
│       ├── tasks.md         # Task breakdown
│       └── data-model.md    # Data structures
├── src/                     # Source code
│   ├── KustoDashboardManager.ps1    # Main entry point
│   ├── modules/             # PowerShell modules
│   └── config/              # Configuration files
├── tests/                   # Pester test suites
├── tools/                   # Development and automation tools
└── docs/                    # Documentation
```

## Quick Start

```powershell
# Clone the repository
git clone https://github.com/jagilber/kusto-dashboard-manager.git
cd kusto-dashboard-manager

# Run the dashboard manager
.\src\KustoDashboardManager.ps1

# Export a dashboard
.\src\KustoDashboardManager.ps1 -Action Export -DashboardId "dashboard-id" -OutputPath ".\exports"

# Import a dashboard
.\src\KustoDashboardManager.ps1 -Action Import -DefinitionPath ".\exports\dashboard.json"
```

## Development Workflow

This project follows **Specification-Driven Development** methodology:

1. **Specification**: All features start with detailed specifications in `specs/`
2. **Planning**: Technical implementation plans with architecture decisions
3. **Task Breakdown**: Executable task lists with clear deliverables
4. **Implementation**: Code generation from specifications
5. **Testing**: Comprehensive test suites derived from specs

## MCP Server Integration

The project integrates with:
- **Azure MCP Server**: Kusto cluster queries and resource management
- **Playwright MCP Server**: Browser automation for dashboard operations
- **PowerShell MCP Server**: Script validation and execution

## License

MIT License - See LICENSE file for details

## Status

🚧 **In Development** - Following spec-driven development methodology
