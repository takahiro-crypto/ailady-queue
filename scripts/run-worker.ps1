# run-worker.ps1 — AILady ワーカー PC 用 Claude Code 起動スクリプト
#
# Windows タスクスケジューラから 5〜10 分おきに呼ぶ想定。
# inbox/ に新カードがあれば claude -p で非対話処理を起こす。
#
# 使い方:
#   1. このスクリプトを各 PC にコピー（または共有 Drive からシンボリックリンク）
#   2. 第一引数で PC ディレクトリ名を指定
#      例: pwsh run-worker.ps1 pc1-billing
#   3. タスクスケジューラに「5 分おきに起動」のトリガーを設定
#
# 環境変数 AILADY_QUEUE_ROOT で ailady-queue のルートを上書き可能。

param(
    [Parameter(Mandatory=$true)]
    [string]$PcDir,

    [string]$QueueRoot = $(if ($env:AILADY_QUEUE_ROOT) { $env:AILADY_QUEUE_ROOT } else { "C:\Users\sugaw\claude-projects\ailady-queue" }),

    # 自動承認モード（デフォルト：acceptEdits）
    # 値: plan / default / acceptEdits / bypassPermissions
    # ワーカーは inbox/outbox/done のファイル編集が必須なので acceptEdits を既定に。
    # plan / default を指定するとプロンプト待ちで実質止まる（テスト時のみ使う）。
    [string]$PermissionMode = "acceptEdits"
)

$ErrorActionPreference = "Stop"

$workDir = Join-Path $QueueRoot $PcDir
$inboxDir = Join-Path $workDir "inbox"
$logFile = Join-Path $workDir ".run-worker.log"

if (-not (Test-Path $workDir)) {
    Write-Host "ERROR: PC directory not found: $workDir"
    exit 1
}

# inbox に処理待ちカード（.md, doneに移動されていないもの）があるか確認
$pendingCards = Get-ChildItem -Path $inboxDir -Filter "*.md" -File -ErrorAction SilentlyContinue
if (-not $pendingCards -or $pendingCards.Count -eq 0) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] inbox empty, skip" | Out-File -FilePath $logFile -Append -Encoding utf8
    exit 0
}

# Claude Code を非対話モードで起動
$prompt = @"
inbox/ ディレクトリに未処理のタスクカード（.md）があります。

次の手順で処理してください:
1. inbox/ 内の最も古いカード 1 件を読む
2. カードの「やってほしいこと」と「完了条件」に従って成果物を outbox/ に作成
3. 不明点があれば outbox/<カードID>-questions.md に列挙して止める
4. 完了したら inbox の元カードを done/ に移動

あなたの役割と禁止事項は CLAUDE.md を必ず参照してください。
"@

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] $($pendingCards.Count) card(s) pending, invoking claude" | Out-File -FilePath $logFile -Append -Encoding utf8

Push-Location $workDir
try {
    # claude CLI を非対話 (-p / --print) で起動
    # 注: claude コマンドが PATH にあること
    # --permission-mode acceptEdits でファイル編集を自動承認
    # --add-dir $workDir で作業ディレクトリを明示
    & claude -p $prompt --permission-mode $PermissionMode --add-dir $workDir 2>&1 | Tee-Object -FilePath $logFile -Append
    $exit = $LASTEXITCODE
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] claude exited with code $exit" | Out-File -FilePath $logFile -Append -Encoding utf8
}
finally {
    Pop-Location
}
