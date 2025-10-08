# 🚀 Kusto Dashboard Manager - Quick Reference

## Project Status
✅ **Phase Complete**: Specification & Planning  
⏳ **Next Phase**: Implementation (Week 1)  
📅 **Created**: 2025-10-08  

---

## 📁 Key Files & Locations

### 📋 Must-Read Documents
| Document | Location | Purpose |
|----------|----------|---------|
| **Constitution** | `.instructions/constitution.md` | 10 immutable principles |
| **Project Instructions** | `.instructions/project-instructions.md` | Development guidelines |
| **Feature Spec** | `specs/001-dashboard-manager/spec.md` | Requirements & acceptance criteria |
| **Implementation Plan** | `specs/001-dashboard-manager/plan.md` | Technical architecture |
| **Task List** | `specs/001-dashboard-manager/tasks.md` | 26 implementation tasks |
| **Setup Summary** | `PROJECT_SETUP_SUMMARY.md` | Complete project overview |

### 🔧 Configuration Files
| File | Purpose |
|------|---------|
| `.vscode/settings.json` | MCP server configuration |
| `config/default.json` | Base application config |
| `config/development.json` | Dev environment overrides |
| `config/production.json` | Production settings |

### 🛠️ Scripts
| Script | Purpose |
|--------|---------|
| `scripts/Install-Dependencies.ps1` | Install all dependencies |
| `scripts/Test-Environment.ps1` | Validate setup |
| `src/KustoDashboardManager.ps1` | Main application entry point |

---

## 🎯 Quick Start

### 1. Initial Setup (Do This First)
```powershell
# Install dependencies
.\scripts\Install-Dependencies.ps1

# Validate environment
.\scripts\Test-Environment.ps1

# Update MCP server paths in .vscode/settings.json
code .vscode\settings.json
```

### 2. Configure MCP Servers
Edit `.vscode/settings.json` and update:
- Playwright MCP Server path
- Azure MCP Server credentials
- PowerShell MCP Server path

### 3. Test MCP Integration
```powershell
# Open VS Code in this workspace
code .

# Verify MCP servers are connected in VS Code
# Test basic MCP tool calls
```

---

## 🏗️ Project Architecture

```
Kusto Dashboard Manager
├── PowerShell 7.4+ Console App
├── Playwright MCP (Edge browser automation)
├── Azure MCP (Kusto integration)
└── Work Profile Authentication (Edge)
```

### Core Modules (To Be Implemented)
```
src/modules/
├── Core/           Configuration & Logging
├── Authentication/ Edge work profile auth
├── Dashboard/      Export & Import operations
├── Playwright/     Browser automation
└── MCP/           MCP server client
```

---

## 📝 Development Workflow

### Spec-Driven Development Process
```
1. Review Specification
   └── specs/001-dashboard-manager/spec.md

2. Review Implementation Plan
   └── specs/001-dashboard-manager/plan.md

3. Review Task List
   └── specs/001-dashboard-manager/tasks.md

4. For Each Task:
   ├── Write Tests FIRST (Red Phase)
   ├── Implement Code (Green Phase)
   └── Refactor (Refactor Phase)

5. Validate Against Specs
```

---

## 🧪 Test-Driven Development

### TDD Cycle
```powershell
# 1. RED - Write failing test
Describe "Export-KustoDashboard" {
    It "Should create output file" {
        # Test that FAILS
    }
}

# 2. GREEN - Implement minimum code
function Export-KustoDashboard { 
    # Code to make test PASS
}

# 3. REFACTOR - Improve code
function Export-KustoDashboard { 
    # Better implementation
}
```

---

## 📊 Task Overview

### Phase 1: Foundation (Week 1)
- [ ] Task 1.1: Core Module Setup (4h)
- [ ] Task 1.2: Logging Module (4h)
- [ ] Task 1.3: MCP Client Module (6h)
- [ ] Task 1.4: Configuration Files (2h)

### Phase 2: Browser Automation (Week 1-2)
- [ ] Task 2.1: Browser Manager Module (6h)
- [ ] Task 2.2: Navigation Helpers (4h)
- [ ] Task 2.3: Authentication Module (6h)

### Phase 3: Dashboard Operations (Week 2)
- [ ] Task 3.1: Dashboard Export Core (8h)
- [ ] Task 3.2: Dashboard Validation (4h)
- [ ] Task 3.3: Dashboard Import Core (10h)

### Phase 4: CLI & UI (Week 3)
- [ ] Task 4.1: Main Entry Point (6h)
- [ ] Task 4.2: Batch Export (4h)
- [ ] Task 4.3: Batch Import (4h)
- [ ] Task 4.4: Interactive Menu (4h)

### Phase 5: Testing & Polish (Week 3-4)
- [ ] Task 5.1: Integration Testing (8h)
- [ ] Task 5.2: Error Scenarios (4h)
- [ ] Task 5.3: Performance Optimization (4h)
- [ ] Task 5.4: Documentation (6h)
- [ ] Task 5.5: Security Review (4h)

### Phase 6: Deployment (Week 4)
- [ ] Task 6.1: Installation Scripts (3h)
- [ ] Task 6.2: Release Packaging (2h)

**Total**: 26 tasks, 100-120 hours, 3-4 weeks

---

## 🎓 Key Commands

### Development
```powershell
# Run main application
.\src\KustoDashboardManager.ps1

# Export dashboard
.\src\KustoDashboardManager.ps1 -Action Export -DashboardId "guid" -OutputPath ".\exports"

# Import dashboard
.\src\KustoDashboardManager.ps1 -Action Import -DefinitionPath ".\dashboard.json"

# Run tests
Invoke-Pester -Path .\tests -Output Detailed

# Code analysis
Invoke-ScriptAnalyzer -Path .\src -Recurse
```

---

## 🔐 Security Checklist

✅ Never commit secrets to source control  
✅ Use Edge work profile for authentication  
✅ Validate all inputs  
✅ Sanitize all outputs  
✅ Follow OWASP guidelines  
✅ Run PSScriptAnalyzer security checks  

---

## 📚 Documentation Index

| Topic | Document |
|-------|----------|
| Constitutional Principles | `.instructions/constitution.md` |
| Development Guidelines | `.instructions/project-instructions.md` |
| User Stories & Requirements | `specs/001-dashboard-manager/spec.md` |
| Technical Architecture | `specs/001-dashboard-manager/plan.md` |
| Data Models & Schemas | `specs/001-dashboard-manager/data-model.md` |
| Implementation Tasks | `specs/001-dashboard-manager/tasks.md` |
| MCP Index Server Usage | `docs/MCP_INDEX_SERVER_USAGE.md` |
| Project Overview | `PROJECT_SETUP_SUMMARY.md` |

---

## 🎯 Success Criteria

- [ ] Export dashboards (<30 sec/dashboard)
- [ ] Import dashboards (<45 sec/dashboard)
- [ ] Batch operations work
- [ ] Edge work profile auth works
- [ ] Test coverage >90%
- [ ] All constitutional principles followed
- [ ] Comprehensive documentation

---

## 💡 Tips & Best Practices

### Development
- ✅ Always write tests BEFORE implementation
- ✅ Follow PowerShell approved verbs
- ✅ Use MCP servers for all external interactions
- ✅ Implement structured logging
- ✅ Handle all error scenarios

### Testing
- ✅ Aim for >90% code coverage
- ✅ Mock MCP calls in unit tests
- ✅ Use real MCP servers in integration tests
- ✅ Test error paths thoroughly

### MCP Integration
- ✅ Always use MCP tools, not direct REST calls
- ✅ Implement retry logic with exponential backoff
- ✅ Log all MCP interactions
- ✅ Handle MCP server failures gracefully

---

## 🆘 Getting Help

### Documentation
- Read the constitution: `.instructions/constitution.md`
- Check project instructions: `.instructions/project-instructions.md`
- Review specifications: `specs/001-dashboard-manager/`

### Troubleshooting
- Run environment test: `.\scripts\Test-Environment.ps1`
- Check logs: `.\logs\`
- Review error messages carefully

### Resources
- GitHub Spec-Kit: https://github.com/github/spec-kit
- MCP Protocol: https://modelcontextprotocol.io/
- PowerShell Docs: https://docs.microsoft.com/powershell/

---

## 📈 Progress Tracking

**Completed**: ✅✅✅✅✅✅✅✅ (8/12 high-level tasks)

- ✅ Initialize Project Structure
- ✅ Create Project Constitution
- ✅ Write Feature Specification
- ✅ Configure MCP Servers
- ✅ Design Implementation Plan
- ✅ Define Data Models
- ✅ Create Task Breakdown
- ✅ Setup Playwright Configuration
- ⏳ Implement Core Console App
- ⏳ Implement Dashboard Export
- ⏳ Implement Dashboard Import
- ⏳ Add Test Suite

**Next Action**: Begin Task 1.1 (Core Module Setup)

---

**Last Updated**: 2025-10-08  
**Project Status**: 🟢 Ready for Implementation
