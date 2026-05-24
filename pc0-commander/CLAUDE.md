# CLAUDE.md — PC0 司令塔

このディレクトリは司令塔 PC（Takahiro が操作する PC）のワーキングディレクトリです。
**司令塔の全体ルールは親ディレクトリ `../CLAUDE.md` を参照してください**。このファイルは PC0 固有の補助メモです。

## このディレクトリの使い方

- `inbox/`：Takahiro が「あとで司令塔に処理してほしいこと」を書き込む場所（任意）
- `outbox/`：司令塔が生成した今日のレポート、進捗ダッシュボード、アラート
- `done/`：完了した司令塔タスク（アーカイブ）

## 司令塔の典型セッション

```
$ cd C:\Users\sugaw\claude-projects\ailady-queue\pc0-commander
$ claude

> 今日の各 PC の状況サマリを出して
[司令塔が pc*/outbox/, pc*/done/ を集計してレポート]

> A 株式会社の請求書を 5 件、PC1 に依頼して
[司令塔が pc1-billing/inbox/2026-05-25-NNN.md を 5 枚書き込む]

> PC1 から outbox 上がってる？ 二重チェックして
[司令塔が pc1-billing/outbox/ を読んで Takahiro に提示]

> OK、承認。done に動かしておいて
[司令塔が outbox/ → done/ へ移動]
```

## レポートテンプレ

`outbox/YYYY-MM-DD-daily-report.md`:

```markdown
# AILady 日次レポート YYYY-MM-DD

## 処理サマリ
| PC | inbox | outbox 待ち承認 | done |
|----|-------|---------------|------|
| PC1 請求 |  |  |  |
| PC2 経費 |  |  |  |
| PC3 勤怠 |  |  |  |
| PC4 採用 |  |  |  |
| PC5 CS  |  |  |  |
| PC6 見積 |  |  |  |

## 要承認の outbox
- [ ] PC1: 案件タイトル — 金額／要点
- [ ] PC5: 案件タイトル — 要点

## ブロッカー・質問
- PCX: questions.md の要約

## 翌日のおすすめタスク
- PCX に xxx を依頼するとよさそう
```
