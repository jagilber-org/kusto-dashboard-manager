<#
.SYNOPSIS
    Kusto Dashboard Manager - Main Entry Point

.DESCRIPTION
    PowerShell console application for managing Azure Data Explorer (Kusto) dashboards.
    Provides import/export capabilities using Playwright browser automation via MCP.

.PARAMETER Action
    The action to perform: Export, Import, Validate

.PARAMETER DashboardUrl
    The full URL of the dashboard (required for Export and Import actions)

.PARAMETER OutputPath
    The path where exported dashboard will be saved (for Export action)
    Default: .\exports\dashboard_{timestamp}.json

.PARAMETER InputPath
    The path to the dashboard definition JSON file (for Import action)

.PARAMETER Browser
    Browser to use for automation: edge, chrome, firefox
    Default: edge

.PARAMETER Headless
    Run browser in headless mode (no visible window)

.PARAMETER Timeout
    Timeout in milliseconds for page operations
    Default: 30000 (30 seconds)

.PARAMETER Force
    Force overwrite when importing (skip conflict checks)

.PARAMETER Environment
    The environment configuration to use: development, staging, production
    Default: development

.PARAMETER LogPath
    Path to the log file. If not specified, logging is disabled.

.PARAMETER LogLevel
    Minimum log level: DEBUG, INFO, WARN, ERROR
    Default: INFO

.EXAMPLE
    .\KustoDashboardManager.ps1 -Action Export -DashboardUrl "https://dataexplorer.azure.com/dashboards/abc123"
    Exports a dashboard to the default output directory

.EXAMPLE
    .\KustoDashboardManager.ps1 -Action Export -DashboardUrl "https://..." -OutputPath "C:\exports\my-dashboard.json" -Headless
    Exports a dashboard in headless mode to a specific file

.EXAMPLE
    .\KustoDashboardManager.ps1 -Action Import -DashboardUrl "https://..." -InputPath ".\dashboard.json" -Force
    Imports a dashboard, overwriting if it already exists

.EXAMPLE
    .\KustoDashboardManager.ps1 -Action Validate -InputPath ".\dashboard.json"
    Validates a dashboard JSON file without importing

.NOTES
    Version: 1.0.0
    Author: Kusto Dashboard Manager Team
    Requires: PowerShell 7.4+, Microsoft Edge, Playwright MCP Server
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Export', 'Import', 'Validate')]
    [string]$Action,
    
    [Parameter(Mandatory = $false)]
    [string]$DashboardUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory = $false)]
    [string]$InputPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('edge', 'chrome', 'firefox')]
    [string]$Browser = 'edge',
    
    [Parameter(Mandatory = $false)]
    [switch]$Headless,
    
    [Parameter(Mandatory = $false)]
    [int]$Timeout = 30000,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('development', 'staging', 'production')]
    [string]$Environment = 'development',
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
    [string]$LogLevel = 'INFO'
)

# Set strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Script root directory
$script:RootPath = $PSScriptRoot

# Import required modules
Write-Host "Initializing Kusto Dashboard Manager..." -ForegroundColor Cyan

try {
    Import-Module "$script:RootPath\modules\Core\Configuration.psm1" -Force
    Import-Module "$script:RootPath\modules\Core\Logging.psm1" -Force
    Import-Module "$script:RootPath\modules\Core\MCPClient.psm1" -Force
    Import-Module "$script:RootPath\modules\Browser\BrowserManager.psm1" -Force
    Import-Module "$script:RootPath\modules\Dashboard\Export-KustoDashboard.psm1" -Force
    Import-Module "$script:RootPath\modules\Dashboard\Import-KustoDashboard.psm1" -Force
    
    Write-Host "✓ Modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to load required modules: $($_.Exception.Message)"
    exit 1
}

# Initialize logging if LogPath is specified
if ($LogPath) {
    try {
        Initialize-Logging -LogFilePath $LogPath -MinLogLevel $LogLevel
        Write-AppLog -Level INFO -Message "Kusto Dashboard Manager started" -Properties @{
            Action = $Action
            Environment = $Environment
            Browser = $Browser
            Headless = $Headless.IsPresent
        }
    }
    catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
    }
}

# Main execution
try {
    Write-Host "`nKusto Dashboard Manager v1.0.0" -ForegroundColor Cyan
    Write-Host "================================`n" -ForegroundColor Cyan
    
    # Parameter validation
    if (-not $Action) {
        Write-Host "ERROR: Action parameter is required" -ForegroundColor Red
        Write-Host "`nUsage examples:" -ForegroundColor Yellow
        Write-Host "  Export:   .\KustoDashboardManager.ps1 -Action Export -DashboardUrl <url>" -ForegroundColor Gray
        Write-Host "  Import:   .\KustoDashboardManager.ps1 -Action Import -DashboardUrl <url> -InputPath <path>" -ForegroundColor Gray
        Write-Host "  Validate: .\KustoDashboardManager.ps1 -Action Validate -InputPath <path>" -ForegroundColor Gray
        exit 1
    }
    
    # Initialize MCP Client for actions that require browser operations
    if ($Action -in @('Export', 'Import')) {
        try {
            Write-Verbose "Initializing MCP Client..."
            $null = Initialize-MCPClient -Servers @('playwright')
            
            if ($LogPath) {
                Write-AppLog -Level INFO -Message "MCP Client initialized successfully"
            }
        }
        catch {
            Write-Error "Failed to initialize MCP Client: $($_.Exception.Message)"
            Write-Host "`nNote: Playwright MCP Server must be running for browser operations." -ForegroundColor Yellow
            Write-Host "Please ensure the MCP server is started before running Export or Import actions." -ForegroundColor Yellow
            exit 1
        }
    }
    
    switch ($Action) {
        'Export' {
            Write-Host "Action: Export Dashboard" -ForegroundColor Yellow
            
            # Validate required parameters
            if (-not $DashboardUrl) {
                throw "DashboardUrl is required for Export action"
            }
            
            # Generate default output path if not specified
            if (-not $OutputPath) {
                $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
                $OutputPath = Join-Path (Get-Location) "exports\dashboard_$timestamp.json"
            }
            
            Write-Host "Dashboard URL: $DashboardUrl" -ForegroundColor Gray
            Write-Host "Output Path:   $OutputPath" -ForegroundColor Gray
            Write-Host "Browser:       $Browser" -ForegroundColor Gray
            Write-Host "Headless:      $($Headless.IsPresent)" -ForegroundColor Gray
            Write-Host ""
            
            # Call export function
            $exportParams = @{
                DashboardUrl = $DashboardUrl
                OutputPath = $OutputPath
                Browser = $Browser
                Headless = $Headless.IsPresent
                Timeout = $Timeout
            }
            
            $result = Export-KustoDashboard @exportParams
            
            if ($result.Success) {
                Write-Host "✓ Export completed successfully" -ForegroundColor Green
                Write-Host "  Output file: $($result.OutputPath)" -ForegroundColor Gray
                if ($LogPath) {
                    Write-AppLog -Level INFO -Message "Dashboard exported successfully" -Properties @{
                        OutputPath = $result.OutputPath
                        DashboardUrl = $DashboardUrl
                    }
                }
            }
            else {
                throw "Export failed: $($result.Error)"
            }
        }
        
        'Import' {
            Write-Host "Action: Import Dashboard" -ForegroundColor Yellow
            
            # Validate required parameters
            if (-not $DashboardUrl) {
                throw "DashboardUrl is required for Import action"
            }
            
            if (-not $InputPath) {
                throw "InputPath is required for Import action"
            }
            
            if (-not (Test-Path $InputPath)) {
                throw "Input file not found: $InputPath"
            }
            
            Write-Host "Dashboard URL: $DashboardUrl" -ForegroundColor Gray
            Write-Host "Input Path:    $InputPath" -ForegroundColor Gray
            Write-Host "Browser:       $Browser" -ForegroundColor Gray
            Write-Host "Headless:      $($Headless.IsPresent)" -ForegroundColor Gray
            Write-Host "Force:         $($Force.IsPresent)" -ForegroundColor Gray
            Write-Host ""
            
            # Call import function
            $importParams = @{
                DashboardUrl = $DashboardUrl
                InputPath = $InputPath
                Browser = $Browser
                Headless = $Headless.IsPresent
                Timeout = $Timeout
                Force = $Force.IsPresent
            }
            
            $result = Import-KustoDashboard @importParams
            
            if ($result.Success) {
                Write-Host "✓ Import completed successfully" -ForegroundColor Green
                Write-Host "  Dashboard Name: $($result.DashboardName)" -ForegroundColor Gray
                if ($LogPath) {
                    Write-AppLog -Level INFO -Message "Dashboard imported successfully" -Properties @{
                        DashboardName = $result.DashboardName
                        DashboardUrl = $DashboardUrl
                        InputPath = $InputPath
                    }
                }
            }
            else {
                throw "Import failed: $($result.Error)"
            }
        }
        
        'Validate' {
            Write-Host "Action: Validate Dashboard Definition" -ForegroundColor Yellow
            
            # Validate required parameters
            if (-not $InputPath) {
                throw "InputPath is required for Validate action"
            }
            
            if (-not (Test-Path $InputPath)) {
                throw "Input file not found: $InputPath"
            }
            
            Write-Host "Input Path: $InputPath" -ForegroundColor Gray
            Write-Host ""
            
            # Read and validate JSON
            $jsonContent = Get-Content -Path $InputPath -Raw -Encoding UTF8
            $dashboard = $jsonContent | ConvertFrom-Json
            
            # Check required fields
            $errors = @()
            $warnings = @()
            
            if (-not $dashboard.DashboardName) {
                $errors += "Missing required field: DashboardName"
            }
            
            if (-not $dashboard.Tiles) {
                $errors += "Missing required field: Tiles"
            }
            elseif ($dashboard.Tiles.Count -eq 0) {
                $warnings += "Dashboard has no tiles"
            }
            
            # Display validation results
            if ($errors.Count -eq 0) {
                Write-Host "✓ Validation passed" -ForegroundColor Green
                Write-Host "  Dashboard Name: $($dashboard.DashboardName)" -ForegroundColor Gray
                Write-Host "  Tiles Count:    $($dashboard.Tiles.Count)" -ForegroundColor Gray
                
                if ($warnings.Count -gt 0) {
                    Write-Host "`nWarnings:" -ForegroundColor Yellow
                    foreach ($warning in $warnings) {
                        Write-Host "  - $warning" -ForegroundColor Yellow
                    }
                }
                
                if ($LogPath) {
                    Write-AppLog -Level INFO -Message "Dashboard validation passed" -Properties @{
                        InputPath = $InputPath
                        DashboardName = $dashboard.DashboardName
                        TilesCount = $dashboard.Tiles.Count
                    }
                }
            }
            else {
                Write-Host "✗ Validation failed" -ForegroundColor Red
                foreach ($error in $errors) {
                    Write-Host "  - $error" -ForegroundColor Red
                }
                
                if ($LogPath) {
                    Write-AppLog -Level ERROR -Message "Dashboard validation failed" -Properties @{
                        InputPath = $InputPath
                        Errors = ($errors -join '; ')
                    }
                }
                
                throw "Validation failed: $($errors -join '; ')"
            }
        }
    }
    
    Write-Host "`n✓ Operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "`n✗ Operation failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}
