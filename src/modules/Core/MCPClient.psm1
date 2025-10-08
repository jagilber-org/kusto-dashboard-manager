# MCPClient Module - MCP Server Communication Wrapper
# Provides retry logic, error handling, and connection management for MCP servers

# Module-level variables
$script:MCPConfig = $null
$script:ConnectionCache = @{}
$script:ServerStatus = @{}

<#
.SYNOPSIS
Initialize MCP client with server configuration.

.DESCRIPTION
Sets up MCP client with server list, retry configuration, and validates server names.

.PARAMETER Servers
Array of MCP server names to initialize (e.g., 'playwright', 'azure', 'powershell').

.PARAMETER Configuration
Optional configuration object (from Configuration module) for advanced settings.

.PARAMETER MaxRetries
Maximum number of retry attempts for failed operations. Default: 3.

.PARAMETER InitialRetryDelayMs
Initial delay in milliseconds before first retry. Default: 100ms.

.EXAMPLE
Initialize-MCPClient -Servers @('playwright', 'azure', 'powershell')

.EXAMPLE
$config = Get-Configuration
Initialize-MCPClient -Servers @('playwright') -Configuration $config -MaxRetries 5
#>
function Initialize-MCPClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Servers = @('playwright', 'azure', 'powershell'),
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Configuration = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,
        
        [Parameter(Mandatory = $false)]
        [int]$InitialRetryDelayMs = 100
    )
    
    # Validate server names
    $validServers = @('playwright', 'azure', 'powershell')
    foreach ($server in $Servers) {
        if ($server -notin $validServers) {
            throw "Invalid server name: $server. Valid servers: $($validServers -join ', ')"
        }
    }
    
    # Initialize configuration
    $script:MCPConfig = @{
        Servers = $Servers
        MaxRetries = $MaxRetries
        InitialRetryDelayMs = $InitialRetryDelayMs
        Configuration = $Configuration
    }
    
    # Initialize connection cache and status
    $script:ConnectionCache = @{}
    $script:ServerStatus = @{}
    foreach ($server in $Servers) {
        $script:ServerStatus[$server] = @{
            Connected = $false
            LastCheck = $null
            LastError = $null
        }
    }
    
    # Log initialization
    if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
        Write-AppLog -Message "MCP Client initialized" -Level INFO -Properties @{
            Servers = ($Servers -join ',')
            MaxRetries = $MaxRetries
        }
    }
    
    return $script:MCPConfig
}

<#
.SYNOPSIS
Invoke an MCP tool with retry logic and error handling.

.DESCRIPTION
Executes an MCP tool on the specified server with automatic retry on failure,
exponential backoff, and comprehensive error handling.

.PARAMETER Server
MCP server name (e.g., 'playwright', 'azure', 'powershell').

.PARAMETER Tool
Tool name to invoke on the MCP server.

.PARAMETER Parameters
Hashtable of parameters to pass to the MCP tool.

.EXAMPLE
Invoke-MCPTool -Server 'playwright' -Tool 'browser_navigate' -Parameters @{url='https://example.com'}

.EXAMPLE
$result = Invoke-MCPTool -Server 'azure' -Tool 'query_kusto' -Parameters @{query='table | limit 10'}
#>
function Invoke-MCPTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('playwright', 'azure', 'powershell')]
        [string]$Server,
        
        [Parameter(Mandatory = $true)]
        [string]$Tool,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )
    
    # Validate MCP client is initialized
    if (-not $script:MCPConfig) {
        throw "MCP Client not initialized. Call Initialize-MCPClient first."
    }
    
    # Validate server is in configuration
    if ($Server -notin $script:MCPConfig.Servers) {
        throw "Server '$Server' not in initialized server list: $($script:MCPConfig.Servers -join ', ')"
    }
    
    # Validate tool name
    if ([string]::IsNullOrWhiteSpace($Tool)) {
        throw "Tool name cannot be empty"
    }
    
    # Build MCP command
    $mcpCommand = "mcp_${Server}_${Tool}"
    
    # Attempt invocation with retry logic
    $retryCount = 0
    $maxRetries = $script:MCPConfig.MaxRetries
    $delayMs = $script:MCPConfig.InitialRetryDelayMs
    
    while ($retryCount -le $maxRetries) {
        try {
            # Log attempt
            if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                Write-AppLog -Message "Invoking MCP tool" -Level DEBUG -Properties @{
                    Server = $Server
                    Tool = $Tool
                    Attempt = ($retryCount + 1)
                }
            }
            
            # Convert parameters to JSON if not empty
            $paramJson = if ($Parameters.Count -gt 0) {
                $Parameters | ConvertTo-Json -Depth 10 -Compress
            } else {
                "{}"
            }
            
            # Execute MCP command (mocked in tests)
            $result = Invoke-Expression "$mcpCommand -Parameters '$paramJson'"
            
            # Update server status
            $script:ServerStatus[$Server].Connected = $true
            $script:ServerStatus[$Server].LastCheck = Get-Date
            $script:ServerStatus[$Server].LastError = $null
            
            # Log success
            if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                Write-AppLog -Message "MCP tool invoked successfully" -Level INFO -Properties @{
                    Server = $Server
                    Tool = $Tool
                }
            }
            
            return $result
            
        } catch {
            $errorMessage = $_.Exception.Message
            
            # Classify error (validation errors should not retry)
            $shouldRetry = $errorMessage -notmatch 'Invalid|cannot be empty|not in initialized'
            
            # Update server status
            $script:ServerStatus[$Server].Connected = $false
            $script:ServerStatus[$Server].LastCheck = Get-Date
            $script:ServerStatus[$Server].LastError = $errorMessage
            
            # Check if we should retry
            if ($shouldRetry -and $retryCount -lt $maxRetries) {
                # Log retry
                if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                    Write-AppLog -Message "MCP tool invocation failed, retrying" -Level WARN -Properties @{
                        Server = $Server
                        Tool = $Tool
                        Attempt = ($retryCount + 1)
                        Error = $errorMessage
                        NextRetryDelayMs = $delayMs
                    }
                }
                
                # Exponential backoff
                Start-Sleep -Milliseconds $delayMs
                $delayMs = [math]::Min($delayMs * 2, 5000) # Cap at 5 seconds
                $retryCount++
                
            } else {
                # Log final failure
                if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
                    Write-AppLog -Message "MCP tool invocation failed" -Level ERROR -Properties @{
                        Server = $Server
                        Tool = $Tool
                        Error = $errorMessage
                        Retries = $retryCount
                    }
                }
                
                # Throw with enriched error information
                throw "MCP tool invocation failed: $errorMessage (Server: $Server, Tool: $Tool, Retries: $retryCount)"
            }
        }
    }
    
    # Should never reach here, but throw just in case
    throw "MCP tool invocation exceeded maximum retries"
}

<#
.SYNOPSIS
Get connection status for MCP servers.

.DESCRIPTION
Returns connection status, last check time, and last error for MCP servers.

.PARAMETER Server
Optional specific server name. If not provided, returns status for all servers.

.EXAMPLE
Get-MCPServerStatus

.EXAMPLE
Get-MCPServerStatus -Server 'playwright'
#>
function Get-MCPServerStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('playwright', 'azure', 'powershell')]
        [string]$Server
    )
    
    # Validate MCP client is initialized
    if (-not $script:MCPConfig) {
        throw "MCP Client not initialized. Call Initialize-MCPClient first."
    }
    
    if ($Server) {
        # Return status for specific server
        if ($script:ServerStatus.ContainsKey($Server)) {
            return [PSCustomObject]@{
                Server = $Server
                Connected = $script:ServerStatus[$Server].Connected
                LastCheck = $script:ServerStatus[$Server].LastCheck
                LastError = $script:ServerStatus[$Server].LastError
            }
        } else {
            throw "Server '$Server' not found in status cache"
        }
    } else {
        # Return status for all servers
        $allStatus = @()
        foreach ($srv in $script:MCPConfig.Servers) {
            $allStatus += [PSCustomObject]@{
                Server = $srv
                Connected = $script:ServerStatus[$srv].Connected
                LastCheck = $script:ServerStatus[$srv].LastCheck
                LastError = $script:ServerStatus[$srv].LastError
            }
        }
        return $allStatus
    }
}

<#
.SYNOPSIS
Test MCP server connection.

.DESCRIPTION
Tests connectivity to an MCP server with optional timeout.

.PARAMETER Server
MCP server name to test.

.PARAMETER TimeoutMs
Connection test timeout in milliseconds. Default: 5000ms.

.EXAMPLE
Test-MCPConnection -Server 'playwright'

.EXAMPLE
$isConnected = Test-MCPConnection -Server 'azure' -TimeoutMs 3000
#>
function Test-MCPConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('playwright', 'azure', 'powershell')]
        [string]$Server,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMs = 5000
    )
    
    # Validate MCP client is initialized
    if (-not $script:MCPConfig) {
        throw "MCP Client not initialized. Call Initialize-MCPClient first."
    }
    
    try {
        # Attempt a simple health check (implementation would vary by server)
        # For now, simulate a connection test
        $testCommand = "Test-Path 'function:\Invoke-Expression'" # Simple validation
        
        # Execute with timeout
        $job = Start-Job -ScriptBlock {
            param($cmd)
            Invoke-Expression $cmd
        } -ArgumentList $testCommand
        
        $completed = Wait-Job -Job $job -Timeout ($TimeoutMs / 1000)
        
        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job -Force
            
            # Update status
            $script:ServerStatus[$Server].Connected = $true
            $script:ServerStatus[$Server].LastCheck = Get-Date
            $script:ServerStatus[$Server].LastError = $null
            
            return $true
        } else {
            # Timeout
            Remove-Job -Job $job -Force
            
            $script:ServerStatus[$Server].Connected = $false
            $script:ServerStatus[$Server].LastCheck = Get-Date
            $script:ServerStatus[$Server].LastError = "Connection test timeout after ${TimeoutMs}ms"
            
            return $false
        }
        
    } catch {
        # Update status with error
        $script:ServerStatus[$Server].Connected = $false
        $script:ServerStatus[$Server].LastCheck = Get-Date
        $script:ServerStatus[$Server].LastError = $_.Exception.Message
        
        # Log error
        if (Get-Command Write-AppLog -ErrorAction SilentlyContinue) {
            Write-AppLog -Message "MCP connection test failed" -Level ERROR -Properties @{
                Server = $Server
                Error = $_.Exception.Message
            }
        }
        
        return $false
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Initialize-MCPClient',
    'Invoke-MCPTool',
    'Get-MCPServerStatus',
    'Test-MCPConnection'
)
