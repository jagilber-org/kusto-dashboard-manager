# Logging.psm1
# Provides structured logging with JSON formatting, log rotation, and level filtering

# Script-scope variables for logging context
$script:LogPath = $null
$script:LogLevel = 'INFO'
$script:SessionId = (New-Guid).ToString()

# Log level hierarchy for filtering
$script:LogLevels = @{
    'DEBUG' = 0
    'INFO'  = 1
    'WARN'  = 2
    'ERROR' = 3
}

<#
.SYNOPSIS
    Initializes the log file and sets logging configuration.

.DESCRIPTION
    Creates the log directory and file if they don't exist. Handles log rotation
    when the file size exceeds the specified maximum. Sets script-scope variables
    for log path, level, and session ID.

.PARAMETER LogPath
    Full path to the log file.

.PARAMETER LogLevel
    Minimum log level to write. Valid values: DEBUG, INFO, WARN, ERROR.
    Default: INFO

.PARAMETER MaxSizeKB
    Maximum log file size in kilobytes before rotation.
    Default: 10240 (10 MB)

.EXAMPLE
    Initialize-LogFile -LogPath ".\logs\app.log" -LogLevel "DEBUG"
#>
function Initialize-LogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$LogLevel = 'INFO',

        [Parameter(Mandatory = $false)]
        [int]$MaxSizeKB = 10240
    )

    # Create log directory if it doesn't exist
    $logDir = Split-Path -Path $LogPath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    # Check if rotation is needed
    if (Test-Path -Path $LogPath) {
        $logFile = Get-Item -Path $LogPath
        $fileSizeKB = $logFile.Length / 1KB
        
        if ($fileSizeKB -gt $MaxSizeKB) {
            # Rotate log file
            $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
            $rotatedPath = $LogPath -replace '\.log$', ".$timestamp.log"
            Move-Item -Path $LogPath -Destination $rotatedPath -Force
        }
    }

    # Create log file if it doesn't exist
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType File -Force | Out-Null
    }

    # Set script-scope variables
    $script:LogPath = $LogPath
    $script:LogLevel = $LogLevel
}

<#
.SYNOPSIS
    Returns the current logging context.

.DESCRIPTION
    Retrieves the current log configuration including log path, level, and session ID.

.OUTPUTS
    PSCustomObject with LogPath, LogLevel, and SessionId properties.

.EXAMPLE
    $context = Get-LogContext
    Write-Host "Logging to: $($context.LogPath)"
#>
function Get-LogContext {
    [CmdletBinding()]
    param()

    return [PSCustomObject]@{
        LogPath   = $script:LogPath
        LogLevel  = $script:LogLevel
        SessionId = $script:SessionId
    }
}

<#
.SYNOPSIS
    Writes a structured log entry to the log file.

.DESCRIPTION
    Creates a JSON-formatted log entry with timestamp, level, message, and optional
    properties. Includes exception details and caller information when available.
    Supports log level filtering and concurrent write safety.

.PARAMETER Message
    Log message to write.

.PARAMETER Level
    Log level. Valid values: DEBUG, INFO, WARN, ERROR.
    Default: INFO

.PARAMETER Properties
    Additional properties to include in the log entry as a hashtable.

.PARAMETER Exception
    Exception object or ErrorRecord to include in the log entry.

.PARAMETER PassThru
    If specified, also writes the log entry to the console.

.EXAMPLE
    Write-AppLog -Message "User logged in" -Level INFO -Properties @{UserId="123"}

.EXAMPLE
    Write-AppLog -Message "Operation failed" -Level ERROR -Exception $_ -PassThru
#>
function Write-AppLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{},

        [Parameter(Mandatory = $false)]
        [Object]$Exception = $null,

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )

    # Check if we should log based on level filtering
    if ($script:LogLevels[$Level] -lt $script:LogLevels[$script:LogLevel]) {
        return
    }

    # Build log entry
    $logEntry = [ordered]@{
        timestamp = (Get-Date).ToString('o')
        level     = $Level
        message   = $Message
        sessionId = $script:SessionId
    }

    # Add caller information
    $caller = (Get-PSCallStack)[1]
    if ($caller) {
        $logEntry['caller'] = @{
            command  = $caller.Command
            location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"
        }
    }

    # Add additional properties (merge directly into log entry)
    if ($Properties.Count -gt 0) {
        foreach ($key in $Properties.Keys) {
            $logEntry[$key] = $Properties[$key]
        }
    }

    # Add exception details
    if ($Exception) {
        # Handle both Exception objects and ErrorRecord objects
        $exceptionObj = if ($Exception -is [System.Management.Automation.ErrorRecord]) {
            $Exception.Exception
        } else {
            $Exception
        }
        
        $logEntry['exception'] = @{
            type       = $exceptionObj.GetType().FullName
            message    = $exceptionObj.Message
            stackTrace = $exceptionObj.StackTrace
        }
    }

    # Convert to JSON
    $jsonEntry = $logEntry | ConvertTo-Json -Compress -Depth 10

    # Write to log file with file locking for concurrent write safety
    if ($script:LogPath) {
        $retryCount = 0
        $maxRetries = 3
        $written = $false

        while (-not $written -and $retryCount -lt $maxRetries) {
            try {
                # Use Add-Content with -Force for concurrent write safety
                Add-Content -Path $script:LogPath -Value $jsonEntry -Force -ErrorAction Stop
                $written = $true
            }
            catch {
                $retryCount++
                if ($retryCount -ge $maxRetries) {
                    throw
                }
                Start-Sleep -Milliseconds (50 * $retryCount)
            }
        }
    }

    # Write to console if PassThru specified
    if ($PassThru) {
        $color = switch ($Level) {
            'DEBUG' { 'Gray' }
            'INFO'  { 'White' }
            'WARN'  { 'Yellow' }
            'ERROR' { 'Red' }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }
}

# Export module members (must be at end of file)
Export-ModuleMember -Function Initialize-LogFile, Get-LogContext, Write-AppLog
