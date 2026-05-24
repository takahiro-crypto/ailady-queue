# scripts/ — ワーカー PC 自動起動スクリプト

## `run-worker.ps1`

Windows タスクスケジューラから定期実行する PowerShell スクリプト。inbox に未処理カードがあれば Claude Code を非対話モード (`claude -p`) で起動して処理させる。

### 手動実行例

```pwsh
# PC1（請求・入金番）を 1 回起動
pwsh C:\Users\sugaw\claude-projects\ailady-queue\scripts\run-worker.ps1 -PcDir pc1-billing

# PC5（問い合わせ番）を 1 回起動
pwsh -File C:\Users\sugaw\claude-projects\ailady-queue\scripts\run-worker.ps1 -PcDir pc5-cs
```

### タスクスケジューラへの登録（GUI）

1. Win + R → `taskschd.msc`
2. 右ペイン「タスクの作成」
3. 全般タブ：
   - 名前：`AILady Worker PC1`
   - ユーザがログオンしているときのみ実行（テスト中は OK。本運用ではサービス起動推奨）
4. トリガータブ：
   - 「毎日」開始時刻 09:00、「繰り返し間隔 5 分間」「継続時間 12 時間」
5. 操作タブ：
   - プログラム：`pwsh.exe`（または `powershell.exe`）
   - 引数：`-NoProfile -ExecutionPolicy Bypass -File "C:\Users\sugaw\claude-projects\ailady-queue\scripts\run-worker.ps1" -PcDir pc1-billing`
6. 条件タブ：
   - 「ネットワーク接続あり」をチェック（Claude API 必須）
7. 設定タブ：
   - 「タスクを停止するまでの時間」を 30 分

### タスクスケジューラへの登録（CLI / schtasks）

```pwsh
schtasks /Create /TN "AILady Worker PC1" /SC MINUTE /MO 5 `
  /TR "pwsh -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\sugaw\claude-projects\ailady-queue\scripts\run-worker.ps1' -PcDir pc1-billing" `
  /RL HIGHEST
```

PC1 〜 PC6 ぶん同じパターンで登録。`/TN` と `-PcDir` をそれぞれ書き換える。

### 司令塔（PC0）は登録しない

司令塔は Takahiro が手で操作する想定なので、定期実行スケジュールは作らない。
必要時に `pc0-commander/` で `claude` を起動する。

### ログ

各 PC ディレクトリ直下に `.run-worker.log` が追記される。
処理失敗・skip の履歴を確認できる。

```pwsh
# PC1 の直近 20 行
Get-Content C:\Users\sugaw\claude-projects\ailady-queue\pc1-billing\.run-worker.log -Tail 20
```

## 前提

- `claude` コマンドが PATH にあること（Claude Code CLI が各 PC にインストール済）
- 各 PC で同じ Claude アカウントにログイン済（Max $200 プラン想定）
- `ailady-queue/` リポジトリが各 PC に clone or 同期されていること

## 同期方法（3 通り、規模別）

| 規模 | 同期手段 | 備考 |
|------|---------|------|
| 〜数日テスト | OneDrive / Google Drive 共有 | 簡単。ただし sync race condition の可能性 |
| 〜数週間運用 | Git remote（GitHub private） | コミット履歴＝監査ログ。`git pull` を Task Scheduler の前段に |
| 顧客展開 | 専用 Git サーバ + webhooks | 完全自動化、複数顧客対応 |
