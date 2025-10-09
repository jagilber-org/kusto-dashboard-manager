<#
.SYNOPSIS
    Integration tests for Kusto Dashboard Manager
    
.DESCRIPTION
    End-to-end integration tests using real MCP servers and browser automation.
    These tests require:
    - Playwright MCP server running
    - Microsoft Edge installed
    - Valid dashboard URL (or mock server)
    
.NOTES
    Run these tests with: Invoke-Pester -Path .\tests\Integration\IntegrationTests.Tests.ps1
#>

BeforeAll {
    # Import all modules
    $script:RootPath = Join-Path $PSScriptRoot ".." ".."
    $script:SrcPath = Join-Path $script:RootPath "src"
    $script:ModulesPath = Join-Path $script:SrcPath "modules"
    
    Import-Module (Join-Path $script:ModulesPath "Core\Configuration.psm1") -Force -Global
    Import-Module (Join-Path $script:ModulesPath "Core\Logging.psm1") -Force -Global
    Import-Module (Join-Path $script:ModulesPath "Core\MCPClient.psm1") -Force -Global
    Import-Module (Join-Path $script:ModulesPath "Browser\BrowserManager.psm1") -Force -Global
    Import-Module (Join-Path $script:ModulesPath "Dashboard\Export-KustoDashboard.psm1") -Force -Global
    Import-Module (Join-Path $script:ModulesPath "Dashboard\Import-KustoDashboard.psm1") -Force -Global
    
    # Test configuration
    $script:TestDashboardUrl = "https://dataexplorer.azure.com/dashboards/test-dashboard"
    $script:TestExportPath = Join-Path $TestDrive "exported-dashboard.json"
    $script:TestImportPath = Join-Path $TestDrive "import-dashboard.json"
    
    # Create sample dashboard JSON for import tests
    $script:SampleDashboard = @{
        DashboardName = "Integration Test Dashboard"
        Description = "Dashboard for integration testing"
        Tiles = @(
            @{
                TileName = "Test Query"
                Query = ".show databases"
                VisualizationType = "table"
            }
        )
        Parameters = @()
        Tags = @("test", "integration")
    }
    
    $script:SampleDashboard | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:TestImportPath -Encoding UTF8
}

Describe "Integration Tests - Module Loading" {
    It "Should load all required modules without errors" {
        { Get-Command -Name "Get-Configuration" -ErrorAction Stop } | Should -Not -Throw
        { Get-Command -Name "Write-AppLog" -ErrorAction Stop } | Should -Not -Throw
        { Get-Command -Name "Initialize-MCPClient" -ErrorAction Stop } | Should -Not -Throw
        { Get-Command -Name "Initialize-Browser" -ErrorAction Stop } | Should -Not -Throw
        { Get-Command -Name "Export-KustoDashboard" -ErrorAction Stop } | Should -Not -Throw
        { Get-Command -Name "Import-KustoDashboard" -ErrorAction Stop } | Should -Not -Throw
    }
    
    It "Should have all modules available in PSModuleInfo" {
        $modules = Get-Module | Where-Object { $_.Name -match "Configuration|Logging|MCPClient|BrowserManager|Export-KustoDashboard|Import-KustoDashboard" }
        $modules.Count | Should -BeGreaterOrEqual 6
    }
}

Describe "Integration Tests - Configuration" {
    It "Should load configuration from default paths" {
        $config = Get-Configuration -ConfigPath (Join-Path $script:RootPath "config\development.json")
        $config | Should -Not -BeNullOrEmpty
    }
    
    It "Should merge environment-specific configurations" {
        $base = @{ Setting1 = "base"; Setting2 = "base" }
        $override = @{ Setting2 = "override"; Setting3 = "new" }
        
        $result = Merge-Configuration -BaseConfig $base -OverrideConfig $override
        
        $result.Setting1 | Should -Be "base"
        $result.Setting2 | Should -Be "override"
        $result.Setting3 | Should -Be "new"
    }
}

Describe "Integration Tests - Logging" {
    It "Should initialize logging with valid path" {
        $logPath = Join-Path $TestDrive "integration.log"
        
        { Initialize-Logging -LogFilePath $logPath -MinLogLevel "INFO" } | Should -Not -Throw
    }
    
    It "Should write log entries to file" {
        $logPath = Join-Path $TestDrive "test.log"
        Initialize-Logging -LogFilePath $logPath -MinLogLevel "INFO"
        
        Write-AppLog -Level INFO -Message "Integration test log entry" -Properties @{ Test = "Integration" }
        
        Test-Path $logPath | Should -Be $true
        $logContent = Get-Content $logPath -Raw
        $logContent | Should -Match "Integration test log entry"
    }
}

Describe "Integration Tests - MCP Client" {
    It "Should initialize MCP client with default configuration" {
        { Initialize-MCPClient -ServerName "playwright" } | Should -Not -Throw
    }
    
    It "Should test MCP connection (may fail if server not running)" {
        # This test will fail if Playwright MCP server is not running
        # That's expected in CI/CD environments
        $result = Test-MCPConnection -ServerName "playwright"
        
        # Just verify we get a result object
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "Connected"
    }
}

Describe "Integration Tests - Browser Manager" -Tag "RequiresMCP" {
    BeforeAll {
        # Initialize MCP client for browser tests
        Initialize-MCPClient -ServerName "playwright"
    }
    
    AfterEach {
        # Cleanup browser after each test
        try {
            Close-Browser -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
    }
    
    It "Should initialize browser with Edge" -Skip {
        # Skip by default - requires MCP server running
        { Initialize-Browser -Browser "edge" -Headless $true } | Should -Not -Throw
    }
    
    It "Should navigate to URL" -Skip {
        # Skip by default - requires MCP server running
        Initialize-Browser -Browser "edge" -Headless $true
        
        { Invoke-BrowserAction -Action "Navigate" -Url "https://www.example.com" } | Should -Not -Throw
    }
    
    It "Should get browser state" -Skip {
        # Skip by default - requires MCP server running
        Initialize-Browser -Browser "edge" -Headless $true
        
        $state = Get-BrowserState
        $state.IsInitialized | Should -Be $true
        $state.Browser | Should -Be "edge"
    }
}

Describe "Integration Tests - Dashboard Export" -Tag "RequiresMCP" {
    AfterEach {
        # Cleanup browser after each test
        try {
            Close-Browser -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
    }
    
    It "Should validate export parameters" {
        { Export-KustoDashboard -DashboardUrl "" -OutputPath $script:TestExportPath } | 
            Should -Throw "*valid URL*"
    }
    
    It "Should create output directory if it doesn't exist" {
        $outputPath = Join-Path $TestDrive "subdir\dashboard.json"
        
        # This will fail at browser init (expected without MCP), but should create directory
        try {
            Export-KustoDashboard -DashboardUrl $script:TestDashboardUrl -OutputPath $outputPath -Headless $true
        } catch {
            # Expected to fail without MCP server
        }
        
        # Verify directory was created
        Test-Path (Split-Path $outputPath -Parent) | Should -Be $true
    }
    
    It "Should return structured result object" {
        # Mock the browser initialization to test return value structure
        Mock Initialize-Browser { return $true } -ModuleName "Export-KustoDashboard"
        Mock Invoke-BrowserAction { 
            if ($Action -eq "GetText") { 
                return '{"DashboardName":"Test","Tiles":[]}' 
            }
        } -ModuleName "Export-KustoDashboard"
        Mock Close-Browser { } -ModuleName "Export-KustoDashboard"
        
        $result = Export-KustoDashboard -DashboardUrl $script:TestDashboardUrl -OutputPath $script:TestExportPath
        
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "Success"
        $result.PSObject.Properties.Name | Should -Contain "OutputPath"
    }
}

Describe "Integration Tests - Dashboard Import" -Tag "RequiresMCP" {
    AfterEach {
        # Cleanup browser after each test
        try {
            Close-Browser -ErrorAction SilentlyContinue
        } catch {
            # Ignore cleanup errors
        }
    }
    
    It "Should validate import parameters" {
        { Import-KustoDashboard -DashboardUrl "" -InputPath $script:TestImportPath } | 
            Should -Throw "*valid URL*"
    }
    
    It "Should validate input file exists" {
        $nonExistentPath = Join-Path $TestDrive "nonexistent.json"
        
        { Import-KustoDashboard -DashboardUrl $script:TestDashboardUrl -InputPath $nonExistentPath } | 
            Should -Throw "*not found*"
    }
    
    It "Should validate JSON structure" {
        $invalidJsonPath = Join-Path $TestDrive "invalid.json"
        @{ InvalidField = "value" } | ConvertTo-Json | Out-File $invalidJsonPath -Encoding UTF8
        
        { Import-KustoDashboard -DashboardUrl $script:TestDashboardUrl -InputPath $invalidJsonPath } | 
            Should -Throw "*DashboardName*"
    }
    
    It "Should parse valid JSON file" {
        # Should not throw during JSON parsing
        { 
            Mock Initialize-Browser { throw "Expected - testing JSON parsing only" } -ModuleName "Import-KustoDashboard"
            Import-KustoDashboard -DashboardUrl $script:TestDashboardUrl -InputPath $script:TestImportPath -ErrorAction Stop
        } | Should -Throw "*Expected - testing JSON parsing only*"
    }
    
    It "Should return structured result object" {
        # Mock the browser initialization to test return value structure
        Mock Initialize-Browser { return $true } -ModuleName "Import-KustoDashboard"
        Mock Invoke-BrowserAction { } -ModuleName "Import-KustoDashboard"
        Mock Close-Browser { } -ModuleName "Import-KustoDashboard"
        
        $result = Import-KustoDashboard -DashboardUrl $script:TestDashboardUrl -InputPath $script:TestImportPath
        
        $result | Should -Not -BeNullOrEmpty
        $result.PSObject.Properties.Name | Should -Contain "Success"
        $result.PSObject.Properties.Name | Should -Contain "DashboardName"
    }
}

Describe "Integration Tests - CLI Entry Point" {
    It "Should load CLI script without errors" {
        $cliPath = Join-Path $script:SrcPath "KustoDashboardManager.ps1"
        Test-Path $cliPath | Should -Be $true
        
        # Parse script to verify syntax
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $cliPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
    }
    
    It "Should show usage when Action is missing" {
        $cliPath = Join-Path $script:SrcPath "KustoDashboardManager.ps1"
        
        # This should exit with code 1 and show usage
        $result = & $cliPath -ErrorAction SilentlyContinue 2>&1
        $result -join "`n" | Should -Match "Usage examples"
    }
}

Describe "Integration Tests - End-to-End Workflow Validation" {
    It "Should have all components needed for export workflow" {
        # Verify all required commands exist
        Get-Command "Initialize-Browser" | Should -Not -BeNullOrEmpty
        Get-Command "Invoke-BrowserAction" | Should -Not -BeNullOrEmpty
        Get-Command "Export-KustoDashboard" | Should -Not -BeNullOrEmpty
        Get-Command "Close-Browser" | Should -Not -BeNullOrEmpty
    }
    
    It "Should have all components needed for import workflow" {
        # Verify all required commands exist
        Get-Command "Initialize-Browser" | Should -Not -BeNullOrEmpty
        Get-Command "Invoke-BrowserAction" | Should -Not -BeNullOrEmpty
        Get-Command "Import-KustoDashboard" | Should -Not -BeNullOrEmpty
        Get-Command "Close-Browser" | Should -Not -BeNullOrEmpty
    }
    
    It "Should have logging integrated in all workflows" {
        Get-Command "Write-AppLog" | Should -Not -BeNullOrEmpty
        Get-Command "Initialize-Logging" | Should -Not -BeNullOrEmpty
    }
}

Describe "Integration Tests - Error Handling" {
    It "Should handle missing MCP server gracefully in Export" {
        $result = Export-KustoDashboard -DashboardUrl $script:TestDashboardUrl -OutputPath $script:TestExportPath -ErrorAction SilentlyContinue
        
        # Should return a result object with Success = $false
        $result | Should -Not -BeNullOrEmpty
        $result.Success | Should -Be $false
        $result.Error | Should -Not -BeNullOrEmpty
    }
    
    It "Should handle missing MCP server gracefully in Import" {
        $result = Import-KustoDashboard -DashboardUrl $script:TestDashboardUrl -InputPath $script:TestImportPath -ErrorAction SilentlyContinue
        
        # Should return a result object with Success = $false
        $result | Should -Not -BeNullOrEmpty
        $result.Success | Should -Be $false
        $result.Error | Should -Not -BeNullOrEmpty
    }
    
    It "Should cleanup browser resources on error" {
        # Verify Close-Browser is called in finally block
        Mock Initialize-Browser { throw "Test error" } -ModuleName "Export-KustoDashboard"
        Mock Close-Browser { } -ModuleName "Export-KustoDashboard"
        
        Export-KustoDashboard -DashboardUrl $script:TestDashboardUrl -OutputPath $script:TestExportPath -ErrorAction SilentlyContinue
        
        Should -Invoke -CommandName Close-Browser -ModuleName "Export-KustoDashboard" -Times 1
    }
}

Describe "Integration Tests - Performance" {
    It "Should initialize modules quickly" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        Import-Module (Join-Path $script:ModulesPath "Core\Configuration.psm1") -Force
        
        $stopwatch.Stop()
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
    }
    
    It "Should handle concurrent module access" {
        # Verify modules can be accessed concurrently
        $jobs = 1..3 | ForEach-Object {
            Start-Job -ScriptBlock {
                param($ModulesPath)
                Import-Module (Join-Path $ModulesPath "Core\Configuration.psm1") -Force
                Get-Configuration -ConfigPath "C:\test\config.json" -ErrorAction SilentlyContinue
            } -ArgumentList $script:ModulesPath
        }
        
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        
        # Should not throw errors
        $results | Should -Not -BeNullOrEmpty
    }
}
