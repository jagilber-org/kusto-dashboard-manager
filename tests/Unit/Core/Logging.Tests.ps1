# Logging.Tests.ps1
# Tests for Logging module

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..\..\..\src\modules\Core\Logging.psm1'
    
    # Create test log directory
    $script:TestLogDir = Join-Path ([System.IO.Path]::GetTempPath()) (New-Guid).ToString()
    New-Item -Path $script:TestLogDir -ItemType Directory -Force | Out-Null
    
    # Helper function to get last log entry (avoids PowerShell array gotcha)
    function Get-LastLogEntry {
        param([string]$LogPath)
        $content = Get-Content $LogPath -Raw
        if (-not $content) { return $null }
        $lines = $content.Trim() -split "`n"
        $lines = $lines | Where-Object { $_.Trim() }
        if ($lines.Count -eq 0) { return $null }
        if ($lines -is [array]) {
            return ($lines[-1] | ConvertFrom-Json)
        } else {
            return ($lines | ConvertFrom-Json)
        }
    }
    
    # Mock Get-Date for consistent timestamps in tests
    Mock Get-Date { return [datetime]'2025-10-08T12:00:00' } -ModuleName Logging
}

AfterAll {
    # Cleanup test directory
    if (Test-Path $script:TestLogDir) {
        Remove-Item -Path $script:TestLogDir -Recurse -Force
    }
}

Describe "Logging Module" -Tag 'Unit', 'Core' {
    
    Context "Module Loading" {
        It "Should export Write-AppLog function" {
            $ModulePath | Should -Exist
            Import-Module $ModulePath -Force
            Get-Command -Name Write-AppLog -Module Logging -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Initialize-LogFile function" {
            Get-Command -Name Initialize-LogFile -Module Logging -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-LogContext function" {
            Get-Command -Name Get-LogContext -Module Logging -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Initialize-LogFile" {
        
        It "Should create log directory if it doesn't exist" {
            $logPath = Join-Path $script:TestLogDir 'logs\test-create.log'
            
            { Initialize-LogFile -LogPath $logPath -ErrorAction Stop } | Should -Not -Throw
            
            $logDir = Split-Path $logPath -Parent
            Test-Path $logDir | Should -Be $true
        }
        
        It "Should create log file if it doesn't exist" {
            $logPath = Join-Path $script:TestLogDir 'test-new.log'
            
            Initialize-LogFile -LogPath $logPath
            
            Test-Path $logPath | Should -Be $true
        }
        
        It "Should not overwrite existing log file" {
            $logPath = Join-Path $script:TestLogDir 'test-existing.log'
            "existing content" | Out-File $logPath
            $originalContent = Get-Content $logPath -Raw
            
            Initialize-LogFile -LogPath $logPath
            
            $newContent = Get-Content $logPath -Raw
            $newContent | Should -Be $originalContent
        }
        
        It "Should rotate log file when size exceeds MaxSizeKB" {
            $logPath = Join-Path $script:TestLogDir 'test-rotate.log'
            
            # Create a large file (> 1KB)
            $largeContent = "x" * 2048
            $largeContent | Out-File $logPath
            
            Initialize-LogFile -LogPath $logPath -MaxSizeKB 1
            
            # Original file should be rotated (renamed)
            $rotatedFiles = Get-ChildItem -Path $script:TestLogDir -Filter "test-rotate.*.log"
            $rotatedFiles.Count | Should -BeGreaterThan 0
            
            # New file should be created
            Test-Path $logPath | Should -Be $true
            (Get-Item $logPath).Length | Should -BeLessThan 2048
        }
        
        It "Should set log path in script scope" {
            $logPath = Join-Path $script:TestLogDir 'test-scope.log'
            
            Initialize-LogFile -LogPath $logPath
            
            $context = Get-LogContext
            $context.LogPath | Should -Be $logPath
        }
    }
    
    Context "Get-LogContext" {
        
        It "Should return current log context" {
            $context = Get-LogContext
            $context | Should -Not -BeNullOrEmpty
        }
        
        It "Should include LogPath property" {
            $logPath = Join-Path $script:TestLogDir 'test-context.log'
            Initialize-LogFile -LogPath $logPath
            
            $context = Get-LogContext
            $context.LogPath | Should -Not -BeNullOrEmpty
            $context.LogPath | Should -Be $logPath
        }
        
        It "Should include LogLevel property" {
            $context = Get-LogContext
            $context.LogLevel | Should -Not -BeNullOrEmpty
            $context.LogLevel | Should -BeIn @('DEBUG', 'INFO', 'WARN', 'ERROR')
        }
        
        It "Should include SessionId property" {
            $context = Get-LogContext
            $context.SessionId | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Write-AppLog" {
        BeforeEach {
            # Initialize clean log file for each test
            $script:TestLogPath = Join-Path $script:TestLogDir "test-write-$((Get-Random)).log"
            Initialize-LogFile -LogPath $script:TestLogPath
        }
        
        It "Should write log entry to file" {
            Write-AppLog -Message "Test message" -Level INFO
            
            Test-Path $script:TestLogPath | Should -Be $true
            $content = Get-Content $script:TestLogPath -Raw
            $content | Should -Not -BeNullOrEmpty
        }
        
        It "Should write JSON formatted log entries" {
            Write-AppLog -Message "Test JSON" -Level INFO
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry | Should -Not -BeNullOrEmpty
        }
        
        It "Should include timestamp in log entry" {
            Write-AppLog -Message "Test timestamp" -Level INFO
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should include log level in log entry" {
            Write-AppLog -Message "Test level" -Level WARN
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Not -BeNullOrEmpty
            $logEntry.level | Should -Be "WARN"
        }
        
        It "Should include message in log entry" {
            $testMessage = "This is a test message"
            Write-AppLog -Message $testMessage -Level INFO
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.message | Should -Not -BeNullOrEmpty
            $logEntry.message | Should -Be $testMessage
        }
        
        It "Should support DEBUG level" {
            Initialize-LogFile -LogPath $script:TestLogPath -LogLevel DEBUG
            Write-AppLog -Message "Debug message" -Level DEBUG
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Be "DEBUG"
        }
        
        It "Should support INFO level" {
            Write-AppLog -Message "Info message" -Level INFO
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Be "INFO"
        }
        
        It "Should support WARN level" {
            Write-AppLog -Message "Warn message" -Level WARN
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Be "WARN"
        }
        
        It "Should support ERROR level" {
            Write-AppLog -Message "Error message" -Level ERROR
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Be "ERROR"
        }
        
        It "Should include additional properties when provided" {
            Write-AppLog -Message "Test props" -Level INFO -Properties @{
                UserId = "test-user"
                Action = "test-action"
            }
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.UserId | Should -Not -BeNullOrEmpty
            $logEntry.UserId | Should -Be "test-user"
            $logEntry.Action | Should -Not -BeNullOrEmpty
            $logEntry.Action | Should -Be "test-action"
        }
        
        It "Should include exception details when provided" {
            try {
                throw "Test exception"
            }
            catch {
                Write-AppLog -Message "Exception occurred" -Level ERROR -Exception $_
            }
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.exception | Should -Not -BeNullOrEmpty
            $logEntry.exception.message | Should -BeLike "*Test exception*"
        }
        
        It "Should include caller information" {
            Write-AppLog -Message "Test caller" -Level INFO
            
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.caller | Should -Not -BeNullOrEmpty
        }
        
        It "Should write to console when -PassThru is specified" {
            Mock Write-Host { }
            
            Write-AppLog -Message "Test passthru" -Level INFO -PassThru
            
            Should -Invoke Write-Host -Times 1
        }
        
        It "Should handle concurrent writes safely" {
            $jobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($LogPath, $Index)
                    Import-Module $using:ModulePath -Force
                    Initialize-LogFile -LogPath $LogPath
                    Write-AppLog -Message "Concurrent message $Index" -Level INFO
                } -ArgumentList $script:TestLogPath, $_
            }
            
            $jobs | Wait-Job | Remove-Job
            
            # Verify all messages were written
            $content = Get-Content $script:TestLogPath -Raw
            $lines = @($content.Trim() -split "`n" | Where-Object { $_ })
            $lines.Count | Should -Be 5
        }
    }
    
    Context "Log Level Filtering" {
        BeforeEach {
            $script:TestLogPath = Join-Path $script:TestLogDir "test-filter-$((Get-Random)).log"
        }
        
        It "Should not log DEBUG when LogLevel is INFO" {
            Initialize-LogFile -LogPath $script:TestLogPath -LogLevel INFO
            
            Write-AppLog -Message "Debug message" -Level DEBUG
            Write-AppLog -Message "Info message" -Level INFO
            
            $content = Get-Content $script:TestLogPath -Raw
            $lines = @($content.Trim() -split "`n" | Where-Object { $_ })
            
            # Should only have 1 line (INFO), not 2
            $lines.Count | Should -Be 1
            $logEntry = Get-LastLogEntry -LogPath $script:TestLogPath
            $logEntry.level | Should -Be "INFO"
        }
        
        It "Should log WARN and ERROR when LogLevel is WARN" {
            Initialize-LogFile -LogPath $script:TestLogPath -LogLevel WARN
            
            Write-AppLog -Message "Info message" -Level INFO
            Write-AppLog -Message "Warn message" -Level WARN
            Write-AppLog -Message "Error message" -Level ERROR
            
            $content = Get-Content $script:TestLogPath -Raw
            $lines = @($content.Trim() -split "`n" | Where-Object { $_ })
            
            # Should have 2 lines (WARN and ERROR), not 3
            $lines.Count | Should -Be 2
        }
    }
}
