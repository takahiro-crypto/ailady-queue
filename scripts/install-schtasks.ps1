# install-schtasks.ps1 — 6 ワーカー PC ぶんの Windows スケジュールタスクを一括登録
#
# 各 PC で実行する想定。実行すると以下のタスクが作られる:
#   "AILady Worker PC1-BILLING" 〜 "AILady Worker PC6-QUOTE"
#   5 分おきに pwsh で run-worker.ps1 を起動
#
# 前提:
# - Claude Code CLI が PATH にあること（claude --version で確認）
# - Claude にログイン済み（Max $200 推奨）
# - ailady-queue が C:\Users\sugaw\claude-projects\ailady-queue に存在
#
# 使い方:
#   PS> cd C:\Users\sugaw\claude-projects\ailady-queue\scripts
#   PS> .\install-schtasks.ps1
#
# 解除:
#   PS> .\uninstall-schtasks.ps1
#
# このスクリプトは AI エージェント（claude -p）を自動定期発火させます。
# 必ず内容を読んでから実行してください。

param(
    [string]$QueueRoot = "C:\Users\sugaw\claude-projects\ailady-queue",
    [string[]]$Pcs = @("pc1-billing","pc2-expense","pc3-payroll","pc4-hr","pc5-cs","pc6-quote"),
    [int]$IntervalMinutes = 5
)

$ErrorActionPreference = "Stop"

$script = Join-Path $QueueRoot "scripts\run-worker.ps1"
if (-not (Test-Path $script)) {
    Write-Host "ERROR: run-worker.ps1 not found at $script" -ForegroundColor Red
    exit 1
}

# claude CLI 確認
$claude = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claude) {
    Write-Host "WARNING: claude CLI not found in PATH. Tasks will fail at runtime." -ForegroundColor Yellow
    Write-Host "         Install Claude Code first: npm install -g @anthropic-ai/claude-code"
}

Write-Host ""
Write-Host "About to register $($Pcs.Count) scheduled tasks, each firing every $IntervalMinutes minutes." -ForegroundColor Cyan
Write-Host "Tasks:"
foreach ($pc in $Pcs) {
    $taskName = "AILady Worker " + ($pc.ToUpper())
    Write-Host "  - $taskName"
}
Write-Host ""
$confirm = Read-Host "Proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Yellow
    exit 0
}

$success = 0
$failed = 0
foreach ($pc in $Pcs) {
    $taskName = "AILady Worker " + ($pc.ToUpper())
    $tr = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$script`" -PcDir $pc"
    try {
        $out = & schtasks /Create /TN $taskName /SC MINUTE /MO $IntervalMinutes /TR $tr /F 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK]   $taskName" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  [FAIL] $taskName : $($out -join ' ')" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  [ERR]  $taskName : $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "Done: $success registered, $failed failed."
Write-Host ""
Write-Host "Verify with:  schtasks /Query /FO LIST /V | Select-String 'AILady Worker'"
Write-Host "Disable all:  .\uninstall-schtasks.ps1"
Write-Host "Run one now:  pwsh -File $script -PcDir pc1-billing"
