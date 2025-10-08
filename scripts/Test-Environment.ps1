<#
.SYNOPSIS
    Test the environment for Kusto Dashboard Manager

.DESCRIPTION
    Validates that all prerequisites are installed and configured correctly.

.EXAMPLE
    .\Test-Environment.ps1

.NOTES
    Version: 1.0.0
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "Kusto Dashboard Manager - Environment Test" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

$allTestsPassed = $true

# Test 1: PowerShell Version
Write-Host "[TEST] PowerShell Version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7 -and $psVersion.Minor -ge 4) {
    Write-Host "  ✓ PASS: PowerShell $psVersion" -ForegroundColor Green
}
else {
    Write-Host "  ✗ FAIL: PowerShell 7.4+ required. Current: $psVersion" -ForegroundColor Red
    $allTestsPassed = $false
}

# Test 2: Required Modules
Write-Host "`n[TEST] Required PowerShell Modules..." -ForegroundColor Yellow

$requiredModules = @(
    @{ Name = 'Pester'; MinVersion = [version]'5.0.0' }
    @{ Name = 'PSScriptAnalyzer'; MinVersion = [version]'1.0.0' }
)

foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module.Name | Where-Object { $_.Version -ge $module.MinVersion }
    if ($installed) {
        Write-Host "  ✓ PASS: $($module.Name) $($installed[0].Version)" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ FAIL: $($module.Name) $($module.MinVersion)+ not found" -ForegroundColor Red
        $allTestsPassed = $false
    }
}

# Test 3: Microsoft Edge
Write-Host "`n[TEST] Microsoft Edge..." -ForegroundColor Yellow
$edgePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edgeFound = $false
foreach ($path in $edgePaths) {
    if (Test-Path $path) {
        Write-Host "  ✓ PASS: Edge found at $path" -ForegroundColor Green
        $edgeFound = $true
        break
    }
}
if (-not $edgeFound) {
    Write-Host "  ✗ FAIL: Microsoft Edge not found" -ForegroundColor Red
    $allTestsPassed = $false
}

# Test 4: Node.js
Write-Host "`n[TEST] Node.js (for Playwright MCP)..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Host "  ✓ PASS: Node.js $nodeVersion" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ FAIL: Node.js not found or not in PATH" -ForegroundColor Red
        $allTestsPassed = $false
    }
}
catch {
    Write-Host "  ✗ FAIL: Node.js not found" -ForegroundColor Red
    $allTestsPassed = $false
}

# Test 5: Project Structure
Write-Host "`n[TEST] Project Directory Structure..." -ForegroundColor Yellow
$requiredDirs = @(
    '.\src',
    '.\config',
    '.\specs',
    '.\tests',
    '.\.instructions'
)

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Host "  ✓ PASS: $dir exists" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ FAIL: $dir not found" -ForegroundColor Red
        $allTestsPassed = $false
    }
}

# Test 6: Configuration Files
Write-Host "`n[TEST] Configuration Files..." -ForegroundColor Yellow
$configFiles = @(
    '.\config\default.json',
    '.\.vscode\settings.json'
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ PASS: $file exists" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠ WARN: $file not found" -ForegroundColor Yellow
    }
}

# Test 7: Network Connectivity
Write-Host "`n[TEST] Network Connectivity..." -ForegroundColor Yellow
try {
    $response = Test-NetConnection -ComputerName dataexplorer.azure.com -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($response) {
        Write-Host "  ✓ PASS: Can reach dataexplorer.azure.com:443" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ FAIL: Cannot reach dataexplorer.azure.com:443" -ForegroundColor Red
        $allTestsPassed = $false
    }
}
catch {
    Write-Host "  ✗ FAIL: Network test failed: $($_.Exception.Message)" -ForegroundColor Red
    $allTestsPassed = $false
}

# Summary
Write-Host "`n===========================================" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "Environment Test: ALL TESTS PASSED ✓" -ForegroundColor Green
    Write-Host "Your environment is ready for development!" -ForegroundColor Green
}
else {
    Write-Host "Environment Test: SOME TESTS FAILED ✗" -ForegroundColor Red
    Write-Host "Please fix the failed tests before proceeding." -ForegroundColor Yellow
}
Write-Host "===========================================`n" -ForegroundColor Cyan

if (-not $allTestsPassed) {
    exit 1
}
