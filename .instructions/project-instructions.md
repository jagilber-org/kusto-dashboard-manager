# Project Instructions - Kusto Dashboard Manager

**Version**: 1.0.0  
**Last Updated**: 2025-10-08  
**Authority**: Subordinate to Project Constitution  

## Technology Stack Integration

### Primary Technologies
- **Language**: PowerShell 7.4+
- **Browser Automation**: Playwright via MCP Server
- **Browser**: Microsoft Edge (required for work profile authentication)
- **Testing Framework**: Pester 5.x
- **Code Quality**: PSScriptAnalyzer

### MCP Server Configuration

#### Required MCP Servers
1. **Playwright MCP Server**: Browser automation
2. **Azure MCP Server**: Kusto cluster integration
3. **PowerShell MCP Server**: Script validation and execution

#### VS Code Settings Configuration

Create or update `.vscode/settings.json`:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "node",
      "args": ["playwright-mcp-server"],
      "env": {
        "BROWSER": "msedge",
        "HEADLESS": "false"
      }
    },
    "azure": {
      "command": "azure-mcp-server",
      "args": [],
      "env": {
        "AZURE_TENANT_ID": "${AZURE_TENANT_ID}",
        "AZURE_SUBSCRIPTION_ID": "${AZURE_SUBSCRIPTION_ID}"
      }
    },
    "powershell": {
      "command": "powershell",
      "args": ["-ExecutionPolicy", "Bypass", "-File", "mcp-server-powershell.ps1"]
    }
  }
}
```

## Project Architecture Patterns

### Module Structure

```
src/
├── KustoDashboardManager.ps1          # Main entry point
├── modules/
│   ├── Core/
│   │   ├── Configuration.psm1         # Configuration management
│   │   └── Logging.psm1              # Logging functionality
│   ├── Authentication/
│   │   └── EdgeAuthentication.psm1   # Edge work profile auth
│   ├── Dashboard/
│   │   ├── Export.psm1               # Export operations
│   │   ├── Import.psm1               # Import operations
│   │   └── Validation.psm1           # Schema validation
│   ├── Playwright/
│   │   ├── BrowserManager.psm1       # Browser automation
│   │   └── NavigationHelpers.psm1    # Navigation utilities
│   └── MCP/
│       └── MCPClient.psm1            # MCP server interaction
├── config/
│   ├── default.json                   # Default configuration
│   ├── development.json               # Development settings
│   └── schema/
│       └── dashboard-schema.json      # Dashboard JSON schema
└── scripts/
    ├── Install-Dependencies.ps1
    └── Test-Environment.ps1
```

### Configuration Management

#### Environment-Specific Configuration

**default.json**:
```json
{
  "application": {
    "name": "KustoDashboardManager",
    "version": "1.0.0"
  },
  "browser": {
    "type": "msedge",
    "headless": false,
    "timeout": 30000,
    "workProfile": true
  },
  "kusto": {
    "baseUrl": "https://dataexplorer.azure.com",
    "timeout": 60000
  },
  "export": {
    "outputPath": "./exports",
    "includeMetadata": true,
    "prettyPrint": true
  },
  "logging": {
    "level": "Info",
    "format": "json",
    "outputPath": "./logs"
  }
}
```

**development.json** (overrides):
```json
{
  "browser": {
    "headless": false
  },
  "logging": {
    "level": "Debug"
  }
}
```

**production.json** (overrides):
```json
{
  "browser": {
    "headless": true,
    "timeout": 60000
  },
  "logging": {
    "level": "Warning",
    "outputPath": "C:\\ProgramData\\KustoDashboardManager\\logs"
  }
}
```

### Error Handling Patterns

All functions must implement consistent error handling:

```powershell
function Export-KustoDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DashboardId,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    $errorContext = @{
        Function = $MyInvocation.MyCommand.Name
        DashboardId = $DashboardId
        OutputPath = $OutputPath
        Timestamp = Get-Date -Format 'o'
        User = $env:USERNAME
        CorrelationId = [guid]::NewGuid()
    }
    
    try {
        Write-LogInfo "Starting dashboard export" -Context $errorContext
        
        # Implementation
        
        Write-LogInfo "Dashboard export completed successfully" -Context $errorContext
    }
    catch {
        $errorContext.Error = $_.Exception.Message
        $errorContext.StackTrace = $_.ScriptStackTrace
        
        Write-LogError "Dashboard export failed" -Context $errorContext
        
        throw [System.Exception]::new(
            "Failed to export dashboard '$DashboardId': $($_.Exception.Message)",
            $_.Exception
        )
    }
}
```

### Logging Strategy

#### Structured Logging Implementation

```powershell
function Write-LogEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [hashtable]$Context = @{}
    )
    
    $logEntry = @{
        Timestamp = Get-Date -Format 'o'
        Level = $Level
        Message = $Message
        MachineName = $env:COMPUTERNAME
        ProcessId = $PID
    } + $Context
    
    $logJson = $logEntry | ConvertTo-Json -Compress
    
    # Write to file
    Add-Content -Path $script:LogFilePath -Value $logJson
    
    # Also output to console based on level
    switch ($Level) {
        'Debug'   { Write-Verbose $Message }
        'Info'    { Write-Information $Message }
        'Warning' { Write-Warning $Message }
        'Error'   { Write-Error $Message }
    }
}
```

## Development Workflow

### 1. Feature Implementation Process

1. **Specification Review**: Ensure spec is complete and approved
2. **Test Creation**: Write Pester tests based on acceptance criteria
3. **Red Phase**: Confirm all tests fail appropriately
4. **Implementation**: Write minimum code to pass tests
5. **Green Phase**: All tests pass
6. **Refactor**: Improve code quality while maintaining tests
7. **Documentation**: Update inline and external documentation

### 2. MCP Integration Patterns

#### Pattern: Browser Navigation

```powershell
function Invoke-PlaywrightNavigation {
    param(
        [string]$Url
    )
    
    $mcpRequest = @{
        Server = 'playwright'
        Tool = 'navigate'
        Parameters = @{
            url = $Url
        }
    }
    
    $result = Invoke-MCPTool @mcpRequest
    
    if (-not $result.Success) {
        throw "Navigation failed: $($result.Error)"
    }
    
    return $result
}
```

#### Pattern: Kusto Query Execution

```powershell
function Invoke-KustoQuery {
    param(
        [string]$ClusterUri,
        [string]$Database,
        [string]$Query
    )
    
    $mcpRequest = @{
        Server = 'azure'
        Tool = 'kusto'
        Parameters = @{
            cluster = $ClusterUri
            database = $Database
            query = $Query
        }
    }
    
    $result = Invoke-MCPTool @mcpRequest
    return $result.Data
}
```

### 3. Testing Standards

#### Test Structure

```powershell
BeforeAll {
    # Import module
    Import-Module "$PSScriptRoot/../src/modules/Dashboard/Export.psm1" -Force
    
    # Mock MCP calls
    Mock Invoke-MCPTool {
        return @{
            Success = $true
            Data = @{ DashboardId = 'test-123' }
        }
    }
}

Describe "Export-KustoDashboard" {
    Context "When exporting a valid dashboard" {
        It "Should create output file" {
            $result = Export-KustoDashboard -DashboardId 'test-123' -OutputPath 'TestDrive:\'
            
            'TestDrive:\test-123.json' | Should -Exist
        }
        
        It "Should include metadata" {
            $result = Export-KustoDashboard -DashboardId 'test-123' -OutputPath 'TestDrive:\'
            $content = Get-Content 'TestDrive:\test-123.json' | ConvertFrom-Json
            
            $content.version | Should -Not -BeNullOrEmpty
            $content.exported | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Error Handling" {
        It "Should throw on invalid dashboard ID" {
            Mock Invoke-MCPTool { throw "Dashboard not found" }
            
            { Export-KustoDashboard -DashboardId 'invalid' -OutputPath 'TestDrive:\' } |
                Should -Throw "*Dashboard not found*"
        }
    }
}
```

#### Test Coverage Requirements

- **Unit Tests**: All functions must have unit tests
- **Integration Tests**: MCP integration points require integration tests
- **Coverage Target**: Minimum 90% code coverage
- **Test Naming**: Use descriptive test names following "Should [behavior] when [condition]" pattern

## Deployment Process

### Local Development Setup

```powershell
# Run setup script
.\scripts\Install-Dependencies.ps1

# Verify environment
.\scripts\Test-Environment.ps1

# Configure MCP servers (manual step in VS Code)
# Update .vscode/settings.json with MCP configuration

# Run tests
Invoke-Pester -Path .\tests -Output Detailed

# Start application
.\src\KustoDashboardManager.ps1
```

### Production Deployment

1. **Build Package**: Create deployment package with all dependencies
2. **Environment Validation**: Verify target environment meets requirements
3. **Configuration**: Deploy environment-specific configuration
4. **Testing**: Run smoke tests in target environment
5. **Documentation**: Update operational runbooks

## Security Guidelines

### Authentication Security

- **Never store credentials**: Use Edge work profile or Azure managed identities
- **Token handling**: Clear tokens from memory after use
- **Audit logging**: Log all authentication events
- **MFA support**: Handle MFA prompts gracefully

### Data Protection

- **Sensitive data**: Identify and protect PII in dashboard definitions
- **Encryption**: Support optional encryption of export files
- **Access control**: Validate user permissions before operations
- **Audit trail**: Maintain audit logs for compliance

### Code Security

- **Input validation**: Validate all user inputs
- **Output encoding**: Sanitize all outputs
- **Dependency scanning**: Regular security scans of dependencies
- **Code analysis**: Run PSScriptAnalyzer with security rules

## Troubleshooting Guide

### Common Issues

#### Issue: Edge Work Profile Not Found

**Symptoms**: Authentication fails, browser prompts for login

**Resolution**:
1. Verify Edge work profile is configured
2. Check work profile name in configuration
3. Ensure user is signed in to work profile

#### Issue: Playwright MCP Server Not Responding

**Symptoms**: Browser automation commands timeout

**Resolution**:
1. Check MCP server configuration in VS Code
2. Restart VS Code
3. Verify Playwright is installed: `npx playwright --version`
4. Check logs: `Get-Content ./logs/mcp-playwright.log`

#### Issue: Dashboard Export Fails

**Symptoms**: Export command throws error

**Diagnostics**:
```powershell
# Enable debug logging
$env:LOG_LEVEL = 'Debug'

# Check dashboard accessibility
Test-DashboardAccess -DashboardId 'abc-123'

# Verify network connectivity
Test-NetConnection dataexplorer.azure.com -Port 443
```

## Performance Guidelines

### Optimization Strategies

- **Parallel Processing**: Process independent dashboards in parallel
- **Caching**: Cache authentication tokens and configuration
- **Connection Pooling**: Reuse browser sessions when possible
- **Batch Operations**: Group related operations

### Performance Targets

- Dashboard Export: <30 seconds
- Dashboard Import: <45 seconds
- Batch Operations: 10 dashboards in <5 minutes

## Maintenance and Support

### Regular Maintenance Tasks

- **Weekly**: Review logs for errors and warnings
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and update documentation
- **Annually**: Comprehensive security audit

### Support Channels

- **Issues**: GitHub Issues for bug reports and feature requests
- **Documentation**: README and docs/ folder
- **Logs**: Check ./logs for operational logs
- **Diagnostics**: Use built-in diagnostic commands

---

**Compliance Note**: All implementations must comply with Project Constitution (see `.instructions/constitution.md`)
