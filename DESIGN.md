# multi-agent-kingdom 設計ドキュメント

> **Status**: 設計中
> **Last Updated**: 2026-02-28

## 概要

multi-agent-kingdom は Claude Code の Agent Teams 機能を使って構築するコーディング特化のマルチエージェントシステム。
既存の tmux ベースシステム（multi-agent-shogun）を完全に置き換える。

---

## 命名規則（キングダム）

| レイヤー | 名前 | 役割の例え |
|---------|------|-----------|
| 人間 | **王** | 最終意思決定者 |
| orchestrator | **大将軍** | 全体統括・王の指示を受ける |
| service-X | **軍師** | サービス内PjM・戦略立案（昌平君的存在） |
| project-X | **千人将** | 機能単位リーダー・部隊管理 |
| executor | **兵** | コーディング実働部隊 |

---

## アーキテクチャ

```
王（人間）
  │
  ▼
大将軍（TeamCreate・常駐）
  │ spawn / SendMessage
  ├─ 軍師（サービスが存在する限り常駐・resume）
  │    │ SendMessage
  │    └─ 千人将（機能開始〜PRマージまで生存・resume）
  │         │ SendMessage
  │         └─ 兵 × N（使い捨て・並列）
  │
  └─ ※ spawn は大将軍のみが実行できる
```

### 重要な制約（PoC で判明）

- **subagent は Task ツールを持たない** → 兵・千人将・軍師は自ら spawn できない
- **spawn は大将軍に集中** → 軍師・千人将が SendMessage で「spawn 要請」し、大将軍が実行する

---

## 各レイヤーの責務

### 大将軍（orchestrator）
- 王のファジーな指示を解釈・ルーティング
- チーム全体の spawn 管理
- 軍師からの spawn 要請を受けて実行
- エスカレーション対応（軍師 → 大将軍 → 王）
- GitHub Issues の作成・管理

### 軍師（service-X）
- サービス全体の技術文脈を保持・管理（`context/{service}.md`）
- 複数機能間の依存関係・優先度の調整（PjM）
- 千人将への spawn 要請（大将軍経由）
- `projects/{service}/*.yaml` の管理

### 千人将（project-X）
- 機能単位のタスク分解
- 兵の spawn 要請（大将軍経由）
- エスカレーション対応（兵 → 千人将 → 軍師）
- dashboard.md 更新
- PRマージ後：実装ログの知見を `context/{service}.md` に吸い上げ → ログ削除 → 終了

### 兵（executor）
- coding → test → commit → PR作成（`Closes #N`）
- `implementation_log.yaml` を書いて終了
- 詰まったら千人将にエスカレーション

---

## セッション生存期間

| レイヤー | 生存期間 | 復元手段 |
|---------|---------|---------|
| 大将軍 | 常駐 | Memory MCP + YAML + GitHub Issues |
| 軍師 | サービスが存在する限り | `context/{service}.md` + YAML |
| 千人将 | 機能開始〜PRマージ | `projects/{service}/{feature}.yaml` |
| 兵 | タスク単位で使い捨て | 不要（都度新規） |

### Resume メカニズム（PoC4で確認済み）
- `resume` パラメータはセッション内のみ有効。**Claude Code の再起動を跨ぐとコンテキストは消える**
- セッション跨ぎの「記憶」は YAML ファイルへの書き出しのみで実現する
- agent_id の保存は行うが、resume による会話履歴復元は期待しない
- 復帰時はコンテキストファイルと YAML を読み直して状態を再構築する

---

## 通信プロトコル

### 通信経路

```
兵 → 千人将      : SendMessage（チーム内・直接）
千人将 → 軍師    : SendMessage（チーム内・直接）
軍師 → 大将軍    : YAML 更新のみ（SendMessage 禁止）
大将軍 → 王      : エスカレーション時のみ
```

### 軍師→大将軍を YAML のみにする理由
王と大将軍の会話が頻繁に割り込まれるのを防ぐため。
本当に判断が必要な時だけ大将軍が王に伝える。

### spawn 要請フロー
```
軍師「千人将が必要」→ SendMessage → 大将軍
大将軍 → Task ツールで千人将を spawn → チームに追加

千人将「兵が必要」→ SendMessage → 軍師 → YAML 更新
大将軍 → YAML を確認 → Task ツールで兵を spawn
```

---

## 記憶の在り処

```
大将軍  → Memory MCP（ルール・王の好み）
        + GitHub Issues（意図・タスクの永続化）

軍師    → context/{service}.md（技術文脈・規約・知見）
        + projects/{service}/*.yaml（各機能の状態・千人将の agent ID）

千人将  → projects/{service}/{feature}.yaml
          （タスク分解・進捗・兵の agent IDs・実装方針）

兵      → implementation_log.yaml（書いて終了）
```

### コンテキスト軽量設計原則
- 重要な状態は**即座に外部ファイルに書き出す**
- コンテキスト = 今この瞬間の作業記憶（揮発性）
- ファイル = 永続記憶（セッション跨ぎで生き残る）
- コンパクション後もファイルを読めば完全復元できる状態を常に維持

### 記憶の更新タイミング（重要）
「後で書こう」は禁止。**決断・状態変化のその瞬間に書け。**

| エージェント | 書くタイミング | 書く先 |
|------------|--------------|--------|
| 軍師 | タスク分解完了時 | `{feature}.yaml` 新規作成 |
| 軍師 | 千人将 spawn 後 | `agents.yaml` に agent_id 追記 |
| 軍師 | 千人将から報告受け取り時 | `{feature}.yaml` 更新 |
| 軍師 | PR マージ後処理完了時 | `agents.yaml` から削除、`context/{service}.md` 更新 |
| 千人将 | タスク分解完了時 | `{feature}.yaml` 更新（タスク一覧） |
| 千人将 | 兵へ指示送信後 | `{feature}.yaml` 更新（hei_agent_id 記録） |
| 千人将 | 兵からの報告受け取り時 | `{feature}.yaml` 更新（task status） |
| 千人将 | PR 作成後 | `{feature}.yaml` 更新（pr_number 記録） |
| 兵 | 実装完了・PR 作成後 | `implementation_log.yaml` 書いて終了 |

**理由**: セッション終了・コンパクション・クラッシュはいつでも起こりうる。
「書く前に消えた」ではなく「書いてから進む」を徹底せよ。

---

## ファイル構成（予定）

```
/
├─ CLAUDE.md                          # システム全体の指示
├─ instructions/
│   ├─ daishogun.md                   # 大将軍の行動規範
│   ├─ gunshi.md                      # 軍師の行動規範
│   ├─ senninsho.md                   # 千人将の行動規範
│   └─ hei.md                         # 兵の行動規範
├─ context/
│   └─ {service}.md                   # サービス固有の技術文脈
├─ projects/
│   └─ {service}/
│       ├─ {feature}.yaml             # 機能ごとの状態・タスク分解
│       └─ agents.yaml                # 軍師・千人将の agent ID 管理
├─ logs/
│   └─ {service}/
│       └─ {feature}/
│           └─ implementation_log.yaml
├─ config/
│   └─ services.yaml                  # サービス一覧
└─ dashboard.md                       # 現在の作業サマリ（千人将が更新）
```

---

## YAML スキーマ

### `config/services.yaml`
```yaml
services:
  - id: myapp
    name: myapp
    path: /path/to/myapp
    status: active          # active | inactive
    gunshi_agent_id: null   # 軍師の agent ID（起動後に記録）
```

### `projects/{service}/agents.yaml`
```yaml
service: myapp
gunshi_agent_id: gunshi-abc123
senninshos:
  - feature_id: preview
    agent_id: senninsho-xyz789
  - feature_id: user-management
    agent_id: senninsho-def456
```

### `projects/{service}/{feature}.yaml`
```yaml
feature_id: preview
feature_name: プレビュー機能
service: myapp
github_issue: 42
status: in_progress   # pending | in_progress | review | done
branch: feature/preview
senninsho_agent_id: senninsho-xyz789
tasks:
  - id: task_001
    description: バックエンドAPI実装
    status: done            # pending | in_progress | done | failed
    hei_agent_id: hei-abc123
  - id: task_002
    description: フロントエンド実装
    status: in_progress
    hei_agent_id: hei-def456
pr_number: null
created_at: 2026-02-28T09:00:00Z
updated_at: 2026-02-28T09:00:00Z
```

### `logs/{service}/{feature}/implementation_log.yaml`

全情報をここに書く。PR description にはこのログから抜粋して記載する。

```yaml
feature: プレビュー機能
service: myapp
branch: feature/preview
pr_number: 42
github_issue: 42

files_changed:
  - path: src/preview/service.ts
    summary: プレビューサービス実装・下書き保存ロジック
  - path: src/preview/controller.ts
    summary: REST エンドポイント定義

decisions:
  - subject: Draft モデルを使わずフラグで実装
    reason: マイグレーションコストを避けるため。Draft テーブル追加は v2 で検討
  - subject: プレビューIDは UUID v4
    reason: 推測されにくくするため

approaches_rejected:
  - approach: セッションCookieでプレビュー状態管理
    reason: CORS問題が発生したため断念

known_issues:
  - プレビューの有効期限切れ処理が未実装（src/preview/service.ts:84）
  - N+1クエリになりうる箇所あり（src/preview/controller.ts:42）

review_concerns:
  - 有効期限の設計についてレビュアーから質問が来る可能性あり

created_at: 2026-02-28T09:00:00Z
```

---

## 正データの定義

| データ | 種別 | 用途 |
|-------|------|------|
| YAML ファイル | **正データ** | タスク状態・進捗・agent ID |
| GitHub Issues | 可視化・通知用 | 意図の永続化・機能進捗の外部公開 |
| dashboard.md | 二次情報 | 今何が動いているかのサマリ |

---

## GitHub Issues との連携

- 王が「○○機能作りたい」→ 大将軍が Issue を作成
- executor が PR 作成時: `Closes #N` で Issue と紐付け
- PR マージで Issue が自動クローズ
- 大将軍再起動時: open issues を読んで意図を復元

---

## PRのライフサイクル

```
1. 兵: coding → test → commit → PR作成（関連 Issue: #N）→ implementation_log 書いて終了

2. PRレビュー指摘発生:
   王が通知 → 大将軍 → 軍師 → 千人将（resume）→ 兵を新規召喚
   兵: implementation_log + PR diff を読んで対応 → commit → 終了

3. PRマージ:
   王が通知 → 大将軍 → 軍師 → 千人将（resume）
   千人将: 知見を context/{service}.md に吸い上げ → ログ削除 → 終了
```

---

## コンフリクト管理

ファイルレベルのコンフリクト検知は **Git に委譲**する。

- 機能ごとにブランチを切る（`feature/{feature-id}`）
- 複数機能が同じファイルを変更した場合は PR マージ時に Git がコンフリクトを検知
- 千人将はタスク分解時に兵間のファイル重複を避けるよう考慮する（ベストエフォート）

---

## エスカレーション

```
兵（詰まる）
  ↓ SendMessage
千人将（再分解 or 判断）
  ↓ SendMessage
軍師（サービス全体の判断が必要な場合）
  ↓ YAML 更新
大将軍（王への確認が必要な場合）
  ↓
王
```

---

## 並列実行

- 兵の並列上限: とりあえずなし（後付けで追加）
- 複数機能を同時並行: 軍師が複数の千人将を管理
- 複数サービスを同時並行: 大将軍が複数の軍師を管理

---

## PoC 検証結果（2026-02-28）

| 検証項目 | 結果 | 備考 |
|---------|------|------|
| TeamCreate | ✅ | |
| チームメンバーの spawn | ✅ | |
| SendMessage（メンバー→大将軍） | ✅ | 自動で届く |
| SendMessage（大将軍→メンバー） | ✅ | |
| SendMessage（メンバー間） | ✅ | 千人将→軍師を確認 |
| subagent が subagent を spawn | ❌ | Task ツールなし |
| resume のセッション跨ぎ | ❌ | 名前衝突なしで再検証。会話コンテキスト消失を確認 |

---

## 未解決事項・今後の課題

### 設計フェーズで決定すること
- [x] YAML スキーマの詳細設計
- [x] `implementation_log.yaml` のフィールド定義
- [x] instructions（各エージェントの行動規範）の作成
- [x] 大将軍の起動フロー・チーム初期化手順
- [x] dashboard.md の更新責任者（千人将が並列で書き込む問題）
  → 軍師が唯一の書き手。自分のサービスの `## {service}` セクションのみ更新

### 将来の拡張
- [x] resume のセッション跨ぎ検証（❌ セッション内のみ有効と確認）
- [ ] PRマージの自動検知（GitHub Actions）
- [ ] 兵の並列上限設定
