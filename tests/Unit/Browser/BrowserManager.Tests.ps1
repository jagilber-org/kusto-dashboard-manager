# BrowserManager.Tests.ps1 - TDD tests for Browser Manager Module
# Following TDD: RED → GREEN → REFACTOR

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..\..\..\src\modules\Browser\BrowserManager.psm1'
    Import-Module $ModulePath -Force
}

Describe "BrowserManager Module" {
    
    Context "Module Loading" {
        
        It "Should export Initialize-Browser function" {
            Get-Command Initialize-Browser -Module BrowserManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Invoke-BrowserAction function" {
            Get-Command Invoke-BrowserAction -Module BrowserManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-BrowserState function" {
            Get-Command Get-BrowserState -Module BrowserManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Close-Browser function" {
            Get-Command Close-Browser -Module BrowserManager -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Initialize-Browser" {
        BeforeEach {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
        }
        
        It "Should initialize browser with default settings" {
            { Initialize-Browser -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should initialize browser with Edge browser" {
            { Initialize-Browser -Browser 'edge' -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should initialize browser with work profile" {
            { Initialize-Browser -Browser 'edge' -ProfilePath 'C:\Users\test\AppData\Local\Microsoft\Edge\User Data' -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should initialize browser in headless mode" {
            { Initialize-Browser -Headless -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should validate browser type" {
            { Initialize-Browser -Browser 'invalid-browser' -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle initialization failure" {
            Mock Invoke-MCPTool { throw "Browser launch failed" } -ModuleName BrowserManager
            
            { Initialize-Browser -ErrorAction Stop } | Should -Throw "*Browser launch failed*"
        }
        
        It "Should store browser session state" {
            Initialize-Browser
            
            $state = Get-BrowserState
            $state | Should -Not -BeNullOrEmpty
            $state.IsInitialized | Should -Be $true
        }
    }
    
    Context "Invoke-BrowserAction - Navigation" {
        BeforeEach {
            Initialize-Browser
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
        }
        
        It "Should navigate to URL" {
            { Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://dataexplorer.azure.com' } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should validate URL parameter for navigation" {
            { Invoke-BrowserAction -Action 'Navigate' -Parameters @{ } -ErrorAction Stop } | Should -Throw
        }
        
        It "Should handle navigation timeout" {
            Mock Invoke-MCPTool { throw "Navigation timeout" } -ModuleName BrowserManager
            
            { Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://example.com' } -ErrorAction Stop } | Should -Throw "*timeout*"
        }
        
        It "Should wait for navigation to complete" {
            Mock Invoke-MCPTool { 
                Start-Sleep -Milliseconds 100
                return @{ success = $true; loaded = $true }
            } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://example.com' }
            $result.loaded | Should -Be $true
        }
    }
    
    Context "Invoke-BrowserAction - Element Interaction" {
        BeforeEach {
            Initialize-Browser
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
        }
        
        It "Should click element by selector" {
            { Invoke-BrowserAction -Action 'Click' -Parameters @{ selector = 'button.submit' } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should type text into element" {
            { Invoke-BrowserAction -Action 'Type' -Parameters @{ selector = 'input#username'; text = 'testuser' } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should get element text" {
            Mock Invoke-MCPTool { return @{ success = $true; text = 'Dashboard Title' } } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'GetText' -Parameters @{ selector = 'h1.title' }
            $result.text | Should -Be 'Dashboard Title'
        }
        
        It "Should wait for element to appear" {
            { Invoke-BrowserAction -Action 'WaitForElement' -Parameters @{ selector = 'div.loaded'; timeout = 5000 } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle element not found" {
            Mock Invoke-MCPTool { throw "Element not found: invalid-selector" } -ModuleName BrowserManager
            
            { Invoke-BrowserAction -Action 'Click' -Parameters @{ selector = 'invalid-selector' } -ErrorAction Stop } | Should -Throw "*not found*"
        }
    }
    
    Context "Invoke-BrowserAction - Page Content" {
        BeforeEach {
            Initialize-Browser
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
        }
        
        It "Should get page HTML" {
            Mock Invoke-MCPTool { return @{ success = $true; html = '<html><body>Test</body></html>' } } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'GetHTML'
            $result.html | Should -BeLike '*<body>*'
        }
        
        It "Should take screenshot" {
            Mock Invoke-MCPTool { return @{ success = $true; screenshot = 'base64data...' } } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'Screenshot' -Parameters @{ path = 'test.png' }
            $result.screenshot | Should -Not -BeNullOrEmpty
        }
        
        It "Should evaluate JavaScript" {
            Mock Invoke-MCPTool { return @{ success = $true; result = 'Test Dashboard' } } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'Evaluate' -Parameters @{ script = 'document.title' }
            $result.result | Should -Be 'Test Dashboard'
        }
    }
    
    Context "Invoke-BrowserAction - Advanced Features" {
        BeforeEach {
            Initialize-Browser
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
        }
        
        It "Should handle file upload" {
            { Invoke-BrowserAction -Action 'Upload' -Parameters @{ selector = 'input[type=file]'; filePath = 'C:\test\file.json' } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle dialog accept" {
            { Invoke-BrowserAction -Action 'HandleDialog' -Parameters @{ accept = $true } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should switch to frame" {
            { Invoke-BrowserAction -Action 'SwitchFrame' -Parameters @{ selector = 'iframe#content' } -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should get network requests" {
            Mock Invoke-MCPTool { return @{ success = $true; requests = @(@{ url = 'https://api.example.com/data' }) } } -ModuleName BrowserManager
            
            $result = Invoke-BrowserAction -Action 'GetNetworkRequests'
            $result.requests | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-BrowserState" {
        
        It "Should return not initialized before Initialize-Browser" {
            # Reset state
            Close-Browser -ErrorAction SilentlyContinue
            
            $state = Get-BrowserState
            $state.IsInitialized | Should -Be $false
        }
        
        It "Should return initialized after Initialize-Browser" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser
            
            $state = Get-BrowserState
            $state.IsInitialized | Should -Be $true
        }
        
        It "Should track current URL" {
            Mock Invoke-MCPTool { return @{ success = $true; url = 'https://dataexplorer.azure.com' } } -ModuleName BrowserManager
            Initialize-Browser
            Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://dataexplorer.azure.com' }
            
            $state = Get-BrowserState
            $state.CurrentUrl | Should -Be 'https://dataexplorer.azure.com'
        }
        
        It "Should track browser type" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser -Browser 'edge'
            
            $state = Get-BrowserState
            $state.Browser | Should -Be 'edge'
        }
        
        It "Should track headless mode" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser -Headless
            
            $state = Get-BrowserState
            $state.Headless | Should -Be $true
        }
    }
    
    Context "Close-Browser" {
        
        It "Should close browser successfully" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser
            
            { Close-Browser -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle browser not initialized" {
            # Ensure browser is not initialized
            try { Close-Browser -ErrorAction SilentlyContinue } catch { }
            
            # Calling Close-Browser when not initialized should throw
            { Close-Browser -ErrorAction Stop } | Should -Throw "*not initialized*"
        }
        
        It "Should reset browser state after close" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser
            Close-Browser
            
            $state = Get-BrowserState
            $state.IsInitialized | Should -Be $false
        }
        
        It "Should cleanup resources on error" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser
            Mock Invoke-MCPTool { throw "Close failed" } -ModuleName BrowserManager
            
            try {
                Close-Browser -ErrorAction Stop
            } catch {
                # Expected
            }
            
            # State should still be reset even on error
            $state = Get-BrowserState
            $state.IsInitialized | Should -Be $false
        }
    }
    
    Context "Error Handling" {
        
        It "Should require initialization before actions" {
            # Ensure browser is closed first
            try { Close-Browser -ErrorAction SilentlyContinue } catch { }
            
            { Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://example.com' } -ErrorAction Stop } | Should -Throw "*not initialized*"
        }
        
        It "Should validate action names" {
            Mock Invoke-MCPTool { return @{ success = $true } } -ModuleName BrowserManager
            Initialize-Browser
            
            { Invoke-BrowserAction -Action 'InvalidAction' -Parameters @{ } -ErrorAction Stop } | Should -Throw
        }
        
        It "Should provide detailed error messages" {
            Mock Invoke-MCPTool { 
                throw "Detailed error: Element '#non-existent' not found on page"
            } -ModuleName BrowserManager
            Initialize-Browser
            
            try {
                Invoke-BrowserAction -Action 'Click' -Parameters @{ selector = '#non-existent' } -ErrorAction Stop
            } catch {
                $_.Exception.Message | Should -BeLike "*Detailed error*"
            }
        }
    }
    
    Context "MCP Integration" {
        
        It "Should use Playwright MCP server" {
            Mock Invoke-MCPTool { 
                param($Server, $Tool, $Parameters)
                $Server | Should -Be 'playwright'
                return @{ success = $true }
            } -ModuleName BrowserManager
            
            Initialize-Browser
        }
        
        It "Should pass correct tool names to MCP" {
            Mock Invoke-MCPTool { 
                param($Server, $Tool, $Parameters)
                $Tool | Should -Be 'browser_navigate'
                return @{ success = $true }
            } -ModuleName BrowserManager
            Initialize-Browser
            
            Invoke-BrowserAction -Action 'Navigate' -Parameters @{ url = 'https://example.com' }
        }
        
        It "Should handle MCP server unavailable" {
            # Close any existing browser to force new initialization
            try { Close-Browser -ErrorAction SilentlyContinue } catch { }
            
            Mock Invoke-MCPTool { throw "MCP server 'playwright' not available" } -ModuleName BrowserManager
            
            { Initialize-Browser -ErrorAction Stop } | Should -Throw "*playwright*"
        }
    }
    
    Context "Configuration Integration" {
        
        It "Should use configuration for default browser" {
            # Skip: Get-Configuration is external dependency
            # In real usage, Configuration module would be loaded
            Set-ItResult -Skipped -Because "Get-Configuration is external dependency"
        }
        
        It "Should override configuration with parameters" {
            # Skip: Get-Configuration is external dependency
            # In real usage, Configuration module would be loaded
            Set-ItResult -Skipped -Because "Get-Configuration is external dependency"
        }
    }
    
    Context "Performance" {
        
        It "Should cache browser instance" {
            # Close any existing browser first
            try { Close-Browser -ErrorAction SilentlyContinue } catch { }
            
            Mock Invoke-MCPTool { return @{ success = $true; sessionId = 'test123' } } -ModuleName BrowserManager
            Initialize-Browser
            
            # Second call should use cached instance (no additional MCP call)
            Initialize-Browser
            
            # Only 1 MCP call should have been made (first initialization)
            Should -Invoke Invoke-MCPTool -ModuleName BrowserManager -Times 1 -Exactly
        }
        
        It "Should handle rapid action calls" {
            # Close any existing browser first
            try { Close-Browser -ErrorAction SilentlyContinue } catch { }
            
            Mock Invoke-MCPTool { return @{ success = $true; sessionId = 'test123' } } -ModuleName BrowserManager
            Initialize-Browser
            
            1..5 | ForEach-Object {
                Invoke-BrowserAction -Action 'GetHTML'
            }
            
            # 1 init + 5 actions = 6 total MCP calls
            Should -Invoke Invoke-MCPTool -ModuleName BrowserManager -Times 6 -Exactly
        }
    }
}
