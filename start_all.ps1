# Start the Arena Hero agent and route overlay in the background.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# Stop only this project's two Python entry points.
$agentEntry = [IO.Path]::GetFullPath((Join-Path $root 'arena_hero_tactic.py'))
$overlayEntry = [IO.Path]::GetFullPath((Join-Path $root 'arena_hero_route_overlay_server.py'))
$old = @(
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
        Where-Object {
            $_.CommandLine -like "*$agentEntry*" -or
            $_.CommandLine -like "*$overlayEntry*"
        }
)
foreach ($process in $old) {
    Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 800

# Start-Process truncates redirected files. Preserve the previous session so a
# crash or transport failure can still be diagnosed after an automatic/manual
# restart. These archives are covered by the arena_hero_*.log ignore rule.
$logTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
foreach ($logSpec in @(
    @{ Current = 'agent.log'; Archive = "arena_hero_agent_$logTimestamp.log" },
    @{ Current = 'agent_err.log'; Archive = "arena_hero_agent_err_$logTimestamp.log" }
)) {
    $currentLog = Join-Path $root $logSpec.Current
    if (Test-Path -LiteralPath $currentLog) {
        $logFile = Get-Item -LiteralPath $currentLog
        if ($logFile.Length -gt 0) {
            Move-Item -LiteralPath $currentLog `
                -Destination (Join-Path $root $logSpec.Archive)
        }
    }
}

Start-Process -FilePath "$root\.venv\Scripts\python.exe" `
    -ArgumentList "$root\arena_hero_route_overlay_server.py", `
        "--routes-file", "$root\.arena_hero_routes.json", `
        "--stats-file", "$root\.arena_hero_stats.json", `
        "--control-file", "$root\.arena_hero_control.json", `
        "--logs-file", "$root\arena_hero_events_zh.jsonl", `
        "--browser-intel-file", "$root\.arena_hero_browser_intel.json", `
        "--port", "8765" `
    -WorkingDirectory $root `
    -WindowStyle Hidden

Start-Sleep -Milliseconds 500

. (Join-Path $root 'arena_hero_credentials.ps1')
$key = Get-ArenaHeroApiKey -Root $root
try {
    $env:ARENA_HERO_API_KEY = $key
    Start-Process -FilePath "$root\.venv\Scripts\python.exe" `
        -ArgumentList "$root\arena_hero_tactic.py" `
        -WorkingDirectory $root `
        -RedirectStandardOutput "$root\agent.log" `
        -RedirectStandardError "$root\agent_err.log" `
        -WindowStyle Hidden
}
finally {
    Remove-Item Env:ARENA_HERO_API_KEY -ErrorAction SilentlyContinue
}

Write-Host 'Arena Hero started in the background:'
Write-Host '  overlay: http://127.0.0.1:8765'
Write-Host '  agent:   see agent.log'
Write-Host "  stopped $($old.Count) old project process(es)"
