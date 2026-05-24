# ailady-queue — AILady 運用キュー（SOKO LIFE 内部検証版）

AILady の「司令塔1 + ワーカー6」体制を、ファイル＋Git でメッセージバスとして実装したリポジトリです。SOKO LIFE 内部で 6 PC 構成を検証するために使い、運用ノウハウが固まったら顧客展開（AILady サービス本番）にテンプレ転用します。

## 全体像

```
ailady-queue/
├── pc0-commander/    # 司令塔（Takahiro が操作 / 全体統括）
├── pc1-billing/      # PC1 経理：請求・入金番
├── pc2-expense/      # PC2 経理：経費・決算番
├── pc3-payroll/      # PC3 人事：勤怠・給与番
├── pc4-hr/           # PC4 人事：採用・手続き番
├── pc5-cs/           # PC5 顧客対応：問い合わせ番
├── pc6-quote/        # PC6 営業事務：見積・契約番
├── templates/        # タスクカード雛形
└── scripts/          # Windows タスクスケジューラ用 PowerShell
```

各 PC ディレクトリの構造：

```
pcN-xxx/
├── CLAUDE.md   # この PC の永続指示（役割・禁止事項・承認ゲート）
├── inbox/      # 司令塔がタスクカード（.md）を置く場所
├── outbox/     # ワーカーが成果物を置く場所（人間レビュー待ち）
└── done/       # 承認・処理完了したカード／成果物のアーカイブ
```

## メッセージフロー

```
[Takahiro] ──→ [PC0 司令塔 Claude Code]
                       │ タスク分解
                       ▼
              pcN-xxx/inbox/YYYY-MM-DD-NNN.md   ← 司令塔が書き込む
                       │
                       │ ワーカーが定期 or 手動発火
                       ▼
              [PCN ワーカー Claude Code]
                       │ inbox の新カードを処理
                       ▼
              pcN-xxx/outbox/YYYY-MM-DD-NNN-result.md
                       │
                       │ 司令塔 or Takahiro が確認
                       ▼
              承認 → done/ へ移動
                       │
                       │ 必要なら対外送信／システム登録
                       ▼
                    [完了]
```

## 起動方法（3 レベル）

### レベル 1：手動運用（テスト開始日〜数日）
- 6 PC それぞれで Claude Code を開く
- 司令塔 PC から RDP / Chrome Remote Desktop で各 PC に入り、`claude` でセッション開始
- 「inbox/ に新しいタスクないか確認して、あれば処理して outbox/ に置いて」と毎回手で指示

### レベル 2：半自動（数日後〜）
- 各 PC で **Windows タスクスケジューラ**を設定し、5〜10 分おきに `scripts/run-pcN.ps1` を実行
- スクリプトは `claude -p "..."` で非対話モードで Claude Code を起動し、inbox を処理させる
- 詳細は `scripts/README.md` 参照

### レベル 3：Git ベース自動化（顧客展開フェーズ）
- 6 PC でこのリポジトリを clone
- 司令塔のコミット → 各 PC が `git pull` → ワーカー処理 → push
- pre-commit hooks で自動発火、PR レビューでの承認ゲート

## 重要：安全設計（承認ゲート）

各ワーカー PC の CLAUDE.md には以下が必ず入る：

- **金銭の確定・給与確定・対外送信・契約締結は禁止**（人間の承認後のみ）
- 不明点があれば inbox のカードに `questions:` を追記して止める
- 成果物は必ず outbox/ に出す（直接システム登録しない）
- 個人情報・財務データは担当領域外には書き出さない

## 進捗ステータス

- [x] フォルダ構造（2026-05-25 作成）
- [x] 司令塔 / 各 PC の CLAUDE.md
- [x] タスクカードテンプレート
- [x] PC1 サンプルカード（請求書ドラフト作成）
- [ ] 各 PC の PowerShell トリガースクリプト
- [ ] Windows タスクスケジューラの XML エクスポート
- [ ] Git remote 設定（GitHub private）
- [ ] 初回 6 PC 並列稼働テスト

## Claude プラン

SOKO LIFE 内部テスト段階では：

- **Max $200 ×1 アカウント** で 6 PC 全部に同じアカウントでログイン
- 同一ユーザー（Takahiro）の運用なので Anthropic ToS 上クリーン
- レート枠は 6 PC で共有プール（Max $200 が現実的下限）

詳細は memory の [reference_claude_multi_device_policy.md](C:/Users/sugaw/.claude/projects/C--Users-sugaw-OneDrive--------kairos/memory/reference_claude_multi_device_policy.md) を参照。

顧客展開フェーズではこの構成は使わず、顧客名義 Claude 契約に切替（[project_ailady_pricing_2026_05.md](C:/Users/sugaw/.claude/projects/C--Users-sugaw-OneDrive--------kairos/memory/project_ailady_pricing_2026_05.md)）。
