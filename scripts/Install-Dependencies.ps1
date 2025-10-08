<#
.SYNOPSIS
    Install dependencies for Kusto Dashboard Manager

.DESCRIPTION
    Installs and configures all required dependencies including PowerShell modules,
    Node.js packages, and validates the environment.

.EXAMPLE
    .\Install-Dependencies.ps1

.NOTES
    Version: 1.0.0
    Requires: PowerShell 7.4+, Administrator privileges (for some installations)
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "Kusto Dashboard Manager - Dependency Installation" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# Check PowerShell version
Write-Host "Checking PowerShell version..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 7 -or ($psVersion.Major -eq 7 -and $psVersion.Minor -lt 4)) {
    Write-Error "PowerShell 7.4 or higher is required. Current version: $psVersion"
    exit 1
}
Write-Host "✓ PowerShell $psVersion" -ForegroundColor Green

# Check for Pester
Write-Host "`nChecking Pester..." -ForegroundColor Yellow
$pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version.Major -ge 5 }
if (-not $pester) {
    Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck
    Write-Host "✓ Pester installed" -ForegroundColor Green
}
else {
    Write-Host "✓ Pester $($pester.Version) already installed" -ForegroundColor Green
}

# Check for PSScriptAnalyzer
Write-Host "`nChecking PSScriptAnalyzer..." -ForegroundColor Yellow
$analyzer = Get-Module -ListAvailable -Name PSScriptAnalyzer
if (-not $analyzer) {
    Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Yellow
    Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
    Write-Host "✓ PSScriptAnalyzer installed" -ForegroundColor Green
}
else {
    Write-Host "✓ PSScriptAnalyzer $($analyzer.Version) already installed" -ForegroundColor Green
}

# Check for Microsoft Edge
Write-Host "`nChecking Microsoft Edge..." -ForegroundColor Yellow
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (Test-Path $edgePath) {
    Write-Host "✓ Microsoft Edge found" -ForegroundColor Green
}
else {
    Write-Warning "Microsoft Edge not found at expected location"
    Write-Host "Please install Microsoft Edge from: https://www.microsoft.com/edge" -ForegroundColor Yellow
}

# Check for Node.js (for Playwright MCP server)
Write-Host "`nChecking Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version 2>$null
    Write-Host "✓ Node.js $nodeVersion" -ForegroundColor Green
}
catch {
    Write-Warning "Node.js not found"
    Write-Host "Please install Node.js from: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host "Note: Node.js is required for Playwright MCP server" -ForegroundColor Yellow
}

# Create required directories
Write-Host "`nCreating project directories..." -ForegroundColor Yellow
$directories = @(
    '.\exports',
    '.\logs',
    '.\tests\Unit',
    '.\tests\Integration',
    '.\tools'
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "✓ Created: $dir" -ForegroundColor Green
    }
    else {
        Write-Host "✓ Exists: $dir" -ForegroundColor Gray
    }
}

# Summary
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Dependency Installation Complete!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure MCP servers in VS Code (see .vscode/settings.json)" -ForegroundColor White
Write-Host "2. Configure your Edge work profile" -ForegroundColor White
Write-Host "3. Run .\scripts\Test-Environment.ps1 to validate setup" -ForegroundColor White
Write-Host "4. Start using: .\src\KustoDashboardManager.ps1" -ForegroundColor White
