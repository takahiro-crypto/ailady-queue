# run-worker.ps1 — AILady ロール用 Claude Code 起動スクリプト
#
# Windows タスクスケジューラから 5〜10 分おきに呼ぶ想定。
# inbox/ に新カードがあれば claude -p で非対話処理を起こす。
#
# 使い方:
#   1. このスクリプトを 1 PC に配置（または共有 Drive からシンボリックリンク）
#   2. 第一引数でロールディレクトリ名を指定
#      例: pwsh run-worker.ps1 role1-billing
#   3. タスクスケジューラに「5 分おきに起動」のトリガーを設定
#
# 環境変数 AILADY_QUEUE_ROOT で ailady-queue のルートを上書き可能。

param(
    [Parameter(Mandatory=$true)]
    [string]$PcDir,

    # QueueRoot の決定順（先勝ち）:
    #   1. -QueueRoot 明示指定
    #   2. 環境変数 AILADY_QUEUE_ROOT
    #   3. このスクリプトが置かれているディレクトリの 1 つ上
    #      （ailady-queue/scripts/run-worker.ps1 を想定）
    [string]$QueueRoot = $(if ($env:AILADY_QUEUE_ROOT) { $env:AILADY_QUEUE_ROOT } else { Split-Path -Parent $PSScriptRoot }),

    # 自動承認モード（デフォルト：acceptEdits）
    # 値: plan / default / acceptEdits / bypassPermissions
    # ワーカーは inbox/outbox/done のファイル編集が必須なので acceptEdits を既定に。
    # plan / default を指定するとプロンプト待ちで実質止まる（テスト時のみ使う）。
    [string]$PermissionMode = "acceptEdits",

    # -NoGitSync を付けると git pull / commit / push をスキップする（テストや非 git 環境用）
    [switch]$NoGitSync
)

$ErrorActionPreference = "Stop"

# コンソール出力を UTF-8 に強制（Windows PowerShell 5.1 の Shift-JIS 表示で文字化けするのを回避）
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {
    # PowerShell 7 などで失敗しても致命ではない
}

$workDir = Join-Path $QueueRoot $PcDir
$inboxDir = Join-Path $workDir "inbox"
$logFile = Join-Path $workDir ".run-worker.log"

if (-not (Test-Path $workDir)) {
    Write-Host "[ERROR] Role directory not found: $workDir" -ForegroundColor Red
    exit 1
}

Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host ("[{0}] AILady worker: {1}" -f (Get-Date -Format 'HH:mm:ss'), $PcDir) -ForegroundColor Cyan
Write-Host ("  work dir : {0}" -f $workDir) -ForegroundColor DarkGray
Write-Host ("  inbox    : {0}" -f $inboxDir) -ForegroundColor DarkGray

# ---------- git pull（最新の inbox を取り込む）----------
$isGitRepo = (Test-Path (Join-Path $QueueRoot ".git"))
if (-not $NoGitSync -and $isGitRepo) {
    Push-Location $QueueRoot
    try {
        Write-Host "  git pull : fetching latest from origin..." -ForegroundColor DarkGray
        $pullOut = & git pull --ff-only 2>&1
        $pullExit = $LASTEXITCODE
        foreach ($line in $pullOut) { Write-Host ("             {0}" -f $line) -ForegroundColor DarkGray }
        if ($pullExit -ne 0) {
            Write-Host "  [WARN] git pull failed (continuing with local state). Check for uncommitted changes or merge conflicts." -ForegroundColor Yellow
        }
    } finally { Pop-Location }
} elseif ($NoGitSync) {
    Write-Host "  git pull : skipped (-NoGitSync)" -ForegroundColor DarkGray
} elseif (-not $isGitRepo) {
    Write-Host "  git pull : skipped (not a git repo)" -ForegroundColor DarkGray
}

# inbox に処理待ちカード（.md, doneに移動されていないもの）があるか確認
$pendingCards = Get-ChildItem -Path $inboxDir -Filter "*.md" -File -ErrorAction SilentlyContinue
if (-not $pendingCards -or $pendingCards.Count -eq 0) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] inbox empty, skip" | Out-File -FilePath $logFile -Append -Encoding utf8
    Write-Host "  status   : inbox empty -> skip (nothing to do)" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    exit 0
}

Write-Host ("  pending  : {0} card(s)" -f $pendingCards.Count) -ForegroundColor Green
foreach ($c in $pendingCards) {
    Write-Host ("             - {0}" -f $c.Name) -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  Invoking claude (typically 1-3 min). Output streams below:" -ForegroundColor Cyan
Write-Host ("-" * 70) -ForegroundColor DarkGray

# Claude Code を非対話モードで起動
$prompt = @"
inbox/ ディレクトリに未処理のタスクカード（.md）があります。

次の手順で処理してください。**各ステップを必ずファイル操作ツールで実行すること**（コマンドの提案だけで止まらない）。

1. inbox/ 内の最も古いカード 1 件を Read で読む
2. CLAUDE.md を Read で読み、自分の役割と禁止事項を確認する
3. カードの「やってほしいこと」と「完了条件」に従って成果物を作成し、
   Write ツールで outbox/<カードID>-result.md に書き出す
4. 不明点があれば Write ツールで outbox/<カードID>-questions.md に列挙して止める
5. 完了したら **Bash ツールで** \`mv inbox/<カードID>.md done/<カードID>.md\` を実行してカードを done/ に移動する
   （\`git mv\` は使わない。コミットは別途行うため）
6. 最後に状況を1〜3行で報告する（処理したカード ID と、outbox に書いたファイル名）

重要：手順 3 と 5 は提案だけで止めず、必ずツール実行で完了させること。
"@

"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] $($pendingCards.Count) card(s) pending, invoking claude" | Out-File -FilePath $logFile -Append -Encoding utf8

$startTime = Get-Date
Push-Location $workDir
try {
    # claude CLI を非対話 (-p / --print) で起動
    # 注: claude コマンドが PATH にあること
    # --permission-mode acceptEdits でファイル編集を自動承認
    # --add-dir $workDir で作業ディレクトリを明示
    & claude -p $prompt --permission-mode $PermissionMode --add-dir $workDir 2>&1 | Tee-Object -FilePath $logFile -Append
    $exit = $LASTEXITCODE
    $elapsed = (Get-Date) - $startTime
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$PcDir] claude exited with code $exit (elapsed $([int]$elapsed.TotalSeconds)s)" | Out-File -FilePath $logFile -Append -Encoding utf8

    Write-Host ("-" * 70) -ForegroundColor DarkGray
    if ($exit -eq 0) {
        Write-Host ("[{0}] claude finished OK (elapsed {1:N1}s)" -f (Get-Date -Format 'HH:mm:ss'), $elapsed.TotalSeconds) -ForegroundColor Green
    } else {
        Write-Host ("[{0}] claude exited with code {1} (elapsed {2:N1}s)" -f (Get-Date -Format 'HH:mm:ss'), $exit, $elapsed.TotalSeconds) -ForegroundColor Red
    }

    # 処理後の状態サマリを表示
    $afterInbox = @(Get-ChildItem -Path $inboxDir -Filter "*.md" -File -ErrorAction SilentlyContinue)
    $outboxDir = Join-Path $workDir "outbox"
    $doneDir = Join-Path $workDir "done"
    $afterOutbox = @(Get-ChildItem -Path $outboxDir -Filter "*.md" -File -ErrorAction SilentlyContinue)
    $afterDone = @(Get-ChildItem -Path $doneDir -Filter "*.md" -File -ErrorAction SilentlyContinue)
    Write-Host ("  after    : inbox={0}  outbox={1}  done={2}" -f $afterInbox.Count, $afterOutbox.Count, $afterDone.Count) -ForegroundColor Cyan
    if ($afterInbox.Count -gt 0) {
        Write-Host "  WARN     : inbox にカードが残っています（移動忘れ？）" -ForegroundColor Yellow
        foreach ($c in $afterInbox) { Write-Host ("             - {0}" -f $c.Name) -ForegroundColor Yellow }
    }
}
finally {
    Pop-Location
}

# ---------- git commit + push（成果物を origin に上げる）----------
if (-not $NoGitSync -and $isGitRepo -and $exit -eq 0) {
    Push-Location $QueueRoot
    try {
        # このロールのディレクトリ配下に変更があるかチェック
        $changes = & git status --porcelain "$PcDir" 2>&1
        if ($changes) {
            $changeCount = (@($changes) | Where-Object { $_ }).Count
            Write-Host ("  git push : staging {0} change(s) in {1}/" -f $changeCount, $PcDir) -ForegroundColor DarkGray
            & git add "$PcDir" 2>&1 | Out-Null

            $msg = "feat($PcDir): worker processed inbox (auto-commit)"
            $commitOut = & git commit -m $msg 2>&1
            $commitExit = $LASTEXITCODE
            if ($commitExit -eq 0) {
                $pushOut = & git push 2>&1
                $pushExit = $LASTEXITCODE
                foreach ($line in $pushOut) { Write-Host ("             {0}" -f $line) -ForegroundColor DarkGray }
                if ($pushExit -eq 0) {
                    Write-Host "  git push : OK (pushed to origin)" -ForegroundColor Green
                } else {
                    Write-Host "  [WARN] git push failed. Manual intervention required." -ForegroundColor Yellow
                }
            } else {
                Write-Host "  [WARN] git commit failed." -ForegroundColor Yellow
                foreach ($line in $commitOut) { Write-Host ("             {0}" -f $line) -ForegroundColor Yellow }
            }
        } else {
            Write-Host "  git push : no changes in $PcDir/ -> skip" -ForegroundColor DarkGray
        }
    } finally { Pop-Location }
}

Write-Host ("=" * 70) -ForegroundColor DarkGray
