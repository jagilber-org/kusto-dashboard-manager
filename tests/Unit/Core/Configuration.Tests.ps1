# Configuration Module Unit Tests
# Test-Driven Development: RED phase - Write failing tests first

BeforeAll {
    # Import the module under test (will fail initially - that's expected in TDD)
    $ModulePath = Join-Path $PSScriptRoot '..' '..' '..' 'src' 'modules' 'Core' 'Configuration.psm1'
    
    # Create test config files
    $script:TestConfigDir = Join-Path $TestDrive 'config'
    New-Item -Path $script:TestConfigDir -ItemType Directory -Force | Out-Null
    
    # Create test default.json
    $defaultConfig = @{
        browser = @{
            type = "msedge"
            headless = $false
            timeout = 30000
        }
        kusto = @{
            baseUrl = "https://dataexplorer.azure.com"
            dashboardsPath = "/dashboards"
        }
        logging = @{
            level = "INFO"
            path = "./logs"
        }
    } | ConvertTo-Json -Depth 10
    $defaultConfig | Out-File (Join-Path $script:TestConfigDir 'default.json') -Encoding UTF8
    
    # Create test development.json (overrides)
    $devConfig = @{
        browser = @{
            headless = $true
        }
        logging = @{
            level = "DEBUG"
        }
    } | ConvertTo-Json -Depth 10
    $devConfig | Out-File (Join-Path $script:TestConfigDir 'development.json') -Encoding UTF8
    
    # Create test production.json
    $prodConfig = @{
        browser = @{
            headless = $true
            timeout = 60000
        }
        logging = @{
            level = "ERROR"
        }
    } | ConvertTo-Json -Depth 10
    $prodConfig | Out-File (Join-Path $script:TestConfigDir 'production.json') -Encoding UTF8
}

Describe "Configuration Module" -Tag 'Unit', 'Core' {
    
    Context "Module Loading" {
        It "Should export Get-Configuration function" {
            $ModulePath | Should -Exist
            # Module should be importable
            { Import-Module $ModulePath -Force -ErrorAction Stop } | Should -Not -Throw
            Get-Command -Name Get-Configuration -Module Configuration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Merge-Configuration function" {
            Get-Command -Name Merge-Configuration -Module Configuration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Test-Configuration function" {
            Get-Command -Name Test-Configuration -Module Configuration -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-Configuration" {
        It "Should load default configuration when no environment specified" {
            $config = Get-Configuration -ConfigPath $script:TestConfigDir
            $config | Should -Not -BeNullOrEmpty
            $config.browser | Should -Not -BeNullOrEmpty
            $config.browser.type | Should -Be "msedge"
        }
        
        It "Should load and merge development configuration" {
            $config = Get-Configuration -ConfigPath $script:TestConfigDir -Environment 'development'
            $config | Should -Not -BeNullOrEmpty
            $config.browser.headless | Should -Be $true
            $config.logging.level | Should -Be "DEBUG"
            # Should preserve default values not overridden
            $config.browser.type | Should -Be "msedge"
            $config.browser.timeout | Should -Be 30000
        }
        
        It "Should load and merge production configuration" {
            $config = Get-Configuration -ConfigPath $script:TestConfigDir -Environment 'production'
            $config | Should -Not -BeNullOrEmpty
            $config.browser.headless | Should -Be $true
            $config.browser.timeout | Should -Be 60000
            $config.logging.level | Should -Be "ERROR"
        }
        
        It "Should throw error if default.json not found" {
            $invalidPath = Join-Path $TestDrive 'nonexistent'
            { Get-Configuration -ConfigPath $invalidPath -ErrorAction Stop } | Should -Throw
        }
        
        It "Should throw error for invalid JSON in default.json" {
            $badConfigPath = Join-Path $TestDrive 'badconfig'
            New-Item -Path $badConfigPath -ItemType Directory -Force | Out-Null
            "{ invalid json" | Out-File (Join-Path $badConfigPath 'default.json') -Encoding UTF8
            { Get-Configuration -ConfigPath $badConfigPath -ErrorAction Stop } | Should -Throw
        }
    }
    
    Context "Merge-Configuration" {
        It "Should merge two configurations without overwriting unspecified values" {
            $base = @{
                browser = @{ type = "chrome"; headless = $false; timeout = 30000 }
                logging = @{ level = "INFO"; path = "./logs" }
            }
            $override = @{
                browser = @{ headless = $true }
            }
            
            $merged = Merge-Configuration -Base $base -Override $override
            $merged.browser.type | Should -Be "chrome"
            $merged.browser.headless | Should -Be $true
            $merged.browser.timeout | Should -Be 30000
            $merged.logging.level | Should -Be "INFO"
        }
        
        It "Should handle nested object merging" {
            $base = @{
                section = @{
                    subsection = @{
                        value1 = "original"
                        value2 = "keep"
                    }
                }
            }
            $override = @{
                section = @{
                    subsection = @{
                        value1 = "overridden"
                    }
                }
            }
            
            $merged = Merge-Configuration -Base $base -Override $override
            $merged.section.subsection.value1 | Should -Be "overridden"
            $merged.section.subsection.value2 | Should -Be "keep"
        }
        
        It "Should handle null or empty override gracefully" {
            $base = @{ key = "value" }
            $merged = Merge-Configuration -Base $base -Override $null
            $merged.key | Should -Be "value"
        }
        
        It "Should handle array values by replacing (not merging arrays)" {
            $base = @{ items = @(1, 2, 3) }
            $override = @{ items = @(4, 5) }
            
            $merged = Merge-Configuration -Base $base -Override $override
            $merged.items.Count | Should -Be 2
            $merged.items[0] | Should -Be 4
        }
    }
    
    Context "Test-Configuration" {
        It "Should validate required browser configuration" {
            $validConfig = @{
                browser = @{
                    type = "msedge"
                    headless = $false
                    timeout = 30000
                }
                kusto = @{
                    baseUrl = "https://dataexplorer.azure.com"
                }
                logging = @{
                    level = "INFO"
                    path = "./logs"
                }
            }
            
            { Test-Configuration -Config $validConfig -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should fail validation if browser section is missing" {
            $invalidConfig = @{
                kusto = @{ baseUrl = "https://test.com" }
            }
            
            { Test-Configuration -Config $invalidConfig -ErrorAction Stop } | Should -Throw
        }
        
        It "Should fail validation if browser.type is missing" {
            $invalidConfig = @{
                browser = @{ headless = $false }
                kusto = @{ baseUrl = "https://test.com" }
            }
            
            { Test-Configuration -Config $invalidConfig -ErrorAction Stop } | Should -Throw
        }
        
        It "Should fail validation if kusto.baseUrl is missing" {
            $invalidConfig = @{
                browser = @{ type = "msedge"; headless = $false }
                kusto = @{ }
            }
            
            { Test-Configuration -Config $invalidConfig -ErrorAction Stop } | Should -Throw
        }
        
        It "Should validate browser.type is one of allowed values" {
            $invalidConfig = @{
                browser = @{ type = "invalid-browser"; headless = $false }
                kusto = @{ baseUrl = "https://test.com" }
            }
            
            { Test-Configuration -Config $invalidConfig -ErrorAction Stop } | Should -Throw
        }
        
        It "Should return $true for valid configuration" {
            $validConfig = @{
                browser = @{ type = "msedge"; headless = $false; timeout = 30000 }
                kusto = @{ baseUrl = "https://dataexplorer.azure.com" }
                logging = @{ level = "INFO"; path = "./logs" }
            }
            
            $result = Test-Configuration -Config $validConfig
            $result | Should -Be $true
        }
    }
    
    Context "Integration: Load and Validate" {
        It "Should load development config and pass validation" {
            $config = Get-Configuration -ConfigPath $script:TestConfigDir -Environment 'development'
            { Test-Configuration -Config $config -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should load production config and pass validation" {
            $config = Get-Configuration -ConfigPath $script:TestConfigDir -Environment 'production'
            { Test-Configuration -Config $config -ErrorAction Stop } | Should -Not -Throw
        }
    }
}
