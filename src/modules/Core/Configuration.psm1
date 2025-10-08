# Configuration Module
# Handles application configuration loading and merging

<#
.SYNOPSIS
    Configuration management module for Kusto Dashboard Manager.

.DESCRIPTION
    Provides functions for loading, merging, and validating application configuration
    from JSON files with environment-specific overrides.

.NOTES
    Module: Core/Configuration
    Version: 1.0.0
    Author: Kusto Dashboard Manager Team
#>

#Requires -Version 7.4

<#
.SYNOPSIS
    Loads configuration from JSON files with environment-specific overrides.

.DESCRIPTION
    Loads the default configuration from default.json and merges it with
    environment-specific configuration (development.json, production.json, etc.).

.PARAMETER ConfigPath
    Path to the directory containing configuration JSON files.
    Defaults to .\config relative to module root.

.PARAMETER Environment
    Environment name for configuration override.
    Valid values: development, staging, production
    Defaults to 'development'

.EXAMPLE
    $config = Get-Configuration
    # Loads default configuration with development overrides

.EXAMPLE
    $config = Get-Configuration -Environment 'production'
    # Loads default configuration with production overrides

.OUTPUTS
    PSCustomObject - Merged configuration object
#>
function Get-Configuration {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$ConfigPath = (Join-Path $PSScriptRoot '..' '..' '..' 'config'),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('development', 'staging', 'production')]
        [string]$Environment = 'development'
    )
    
    begin {
        Write-Verbose "Loading configuration from: $ConfigPath"
        Write-Verbose "Environment: $Environment"
    }
    
    process {
        try {
            # Load default configuration
            $defaultConfigPath = Join-Path $ConfigPath 'default.json'
            if (-not (Test-Path $defaultConfigPath)) {
                throw "Default configuration file not found: $defaultConfigPath"
            }
            
            Write-Verbose "Loading default configuration: $defaultConfigPath"
            $defaultConfigJson = Get-Content -Path $defaultConfigPath -Raw -ErrorAction Stop
            $defaultConfig = $defaultConfigJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            
            # Load environment-specific configuration if it exists
            $envConfigPath = Join-Path $ConfigPath "$Environment.json"
            if (Test-Path $envConfigPath) {
                Write-Verbose "Loading environment configuration: $envConfigPath"
                $envConfigJson = Get-Content -Path $envConfigPath -Raw -ErrorAction Stop
                $envConfig = $envConfigJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop
                
                # Merge configurations
                $mergedConfig = Merge-Configuration -Base $defaultConfig -Override $envConfig
                Write-Verbose "Configuration merged with $Environment overrides"
                return [PSCustomObject]$mergedConfig
            }
            else {
                Write-Verbose "No environment-specific configuration found for: $Environment"
                return [PSCustomObject]$defaultConfig
            }
        }
        catch {
            Write-Error "Failed to load configuration: $_"
            throw
        }
    }
}

<#
.SYNOPSIS
    Merges two configuration objects recursively.

.DESCRIPTION
    Deep merges an override configuration into a base configuration,
    preserving values from the base that are not overridden.
    Arrays are replaced, not merged.

.PARAMETER Base
    Base configuration hashtable.

.PARAMETER Override
    Override configuration hashtable. Values from this object take precedence.

.EXAMPLE
    $merged = Merge-Configuration -Base $baseConfig -Override $envConfig

.OUTPUTS
    Hashtable - Merged configuration
#>
function Merge-Configuration {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Base,
        
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$Override
    )
    
    begin {
        Write-Verbose "Merging configuration objects"
    }
    
    process {
        # Handle null or empty override
        if ($null -eq $Override -or $Override.Count -eq 0) {
            Write-Verbose "Override is null or empty, returning base configuration"
            return $Base.Clone()
        }
        
        # Create a deep clone of the base configuration
        $result = @{}
        foreach ($key in $Base.Keys) {
            $value = $Base[$key]
            
            if ($value -is [hashtable]) {
                # Deep clone nested hashtables
                $result[$key] = $value.Clone()
            }
            elseif ($value -is [Array]) {
                # Clone arrays
                $result[$key] = $value.Clone()
            }
            else {
                # Copy value types and references
                $result[$key] = $value
            }
        }
        
        # Merge override values
        foreach ($key in $Override.Keys) {
            $overrideValue = $Override[$key]
            
            if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $overrideValue -is [hashtable]) {
                # Recursively merge nested hashtables
                Write-Verbose "Recursively merging key: $key"
                $result[$key] = Merge-Configuration -Base $result[$key] -Override $overrideValue
            }
            else {
                # Replace value (including arrays)
                Write-Verbose "Overriding key: $key"
                if ($overrideValue -is [hashtable]) {
                    $result[$key] = $overrideValue.Clone()
                }
                elseif ($overrideValue -is [Array]) {
                    $result[$key] = $overrideValue.Clone()
                }
                else {
                    $result[$key] = $overrideValue
                }
            }
        }
        
        return $result
    }
}

<#
.SYNOPSIS
    Validates configuration object against required schema.

.DESCRIPTION
    Checks that all required configuration fields are present and valid.
    Throws an exception if validation fails.

.PARAMETER Config
    Configuration object to validate (hashtable or PSCustomObject).

.EXAMPLE
    Test-Configuration -Config $config
    # Returns $true if valid, throws exception if invalid

.OUTPUTS
    Boolean - $true if configuration is valid
#>
function Test-Configuration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        $Config
    )
    
    begin {
        Write-Verbose "Validating configuration"
        $validBrowserTypes = @('chrome', 'msedge', 'firefox', 'webkit')
    }
    
    process {
        try {
            # Convert PSCustomObject to hashtable if needed
            $configHash = if ($Config -is [hashtable]) {
                $Config
            }
            elseif ($Config -is [PSCustomObject]) {
                $ht = @{}
                $Config.PSObject.Properties | ForEach-Object { $ht[$_.Name] = $_.Value }
                $ht
            }
            else {
                throw "Config must be a hashtable or PSCustomObject"
            }
            
            # Validate browser configuration
            if (-not $configHash.ContainsKey('browser')) {
                throw "Configuration missing required section: browser"
            }
            
            $browser = $configHash['browser']
            if ($browser -is [PSCustomObject]) {
                $browserHash = @{}
                $browser.PSObject.Properties | ForEach-Object { $browserHash[$_.Name] = $_.Value }
                $browser = $browserHash
            }
            
            if (-not $browser.ContainsKey('type')) {
                throw "Configuration missing required field: browser.type"
            }
            
            if ($browser['type'] -notin $validBrowserTypes) {
                throw "Invalid browser.type: $($browser['type']). Must be one of: $($validBrowserTypes -join ', ')"
            }
            
            # Validate kusto configuration
            if (-not $configHash.ContainsKey('kusto')) {
                throw "Configuration missing required section: kusto"
            }
            
            $kusto = $configHash['kusto']
            if ($kusto -is [PSCustomObject]) {
                $kustoHash = @{}
                $kusto.PSObject.Properties | ForEach-Object { $kustoHash[$_.Name] = $_.Value }
                $kusto = $kustoHash
            }
            
            if (-not $kusto.ContainsKey('baseUrl')) {
                throw "Configuration missing required field: kusto.baseUrl"
            }
            
            if ([string]::IsNullOrWhiteSpace($kusto['baseUrl'])) {
                throw "Configuration field kusto.baseUrl cannot be empty"
            }
            
            Write-Verbose "Configuration validation passed"
            return $true
        }
        catch {
            Write-Error "Configuration validation failed: $_"
            throw
        }
    }
}

# Export module members
Export-ModuleMember -Function Get-Configuration, Merge-Configuration, Test-Configuration
