# BrowserManager Module - Playwright Browser Automation Wrapper
# Provides high-level browser automation using Playwright MCP server

# Module-level state
$script:BrowserState = @{
    IsInitialized = $false
    Browser = $null
    Headless = $false
    ProfilePath = $null
    CurrentUrl = $null
    SessionId = $null
}

<#
.SYNOPSIS
Initialize browser session with Playwright.

.DESCRIPTION
Initializes a browser session using the Playwright MCP server. Supports Edge browser
with work profile authentication, headless mode, and configuration integration.

.PARAMETER Browser
Browser type to use. Valid values: 'edge', 'chrome', 'firefox'. Default: 'edge'.

.PARAMETER ProfilePath
Path to browser profile directory for persistent authentication.

.PARAMETER Headless
Run browser in headless mode (no UI).

.PARAMETER UseConfiguration
Load default settings from Configuration module.

.EXAMPLE
Initialize-Browser

.EXAMPLE
Initialize-Browser -Browser 'edge' -ProfilePath 'C:\Users\user\AppData\Local\Microsoft\Edge\User Data'

.EXAMPLE
Initialize-Browser -Headless -UseConfiguration
#>
function Initialize-Browser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('edge', 'chrome', 'firefox')]
        [string]$Browser = 'edge',
        
        [Parameter(Mandatory = $false)]
        [string]$ProfilePath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Headless,
        
        [Parameter(Mandatory = $false)]
        [switch]$UseConfiguration
    )
    
    # Check if already initialized (cache browser instance)
    if ($script:BrowserState.IsInitialized -and 
        $script:BrowserState.Browser -eq $Browser -and
        $script:BrowserState.Headless -eq $Headless.IsPresent) {
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser already initialized, reusing instance" -Level DEBUG
        }
        return
    }
    
    # Load configuration if requested
    if ($UseConfiguration -and (Get-Command Get-Configuration -ErrorAction SilentlyContinue)) {
        $config = Get-Configuration
        if (-not $Browser -and $config.browser.type) {
            $Browser = $config.browser.type
        }
        if (-not $Headless.IsPresent -and $config.browser.headless) {
            $Headless = $config.browser.headless
        }
        if (-not $ProfilePath -and $config.browser.profilePath) {
            $ProfilePath = $config.browser.profilePath
        }
    }
    
    try {
        # Ensure MCP Client is available
        if (-not (Get-Command Invoke-MCPTool -ErrorAction SilentlyContinue)) {
            throw "MCPClient module not loaded. Import MCPClient module first."
        }
        
        # Prepare browser launch parameters
        $launchParams = @{
            browser = $Browser
            headless = $Headless.IsPresent
        }
        
        if ($ProfilePath) {
            $launchParams.userDataDir = $ProfilePath
        }
        
        # Launch browser via Playwright MCP
        $result = Invoke-MCPTool -Server 'playwright' -Tool 'browser_launch' -Parameters $launchParams
        
        if (-not $result.success) {
            throw "Browser launch failed: $($result.error)"
        }
        
        # Update state
        $script:BrowserState.IsInitialized = $true
        $script:BrowserState.Browser = $Browser
        $script:BrowserState.Headless = $Headless.IsPresent
        $script:BrowserState.ProfilePath = $ProfilePath
        $script:BrowserState.SessionId = $result.sessionId
        
        # Log initialization
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser initialized successfully" -Level INFO -Properties @{
                Browser = $Browser
                Headless = $Headless.IsPresent
                ProfilePath = $ProfilePath
            }
        }
        
    } catch {
        $script:BrowserState.IsInitialized = $false
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser initialization failed" -Level ERROR -Properties @{
                Browser = $Browser
                Error = $_.Exception.Message
            }
        }
        
        throw "Browser initialization failed: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Invoke browser action via Playwright.

.DESCRIPTION
Executes various browser actions including navigation, element interaction,
content extraction, and advanced features like file upload and dialog handling.

.PARAMETER Action
Action to perform. Valid actions include:
- Navigate, Click, Type, GetText, WaitForElement
- GetHTML, Screenshot, Evaluate
- Upload, HandleDialog, SwitchFrame, GetNetworkRequests

.PARAMETER Parameters
Hashtable of parameters specific to the action.

.EXAMPLE
Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://dataexplorer.azure.com' }

.EXAMPLE
Invoke-BrowserAction -Action 'Click' -Parameters @{ selector = 'button.submit' }

.EXAMPLE
Invoke-BrowserAction -Action 'Type' -Parameters @{ selector = 'input#username'; text = 'user@domain.com' }
#>
function Invoke-BrowserAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Navigate', 'Click', 'Type', 'GetText', 'WaitForElement', 
                     'GetHTML', 'Screenshot', 'Evaluate', 'Upload', 'HandleDialog', 
                     'SwitchFrame', 'GetNetworkRequests')]
        [string]$Action,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )
    
    # Validate browser is initialized
    if (-not $script:BrowserState.IsInitialized) {
        throw "Browser not initialized. Call Initialize-Browser first."
    }
    
    try {
        # Map action to MCP tool
        $toolMapping = @{
            'Navigate' = 'browser_navigate'
            'Click' = 'browser_click'
            'Type' = 'browser_type'
            'GetText' = 'browser_get_text'
            'WaitForElement' = 'browser_wait_for_element'
            'GetHTML' = 'browser_get_html'
            'Screenshot' = 'browser_screenshot'
            'Evaluate' = 'browser_evaluate'
            'Upload' = 'browser_upload'
            'HandleDialog' = 'browser_handle_dialog'
            'SwitchFrame' = 'browser_switch_frame'
            'GetNetworkRequests' = 'browser_get_network_requests'
        }
        
        $mcpTool = $toolMapping[$Action]
        if (-not $mcpTool) {
            throw "Unknown action: $Action"
        }
        
        # Validate required parameters for specific actions
        switch ($Action) {
            'Navigate' {
                if (-not $Parameters.url) {
                    throw "Navigate action requires 'url' parameter"
                }
            }
            'Click' {
                if (-not $Parameters.selector) {
                    throw "Click action requires 'selector' parameter"
                }
            }
            'Type' {
                if (-not $Parameters.selector -or -not $Parameters.ContainsKey('text')) {
                    throw "Type action requires 'selector' and 'text' parameters"
                }
            }
        }
        
        # Execute action via MCP
        $result = Invoke-MCPTool -Server 'playwright' -Tool $mcpTool -Parameters $Parameters
        
        # Update current URL if navigating
        if ($Action -eq 'Navigate' -and $result.success) {
            $script:BrowserState.CurrentUrl = $Parameters.url
        }
        
        # Log action
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser action executed" -Level DEBUG -Properties @{
                Action = $Action
                Success = $result.success
            }
        }
        
        return $result
        
    } catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser action failed" -Level ERROR -Properties @{
                Action = $Action
                Error = $_.Exception.Message
            }
        }
        
        throw "Browser action '$Action' failed: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
Get current browser state.

.DESCRIPTION
Returns the current state of the browser session including initialization status,
browser type, current URL, and configuration.

.EXAMPLE
$state = Get-BrowserState
if ($state.IsInitialized) {
    Write-Host "Browser is ready"
}
#>
function Get-BrowserState {
    [CmdletBinding()]
    param()
    
    return [PSCustomObject]@{
        IsInitialized = $script:BrowserState.IsInitialized
        Browser = $script:BrowserState.Browser
        Headless = $script:BrowserState.Headless
        ProfilePath = $script:BrowserState.ProfilePath
        CurrentUrl = $script:BrowserState.CurrentUrl
        SessionId = $script:BrowserState.SessionId
    }
}

<#
.SYNOPSIS
Close browser session.

.DESCRIPTION
Closes the current browser session and cleans up resources. Resets browser state.

.EXAMPLE
Close-Browser
#>
function Close-Browser {
    [CmdletBinding()]
    param()
    
    if (-not $script:BrowserState.IsInitialized) {
        throw "Browser not initialized. Nothing to close."
    }
    
    try {
        # Close browser via MCP
        $result = Invoke-MCPTool -Server 'playwright' -Tool 'browser_close' -Parameters @{}
        
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser closed successfully" -Level INFO
        }
        
    } catch {
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "Browser close failed" -Level WARN -Properties @{
                Error = $_.Exception.Message
            }
        }
        # Continue to reset state even on error
    } finally {
        # Always reset state
        $script:BrowserState.IsInitialized = $false
        $script:BrowserState.Browser = $null
        $script:BrowserState.Headless = $false
        $script:BrowserState.ProfilePath = $null
        $script:BrowserState.CurrentUrl = $null
        $script:BrowserState.SessionId = $null
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-Browser',
    'Invoke-BrowserAction',
    'Get-BrowserState',
    'Close-Browser'
)
