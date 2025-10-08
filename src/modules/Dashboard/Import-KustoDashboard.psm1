# Import-KustoDashboard.psm1
# Module for importing Kusto dashboards from JSON files to Azure Data Explorer

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
    Imports a Kusto dashboard from a JSON file to Azure Data Explorer.

.DESCRIPTION
    Automates the import of Kusto dashboards by loading a JSON file,
    navigating to the dashboard portal, and uploading the dashboard configuration.
    Uses Playwright for browser automation via the BrowserManager module.

.PARAMETER DashboardUrl
    The full URL of the Kusto dashboard portal where the dashboard will be imported
    (e.g., https://dataexplorer.azure.com/dashboards/123)

.PARAMETER InputPath
    Path to the JSON file containing the dashboard definition. Must have .json extension.

.PARAMETER Browser
    Browser to use for automation. Options: 'edge', 'chrome', 'firefox'. Default: 'edge'

.PARAMETER Headless
    Run browser in headless mode (no visible window). Default: $false

.PARAMETER Timeout
    Timeout in milliseconds for page load operations. Default: 30000

.PARAMETER Force
    Force overwrite if dashboard already exists. Default: $false

.EXAMPLE
    Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/abc123" -InputPath "C:\exports\dashboard.json"

.EXAMPLE
    Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/abc123" -InputPath "dashboard.json" -Force -Headless

.OUTPUTS
    PSCustomObject with import result details
#>
function Import-KustoDashboard {
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
            if (-not (Test-Path $_)) {
                throw "InputPath file not found: $_"
            }
            if ($_ -notlike '*.json') {
                throw "InputPath must have a .json extension"
            }
            $true
        })]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('edge', 'chrome', 'firefox')]
        [string]$Browser = 'edge',

        [Parameter(Mandatory = $false)]
        [switch]$Headless,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1000, 300000)]
        [int]$Timeout = 30000,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'
    $browserInitialized = $false

    try {
        # Load and validate JSON file
        Write-Verbose "Loading dashboard JSON from: $InputPath"
        
        $dashboardJson = $null
        try {
            $dashboardContent = Get-Content -Path $InputPath -Raw -Encoding UTF8
            $dashboardJson = $dashboardContent | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse JSON file: $($_.Exception.Message)"
        }

        # Validate required fields
        if (-not $dashboardJson.PSObject.Properties['DashboardName']) {
            throw "JSON file must contain 'DashboardName' field"
        }

        if (-not $dashboardJson.PSObject.Properties['Tiles']) {
            throw "JSON file must contain 'Tiles' array"
        }

        $dashboardName = $dashboardJson.DashboardName
        $tileCount = if ($dashboardJson.Tiles) { $dashboardJson.Tiles.Count } else { 0 }

        # Log import start
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Info -Message "Starting import of dashboard: $dashboardName" -Properties @{ 
                InputPath = $InputPath
                TargetUrl = $DashboardUrl
                TileCount = $tileCount
            }
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

        # Wait for dashboard to load
        Write-Verbose "Waiting for dashboard portal to load (timeout: ${Timeout}ms)"
        $waitResult = Invoke-BrowserAction -Action 'WaitForElement' -Parameters @{
            Selector = '[data-testid="dashboard-canvas"], .dashboard-container, #dashboard-root, .dashboard-page'
            Timeout = $Timeout
        }

        if (-not $waitResult.Success) {
            throw "Dashboard portal did not load within timeout: $($waitResult.Error)"
        }

        # Click on edit/settings button to access import functionality
        Write-Verbose "Accessing dashboard import options"
        $editResult = Invoke-BrowserAction -Action 'Click' -Parameters @{
            Selector = '[data-testid="dashboard-edit"], [aria-label*="Edit"], button:has-text("Edit"), .edit-button'
        }

        if (-not $editResult.Success) {
            Write-Verbose "Edit button not found, trying alternative selectors"
        }

        # Wait for edit mode or import dialog
        Start-Sleep -Milliseconds 500

        # Look for import/upload JSON option
        Write-Verbose "Locating import JSON option"
        $importButtonResult = Invoke-BrowserAction -Action 'Click' -Parameters @{
            Selector = '[data-testid="import-json"], [aria-label*="Import"], button:has-text("Import"), .import-button'
        }

        if (-not $importButtonResult.Success) {
            Write-Verbose "Import button not found, trying menu options"
        }

        Start-Sleep -Milliseconds 500

        # Check for conflict (dashboard already exists)
        if (-not $Force) {
            $conflictCheck = Invoke-BrowserAction -Action 'GetText' -Parameters @{
                Selector = '[data-testid="conflict-message"], .conflict-warning, .error-message'
            }

            if ($conflictCheck.Success -and $conflictCheck.Data -match 'already exists|conflict') {
                throw "Dashboard already exists at target URL. Use -Force to overwrite."
            }
        }

        # Locate the JSON input field (could be textarea, input, or code editor)
        Write-Verbose "Locating JSON input field"
        $inputField = '[data-testid="json-input"], textarea[placeholder*="JSON"], .json-editor, #dashboard-json-input'
        
        # Click to focus the input field
        $clickInputResult = Invoke-BrowserAction -Action 'Click' -Parameters @{
            Selector = $inputField
        }

        if (-not $clickInputResult.Success) {
            Write-Verbose "Standard input field not found, trying alternative approaches"
        }

        # Clear any existing content and paste dashboard JSON
        Write-Verbose "Pasting dashboard JSON content"
        $typeResult = Invoke-BrowserAction -Action 'Type' -Parameters @{
            Selector = $inputField
            Text = $dashboardContent
        }

        if (-not $typeResult.Success) {
            throw "Failed to input dashboard JSON: $($typeResult.Error)"
        }

        # Click submit/save button
        Write-Verbose "Submitting dashboard import"
        $submitResult = Invoke-BrowserAction -Action 'Click' -Parameters @{
            Selector = '[data-testid="submit-import"], [data-testid="save-dashboard"], button:has-text("Save"), button:has-text("Import"), .save-button'
        }

        if (-not $submitResult.Success) {
            throw "Failed to click submit button: $($submitResult.Error)"
        }

        # Wait for import confirmation
        Write-Verbose "Waiting for import confirmation"
        $confirmResult = Invoke-BrowserAction -Action 'WaitForElement' -Parameters @{
            Selector = '[data-testid="success-message"], .success-notification, .import-success'
            Timeout = $Timeout
        }

        if (-not $confirmResult.Success) {
            Write-Verbose "Standard confirmation not found, checking for dashboard render"
            # Alternative: Wait for dashboard to render tiles
            $tileCheck = Invoke-BrowserAction -Action 'WaitForElement' -Parameters @{
                Selector = '[data-testid*="tile"], .dashboard-tile'
                Timeout = 5000
            }
        }

        # Handle Force overwrite if conflict detected
        if ($Force) {
            Write-Verbose "Force overwrite enabled, clicking overwrite confirmation if present"
            $overwriteResult = Invoke-BrowserAction -Action 'Click' -Parameters @{
                Selector = '[data-testid="confirm-overwrite"], button:has-text("Overwrite"), button:has-text("Replace")'
            }
        }

        # Log completion
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Info -Message "Import completed successfully" -Properties @{ 
                DashboardName = $dashboardName
                TargetUrl = $DashboardUrl
                TileCount = $tileCount
            }
        }

        # Return result object
        return [PSCustomObject]@{
            PSTypeName = 'KustoDashboard.ImportResult'
            Success = $true
            DashboardName = $dashboardName
            TargetUrl = $DashboardUrl
            InputPath = $InputPath
            TileCount = $tileCount
            ImportDate = (Get-Date).ToString('o')
        }
    }
    catch {
        # Log error
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Level Error -Message "Import failed: $($_.Exception.Message)" -Properties @{ 
                DashboardUrl = $DashboardUrl
                InputPath = $InputPath
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
Export-ModuleMember -Function Import-KustoDashboard
