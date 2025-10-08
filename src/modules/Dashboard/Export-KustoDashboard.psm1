# Export-KustoDashboard.psm1
# Module for exporting Kusto dashboards to JSON format

# Import dependencies
$BrowserManagerPath = Join-Path $PSScriptRoot "..\Browser\BrowserManager.psm1"
if (Test-Path $BrowserManagerPath) {
    Import-Module $BrowserManagerPath -Force
}

$ConfigurationPath = Join-Path $PSScriptRoot "..\Core\Configuration.psm1"
if (Test-Path $ConfigurationPath) {
    Import-Module $ConfigurationPath -Force -ErrorAction SilentlyContinue
}

$LoggingPath = Join-Path $PSScriptRoot "..\Core\Logging.psm1"
if (Test-Path $LoggingPath) {
    Import-Module $LoggingPath -Force -ErrorAction SilentlyContinue
}

<#
.SYNOPSIS
    Exports a Kusto dashboard from Azure Data Explorer to a JSON file.

.DESCRIPTION
    Automates the export of Kusto dashboards by navigating to the dashboard URL,
    extracting dashboard configuration and tiles, and saving as structured JSON.
    Uses Playwright for browser automation via the BrowserManager module.

.PARAMETER DashboardUrl
    The full URL of the Kusto dashboard to export (e.g., https://dataexplorer.azure.com/dashboards/123)

.PARAMETER OutputPath
    Path where the JSON file will be saved. Must have .json extension.

.PARAMETER Browser
    Browser to use for automation. Options: 'edge', 'chrome', 'firefox'. Default: 'edge'

.PARAMETER Headless
    Run browser in headless mode (no visible window). Default: $false

.PARAMETER Timeout
    Timeout in milliseconds for page load operations. Default: 30000

.EXAMPLE
    Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/abc123" -OutputPath "C:\exports\dashboard.json"

.EXAMPLE
    Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/abc123" -OutputPath "dashboard.json" -Headless -Timeout 60000

.OUTPUTS
    PSCustomObject with export result details
#>
function Export-KustoDashboard {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ($_ -notmatch '^https?://') {
                throw "DashboardUrl must be a valid URL starting with http:// or https://"
            }
            $true
        })]
        [string]$DashboardUrl,

        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if ($_ -notlike '*.json') {
                throw "OutputPath must have a .json extension"
            }
            $true
        })]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('edge', 'chrome', 'firefox')]
        [string]$Browser = 'edge',

        [Parameter(Mandatory = $false)]
        [switch]$Headless,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1000, 300000)]
        [int]$Timeout = 30000
    )

    $ErrorActionPreference = 'Stop'
    $browserInitialized = $false

    try {
        # Log export start
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Info -Message "Starting export of dashboard: $DashboardUrl" -Properties @{ OutputPath = $OutputPath }
        }

        # Initialize browser
        Write-Verbose "Initializing browser: $Browser (Headless: $Headless)"
        $initResult = Initialize-Browser -Browser $Browser -Headless:$Headless

        if (-not $initResult.Success) {
            throw "Failed to initialize browser: $($initResult.Error)"
        }
        $browserInitialized = $true

        # Navigate to dashboard URL
        Write-Verbose "Navigating to dashboard URL: $DashboardUrl"
        $navResult = Invoke-BrowserAction -Action 'Navigate' -Parameters @{
            Url = $DashboardUrl
        }

        if (-not $navResult.Success) {
            throw "Failed to navigate to dashboard: $($navResult.Error)"
        }

        # Wait for dashboard to load (wait for main dashboard container)
        Write-Verbose "Waiting for dashboard to load (timeout: ${Timeout}ms)"
        $waitResult = Invoke-BrowserAction -Action 'WaitForElement' -Parameters @{
            Selector = '[data-testid="dashboard-canvas"], .dashboard-container, #dashboard-root'
            Timeout = $Timeout
        }

        if (-not $waitResult.Success) {
            throw "Dashboard did not load within timeout: $($waitResult.Error)"
        }

        # Extract dashboard name
        Write-Verbose "Extracting dashboard name"
        $nameResult = Invoke-BrowserAction -Action 'GetText' -Parameters @{
            Selector = '[data-testid="dashboard-name"], .dashboard-title, h1'
        }

        $dashboardName = if ($nameResult.Success) { $nameResult.Data } else { "Untitled Dashboard" }

        # Extract dashboard content using JavaScript evaluation
        Write-Verbose "Extracting dashboard tiles and configuration"
        $contentResult = Invoke-BrowserAction -Action 'Evaluate' -Parameters @{
            Expression = @"
() => {
    // Try to extract dashboard tiles from common Kusto dashboard structures
    const tiles = [];
    
    // Method 1: Look for tile elements with data attributes
    const tileElements = document.querySelectorAll('[data-testid*="tile"], .dashboard-tile, .tile-container');
    tileElements.forEach((tile, index) => {
        const titleEl = tile.querySelector('[data-testid*="title"], .tile-title, h2, h3');
        const title = titleEl ? titleEl.textContent.trim() : `Tile ${index + 1}`;
        
        tiles.push({
            Title: title,
            Index: index,
            Type: tile.getAttribute('data-tile-type') || 'unknown'
        });
    });
    
    // Method 2: If no tiles found, try to get from global state (React/Angular apps)
    if (tiles.length === 0 && window.__DASHBOARD_STATE__) {
        return window.__DASHBOARD_STATE__.tiles || [];
    }
    
    return tiles;
}
"@
        }

        $tiles = if ($contentResult.Success -and $contentResult.Data) { 
            $contentResult.Data 
        } else { 
            @() 
        }

        # Get page HTML for additional parsing if needed
        Write-Verbose "Retrieving page HTML for metadata extraction"
        $htmlResult = Invoke-BrowserAction -Action 'GetHTML' -Parameters @{}
        $pageHtml = if ($htmlResult.Success) { $htmlResult.Data } else { "" }

        # Build export object
        $exportData = [PSCustomObject]@{
            PSTypeName = 'KustoDashboard.ExportResult'
            DashboardName = $dashboardName
            SourceUrl = $DashboardUrl
            ExportDate = (Get-Date).ToString('o')
            Tiles = $tiles
            TileCount = $tiles.Count
            Browser = $Browser
            PageTitle = if ($pageHtml -match '<title>(.*?)</title>') { $Matches[1] } else { $dashboardName }
        }

        # Ensure output directory exists
        $outputDir = Split-Path -Path $OutputPath -Parent
        if ($outputDir -and -not (Test-Path $outputDir)) {
            Write-Verbose "Creating output directory: $outputDir"
            New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        }

        # Save to JSON file
        Write-Verbose "Saving dashboard to: $OutputPath"
        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

        # Log completion
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Info -Message "Export completed successfully" -Properties @{ 
                OutputPath = $OutputPath
                TileCount = $tiles.Count
                DashboardName = $dashboardName
            }
        }

        # Return result object
        return [PSCustomObject]@{
            PSTypeName = 'KustoDashboard.ExportResult'
            Success = $true
            DashboardName = $dashboardName
            SourceUrl = $DashboardUrl
            OutputPath = $OutputPath
            TileCount = $tiles.Count
            ExportDate = $exportData.ExportDate
        }
    }
    catch {
        # Log error
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Error -Message "Export failed: $($_.Exception.Message)" -Properties @{ 
                DashboardUrl = $DashboardUrl
                Error = $_.Exception.Message
            }
        }

        throw
    }
    finally {
        # Always close browser, even on error
        if ($browserInitialized) {
            try {
                Write-Verbose "Closing browser"
                Close-Browser
            }
            catch {
                # Don't suppress original error if cleanup fails
                Write-Warning "Failed to close browser: $($_.Exception.Message)"
            }
        }
    }
}

# Export functions
Export-ModuleMember -Function Export-KustoDashboard
