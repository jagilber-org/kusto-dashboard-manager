# Kusto Dashboard Manager

A Python command-line tool for exporting and importing Azure Data Explorer (Kusto) dashboards using browser automation via the Model Context Protocol (MCP).

[![Tests](https://img.shields.io/badge/tests-130%20passing-brightgreen)](tests/)
[![Coverage](https://img.shields.io/badge/coverage-94--100%25-brightgreen)](tests/)
[![Python](https://img.shields.io/badge/python-3.8%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Features

- **Export Dashboards**: Export Azure Data Explorer dashboards to JSON files with metadata
- **Import Dashboards**: Import dashboard JSON files back into Azure Data Explorer
- **Validate**: Validate dashboard JSON file structure before import
- **Browser Automation**: Uses Playwright MCP server for reliable browser automation
- **Configuration Management**: Flexible configuration via environment variables or JSON files
- **Comprehensive Testing**: 130 tests with 94-100% coverage across all modules

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Development](#development)
- [Testing](#testing)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Prerequisites

- Python 3.8 or higher
- Node.js (for Playwright MCP server)
- Azure Data Explorer account with dashboard access

### Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jagilber/kusto-dashboard-manager.git
   cd kusto-dashboard-manager
   ```

2. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Install Playwright MCP server** (one-time setup):
   ```bash
   npx @playwright/mcp@latest
   ```

4. **Verify installation**:
   ```bash
   python src/kusto_dashboard_manager.py version
   ```

## Quick Start

### Export a Dashboard

```bash
python src/kusto_dashboard_manager.py export \
  "https://dataexplorer.azure.com/dashboards/12345" \
  -o my_dashboard.json
```

### Validate Dashboard JSON

```bash
python src/kusto_dashboard_manager.py validate my_dashboard.json
```

### Import a Dashboard

```bash
python src/kusto_dashboard_manager.py import my_dashboard.json
```

## Usage

### Command Line Interface

The tool provides five main commands:

#### 1. Export Command

Export an Azure Data Explorer dashboard to a JSON file.

```bash
python src/kusto_dashboard_manager.py export <dashboard_url> [-o OUTPUT_FILE]
```

**Options**:
- `dashboard_url`: URL of the dashboard to export (required)
- `-o, --output`: Output file path (default: auto-generated from dashboard name)

**Example**:
```bash
python src/kusto_dashboard_manager.py export \
  "https://dataexplorer.azure.com/dashboards/my-dashboard" \
  -o exports/dashboard_2024.json
```

#### 2. Import Command

Import a dashboard JSON file into Azure Data Explorer.

```bash
python src/kusto_dashboard_manager.py import <json_file> [--no-verify]
```

**Options**:
- `json_file`: Path to dashboard JSON file (required)
- `--no-verify`: Skip verification after import (optional)

**Example**:
```bash
python src/kusto_dashboard_manager.py import exports/dashboard_2024.json
```

#### 3. Validate Command

Validate a dashboard JSON file structure.

```bash
python src/kusto_dashboard_manager.py validate <json_file>
```

**Example**:
```bash
python src/kusto_dashboard_manager.py validate exports/dashboard_2024.json
```

#### 4. Config Command

View or modify configuration settings.

```bash
# Show all configuration
python src/kusto_dashboard_manager.py config

# Get specific value
python src/kusto_dashboard_manager.py config --get browser.headless

# Set value
python src/kusto_dashboard_manager.py config --set browser.headless=false
```

#### 5. Version Command

Display version information.

```bash
python src/kusto_dashboard_manager.py version
```

### Global Options

These flags can be used with any command:

- `--verbose, -v`: Enable verbose logging (DEBUG level)
- `--config-file, -c`: Specify custom configuration file path

**Example**:
```bash
python src/kusto_dashboard_manager.py --verbose --config-file custom_config.json export <url>
```

## Configuration

### Configuration Files

Configuration can be provided via:

1. **Environment variables** (prefix: `KDM_`)
2. **JSON configuration file** (via `--config-file`)
3. **Default configuration** (built-in)

### Configuration Structure

```json
{
  "browser": {
    "headless": true,
    "timeout": 30000,
    "viewport": {
      "width": 1920,
      "height": 1080
    }
  },
  "dashboard": {
    "base_url": "https://dataexplorer.azure.com/dashboards",
    "export_timeout": 60000,
    "wait_for_load": true
  },
  "logging": {
    "enabled": true,
    "level": "INFO",
    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  }
}
```

### Environment Variables

Set configuration via environment variables:

```bash
# Windows (PowerShell)
$env:KDM_BROWSER_HEADLESS = "false"
$env:KDM_BROWSER_TIMEOUT = "60000"
$env:KDM_LOGGING_LEVEL = "DEBUG"

# Linux/macOS
export KDM_BROWSER_HEADLESS=false
export KDM_BROWSER_TIMEOUT=60000
export KDM_LOGGING_LEVEL=DEBUG
```

### Configuration Priority

1. Command-line arguments (highest priority)
2. Environment variables
3. Configuration file (via `--config-file`)
4. Default configuration (lowest priority)

## Development

### Project Structure

```
kusto-dashboard-manager/
├── src/
│   ├── __init__.py                    # Package initialization
│   ├── kusto_dashboard_manager.py     # CLI entry point (106 statements, 94% coverage)
│   ├── config.py                      # Configuration management (76 statements, 96% coverage)
│   ├── utils.py                       # Utility functions (61 statements, 93% coverage)
│   ├── browser_manager.py             # Browser automation (45 statements, 100% coverage)
│   ├── dashboard_export.py            # Export functionality (61 statements, 97% coverage)
│   ├── dashboard_import.py            # Import functionality (54 statements, 100% coverage)
│   └── playwright_mcp_client.py       # MCP client wrapper
├── tests/
│   ├── conftest.py                    # Pytest fixtures
│   ├── test_config.py                 # Config tests (14 tests)
│   ├── test_utils.py                  # Utils tests (18 tests)
│   ├── test_browser_manager.py        # Browser tests (18 tests)
│   ├── test_dashboard_export.py       # Export tests (22 tests)
│   ├── test_dashboard_import.py       # Import tests (23 tests)
│   └── test_cli.py                    # CLI tests (35 tests)
├── requirements.txt                   # Python dependencies
├── pytest.ini                         # Pytest configuration
└── README.md                          # This file
```

### Setting Up Development Environment

1. **Clone and install**:
   ```bash
   git clone https://github.com/jagilber/kusto-dashboard-manager.git
   cd kusto-dashboard-manager
   pip install -r requirements.txt
   pip install -r requirements-dev.txt  # Development dependencies
   ```

2. **Run tests**:
   ```bash
   pytest tests/ -v
   ```

3. **Check coverage**:
   ```bash
   pytest tests/ --cov=src --cov-report=term-missing
   ```

4. **Run specific test file**:
   ```bash
   pytest tests/test_cli.py -v
   ```

## Testing

### Test Suite Overview

The project includes 130 comprehensive tests across 6 test files:

| Module | Tests | Coverage | Description |
|--------|-------|----------|-------------|
| `config.py` | 14 | 96% | Configuration management |
| `utils.py` | 18 | 93% | Utility functions |
| `browser_manager.py` | 18 | 100% | Browser automation |
| `dashboard_export.py` | 22 | 97% | Dashboard export |
| `dashboard_import.py` | 23 | 100% | Dashboard import |
| `kusto_dashboard_manager.py` | 35 | 94% | CLI interface |
| **Total** | **130** | **94-100%** | Full test suite |

### Running Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=src --cov-report=html

# Run specific test class
pytest tests/test_cli.py::TestArgumentParsing -v

# Run with verbose output
pytest tests/ -v --tb=short

# Run in parallel (faster)
pytest tests/ -n auto
```

### Test Categories

1. **Unit Tests** (`test_config.py`, `test_utils.py`)
   - Configuration management
   - Validation functions
   - File operations
   - Logger functionality

2. **Integration Tests** (`test_browser_manager.py`, `test_dashboard_export.py`, `test_dashboard_import.py`)
   - Browser automation with mock MCP
   - Dashboard extraction
   - Metadata enrichment
   - Import workflow

3. **CLI Tests** (`test_cli.py`)
   - Argument parsing
   - Command execution
   - Error handling
   - Integration workflows

### Mock MCP Client

Tests use a `MockMCPClient` that simulates Playwright MCP server responses:

```python
# Example test setup
@pytest.fixture
def mock_mcp_client():
    return MockMCPClient()

async def test_export(mock_mcp_client):
    mock_mcp_client.set_response("mcp_playwright_browser_navigate", {"success": True})
    # Test code here
```

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Kusto Dashboard Manager                   │
│                         (CLI Tool)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Commands
                              ▼
        ┌─────────────────────────────────────────┐
        │      kusto_dashboard_manager.py         │
        │         (CLI Entry Point)               │
        └─────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌──────────────────┐                    ┌──────────────────┐
│ DashboardExporter│                    │ DashboardImporter│
│   (Export Logic) │                    │   (Import Logic) │
└──────────────────┘                    └──────────────────┘
        │                                           │
        └─────────────────────┬─────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │   BrowserManager     │
                  │ (Browser Automation) │
                  └──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │ PlaywrightMCPClient  │
                  │   (MCP Protocol)     │
                  └──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │   Playwright MCP     │
                  │      Server          │
                  └──────────────────────┘
                              │
                              ▼
                  ┌──────────────────────┐
                  │   Browser (Chrome)   │
                  └──────────────────────┘
```

### Key Components

1. **CLI Layer** (`kusto_dashboard_manager.py`)
   - Argument parsing (argparse)
   - Command routing
   - Configuration loading
   - Logger setup

2. **Export Module** (`dashboard_export.py`)
   - Dashboard URL extraction
   - DOM element selection
   - JSON serialization
   - Metadata enrichment

3. **Import Module** (`dashboard_import.py`)
   - File validation
   - Metadata stripping
   - JavaScript injection
   - Browser navigation

4. **Browser Manager** (`browser_manager.py`)
   - MCP client wrapper
   - Browser lifecycle management
   - Navigation and interaction
   - Script execution

5. **Configuration** (`config.py`)
   - Environment variable parsing
   - JSON file loading
   - Nested key access
   - Validation

6. **Utilities** (`utils.py`)
   - Logging setup
   - JSON validation
   - File operations
   - Output formatting

### Data Flow

#### Export Flow

```
User Command → CLI Parser → DashboardExporter
    ↓
BrowserManager → MCP Client → Browser Launch
    ↓
Navigate to Dashboard URL
    ↓
Extract Dashboard Data (JavaScript execution)
    ↓
Enrich with Metadata (timestamp, URL, version)
    ↓
Validate JSON Structure
    ↓
Write to File → Success Message
```

#### Import Flow

```
User Command → CLI Parser → DashboardImporter
    ↓
Validate Dashboard JSON File
    ↓
Strip Export Metadata (_metadata key)
    ↓
BrowserManager → MCP Client → Browser Launch
    ↓
Navigate to /new Endpoint
    ↓
Inject Dashboard JSON (2 methods: window variable, custom event)
    ↓
Verify Import (optional) → Success Message
```

## Troubleshooting

### Common Issues

#### 1. "Module not found" error

**Problem**: Python can't find the `src` modules.

**Solution**:
```bash
# Add src to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src"  # Linux/macOS
$env:PYTHONPATH += ";$(pwd)\src"              # Windows PowerShell
```

#### 2. MCP server connection fails

**Problem**: Can't connect to Playwright MCP server.

**Solution**:
```bash
# Verify Playwright MCP is installed
npx @playwright/mcp@latest --version

# Check if server is running
ps aux | grep playwright  # Linux/macOS
Get-Process | Where-Object {$_.ProcessName -like "*node*"}  # Windows
```

#### 3. Browser launch timeout

**Problem**: Browser fails to launch within timeout.

**Solution**:
- Increase timeout in configuration:
  ```json
  {
    "browser": {
      "timeout": 60000
    }
  }
  ```
- Or use environment variable:
  ```bash
  export KDM_BROWSER_TIMEOUT=60000
  ```

#### 4. Dashboard extraction fails

**Problem**: Can't extract dashboard data from page.

**Solution**:
- Verify you're logged into Azure Data Explorer
- Check dashboard URL is correct
- Try with headless mode disabled:
  ```bash
  python src/kusto_dashboard_manager.py --config-file config.json export <url>
  # config.json: {"browser": {"headless": false}}
  ```

#### 5. Import injection fails

**Problem**: Dashboard data not injected properly.

**Solution**:
- The tool uses two fallback methods for injection
- Check browser console for errors (with headless=false)
- Verify dashboard JSON is valid:
  ```bash
  python src/kusto_dashboard_manager.py validate dashboard.json
  ```

### Debug Mode

Enable verbose logging for detailed troubleshooting:

```bash
python src/kusto_dashboard_manager.py --verbose export <url>
```

This will show:
- MCP client calls
- Browser automation steps
- JavaScript execution results
- Error stack traces

## Contributing

Contributions are welcome! Please follow these guidelines:

### Development Workflow

1. **Fork the repository**
2. **Create a feature branch**:
   ```bash
   git checkout -b feature/my-new-feature
   ```

3. **Make your changes**:
   - Write code following existing style
   - Add tests for new functionality
   - Update documentation

4. **Run tests**:
   ```bash
   pytest tests/ -v --cov=src
   ```

5. **Commit changes**:
   ```bash
   git commit -am "Add new feature: description"
   ```

6. **Push to your fork**:
   ```bash
   git push origin feature/my-new-feature
   ```

7. **Create Pull Request**

### Code Style

- Follow PEP 8 style guidelines
- Use type hints where possible
- Write docstrings for all public functions
- Keep functions focused and testable
- Aim for 90%+ test coverage

### Testing Requirements

- All new features must include tests
- Tests should cover success and failure cases
- Use pytest fixtures for common setup
- Mock external dependencies (MCP client, file I/O)

### Documentation

- Update README.md for new features
- Add docstrings to all public APIs
- Include usage examples
- Update CHANGELOG.md

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **PowerShell Reference**: Based on the original PowerShell implementation
- **Playwright MCP**: Uses the [@playwright/mcp](https://www.npmjs.com/package/@playwright/mcp) protocol
- **Azure Data Explorer**: Microsoft's big data analytics platform

## Support

For questions, issues, or feature requests:

- **Issues**: [GitHub Issues](https://github.com/jagilber/kusto-dashboard-manager/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jagilber/kusto-dashboard-manager/discussions)
- **Email**: [Contact maintainer](mailto:jagilber@example.com)

## Changelog

### Version 1.0.0 (Current)

**Features**:
- ✅ Export dashboards to JSON with metadata
- ✅ Import dashboards from JSON files
- ✅ Validate dashboard JSON structure
- ✅ Configuration management (env vars, JSON files)
- ✅ Comprehensive CLI with 5 commands
- ✅ 130 tests with 94-100% coverage
- ✅ Browser automation via Playwright MCP

**Known Limitations**:
- Requires manual Azure login before export
- No support for dashboard permissions export
- No batch export/import functionality

**Future Enhancements**:
- Batch operations for multiple dashboards
- Dashboard diff/merge capabilities
- Export/import dashboard permissions
- CI/CD integration examples
- Docker container support

---

**Made with ❤️ for Azure Data Explorer users**
