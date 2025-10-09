<#
.SYNOPSIS
    Manual smoke tests for Kusto Dashboard Manager
    
.DESCRIPTION
    These are manual smoke tests that should be run with a real Playwright MCP server
    and actual browser to verify end-to-end functionality.
    
    PREREQUISITES:
    1. Playwright MCP server must be running
    2. Microsoft Edge must be installed
    3. You must have access to a test Kusto dashboard
    
.PARAMETER DashboardUrl
    The URL of a test dashboard to use for smoke testing
    
.PARAMETER SkipBrowserTests
    Skip tests that require browser automation
    
.EXAMPLE
    .\SmokeTests.ps1 -DashboardUrl "https://dataexplorer.azure.com/dashboards/your-test-dashboard"
    
.EXAMPLE
    .\SmokeTests.ps1 -SkipBrowserTests
    Run only non-browser tests
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$DashboardUrl,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBrowserTests
)

$ErrorActionPreference = 'Continue'
$script:PassedTests = 0
$script:FailedTests = 0
$script:SkippedTests = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        if ($Message) {
            Write-Host "  └─ $Message" -ForegroundColor Gray
        }
        $script:PassedTests++
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "  └─ $Message" -ForegroundColor Yellow
        }
        $script:FailedTests++
    }
}

function Write-TestSkipped {
    param([string]$TestName, [string]$Reason)
    Write-Host "⊘ SKIP: $TestName - $Reason" -ForegroundColor Yellow
    $script:SkippedTests++
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Kusto Dashboard Manager - Smoke Tests                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get script paths
$scriptRoot = $PSScriptRoot
$rootPath = Join-Path $scriptRoot ".." ".."
$srcPath = Join-Path $rootPath "src"
$modulesPath = Join-Path $srcPath "modules"
$testDataPath = Join-Path $scriptRoot "test-data"

# Test 1: Module Loading
Write-Host "`n[1/10] Testing Module Loading..." -ForegroundColor Cyan
try {
    Import-Module (Join-Path $modulesPath "Core\Configuration.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesPath "Core\Logging.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesPath "Core\MCPClient.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesPath "Browser\BrowserManager.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesPath "Dashboard\Export-KustoDashboard.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $modulesPath "Dashboard\Import-KustoDashboard.psm1") -Force -ErrorAction Stop
    Write-TestResult "All modules loaded successfully" $true "6 modules imported"
}
catch {
    Write-TestResult "Module loading" $false $_.Exception.Message
}

# Test 2: Configuration Module
Write-Host "`n[2/10] Testing Configuration Module..." -ForegroundColor Cyan
try {
    $configPath = Join-Path $rootPath "config\development.json"
    $config = Get-Configuration -ConfigPath $configPath -ErrorAction Stop
    Write-TestResult "Configuration loading" $true "Loaded from $configPath"
}
catch {
    Write-TestResult "Configuration loading" $false $_.Exception.Message
}

# Test 3: Logging Module
Write-Host "`n[3/10] Testing Logging Module..." -ForegroundColor Cyan
try {
    $logPath = Join-Path $env:TEMP "kusto-dashboard-smoke-test.log"
    Initialize-Logging -LogFilePath $logPath -MinLogLevel "INFO"
    Write-AppLog -Level INFO -Message "Smoke test started" -Properties @{ Test = "Smoke" }
    
    if (Test-Path $logPath) {
        $logContent = Get-Content $logPath -Raw
        if ($logContent -match "Smoke test started") {
            Write-TestResult "Logging functionality" $true "Log file: $logPath"
        }
        else {
            Write-TestResult "Logging functionality" $false "Log entry not found in file"
        }
    }
    else {
        Write-TestResult "Logging functionality" $false "Log file not created"
    }
}
catch {
    Write-TestResult "Logging functionality" $false $_.Exception.Message
}

# Test 4: MCP Client Initialization
Write-Host "`n[4/10] Testing MCP Client Initialization..." -ForegroundColor Cyan
try {
    Initialize-MCPClient -ServerName "playwright"
    Write-TestResult "MCP client initialization" $true
}
catch {
    Write-TestResult "MCP client initialization" $false $_.Exception.Message
}

# Test 5: MCP Connection Test
Write-Host "`n[5/10] Testing MCP Server Connection..." -ForegroundColor Cyan
try {
    $connectionResult = Test-MCPConnection -ServerName "playwright"
    if ($connectionResult.Connected) {
        Write-TestResult "MCP server connectivity" $true "Server is reachable"
    }
    else {
        Write-TestResult "MCP server connectivity" $false "Server not responding (is Playwright MCP running?)"
    }
}
catch {
    Write-TestResult "MCP server connectivity" $false $_.Exception.Message
}

# Test 6: CLI Script Validation
Write-Host "`n[6/10] Testing CLI Script..." -ForegroundColor Cyan
try {
    $cliPath = Join-Path $srcPath "KustoDashboardManager.ps1"
    if (Test-Path $cliPath) {
        # Test syntax
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $cliPath -Raw), [ref]$errors)
        
        if ($errors.Count -eq 0) {
            Write-TestResult "CLI script syntax" $true "No syntax errors"
        }
        else {
            Write-TestResult "CLI script syntax" $false "$($errors.Count) syntax errors found"
        }
    }
    else {
        Write-TestResult "CLI script existence" $false "Script not found at $cliPath"
    }
}
catch {
    Write-TestResult "CLI script validation" $false $_.Exception.Message
}

# Test 7: JSON Validation
Write-Host "`n[7/10] Testing JSON Validation..." -ForegroundColor Cyan
try {
    # Create test data directory
    if (-not (Test-Path $testDataPath)) {
        New-Item -Path $testDataPath -ItemType Directory -Force | Out-Null
    }
    
    # Create valid test JSON
    $validJsonPath = Join-Path $testDataPath "valid-dashboard.json"
    @{
        DashboardName = "Smoke Test Dashboard"
        Description = "Test dashboard"
        Tiles = @(
            @{ TileName = "Test"; Query = ".show databases"; VisualizationType = "table" }
        )
    } | ConvertTo-Json -Depth 10 | Out-File $validJsonPath -Encoding UTF8
    
    # Test with CLI
    $cliPath = Join-Path $srcPath "KustoDashboardManager.ps1"
    $validateResult = & $cliPath -Action Validate -InputPath $validJsonPath 2>&1
    
    if ($validateResult -match "Validation passed") {
        Write-TestResult "JSON validation" $true "Valid dashboard JSON accepted"
    }
    else {
        Write-TestResult "JSON validation" $false "Validation did not pass as expected"
    }
}
catch {
    Write-TestResult "JSON validation" $false $_.Exception.Message
}

# Test 8: Browser Initialization (Optional)
Write-Host "`n[8/10] Testing Browser Initialization..." -ForegroundColor Cyan
if ($SkipBrowserTests) {
    Write-TestSkipped "Browser initialization" "SkipBrowserTests flag set"
}
else {
    try {
        $browserResult = Initialize-Browser -Browser "edge" -Headless $true -ErrorAction Stop
        if ($browserResult) {
            Write-TestResult "Browser initialization" $true "Edge browser initialized in headless mode"
            
            # Cleanup
            Close-Browser
        }
        else {
            Write-TestResult "Browser initialization" $false "Failed to initialize browser"
        }
    }
    catch {
        Write-TestResult "Browser initialization" $false $_.Exception.Message
    }
}

# Test 9: Export Workflow (Optional)
Write-Host "`n[9/10] Testing Export Workflow..." -ForegroundColor Cyan
if ($SkipBrowserTests) {
    Write-TestSkipped "Export workflow" "SkipBrowserTests flag set"
}
elseif (-not $DashboardUrl) {
    Write-TestSkipped "Export workflow" "DashboardUrl not provided"
}
else {
    try {
        $exportPath = Join-Path $testDataPath "exported-dashboard.json"
        $exportResult = Export-KustoDashboard -DashboardUrl $DashboardUrl -OutputPath $exportPath -Headless $true -ErrorAction Stop
        
        if ($exportResult.Success -and (Test-Path $exportPath)) {
            Write-TestResult "Export workflow" $true "Dashboard exported to $exportPath"
        }
        else {
            Write-TestResult "Export workflow" $false $exportResult.Error
        }
    }
    catch {
        Write-TestResult "Export workflow" $false $_.Exception.Message
    }
}

# Test 10: Import Workflow (Optional)
Write-Host "`n[10/10] Testing Import Workflow..." -ForegroundColor Cyan
if ($SkipBrowserTests) {
    Write-TestSkipped "Import workflow" "SkipBrowserTests flag set"
}
elseif (-not $DashboardUrl) {
    Write-TestSkipped "Import workflow" "DashboardUrl not provided"
}
else {
    try {
        $importPath = Join-Path $testDataPath "valid-dashboard.json"
        $importResult = Import-KustoDashboard -DashboardUrl $DashboardUrl -InputPath $importPath -Headless $true -Force $true -ErrorAction Stop
        
        if ($importResult.Success) {
            Write-TestResult "Import workflow" $true "Dashboard imported successfully"
        }
        else {
            Write-TestResult "Import workflow" $false $importResult.Error
        }
    }
    catch {
        Write-TestResult "Import workflow" $false $_.Exception.Message
    }
}

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    SMOKE TEST SUMMARY                      ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Tests:   " -NoNewline; Write-Host ($script:PassedTests + $script:FailedTests + $script:SkippedTests) -ForegroundColor Cyan
Write-Host "  Passed:        " -NoNewline; Write-Host $script:PassedTests -ForegroundColor Green
Write-Host "  Failed:        " -NoNewline; Write-Host $script:FailedTests -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "  Skipped:       " -NoNewline; Write-Host $script:SkippedTests -ForegroundColor Yellow
Write-Host ""

if ($script:FailedTests -eq 0) {
    Write-Host "✓ All smoke tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some smoke tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
}
