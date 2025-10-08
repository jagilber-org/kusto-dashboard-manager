# Export-KustoDashboard.Tests.ps1
# Unit tests for Kusto Dashboard Export functionality
# TDD - RED Phase: Write tests first, expect failures

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\..\..\src\modules\Dashboard\Export-KustoDashboard.psm1"
    Import-Module $ModulePath -Force

    # Mock dependencies
    Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Export-KustoDashboard
    Mock Invoke-BrowserAction { return @{ Success = $true; Data = $null } } -ModuleName Export-KustoDashboard
    Mock Close-Browser { } -ModuleName Export-KustoDashboard
    Mock Get-Configuration { return @{ DefaultTimeout = 30000 } } -ModuleName Export-KustoDashboard
    Mock Write-AppLog { } -ModuleName Export-KustoDashboard
}

Describe "Export-KustoDashboard Module" {
    Context "Module Loading" {
        It "Should export Export-KustoDashboard function" {
            $Commands = Get-Command -Module Export-KustoDashboard
            $Commands.Name | Should -Contain 'Export-KustoDashboard'
        }

        It "Should have proper function metadata" {
            $Command = Get-Command Export-KustoDashboard
            $Command.CommandType | Should -Be 'Function'
        }
    }
}

Describe "Export-KustoDashboard" {
    BeforeEach {
        # Reset mocks before each test
        Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Export-KustoDashboard
        Mock Invoke-BrowserAction { return @{ Success = $true; Data = $null } } -ModuleName Export-KustoDashboard
        Mock Close-Browser { } -ModuleName Export-KustoDashboard
        Mock Write-AppLog { } -ModuleName Export-KustoDashboard
    }

    Context "Parameter Validation" {
        It "Should require DashboardUrl parameter" {
            $Command = Get-Command Export-KustoDashboard
            $Command.Parameters['DashboardUrl'].Attributes.Mandatory | Should -Be $true
        }

        It "Should require OutputPath parameter" {
            $Command = Get-Command Export-KustoDashboard
            $Command.Parameters['OutputPath'].Attributes.Mandatory | Should -Be $true
        }

        It "Should accept optional Browser parameter" {
            $Command = Get-Command Export-KustoDashboard
            $Command.Parameters.ContainsKey('Browser') | Should -Be $true
            $Command.Parameters['Browser'].Attributes.Mandatory | Should -Be $false
        }

        It "Should accept optional Headless parameter" {
            $Command = Get-Command Export-KustoDashboard
            $Command.Parameters.ContainsKey('Headless') | Should -Be $true
        }

        It "Should accept optional Timeout parameter" {
            $Command = Get-Command Export-KustoDashboard
            $Command.Parameters.ContainsKey('Timeout') | Should -Be $true
        }

        It "Should validate DashboardUrl format" {
            { Export-KustoDashboard -DashboardUrl "not-a-url" -OutputPath "C:\temp\test.json" } |
                Should -Throw "*valid URL*"
        }

        It "Should validate OutputPath has .json extension" {
            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "C:\temp\test.txt" } |
                Should -Throw "*.json*"
        }
    }

    Context "Browser Initialization" {
        It "Should initialize browser with default settings" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Initialize-Browser -ModuleName Export-KustoDashboard -Times 1
        }

        It "Should initialize browser with specified browser type" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" -Browser "chrome"

            Should -Invoke Initialize-Browser -ModuleName Export-KustoDashboard -ParameterFilter {
                $Browser -eq 'chrome'
            }
        }

        It "Should initialize browser in headless mode when specified" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" -Headless

            Should -Invoke Initialize-Browser -ModuleName Export-KustoDashboard -ParameterFilter {
                $Headless -eq $true
            }
        }

        It "Should throw error if browser initialization fails" {
            Mock Initialize-Browser { return @{ Success = $false; Error = "Browser failed to start" } } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*Browser failed to start*"
        }
    }

    Context "Dashboard Navigation" {
        It "Should navigate to dashboard URL" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Action -eq 'Navigate' -and $Parameters.Url -eq 'https://dataexplorer.azure.com/dashboards/123'
            }
        }

        It "Should wait for page load after navigation" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Action -eq 'WaitForElement'
            }
        }

        It "Should use custom timeout if specified" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" -Timeout 60000

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Action -eq 'WaitForElement' -and $Parameters.Timeout -eq 60000
            }
        }

        It "Should throw error if navigation fails" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'Navigate') {
                    return @{ Success = $false; Error = "Navigation timeout" }
                }
                return @{ Success = $true }
            } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*Navigation timeout*"
        }
    }

    Context "Dashboard Content Extraction" {
        It "Should extract dashboard name" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'GetText' -and $Parameters.Selector -like '*dashboard*name*') {
                    return @{ Success = $true; Data = "My Dashboard" }
                }
                return @{ Success = $true; Data = $null }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Action -eq 'GetText' -and $Parameters.Selector -ne $null
            }
        }

        It "Should extract dashboard tiles" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'Evaluate') {
                    return @{ 
                        Success = $true
                        Data = @(
                            @{ Title = "Tile 1"; Query = "KQL Query 1" }
                            @{ Title = "Tile 2"; Query = "KQL Query 2" }
                        )
                    }
                }
                return @{ Success = $true; Data = $null }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Action -eq 'Evaluate'
            }
        }

        It "Should extract dashboard metadata" {
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = "metadata-value" }
            } -ModuleName Export-KustoDashboard

            $Result = Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            $Result.DashboardName | Should -Not -BeNullOrEmpty
            $Result.ExportDate | Should -Not -BeNullOrEmpty
            $Result.SourceUrl | Should -Be "https://dataexplorer.azure.com/dashboards/123"
        }

        It "Should handle missing dashboard elements gracefully" {
            Mock Invoke-BrowserAction { 
                return @{ Success = $false; Error = "Element not found" }
            } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*Element not found*"
        }
    }

    Context "JSON Export" {
        It "Should create output directory if it doesn't exist" {
            $TestPath = Join-Path $TestDrive "subdir\test.json"
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            Test-Path (Split-Path $TestPath -Parent) | Should -Be $true
        }

        It "Should save dashboard as JSON file" {
            $TestPath = Join-Path $TestDrive "test.json"
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test Dashboard" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            Test-Path $TestPath | Should -Be $true
        }

        It "Should create valid JSON output" {
            $TestPath = Join-Path $TestDrive "test.json"
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            $Content = Get-Content $TestPath -Raw | ConvertFrom-Json
            $Content | Should -Not -BeNullOrEmpty
        }

        It "Should include all required fields in JSON" {
            $TestPath = Join-Path $TestDrive "test.json"
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            $Content = Get-Content $TestPath -Raw | ConvertFrom-Json
            $Content.PSObject.Properties.Name | Should -Contain 'DashboardName'
            $Content.PSObject.Properties.Name | Should -Contain 'SourceUrl'
            $Content.PSObject.Properties.Name | Should -Contain 'ExportDate'
        }

        It "Should overwrite existing file" {
            $TestPath = Join-Path $TestDrive "test.json"
            "old content" | Out-File $TestPath
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            $Content = Get-Content $TestPath -Raw
            $Content | Should -Not -Be "old content"
        }

        It "Should use UTF8 encoding for JSON file" {
            $TestPath = Join-Path $TestDrive "test.json"
            
            Mock Invoke-BrowserAction { 
                return @{ Success = $true; Data = @{ Name = "Test with émojis 🎉" } }
            } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            $Content = Get-Content $TestPath -Raw -Encoding UTF8
            $Content | Should -Match "émojis"
        }
    }

    Context "Browser Cleanup" {
        It "Should close browser after successful export" {
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{} } } -ModuleName Export-KustoDashboard
            Mock Close-Browser { } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Close-Browser -ModuleName Export-KustoDashboard -Times 1
        }

        It "Should close browser even after error" {
            Mock Invoke-BrowserAction { throw "Simulated error" } -ModuleName Export-KustoDashboard
            Mock Close-Browser { } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw

            Should -Invoke Close-Browser -ModuleName Export-KustoDashboard -Times 1
        }

        It "Should not suppress original error when cleanup fails" {
            Mock Invoke-BrowserAction { throw "Original error" } -ModuleName Export-KustoDashboard
            Mock Close-Browser { throw "Cleanup error" } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*Original error*"
        }
    }

    Context "Return Value" {
        It "Should return export result object" {
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{ Name = "Test" } } } -ModuleName Export-KustoDashboard

            $Result = Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            $Result | Should -Not -BeNullOrEmpty
            $Result.PSObject.TypeNames[0] | Should -BeLike '*ExportResult*'
        }

        It "Should include success status in result" {
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{ Name = "Test" } } } -ModuleName Export-KustoDashboard

            $Result = Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            $Result.Success | Should -Be $true
        }

        It "Should include output path in result" {
            $TestPath = Join-Path $TestDrive "test.json"
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{ Name = "Test" } } } -ModuleName Export-KustoDashboard

            $Result = Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath $TestPath

            $Result.OutputPath | Should -Be $TestPath
        }

        It "Should include dashboard metadata in result" {
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{ Name = "Test Dashboard" } } } -ModuleName Export-KustoDashboard

            $Result = Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            $Result.DashboardName | Should -Not -BeNullOrEmpty
            $Result.SourceUrl | Should -Be "https://dataexplorer.azure.com/dashboards/123"
        }
    }

    Context "Logging Integration" {
        It "Should log export start" {
            Mock Write-AppLog { } -ModuleName Export-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{} } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Write-AppLog -ModuleName Export-KustoDashboard -ParameterFilter {
                $Level -eq 'Info' -and $Message -like "*Starting export*"
            }
        }

        It "Should log export completion" {
            Mock Write-AppLog { } -ModuleName Export-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{} } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Write-AppLog -ModuleName Export-KustoDashboard -ParameterFilter {
                $Level -eq 'Info' -and $Message -like "*Export completed*"
            }
        }

        It "Should log errors" {
            Mock Write-AppLog { } -ModuleName Export-KustoDashboard
            Mock Invoke-BrowserAction { throw "Test error" } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw

            Should -Invoke Write-AppLog -ModuleName Export-KustoDashboard -ParameterFilter {
                $Level -eq 'Error'
            }
        }
    }

    Context "Configuration Integration" -Skip {
        # Skipped - external dependency on Configuration module
        It "Should use timeout from configuration if not specified" {
            Mock Get-Configuration { return @{ Dashboard = @{ DefaultTimeout = 45000 } } } -ModuleName Export-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true; Data = @{} } } -ModuleName Export-KustoDashboard

            Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json"

            Should -Invoke Invoke-BrowserAction -ModuleName Export-KustoDashboard -ParameterFilter {
                $Parameters.Timeout -eq 45000
            }
        }
    }

    Context "Error Handling" {
        It "Should provide clear error message for invalid URL" {
            { Export-KustoDashboard -DashboardUrl "invalid" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*valid URL*"
        }

        It "Should provide clear error message for invalid output path" {
            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "C:\invalid\:\path.json" } |
                Should -Throw
        }

        It "Should handle network errors gracefully" {
            Mock Invoke-BrowserAction { throw "Network error: Connection refused" } -ModuleName Export-KustoDashboard

            { Export-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -OutputPath "TestDrive:\test.json" } |
                Should -Throw "*Network error*"
        }
    }
}
