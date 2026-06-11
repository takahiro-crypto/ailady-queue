# CLAUDE.md — commander コーディネータ

このディレクトリはコーディネータ PC（Takahiro が操作する PC）のワーキングディレクトリです。
**コーディネータの全体ルールは親ディレクトリ `../CLAUDE.md` を参照してください**。このファイルは commander 固有の補助メモです。

## このディレクトリの使い方

- `inbox/`：Takahiro が「あとでコーディネータに処理してほしいこと」を書き込む場所（任意）
- `outbox/`：コーディネータが生成した今日のレポート、進捗ダッシュボード、アラート
- `done/`：完了したコーディネータタスク（アーカイブ）

## コーディネータの典型セッション

```
$ cd C:\Users\sugaw\claude-projects\ailady-queue\commander
$ claude

> 今日の各 PC の状況サマリを出して
[コーディネータが pc*/outbox/, pc*/done/ を集計してレポート]

> A 株式会社の請求書を 5 件、AI 1 に依頼して
[コーディネータが role1-billing/inbox/2026-05-25-NNN.md を 5 枚書き込む]

> AI 1 から outbox 上がってる？ 二重チェックして
[コーディネータが role1-billing/outbox/ を読んで Takahiro に提示]

> OK、承認。done に動かしておいて
[コーディネータが outbox/ → done/ へ移動]
```

## レポートテンプレ

`outbox/YYYY-MM-DD-daily-report.md`:

```markdown
# AILady 日次レポート YYYY-MM-DD

## 処理サマリ
| PC | inbox | outbox 待ち承認 | done |
|----|-------|---------------|------|
| AI 1 請求 |  |  |  |
| AI 2 経費 |  |  |  |
| AI 3 勤怠 |  |  |  |
| AI 4 採用 |  |  |  |
| AI 5 CS  |  |  |  |
| AI 6 見積 |  |  |  |

## 要承認の outbox
- [ ] AI 1: 案件タイトル — 金額／要点
- [ ] AI 5: 案件タイトル — 要点

## ブロッカー・質問
- PCX: questions.md の要約

## 翌日のおすすめタスク
- PCX に xxx を依頼するとよさそう
```
