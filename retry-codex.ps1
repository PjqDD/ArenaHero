# ============================================================
#  retry-codex.ps1 — Codex CLI 自动重试脚本 v5 (终极版)
#  作者：Anty for NiceZ  |  更新时间：2026-08-09
#
#  原理：
#    1. 正常启动 codex（不破坏 TTY）
#    2. Codex 退出后，读取 ~/.codex/sessions/ 下最新的 JSONL 日志
#    3. 解析 task_complete 事件，判断是否含 error
#    4. 若出错，提取最后一条用户消息
#    5. 用 codex resume --last "<最后指令>" 恢复会话并自动重发
# ============================================================
#
#  用法：
#    .\retry-codex.ps1                              # 交互模式启动
#    .\retry-codex.ps1 "explain this codebase"       # 带 Prompt 启动
#    .\retry-codex.ps1 -MaxRetries 10 -DelaySec 5    # 自定义重试参数
#
# ============================================================

param(
    [string]$Prompt     = "",
    [int]$MaxRetries    = 10,
    [int]$DelaySec      = 5
)

$SessionRoot = "$env:USERPROFILE\.codex\sessions"

# ── 找到最新的 session JSONL 日志 ──────────────────────────────
function Get-LatestSessionFile {
    Get-ChildItem -Path $SessionRoot -Recurse -Filter "rollout-*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

# ── 检测 session 是否以错误结束 ─────────────────────────────────
function Test-SessionError {
    param([string]$FilePath)
    $lines = Get-Content -Path $FilePath -Tail 30 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($obj.payload.type -eq "task_complete" -and $obj.payload.error) {
                return $obj.payload.error.message
            }
        } catch { }
    }
    return $null
}

# ── 从 session JSONL 中提取最后一条用户消息 ──────────────────────
function Get-LastUserMessage {
    param([string]$FilePath)
    $lastMsg = $null
    $lines = Get-Content -Path $FilePath -Tail 50 -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        try {
            $obj = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($obj.payload.role -eq "user" -and $obj.payload.content) {
                foreach ($c in $obj.payload.content) {
                    if ($c.type -eq "input_text" -and $c.text) {
                        $lastMsg = $c.text
                    }
                }
            }
        } catch { }
    }
    return $lastMsg
}

# ════════════════════════════════════════════════════════════════
#  主循环
# ════════════════════════════════════════════════════════════════

for ($i = 1; $i -le $MaxRetries; $i++) {

    if ($i -eq 1) {
        Write-Host ""
        Write-Host "🚀 启动 Codex CLI..." -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

        # 首次启动
        if ($Prompt -ne "") {
            codex $Prompt
        } else {
            codex
        }
    } else {
        Write-Host ""
        Write-Host "🔄 第 $i / $MaxRetries 次重试 (${DelaySec}s 后恢复会话)..." -ForegroundColor Yellow
        Start-Sleep -Seconds $DelaySec
        Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

        # 后续重试：resume 上一个会话 + 自动重发最后指令
        if ($lastUserMsg) {
            Write-Host "📝 自动重发指令：$lastUserMsg" -ForegroundColor Cyan
            codex resume --last $lastUserMsg
        } else {
            Write-Host "📝 恢复上一个会话..." -ForegroundColor Cyan
            codex resume --last
        }
    }

    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

    # 等日志刷盘
    Start-Sleep -Milliseconds 800

    # ── 检测是否出错 ───────────────────────────────────────────
    $latest = Get-LatestSessionFile
    if (-not $latest) {
        Write-Host "✅ 正常退出。" -ForegroundColor Green
        exit 0
    }

    $errorMsg = Test-SessionError -FilePath $latest.FullName

    if (-not $errorMsg) {
        Write-Host "✅ 正常退出。" -ForegroundColor Green
        exit 0
    }

    # 提取最后一条用户消息，供下次重试使用
    $lastUserMsg = Get-LastUserMessage -FilePath $latest.FullName

    Write-Host "⚠️  错误：$errorMsg" -ForegroundColor Red
    if ($lastUserMsg) {
        Write-Host "   📋 将重发指令：$lastUserMsg" -ForegroundColor DarkYellow
    }

    if ($i -eq $MaxRetries) {
        Write-Host ""
        Write-Host "❌ 已达最大重试次数 ($MaxRetries)，放弃。" -ForegroundColor Red
        exit 1
    }
}
