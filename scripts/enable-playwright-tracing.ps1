# Enable Playwright MCP Tracing and Prepare for Interactive Workflow
# Purpose: Configure tracing, create output directory, and prepare for browser_snapshot workflow

$ErrorActionPreference = 'Stop'

# Configuration
$mcpConfigPath = "$env:APPDATA\Code\User\mcp.json"
$outputDir = "$PSScriptRoot\..\traces"
$backupPath = "$mcpConfigPath.backup"

Write-Host "=== Playwright MCP Tracing Setup ===" -ForegroundColor Cyan
Write-Host ""

# Create output directory for traces
if (-not (Test-Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    Write-Host "✓ Created traces directory: $outputDir" -ForegroundColor Green
} else {
    Write-Host "✓ Traces directory exists: $outputDir" -ForegroundColor Green
}

# Check if MCP config exists
if (-not (Test-Path $mcpConfigPath)) {
    Write-Host "✗ MCP config not found at: $mcpConfigPath" -ForegroundColor Red
    Write-Host "  Please configure Playwright MCP in VS Code first" -ForegroundColor Yellow
    exit 1
}

# Backup existing config
Copy-Item $mcpConfigPath $backupPath -Force
Write-Host "✓ Backed up config to: $backupPath" -ForegroundColor Green

# Read current config
$config = Get-Content $mcpConfigPath -Raw | ConvertFrom-Json

# Show current Playwright config
Write-Host ""
Write-Host "Current Playwright MCP Configuration:" -ForegroundColor Cyan
if ($config.mcpServers.Playwright) {
    $config.mcpServers.Playwright | ConvertTo-Json -Depth 10 | Write-Host
} else {
    Write-Host "  No Playwright server configured!" -ForegroundColor Red
    exit 1
}

# Update Playwright config with tracing
Write-Host ""
Write-Host "Adding tracing configuration..." -ForegroundColor Cyan

$tracesPath = (Resolve-Path $outputDir).Path

# Ensure args is an array
if (-not $config.mcpServers.Playwright.args) {
    $config.mcpServers.Playwright.args = @("@playwright/mcp@latest")
}

# Remove any existing trace/output args
$config.mcpServers.Playwright.args = @(
    $config.mcpServers.Playwright.args | Where-Object { 
        $_ -notmatch '^--save-trace' -and 
        $_ -notmatch '^--output-dir' -and
        $_ -notmatch '^--save-session' -and
        $_ -ne '@playwright/mcp@latest'
    }
)

# Add package first, then trace options
$config.mcpServers.Playwright.args = @(
    "@playwright/mcp@latest"
    "--save-trace"
    "--save-session"
    "--output-dir=$tracesPath"
) + $config.mcpServers.Playwright.args

# Save updated config
$config | ConvertTo-Json -Depth 10 | Set-Content $mcpConfigPath -Encoding UTF8

Write-Host "✓ Updated MCP configuration with tracing" -ForegroundColor Green
Write-Host ""
Write-Host "New Playwright MCP Configuration:" -ForegroundColor Cyan
$config.mcpServers.Playwright | ConvertTo-Json -Depth 10 | Write-Host

Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Tracing Configuration:" -ForegroundColor Cyan
Write-Host "  Output Directory: $tracesPath" -ForegroundColor White
Write-Host "  Trace Files: *.zip" -ForegroundColor White
Write-Host "  Session Files: *.json" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Restart VS Code to reload MCP configuration" -ForegroundColor White
Write-Host "  2. Use Copilot Chat with Playwright MCP tools" -ForegroundColor White
Write-Host "  3. View traces with: npx playwright show-trace <trace-file>.zip" -ForegroundColor White
Write-Host ""
Write-Host "To restore original config:" -ForegroundColor Yellow
Write-Host "  Copy-Item '$backupPath' '$mcpConfigPath' -Force" -ForegroundColor Gray
Write-Host ""
