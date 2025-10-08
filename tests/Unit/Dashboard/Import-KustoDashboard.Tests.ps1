# Import-KustoDashboard.Tests.ps1
# Unit tests for Kusto Dashboard Import functionality
# TDD - RED Phase: Write tests first, expect failures

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot "..\..\..\src\modules\Dashboard\Import-KustoDashboard.psm1"
    Import-Module $ModulePath -Force

    # Mock dependencies
    Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Import-KustoDashboard
    Mock Invoke-BrowserAction { return @{ Success = $true; Data = $null } } -ModuleName Import-KustoDashboard
    Mock Close-Browser { } -ModuleName Import-KustoDashboard
    Mock Get-Configuration { return @{ DefaultTimeout = 30000 } } -ModuleName Import-KustoDashboard
    Mock Write-AppLog { } -ModuleName Import-KustoDashboard
}

Describe "Import-KustoDashboard Module" {
    Context "Module Loading" {
        It "Should export Import-KustoDashboard function" {
            $Commands = Get-Command -Module Import-KustoDashboard
            $Commands.Name | Should -Contain 'Import-KustoDashboard'
        }

        It "Should have proper function metadata" {
            $Command = Get-Command Import-KustoDashboard
            $Command.CommandType | Should -Be 'Function'
        }
    }
}

Describe "Import-KustoDashboard" {
    BeforeEach {
        # Reset mocks before each test
        Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Import-KustoDashboard
        Mock Invoke-BrowserAction { return @{ Success = $true; Data = $null } } -ModuleName Import-KustoDashboard
        Mock Close-Browser { } -ModuleName Import-KustoDashboard
        Mock Write-AppLog { } -ModuleName Import-KustoDashboard
    }

    Context "Parameter Validation" {
        It "Should require DashboardUrl parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters['DashboardUrl'].Attributes.Mandatory | Should -Be $true
        }

        It "Should require InputPath parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters['InputPath'].Attributes.Mandatory | Should -Be $true
        }

        It "Should accept optional Browser parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters.ContainsKey('Browser') | Should -Be $true
            $Command.Parameters['Browser'].Attributes.Mandatory | Should -Be $false
        }

        It "Should accept optional Headless parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters.ContainsKey('Headless') | Should -Be $true
        }

        It "Should accept optional Timeout parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters.ContainsKey('Timeout') | Should -Be $true
        }

        It "Should accept optional Force parameter" {
            $Command = Get-Command Import-KustoDashboard
            $Command.Parameters.ContainsKey('Force') | Should -Be $true
        }

        It "Should validate DashboardUrl format" {
            $TestFile = Join-Path $TestDrive "test.json"
            '{"DashboardName":"Test"}' | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "not-a-url" -InputPath $TestFile } |
                Should -Throw "*valid URL*"
        }

        It "Should validate InputPath exists" {
            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath "C:\nonexistent.json" } |
                Should -Throw "*not found*"
        }

        It "Should validate InputPath has .json extension" {
            $TestFile = Join-Path $TestDrive "test.txt"
            "test content" | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile } |
                Should -Throw "*.json*"
        }
    }

    Context "JSON File Validation" {
        It "Should validate JSON file is valid JSON" {
            $TestFile = Join-Path $TestDrive "invalid.json"
            "not valid json {" | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile } |
                Should -Throw "*JSON*"
        }

        It "Should validate JSON contains required DashboardName field" {
            $TestFile = Join-Path $TestDrive "missing-name.json"
            '{"SomeField":"value"}' | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile } |
                Should -Throw "*DashboardName*"
        }

        It "Should validate JSON contains Tiles array" {
            $TestFile = Join-Path $TestDrive "missing-tiles.json"
            '{"DashboardName":"Test"}' | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile } |
                Should -Throw "*Tiles*"
        }

        It "Should accept valid dashboard JSON" {
            $TestFile = Join-Path $TestDrive "valid.json"
            @{
                DashboardName = "Test Dashboard"
                Tiles = @(
                    @{ Title = "Tile 1"; Type = "query" }
                )
            } | ConvertTo-Json -Depth 10 | Out-File $TestFile

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile } |
                Should -Not -Throw
        }
    }

    Context "Browser Initialization" {
        BeforeEach {
            $TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $TestFile
        }

        It "Should initialize browser with default settings" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json")

            Should -Invoke Initialize-Browser -ModuleName Import-KustoDashboard -Times 1
        }

        It "Should initialize browser with specified browser type" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json") -Browser "chrome"

            Should -Invoke Initialize-Browser -ModuleName Import-KustoDashboard -ParameterFilter {
                $Browser -eq 'chrome'
            }
        }

        It "Should initialize browser in headless mode when specified" {
            Mock Initialize-Browser { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json") -Headless

            Should -Invoke Initialize-Browser -ModuleName Import-KustoDashboard -ParameterFilter {
                $Headless -eq $true
            }
        }

        It "Should throw error if browser initialization fails" {
            Mock Initialize-Browser { return @{ Success = $false; Error = "Browser failed to start" } } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json") } |
                Should -Throw "*Browser failed to start*"
        }
    }

    Context "Dashboard Navigation" {
        BeforeEach {
            $TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $TestFile
        }

        It "Should navigate to dashboard URL" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json")

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Navigate' -and $Parameters.Url -eq 'https://dataexplorer.azure.com/dashboards/123'
            }
        }

        It "Should wait for page load after navigation" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json")

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'WaitForElement'
            }
        }

        It "Should use custom timeout if specified" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json") -Timeout 60000

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'WaitForElement' -and $Parameters.Timeout -eq 60000
            }
        }

        It "Should throw error if navigation fails" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'Navigate') {
                    return @{ Success = $false; Error = "Navigation timeout" }
                }
                return @{ Success = $true }
            } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath (Join-Path $TestDrive "test.json") } |
                Should -Throw "*Navigation timeout*"
        }
    }

    Context "Dashboard Import Actions" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test Dashboard"
                Tiles = @(
                    @{ Title = "Tile 1"; Type = "query" }
                    @{ Title = "Tile 2"; Type = "markdown" }
                )
            } | ConvertTo-Json -Depth 10 | Out-File $script:TestFile
        }

        It "Should click on edit/import button" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Click'
            }
        }

        It "Should locate import JSON input field" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Type' -or $Action -eq 'Click'
            }
        }

        It "Should paste dashboard JSON content" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Type' -and $Parameters.Text -ne $null
            }
        }

        It "Should click submit/save button" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Click'
            } -Times 2 -Because "Should click edit and submit buttons"
        }

        It "Should wait for import confirmation" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'WaitForElement'
            } -Times 2 -Because "Should wait for dashboard load and import confirmation"
        }
    }

    Context "Force Overwrite Handling" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $script:TestFile
        }

        It "Should detect existing dashboard conflict" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'GetText' -and $Parameters.Selector -like '*conflict*') {
                    return @{ Success = $true; Data = "Dashboard already exists" }
                }
                return @{ Success = $true }
            } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw "*already exists*"
        }

        It "Should overwrite when Force parameter is specified" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile -Force } |
                Should -Not -Throw
        }

        It "Should click overwrite confirmation when Force is used" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile -Force

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Action -eq 'Click'
            }
        }
    }

    Context "Error Handling" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $script:TestFile
        }

        It "Should provide clear error message for invalid URL" {
            { Import-KustoDashboard -DashboardUrl "invalid" -InputPath $script:TestFile } |
                Should -Throw "*valid URL*"
        }

        It "Should handle import failure gracefully" {
            Mock Invoke-BrowserAction { 
                if ($Action -eq 'Type') {
                    return @{ Success = $false; Error = "Input field not found" }
                }
                return @{ Success = $true }
            } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw "*Input field not found*"
        }

        It "Should handle network errors gracefully" {
            Mock Invoke-BrowserAction { throw "Network error: Connection refused" } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw "*Network error*"
        }
    }

    Context "Browser Cleanup" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $script:TestFile
        }

        It "Should close browser after successful import" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard
            Mock Close-Browser { } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Close-Browser -ModuleName Import-KustoDashboard -Times 1
        }

        It "Should close browser even after error" {
            Mock Invoke-BrowserAction { throw "Simulated error" } -ModuleName Import-KustoDashboard
            Mock Close-Browser { } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw

            Should -Invoke Close-Browser -ModuleName Import-KustoDashboard -Times 1
        }

        It "Should not suppress original error when cleanup fails" {
            Mock Invoke-BrowserAction { throw "Original error" } -ModuleName Import-KustoDashboard
            Mock Close-Browser { throw "Cleanup error" } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw "*Original error*"
        }
    }

    Context "Return Value" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test Dashboard"
                Tiles = @()
            } | ConvertTo-Json | Out-File $script:TestFile
        }

        It "Should return import result object" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $Result = Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            $Result | Should -Not -BeNullOrEmpty
            $Result.PSObject.TypeNames[0] | Should -BeLike '*ImportResult*'
        }

        It "Should include success status in result" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $Result = Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            $Result.Success | Should -Be $true
        }

        It "Should include dashboard name in result" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $Result = Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            $Result.DashboardName | Should -Be "Test Dashboard"
        }

        It "Should include target URL in result" {
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $Result = Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            $Result.TargetUrl | Should -Be "https://dataexplorer.azure.com/dashboards/123"
        }

        It "Should include tile count in result" {
            $TestFile2 = Join-Path $TestDrive "test2.json"
            @{
                DashboardName = "Test"
                Tiles = @(
                    @{ Title = "Tile 1" }
                    @{ Title = "Tile 2" }
                    @{ Title = "Tile 3" }
                )
            } | ConvertTo-Json -Depth 10 | Out-File $TestFile2

            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $Result = Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile2

            $Result.TileCount | Should -Be 3
        }
    }

    Context "Logging Integration" {
        BeforeEach {
            $script:TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $script:TestFile
        }

        It "Should log import start" {
            Mock Write-AppLog { } -ModuleName Import-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Write-AppLog -ModuleName Import-KustoDashboard -ParameterFilter {
                $Level -eq 'Info' -and $Message -like "*Starting import*"
            }
        }

        It "Should log import completion" {
            Mock Write-AppLog { } -ModuleName Import-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile

            Should -Invoke Write-AppLog -ModuleName Import-KustoDashboard -ParameterFilter {
                $Level -eq 'Info' -and $Message -like "*Import completed*"
            }
        }

        It "Should log errors" {
            Mock Write-AppLog { } -ModuleName Import-KustoDashboard
            Mock Invoke-BrowserAction { throw "Test error" } -ModuleName Import-KustoDashboard

            { Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $script:TestFile } |
                Should -Throw

            Should -Invoke Write-AppLog -ModuleName Import-KustoDashboard -ParameterFilter {
                $Level -eq 'Error'
            }
        }
    }

    Context "Configuration Integration" -Skip {
        # Skipped - external dependency on Configuration module
        It "Should use timeout from configuration if not specified" {
            Mock Get-Configuration { return @{ Dashboard = @{ DefaultTimeout = 45000 } } } -ModuleName Import-KustoDashboard
            Mock Invoke-BrowserAction { return @{ Success = $true } } -ModuleName Import-KustoDashboard

            $TestFile = Join-Path $TestDrive "test.json"
            @{
                DashboardName = "Test"
                Tiles = @()
            } | ConvertTo-Json | Out-File $TestFile

            Import-KustoDashboard -DashboardUrl "https://dataexplorer.azure.com/dashboards/123" -InputPath $TestFile

            Should -Invoke Invoke-BrowserAction -ModuleName Import-KustoDashboard -ParameterFilter {
                $Parameters.Timeout -eq 45000
            }
        }
    }
}
