# ============================================================
#  codex.ps1 — 带高重试次数的 Codex CLI 启动器
#  作者：Anty for NiceZ  |  更新时间：2026-08-09
#
#  原理：
#    从 ~/.codex/auth.json 动态读取 API Key 并注入环境变量，
#    配合 config.toml 中 [model_providers.openai-custom] 的
#    高重试配置，让 Codex 内部自动重试远超默认 5 次。
#
#  用法（完全替代直接运行 codex）：
#    .\codex.ps1                           # 交互模式
#    .\codex.ps1 "explain this codebase"   # 带 Prompt
#    .\codex.ps1 resume --last             # 恢复上次会话
# ============================================================

# ── 从 auth.json 动态读取 API Key ─────────────────────────────
$authFile = "$env:USERPROFILE\.codex\auth.json"
if (Test-Path $authFile) {
    $auth = Get-Content $authFile -Raw | ConvertFrom-Json
    if ($auth.OPENAI_API_KEY) {
        $env:OPENAI_API_KEY = $auth.OPENAI_API_KEY
    } else {
        Write-Host "⚠️  auth.json 中未找到 OPENAI_API_KEY" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ 未找到 $authFile" -ForegroundColor Red
    exit 1
}

# ── 透传所有参数给 codex ──────────────────────────────────────
codex @args
