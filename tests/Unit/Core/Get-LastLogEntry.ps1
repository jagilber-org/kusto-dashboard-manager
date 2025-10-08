# Helper to parse last log entry
function Get-LastLogEntry {
    param([string]$LogPath)
    $content = Get-Content $LogPath -Raw
    $lines = @($content.Trim() -split "`n") | Where-Object { $_ }
    if ($lines) {
        $lines[-1] | ConvertFrom-Json
    }
}
