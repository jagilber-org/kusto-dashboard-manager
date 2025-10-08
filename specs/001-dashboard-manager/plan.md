# Implementation Plan: Dashboard Manager Core Functionality

**Specification**: [spec.md](./spec.md)  
**Implementation Branch**: `001-dashboard-manager`  
**Estimated Effort**: 40-60 hours  
**Dependencies**: MCP servers configured, Edge browser with work profile  

## Executive Summary

This implementation plan defines the technical architecture for building a PowerShell-based Kusto Dashboard Manager that leverages Playwright for browser automation, Azure MCP for Kusto integration, and Microsoft Edge work profiles for authentication.

## Architecture Decisions

### Technology Choices

#### Primary Technology: PowerShell 7.4+
**Rationale**:
- Native Windows automation and enterprise integration
- Excellent module system for maintainable code
- Strong Azure and Microsoft ecosystem support
- First-class scripting capabilities
- Built-in cmdlet framework for CLI applications

#### Browser Automation: Playwright via MCP Server
**Rationale**:
- Modern, reliable browser automation
- Excellent Edge browser support
- MCP integration provides standardized interface
- Support for work profile authentication
- Better debugging and error handling than alternatives

#### Browser: Microsoft Edge (Required)
**Rationale**:
- Native work profile support for Azure AD authentication
- Seamless SSO with organizational accounts
- Better integration with Windows security features
- Required for accessing dataexplorer.azure.com with work credentials

#### Testing Strategy: Pester 5.x
**Rationale**:
- Industry standard for PowerShell testing
- BDD-style syntax for readable tests
- Excellent mocking capabilities
- Native PowerShell integration

### Design Patterns

#### Pattern: Module-Based Architecture
**Implementation**: Separate functional modules with clear responsibilities
- Core module for configuration and logging
- Authentication module for Edge profile management
- Dashboard module for import/export operations
- Playwright module for browser automation
- MCP module for server communication

#### Pattern: Configuration-Driven Behavior
**Implementation**: JSON-based configuration with environment overrides
- Default configuration with sensible defaults
- Environment-specific overrides (dev, staging, prod)
- Runtime configuration validation
- Secret management for sensitive values

#### Error Handling: Try-Catch with Structured Logging
**Implementation**: Consistent error handling across all modules
- Try-catch blocks for all I/O operations
- Structured error context logging
- User-friendly error messages
- Detailed technical logs for debugging

#### Logging: Structured JSON Logging
**Implementation**: All logs in JSON format with correlation IDs
- Timestamp, level, message, context
- Correlation IDs for request tracing
- Separate log files by date
- Configurable log levels per environment

## Implementation Phases

### Phase 1: Foundation (TDD Red Phase)

#### 1.1 Project Structure Setup
- [x] Create directory structure (src/, tests/, tools/, config/)
- [x] Initialize Git repository
- [x] Create README and documentation
- [x] Configure VS Code settings for MCP servers

#### 1.2 Core Infrastructure
- [ ] Implement Configuration module
  - Load configuration from JSON files
  - Support environment-specific overrides
  - Validate configuration schema
  - Test: Configuration loading and validation

- [ ] Implement Logging module
  - Structured JSON logging
  - Multiple log levels
  - File and console output
  - Test: Log entry creation and output

#### 1.3 MCP Client Implementation
- [ ] Create MCPClient module
  - Generic MCP tool invocation
  - Error handling for MCP failures
  - Response parsing and validation
  - Test: MCP tool invocation with mocked responses

### Phase 2: Browser Automation (TDD Green Phase)

#### 2.1 Playwright Integration
- [ ] Implement BrowserManager module
  - Initialize Playwright with Edge
  - Manage browser sessions
  - Handle browser lifecycle
  - Test: Browser initialization and cleanup

- [ ] Implement NavigationHelpers module
  - Navigate to URLs
  - Wait for page load
  - Handle navigation errors
  - Test: Navigation scenarios with mocked Playwright

#### 2.2 Authentication Management
- [ ] Implement EdgeAuthentication module
  - Detect work profile
  - Wait for authentication
  - Validate authenticated session
  - Test: Authentication detection and validation

### Phase 3: Dashboard Operations (TDD Refactor Phase)

#### 3.1 Export Functionality
- [ ] Implement Export module
  - Navigate to dashboard URL
  - Extract dashboard definition
  - Parse dashboard JSON
  - Save to file with metadata
  - Test: Complete export workflow

- [ ] Implement Validation module
  - Validate dashboard schema
  - Check required fields
  - Verify data integrity
  - Test: Schema validation scenarios

#### 3.2 Import Functionality
- [ ] Implement Import module
  - Load dashboard definition
  - Navigate to dashboard portal
  - Create/update dashboard via UI
  - Validate successful import
  - Test: Complete import workflow

### Phase 4: CLI and User Interface

#### 4.1 Command-Line Interface
- [ ] Implement main entry point (KustoDashboardManager.ps1)
  - Parameter parsing
  - Action routing
  - Help text generation
  - Test: CLI parameter handling

- [ ] Implement batch operations
  - Process multiple dashboards
  - Progress reporting
  - Error handling for failed items
  - Test: Batch processing scenarios

#### 4.2 Interactive Menu
- [ ] Implement menu system
  - Display menu options
  - Handle user input
  - Navigate menu hierarchy
  - Test: Menu interaction scenarios

### Phase 5: Integration and Validation

#### 5.1 Integration Testing
- [ ] End-to-end export test
- [ ] End-to-end import test
- [ ] Batch operation test
- [ ] Error recovery test
- [ ] Authentication flow test

#### 5.2 Performance Testing
- [ ] Measure export performance
- [ ] Measure import performance
- [ ] Optimize bottlenecks
- [ ] Validate performance targets

#### 5.3 Security Validation
- [ ] Credential handling review
- [ ] Input validation review
- [ ] Output sanitization review
- [ ] Security scan with PSScriptAnalyzer

## Testing Strategy

### Unit Testing

#### Test Structure Template
```powershell
BeforeAll {
    # Import module under test
    Import-Module "$PSScriptRoot/../src/modules/Dashboard/Export.psm1" -Force
    
    # Setup mocks
    Mock Invoke-MCPTool {
        return @{
            Success = $true
            Data = @{ DashboardId = 'test-123' }
        }
    }
    
    Mock Write-LogInfo { }
    Mock Write-LogError { }
}

Describe "Export-KustoDashboard" {
    Context "When exporting a valid dashboard" {
        It "Should navigate to dashboard URL" {
            Export-KustoDashboard -DashboardId 'test-123' -OutputPath 'TestDrive:\'
            
            Should -Invoke Invoke-MCPTool -Times 1 -ParameterFilter {
                $Tool -eq 'navigate'
            }
        }
        
        It "Should create output file with correct structure" {
            Export-KustoDashboard -DashboardId 'test-123' -OutputPath 'TestDrive:\'
            
            $file = Get-Content 'TestDrive:\test-123.json' | ConvertFrom-Json
            $file.version | Should -Be '1.0'
            $file.dashboard.id | Should -Be 'test-123'
        }
    }
    
    Context "Error Handling" {
        It "Should throw when dashboard not found" {
            Mock Invoke-MCPTool { throw "Dashboard not found" }
            
            { Export-KustoDashboard -DashboardId 'invalid' -OutputPath 'TestDrive:\' } |
                Should -Throw "*Dashboard not found*"
        }
        
        It "Should log error context" {
            Mock Invoke-MCPTool { throw "Network error" }
            
            try {
                Export-KustoDashboard -DashboardId 'test-123' -OutputPath 'TestDrive:\'
            }
            catch { }
            
            Should -Invoke Write-LogError -Times 1
        }
    }
}
```

### Integration Testing

#### Integration Test Scenarios
1. **Real Browser Test**: Test with actual Playwright and Edge browser
2. **Authentication Test**: Test work profile authentication flow
3. **Dashboard Portal Test**: Test navigation to real dashboard portal (in test environment)
4. **End-to-End Export**: Complete export workflow with real MCP servers
5. **End-to-End Import**: Complete import workflow with real MCP servers

### Test Coverage Requirements
- **Minimum Coverage**: 90% code coverage
- **Critical Paths**: 100% coverage for export/import workflows
- **Error Handling**: All error paths must be tested
- **Edge Cases**: All boundary conditions must be tested

## Technical Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│         KustoDashboardManager.ps1 (CLI Entry)           │
└─────────┬───────────────────────────────────────────────┘
          │
          ├─► Configuration Module (config loading)
          ├─► Logging Module (structured logging)
          │
          ├─► Dashboard Module
          │   ├─► Export.psm1
          │   ├─► Import.psm1
          │   └─► Validation.psm1
          │
          ├─► Playwright Module
          │   ├─► BrowserManager.psm1
          │   └─► NavigationHelpers.psm1
          │
          ├─► Authentication Module
          │   └─► EdgeAuthentication.psm1
          │
          └─► MCP Module
              └─► MCPClient.psm1
                  │
                  ├─► Playwright MCP Server
                  ├─► Azure MCP Server
                  └─► PowerShell MCP Server
```

### Data Flow Diagram

#### Export Flow
```
User Command
    │
    ├─► Parse Parameters
    │
    ├─► Load Configuration
    │
    ├─► Initialize Browser (via Playwright MCP)
    │   └─► Launch Edge with work profile
    │
    ├─► Authenticate (if needed)
    │   └─► Wait for user login
    │
    ├─► Navigate to Dashboard URL
    │
    ├─► Extract Dashboard Definition
    │   └─► Execute JavaScript to get dashboard JSON
    │
    ├─► Validate Dashboard Schema
    │
    ├─► Add Metadata (timestamp, user, version)
    │
    └─► Save to File
        └─► Return success/failure
```

#### Import Flow
```
User Command
    │
    ├─► Load Dashboard Definition File
    │
    ├─► Validate Schema
    │
    ├─► Initialize Browser (via Playwright MCP)
    │
    ├─► Navigate to Dashboard Portal
    │
    ├─► Create New Dashboard (or open existing)
    │
    ├─► Fill Dashboard Configuration
    │   ├─► Set name, description
    │   ├─► Configure data sources
    │   └─► Add tiles and visualizations
    │
    ├─► Save Dashboard
    │
    ├─► Validate Creation
    │
    └─► Return Dashboard ID
```

## Playwright Automation Details

### Edge Browser Configuration

```json
{
  "browser": {
    "type": "msedge",
    "channel": "msedge",
    "headless": false,
    "args": [
      "--profile-directory=Profile 1"
    ],
    "ignoreDefaultArgs": false,
    "timeout": 30000
  }
}
```

### Key Automation Scenarios

#### Scenario 1: Navigate to Dashboard
```powershell
function Get-Dashboard {
    param([string]$DashboardId)
    
    # Navigate to dashboard
    $url = "https://dataexplorer.azure.com/dashboards/$DashboardId"
    Invoke-MCPTool -Server 'playwright' -Tool 'navigate' -Parameters @{ url = $url }
    
    # Wait for dashboard to load
    Invoke-MCPTool -Server 'playwright' -Tool 'wait_for' -Parameters @{
        selector = '.dashboard-container'
        state = 'visible'
    }
}
```

#### Scenario 2: Extract Dashboard Definition
```powershell
function Get-DashboardDefinition {
    # Execute JavaScript to extract dashboard JSON
    $script = @'
        return {
            id: window.dashboardId,
            name: window.dashboardName,
            definition: window.dashboardDefinition
        };
'@
    
    $result = Invoke-MCPTool -Server 'playwright' -Tool 'evaluate' -Parameters @{
        script = $script
    }
    
    return $result.Data
}
```

#### Scenario 3: Handle Authentication
```powershell
function Wait-ForAuthentication {
    # Check if on login page
    $isLoginPage = Invoke-MCPTool -Server 'playwright' -Tool 'evaluate' -Parameters @{
        script = "return window.location.href.includes('login.microsoftonline.com');"
    }
    
    if ($isLoginPage.Data) {
        Write-Host "Authentication required. Please sign in..."
        
        # Wait for authentication to complete
        Invoke-MCPTool -Server 'playwright' -Tool 'wait_for' -Parameters @{
            url = '*dataexplorer.azure.com*'
            timeout = 120000
        }
    }
}
```

## Configuration Schema

### Dashboard Definition Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "dashboard"],
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^[0-9]+\\.[0-9]+$"
    },
    "exported": {
      "type": "string",
      "format": "date-time"
    },
    "exportedBy": {
      "type": "string",
      "format": "email"
    },
    "dashboard": {
      "type": "object",
      "required": ["id", "name", "tiles"],
      "properties": {
        "id": {
          "type": "string",
          "format": "uuid"
        },
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 255
        },
        "description": {
          "type": "string"
        },
        "dataSource": {
          "type": "object",
          "required": ["clusterUri", "database"],
          "properties": {
            "clusterUri": {
              "type": "string",
              "format": "uri"
            },
            "database": {
              "type": "string"
            }
          }
        },
        "tiles": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["id", "title", "query"],
            "properties": {
              "id": {
                "type": "string"
              },
              "title": {
                "type": "string"
              },
              "query": {
                "type": "string"
              },
              "visualization": {
                "type": "string",
                "enum": ["table", "chart", "map", "card", "markdown"]
              }
            }
          }
        }
      }
    }
  }
}
```

## Definition of Done

### Implementation Criteria
- [x] Complete specification approved
- [ ] All modules implemented with tests
- [ ] Test coverage >90%
- [ ] Code review completed
- [ ] Documentation updated
- [ ] Performance targets met
- [ ] Security validation passed

### Quality Gates
- [ ] No critical PSScriptAnalyzer warnings
- [ ] All Pester tests passing
- [ ] Integration tests with real MCP servers passing
- [ ] Manual testing completed
- [ ] Security review completed

## Risk Assessment and Mitigation

### Technical Risks

**Risk**: Playwright MCP server instability  
**Probability**: Medium | **Impact**: High  
**Mitigation**: 
- Implement retry logic with exponential backoff
- Add fallback to direct Playwright library if MCP fails
- Comprehensive error handling and logging

**Risk**: Edge work profile authentication complexity  
**Probability**: High | **Impact**: High  
**Mitigation**:
- Implement robust authentication detection
- Provide clear user guidance for authentication
- Support manual authentication workflow
- Test with various work profile configurations

**Risk**: Dashboard schema changes over time  
**Probability**: Medium | **Impact**: Medium  
**Mitigation**:
- Version dashboard schema explicitly
- Implement schema validation with clear error messages
- Support multiple schema versions
- Document breaking changes

### Dependencies and Blockers

**Dependency**: MCP servers must be installed and configured  
**Owner**: Developer | **ETA**: Day 1  
**Status**: In progress

**Dependency**: Edge browser with work profile  
**Owner**: User/Administrator | **ETA**: Before first use  
**Status**: Required prerequisite

**Dependency**: Access to dataexplorer.azure.com  
**Owner**: Network/Security team | **ETA**: Before testing  
**Status**: Should be available

## Development Timeline

### Week 1: Foundation
- Day 1-2: Core infrastructure (Configuration, Logging, MCP Client)
- Day 3-4: Browser automation (Playwright integration)
- Day 5: Authentication management

### Week 2: Dashboard Operations
- Day 1-2: Export functionality
- Day 3-4: Import functionality
- Day 5: Validation and error handling

### Week 3: CLI and Testing
- Day 1-2: Command-line interface
- Day 3-4: Integration testing
- Day 5: Performance optimization

### Week 4: Polish and Documentation
- Day 1-2: Bug fixes and refinements
- Day 3: Documentation
- Day 4: Security review
- Day 5: Final validation and release preparation

## Next Steps

1. ✅ Complete specification and implementation plan
2. ✅ Configure MCP servers in VS Code
3. ⏭️ Create detailed task breakdown (tasks.md)
4. ⏭️ Begin Phase 1 implementation (Core infrastructure)
5. ⏭️ Write and run first tests (TDD Red phase)

---

**Status**: Ready for implementation  
**Last Updated**: 2025-10-08  
**Approved By**: [Pending]
