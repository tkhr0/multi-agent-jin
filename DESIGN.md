# multi-agent-kingdom 設計ドキュメント

> **Status**: v2.0
> **Last Updated**: 2026-03-01

## 概要

multi-agent-kingdom は Claude Code の Agent Teams 機能を使って構築するコーディング特化のマルチエージェントシステム。
既存の tmux ベースシステム（multi-agent-shogun）を完全に置き換える。

---

## 命名規則（キングダム）

| レイヤー | 名前 | 役割 |
|---------|------|------|
| 人間 | **王** | 最終意思決定者 |
| team-lead | **本陣** | spawn 管理専用ハブ（指揮系統の外） |
| service-leader | **大将軍** | サービス統括・王と対話・戦略 |
| feature-leader | **軍師** | 機能管理・兵への指示 |
| executor | **兵** | コーディング実働部隊 |

---

## アーキテクチャ

サービス単位で独立した Claude session（本陣）を起動する。

```
王（人間）
  │
  ├─ 本陣-myapp（Claude session = team-lead）
  │   ├─ 大将軍（subagent）← 王と対話・サービス全体管理
  │   ├─ 軍師（subagent）← 機能管理・兵に指示
  │   └─ 兵 × N（subagent）← 実装・使い捨て
  │
  ├─ 本陣-other（Claude session = team-lead）
  │   ├─ 大将軍（subagent）
  │   ├─ 軍師（subagent）
  │   └─ 兵 × N（subagent）
  ...
```

### 2つの系統

```
指揮系統: 王 → 大将軍 → 軍師 → 兵
spawn系統: 大将軍 → 本陣 / 軍師 → 本陣（指揮系統バイパス）
```

### 重要な制約（PoC で判明）

- **subagent は Task ツールを持たない** → 大将軍・軍師・兵は自ら spawn できない
- **spawn は本陣（team-lead）に集中** → 大将軍・軍師が SendMessage で「spawn 要請」し、本陣が実行する
- **本陣は指揮系統に介入しない** → spawn 管理と王⇔大将軍のメッセージ中継のみ

### shogun システムとの違い

| | shogun（tmux） | kingdom（Agent Teams） |
|--|---------------|----------------------|
| セッション | tmux 1つ（固定） | サービス単位で独立 |
| コンテキスト混濁 | 全サービスが1セッションに混在 | サービスごとに分離 |
| 層の深さ | 3層（将軍→家老→足軽） | 3層 + 本陣（大将軍→軍師→兵） |
| spawn | 将軍が tmux send-keys | 本陣が Agent tool |
| 通信 | YAML + tmux send-keys | SendMessage |

---

## 各レイヤーの責務

### 本陣（team-lead）
- spawn 管理専用（大将軍・軍師からの spawn 要請を受けて実行）
- 王と大将軍間のメッセージ中継（透過的）
- 技術判断・タスク管理・ファイル編集は一切行わない
- **状態を持たない**（agent_id の記録は大将軍の責任）

### 大将軍（service-leader）
- 王の指示を解釈・戦略立案（サービス単位）
- `context/{service}.md` の守護者
- dashboard.md の更新責任者
- `projects/{service}/agents.yaml` の管理
- `{feature}.yaml` の新規作成
- GitHub Issues の作成・管理
- Memory MCP 管理
- エスカレーション対応（軍師 → 大将軍 → 王）

### 軍師（feature-leader）
- 機能単位のタスク分解（五つの問い）
- 兵の spawn 要請（**本陣に直接** SendMessage）
- 兵への指示・管理
- CI 監視（sleep → 1回確認パターン）
- PRレビュー対応の調整
- PRマージ後：知見を `context/{service}.md` に追記 → 大将軍に報告 → 終了

### 兵（executor）
- coding → test → commit → PR作成（`関連 Issue: #N`）
- `implementation_log.yaml` を書いて終了
- 詰まったら軍師にエスカレーション

---

## セッション生存期間

| レイヤー | 生存期間 | 復元手段 |
|---------|---------|---------|
| 本陣 | サービスが存在する限り | 復元不要（状態を持たない） |
| 大将軍 | サービスが存在する限り | Memory MCP + `context/{service}.md` + YAML + GitHub Issues |
| 軍師 | 機能開始〜PRマージ | `projects/{service}/{feature}.yaml` |
| 兵 | タスク単位で使い捨て | 不要（都度新規） |

### Resume メカニズム（PoC4で確認済み）
- `resume` パラメータはセッション内のみ有効。**Claude Code の再起動を跨ぐとコンテキストは消える**
- セッション跨ぎの「記憶」は YAML ファイルへの書き出しのみで実現する
- 復帰時はコンテキストファイルと YAML を読み直して状態を再構築する

---

## 通信プロトコル

### 指揮系統の通信

```
兵 → 軍師       : SendMessage（チーム内・直接）
軍師 → 大将軍   : SendMessage（チーム内・直接）
大将軍 → 王     : 本陣経由の透過的中継
```

### spawn 要請（指揮系統バイパス）

```
大将軍「軍師が必要」→ SendMessage → 本陣 → spawn 実行
軍師「兵が必要」  → SendMessage → 本陣 → spawn 実行
  ※ 軍師は大将軍を経由せず本陣に直接要請する
```

### 軍師→大将軍の通信が SendMessage である理由
旧構造では「軍師→大将軍は YAML のみ」だった（王との会話を割り込まないため）。
新構造では大将軍が subagent になったため、チーム内 SendMessage は王に直接見えない。
ただし「大将軍の行動が必要な場合のみ SendMessage」の規律は維持する。

---

## 記憶の在り処

```
本陣    → 状態を持たない

大将軍  → Memory MCP（ルール・王の好み）
        + GitHub Issues（意図・タスクの永続化）
        + context/{service}.md（技術文脈・規約・知見）
        + projects/{service}/*.yaml（各機能の状態・軍師の agent ID）

軍師    → projects/{service}/{feature}.yaml
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
| 大将軍 | タスク分解依頼時 | `{feature}.yaml` 新規作成 |
| 大将軍 | 軍師 spawn 後 | `agents.yaml` に agent_id 追記 |
| 大将軍 | 軍師から報告受け取り時 | `{feature}.yaml` 更新 |
| 大将軍 | PR マージ後処理完了時 | `agents.yaml` から削除、`context/{service}.md` 更新 |
| 軍師 | タスク分解完了時 | `{feature}.yaml` 更新（タスク一覧） |
| 軍師 | 兵へ指示送信後 | `{feature}.yaml` 更新（hei_agent_id 記録） |
| 軍師 | 兵からの報告受け取り時 | `{feature}.yaml` 更新（task status） |
| 軍師 | PR 作成後 | `{feature}.yaml` 更新（pr_number 記録） |
| 兵 | 実装完了・PR 作成後 | `implementation_log.yaml` 書いて終了 |

**理由**: セッション終了・コンパクション・クラッシュはいつでも起こりうる。
「書く前に消えた」ではなく「書いてから進む」を徹底せよ。

---

## ファイル構成

```
/
├─ CLAUDE.md                          # 本陣（team-lead）の指示
├─ instructions/
│   ├─ honjin.md                     # 本陣の行動規範
│   ├─ daishogun.md                  # 大将軍の行動規範
│   ├─ gunshi.md                     # 軍師の行動規範
│   └─ hei.md                        # 兵の行動規範
├─ context/
│   └─ {service}.md                   # サービス固有の技術文脈
├─ projects/
│   └─ {service}/
│       ├─ {feature}.yaml             # 機能ごとの状態・タスク分解
│       └─ agents.yaml                # 大将軍・軍師の agent ID 管理
├─ logs/
│   └─ {service}/
│       └─ {feature}/
│           └─ implementation_log.yaml
├─ config/
│   └─ services.yaml                  # サービス一覧
└─ dashboard.md                       # 現在の作業サマリ（大将軍が更新）
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
    description: FAQ・チャットサポートサービス
```

### `projects/{service}/agents.yaml`
```yaml
service: myapp
agents:
  daishogun: daishogun-myapp   # 大将軍の agent ID
  gunshis:                       # 軍師一覧（機能単位）
    - feature_id: preview
      agent_id: gunshi-preview
    - feature_id: user-management
      agent_id: gunshi-usermgmt
```

### `projects/{service}/{feature}.yaml`
```yaml
feature_id: preview
feature_name: プレビュー機能
service: myapp
github_issue: 42
status: in_progress   # pending | in_progress | review | done
branch: feature/preview
gunshi_agent_id: gunshi-preview
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

decisions:
  - subject: Draft モデルを使わずフラグで実装
    reason: マイグレーションコストを避けるため

approaches_rejected:
  - approach: セッションCookieでプレビュー状態管理
    reason: CORS問題が発生したため断念

known_issues:
  - プレビューの有効期限切れ処理が未実装（src/preview/service.ts:84）

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
- 兵が PR 作成時: `関連 Issue: #N` で紐付け（`Closes #N` は禁止）
- Issue のクローズ・PR のマージは王のみが行う
- 大将軍再起動時: open issues を読んで意図を復元

---

## PRのライフサイクル

```
1. 兵: coding → test → commit → PR作成（関連 Issue: #N）→ implementation_log 書いて終了

2. PRレビュー指摘発生:
   王が通知 → 大将軍 → 軍師 → 兵を新規召喚
   兵: implementation_log + PR diff を読んで対応 → commit → 終了

3. PRマージ:
   王が通知 → 大将軍 → 軍師
   軍師: 知見を context/{service}.md に吸い上げ → ログ削除 → 大将軍に報告 → 終了
```

---

## コンフリクト管理

ファイルレベルのコンフリクト検知は **Git に委譲**する。

- 機能ごとにブランチを切る（`feature/{feature-id}`）
- 複数機能が同じファイルを変更した場合は PR マージ時に Git がコンフリクトを検知
- 軍師はタスク分解時に兵間のファイル重複を避けるよう考慮する（ベストエフォート）

---

## エスカレーション

```
兵（詰まる）
  ↓ SendMessage
軍師（再分解 or 判断）
  ↓ SendMessage
大将軍（王への確認が必要な場合）
  ↓ 本陣経由
王
```

---

## 並列実行

- 兵の並列上限: とりあえずなし（後付けで追加）
- 複数機能を同時並行: 大将軍が複数の軍師を管理
- 複数サービスを同時並行: 王が複数の本陣を起動

---

## PoC 検証結果（2026-02-28）

| 検証項目 | 結果 | 備考 |
|---------|------|------|
| TeamCreate | ✅ | |
| チームメンバーの spawn | ✅ | |
| SendMessage（メンバー→team-lead） | ✅ | 自動で届く |
| SendMessage（team-lead→メンバー） | ✅ | |
| SendMessage（メンバー間） | ✅ | |
| subagent が subagent を spawn | ❌ | Task ツールなし |
| resume のセッション跨ぎ | ❌ | 会話コンテキスト消失を確認 |

### 未検証（v2.0 で追加）
- [ ] 本陣の透過的中継（王⇔大将軍の会話が成立するか）
- [ ] 複数本陣（複数サービス）の同時起動
- [ ] 軍師から本陣への直接 spawn 要請

---

## 未解決事項・今後の課題

### 設計フェーズで決定済み
- [x] YAML スキーマの詳細設計
- [x] `implementation_log.yaml` のフィールド定義
- [x] instructions（各エージェントの行動規範）の作成
- [x] 本陣の起動フロー・チーム初期化手順
- [x] dashboard.md の更新責任者 → 大将軍
- [x] resume のセッション跨ぎ検証（❌ セッション内のみ有効と確認）
- [x] 千人将の廃止・3層化

### 将来の拡張
- [ ] PRマージの自動検知（GitHub Actions）
- [ ] 兵の並列上限設定
- [ ] 本陣の透過的中継の PoC 検証
