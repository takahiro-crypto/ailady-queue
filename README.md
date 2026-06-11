# ailady-queue — AILady 運用キュー（SOKO LIFE 内部検証版）

AILady の「**1 台の PC に 6 つの AI 専門役割**」体制を、ファイル＋Git でメッセージバスとして実装したリポジトリです。SOKO LIFE 内部で 1 PC 構成（Claude Code を並行起動）を検証するために使い、運用ノウハウが固まったら顧客展開（AILady サービス本番）にテンプレ転用します。

## 全体像

```
ailady-queue/
├── commander/         # SOKO LIFE オペレータ用（全体統括・日次レポート）
├── role1-billing/     # AI 1 経理：請求・入金番
├── role2-expense/     # AI 2 経理：経費・決算番
├── role3-payroll/     # AI 3 人事：勤怠・給与番
├── role4-hr/          # AI 4 人事：採用・手続き番
├── role5-cs/          # AI 5 顧客対応：問い合わせ番
├── role6-quote/       # AI 6 営業事務：見積・契約番
├── templates/         # タスクカード雛形
└── scripts/           # Windows タスクスケジューラ用 PowerShell
```

各ロールディレクトリの構造：

```
roleN-xxx/
├── CLAUDE.md   # このロールの永続指示（役割・禁止事項・承認ゲート）
├── inbox/      # SOKO LIFE オペレータがタスクカード（.md）を置く場所
├── outbox/     # ロールが成果物を置く場所（人間レビュー待ち）
└── done/       # 承認・処理完了したカード／成果物のアーカイブ
```

## アーキテクチャ：1 台の PC に 6 並行セッション

- **物理 PC は 1 台**（顧客先に設置）
- その PC で **Claude Code を 6 つのセッションとして並行起動**
- 各セッションは roleN-xxx/ のディレクトリで動作（`claude --add-dir roleN-xxx/`）
- **Claude プラン**：Max $200/月 1 アカウント（同一ユーザの並行セッションは Anthropic 公式に許可）
- SOKO LIFE オペレータが commander/ に座って、各 inbox にタスクカードを投入

## メッセージフロー

```
[Takahiro / SOKO LIFE オペレータ]
       │ タスク分解（commander/ で）
       ▼
roleN-xxx/inbox/YYYY-MM-DD-NNN.md
       │
       │ ロールが定期 or 手動発火
       ▼
[role N 担当 Claude Code セッション]
       │ inbox の新カードを処理
       ▼
roleN-xxx/outbox/YYYY-MM-DD-NNN-result.md
       │
       │ SOKO LIFE or 顧客が確認
       ▼
承認 → done/ へ移動
       │
       │ 必要なら対外送信／システム登録
       ▼
    [完了]
```

## 起動方法（3 レベル）

### レベル 1：手動運用（テスト開始日〜数日）
- 1 PC で Claude Code を 6 セッション開く（別ターミナル or worktree）
- 各セッションで `cd roleN-xxx && claude` でその役割の Claude を起動
- 「inbox/ に新しいタスクないか確認して、あれば処理して outbox/ に置いて」と毎回手で指示

### レベル 2：半自動（数日後〜）
- **Windows タスクスケジューラ**を設定し、各ロールごとに 5〜10 分おきに `scripts/run-worker.ps1` を実行
- スクリプトは `claude -p "..."` で非対話モードで Claude Code を起動し、inbox を処理させる
- 詳細は `scripts/README.md` 参照

### レベル 3：Git ベース自動化（顧客展開フェーズ）
- 1 PC 上で git pull → 各ロール処理 → git push
- pre-commit hooks で自動発火、PR レビューでの承認ゲート

## 重要：安全設計（承認ゲート）

各ロールの CLAUDE.md には以下が必ず入る：

- **金銭の確定・給与確定・対外送信・契約締結は禁止**（人間の承認後のみ）
- 不明点があれば inbox のカードに `questions:` を追記して止める
- 成果物は必ず outbox/ に出す（直接システム登録しない）
- 個人情報・財務データは担当領域外には書き出さない

## 進捗ステータス

- [x] フォルダ構造（2026-05-25 作成 → 2026-06-12 に 1 PC モデルへ refactor）
- [x] commander / 各ロールの CLAUDE.md
- [x] タスクカードテンプレート
- [x] role1 サンプルカード（請求書ドラフト作成）6 件処理済
- [x] PowerShell トリガースクリプト
- [x] Windows タスクスケジューラ用 install-schtasks.ps1
- [x] Git remote 設定（GitHub private）
- [ ] **1 PC 上での 6 ロール並行稼働テスト**（次フェーズ）

## Claude プラン

SOKO LIFE 内部テスト段階では：

- **Max $200 ×1 アカウント** で 1 PC に 6 並行 Claude Code セッション
- 同一ユーザー（Takahiro）の運用なので Anthropic ToS 上クリーン
- 同一ユーザの並行 Claude Code セッションは Anthropic 公式に許可
- レート枠は 6 セッションで共有プール（Max $200 が現実的下限）

詳細は memory の [reference_claude_multi_device_policy.md](C:/Users/sugaw/.claude/projects/C--Users-sugaw-OneDrive--------kairos/memory/reference_claude_multi_device_policy.md) を参照。

顧客展開フェーズではこの構成は使わず、顧客名義 Claude 契約に切替（[project_ailady_pricing_2026_05.md](C:/Users/sugaw/.claude/projects/C--Users-sugaw-OneDrive--------kairos/memory/project_ailady_pricing_2026_05.md)）。
