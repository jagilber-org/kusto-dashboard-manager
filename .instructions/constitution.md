# Kusto Dashboard Manager - Project Constitution

**Version**: 1.0.0  
**Status**: Active  
**Last Updated**: 2025-10-08

## Preamble

This constitution defines the immutable architectural principles for the Kusto Dashboard Manager project. These principles guide all design decisions and implementation patterns. Any changes to this constitution require review and approval from the project maintainers.

---

## Article I: PowerShell-First Principle

**All core functionality SHALL be implemented in PowerShell Core 7.4+**

### Rationale
- Native Windows automation capabilities
- Excellent module system for maintainability
- Strong community support and enterprise adoption
- First-class integration with Azure and Microsoft services

### Implementation Requirements
- Use PowerShell approved verbs (Get-, Set-, New-, Remove-, etc.)
- Follow PowerShell best practices and style guidelines
- Leverage PowerShell modules for code organization
- Implement proper parameter validation and help documentation

---

## Article II: MCP Integration Mandate

**All external service interactions SHALL utilize MCP (Model Context Protocol) servers**

### Rationale
- Standardized protocol for tool integration
- Enhanced security through controlled interfaces
- Better observability and debugging
- Separation of concerns between business logic and service integration

### MCP Server Requirements
- **Azure MCP Server**: For Kusto queries and Azure resource management
- **Playwright MCP Server**: For browser automation and dashboard interaction
- **PowerShell MCP Server**: For script validation and security analysis

### Integration Patterns
```powershell
# Use MCP tools instead of direct REST calls
$dashboards = Invoke-MCPTool -Server "azure" -Tool "kusto" -Query $kql

# Use Playwright MCP for browser automation
$result = Invoke-MCPTool -Server "playwright" -Tool "navigate" -Url $dashboardUrl
```

---

## Article III: Browser Automation Strategy

**Dashboard operations SHALL use Microsoft Edge with work profile authentication**

### Rationale
- Seamless authentication with organizational work profiles
- Native integration with Azure AD and Microsoft services
- Playwright MCP server provides controlled automation
- Security and compliance with enterprise policies

### Requirements
- Always specify Edge browser in Playwright configuration
- Use persistent authentication with work profiles
- Implement proper error handling for authentication failures
- Support headless mode for automated scenarios

---

## Article IV: Test-First Imperative

**No implementation code SHALL be written before comprehensive tests**

### Rationale
- Ensures specifications are testable and complete
- Reduces defects and improves code quality
- Provides living documentation through test scenarios
- Facilitates refactoring with confidence

### Testing Requirements
- Use Pester for all PowerShell testing
- Achieve minimum 90% code coverage
- Mock MCP server calls for unit tests
- Implement integration tests with real MCP servers
- Include error and edge case scenarios

---

## Article V: Configuration Externalization

**All configuration SHALL be externalized and environment-specific**

### Rationale
- Supports multiple environments (dev, staging, production)
- Prevents hardcoded credentials and secrets
- Enables easy configuration changes without code modification
- Improves security through separation of code and config

### Configuration Structure
```powershell
# Config files organized by environment
config/
├── default.json          # Default configuration
├── development.json      # Dev overrides
├── staging.json         # Staging overrides
└── production.json      # Production overrides
```

### Secret Management
- Use Azure Key Vault for production secrets
- Support .env files for local development
- Never commit secrets to source control
- Implement secret rotation policies

---

## Article VI: Error Transparency and Logging

**All errors SHALL provide detailed context and actionable information**

### Rationale
- Reduces debugging time
- Improves user experience
- Facilitates troubleshooting in production
- Provides audit trail for compliance

### Error Handling Patterns
```powershell
try {
    # Operation
}
catch {
    $errorContext = @{
        Operation = "ExportDashboard"
        DashboardId = $dashboardId
        Timestamp = Get-Date
        User = $env:USERNAME
        Error = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
    }
    
    Write-ErrorLog @errorContext
    throw "Dashboard export failed: $($_.Exception.Message). Check logs for details."
}
```

### Logging Requirements
- Use structured logging (JSON format)
- Include correlation IDs for tracing
- Log at appropriate levels (Debug, Info, Warning, Error)
- Implement log rotation and retention policies

---

## Article VII: Dependency Minimalism

**Prefer PowerShell built-in capabilities over external dependencies**

### Rationale
- Reduces attack surface
- Simplifies deployment and maintenance
- Improves reliability and performance
- Minimizes version conflicts

### Dependency Guidelines
- Use built-in cmdlets when available
- Evaluate necessity of each external module
- Pin module versions for reproducibility
- Document all dependencies with rationale

### Approved Dependencies
- **Pester**: Testing framework (industry standard)
- **PSScriptAnalyzer**: Code quality analysis
- MCP server clients (core requirement)

---

## Article VIII: Data Model Integrity

**Dashboard data models SHALL be versioned and validated**

### Rationale
- Ensures compatibility across versions
- Prevents data corruption
- Enables migration strategies
- Provides clear schema documentation

### Schema Requirements
- Define JSON schemas for all data models
- Validate all imported/exported data
- Support schema migration for backwards compatibility
- Document breaking changes explicitly

---

## Article IX: Security-First Design

**Security considerations SHALL be evaluated at every design decision**

### Security Requirements
- Validate all user inputs
- Sanitize all outputs (especially in web context)
- Use least-privilege principles
- Implement audit logging for sensitive operations
- Follow OWASP guidelines for web security

### Authentication Patterns
- Use managed identities when possible
- Support multi-factor authentication
- Implement token refresh for long-running operations
- Never log or persist credentials

---

## Article X: Spec-Driven Development

**All features SHALL begin as specifications before implementation**

### Rationale
- Ensures clear requirements before coding
- Facilitates stakeholder review and approval
- Provides living documentation
- Enables parallel implementation exploration

### Specification Requirements
- Create complete specification in `specs/` directory
- Define acceptance criteria for all features
- Include user stories and scenarios
- Document technical constraints and decisions

---

## Constitutional Enforcement

### Pre-Implementation Checklist

Before implementing any feature, validate:

- [ ] Specification complete and approved
- [ ] Tests written and failing (red phase)
- [ ] MCP integration points identified
- [ ] Configuration requirements documented
- [ ] Error handling strategy defined
- [ ] Security implications assessed
- [ ] Dependencies justified and approved
- [ ] Data models versioned and validated

### Code Review Gates

All code changes must:

- [ ] Follow PowerShell best practices
- [ ] Use MCP servers for external interactions
- [ ] Include comprehensive tests
- [ ] Pass all existing tests
- [ ] Meet code coverage requirements
- [ ] Include appropriate logging
- [ ] Update documentation
- [ ] Pass security analysis

---

## Amendment Process

This constitution may only be amended through:

1. Formal proposal with detailed rationale
2. Impact assessment on existing implementation
3. Review by project maintainers
4. Unanimous approval from core team
5. Version increment and change log update
6. Migration plan for affected code

---

## Acknowledgments

This constitution draws inspiration from:
- GitHub Spec-Kit methodology
- PowerShell best practices
- Microsoft secure development practices
- Model Context Protocol standards

---

**Adopted**: 2025-10-08  
**Effective**: Immediately  
**Review**: Quarterly
