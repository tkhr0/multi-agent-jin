# jin — マルチエージェント開発支援システム

jin は、Claude Code を主軸にしたマルチエージェント開発支援システムです。必要に応じて Codex CLI でも起動できます。戦国時代の軍制をメタファーに、複数の AI エージェントが階層的に連携してソフトウェア開発タスクを遂行します。

指示を出すだけで、設計・実装・テスト・PR 作成・知見の蓄積までを自律的に行います。

本システムは [yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) を参考にしています。

## セットアップ

### 1. リポジトリの clone

```bash
git clone git@github.com:{owner}/multi-agent-jin.git
cd multi-agent-jin
```

### 2. サービスの追加

```bash
./add_service.sh                                          # 対話モード
./add_service.sh --id myapp --path /path/to/myapp         # 非対話モード
```

`config/services.yaml` への登録、`context/`・`projects/` の初期化を自動で行います。

### 3. 起動

```bash
./shutsujin.sh myapp                  # myapp サービスを起動
./shutsujin.sh myapp --cli codex      # Codex CLI で起動
./shutsujin.sh myapp --model sonnet   # モデルを指定して起動
./shutsujin.sh myapp --clean          # 状態をリセットして起動
```

環境変数（`JIN_SERVICE_ID`、`JIN_SERVICE_PATH`）はスクリプトが自動設定します。
Codex CLI を使う場合は `--cli codex` を指定します。`AGENT.md` は Codex 向けの入口として置いてあります。

起動すると、jin は自動で以下を実行します（確認は求められません）:

1. 指示書（`instructions/honjin.md`）を読み込む
2. 環境変数から担当サービスを特定する
3. 大将軍（Daishogun）エージェントを起動する
4. 「起動完了」と報告する

起動完了後、自然言語で指示を出せば開発が始まります。

## 使い方

### 基本的なワークフロー

機能開発では、GitHub Issue を作成し、その Issue を参照させて指示を出します。

```
あなた（王）: 「Issue #123 を対応してほしい」
    ↓
本陣（Honjin）: 指示を解釈し、大将軍に伝達
    ↓
大将軍（Daishogun）: 軍師を召喚して設計を指示
    ↓
軍師（Gunshi）: 設計を行い、タスクを分解して兵に実装を指示
    ↓
兵（Hei）: 実装・テスト・コミット・PR 作成・実装ログ記録
    ↓
あなた: PR をレビューしてマージ
```

Issue に要件を書いておくことで、エージェントが正確に仕様を把握できます。

### 指示の出し方

```
# 機能開発・バグ修正（Issue を参照させる）
「Issue #123 を対応してほしい」
「Issue #456 の内容を設計してくれ」

# 調査・設計（フリーな会話）
「認証基盤を Auth0 に移行する場合の影響範囲を調査してほしい」

# 状況確認
「今の進捗を教えてくれ」
```

機能開発・バグ修正は Issue 経由、調査や状況確認はフリーな会話で指示できます。

### 設計レビューフロー

大きな機能開発では、実装前に設計レビューを挟みます。

1. jin が設計内容を報告してくる
2. 内容を確認し、承認 or フィードバックを返す
3. 承認後、自動的に実装フェーズに移行する

### PR とマージ

- PR の作成は jin が行います
- **PR のマージと Issue のクローズはあなた（王）の責務です**（jin は行いません）
- マージ後、jin に「PR #123 をマージした」と伝えてください。PR 番号を含めることで、jin が対象を特定し、知見の抽出・context への追記・ダッシュボード更新を自動実行します

## サービスの追加

新しいサービス（リポジトリ）を jin の管理下に置くには、`add_service.sh` を使います。

```bash
./add_service.sh --id myapp --path /path/to/myapp --desc "マイアプリの説明"
```

`context/myapp/base.md` の記載は任意ですが、技術スタックやコーディング規約を書いておくとエージェントの精度が上がります。Serena MCP を使ってリポジトリの概要を自動記載させるのがおすすめです。

対象リポジトリに `wiki/` submodule が存在する場合は、Wiki の内容を参考にして context を生成させるとより効果的です。

## ディレクトリ構成

```
multi-agent-jin/
├── CLAUDE.md                          # jin のメイン設定（本陣の指示書）
├── AGENT.md                           # Codex 向けの入口
├── config/
│   └── services.yaml                  # 管理対象サービスの一覧
├── instructions/                      # エージェントの指示書
│   ├── honjin.md                      #   本陣（司令塔）
│   ├── daishogun.md                   #   大将軍（テックリード）
│   ├── gunshi.md                      #   軍師（設計・タスク管理）
│   └── hei.md                         #   兵（実装担当）
├── context/{service}/                 # サービス固有の技術知見
│   ├── base.md                        #   共通ルール（全兵必読）
│   └── {domain}.md                    #   領域別知見（openapi, design, e2e, deploy 等）
├── projects/{service}/                # プロジェクト管理
│   ├── agents.yaml                    #   稼働中エージェントの ID
│   └── {feature_id}.yaml             #   機能ごとの状態・タスク
├── logs/{service}/{feature_id}/       # 実装ログ
│   └── implementation_log.yaml        #   兵が書く引き継ぎ情報
├── dashboard.md                       # 全体進捗ダッシュボード
├── skills/                            # 再利用可能な作業パターン
│   └── {skill-name}/SKILL.md
├── designs/{service}/                 # 設計仕様書
└── reports/{service}/                 # 調査報告書・週次報告等
```

### 主要ファイルの役割

| ファイル | 管理者 | 説明 |
|---------|--------|------|
| `CLAUDE.md` | 手動 | jin のエントリーポイント。本陣の起動設定 |
| `AGENT.md` | 手動 | Codex 向けの入口。本陣への案内 |
| `config/services.yaml` | 手動 | 管理対象サービスの登録 |
| `context/{service}/` | 大将軍 | 技術知見の蓄積。PR マージ時に自動更新 |
| `projects/{service}/` | 大将軍 | タスク状態・エージェント管理 |
| `dashboard.md` | 大将軍 | 進捗の概要。人間が見るためのサマリ |
| `instructions/` | 手動 | エージェントの行動規範 |
| `skills/` | 大将軍 + 手動 | 再利用可能なワークフロー |
| `logs/` | 兵 | 実装の引き継ぎ情報。PR マージ後に削除 |

## エージェント構成

jin は4層の階層構造で動作します。各エージェントは指示書（`instructions/` 配下）に従って行動します。

```
王（あなた）
  └── 本陣（Honjin） ← CLAUDE.md で定義
        └── 大将軍（Daishogun） ← テックリード相当
              └── 軍師（Gunshi） ← 設計・タスク管理
                    └── 兵（Hei） ← 実装担当（複数可）
```

### 本陣（Honjin）— 司令塔

- あなた（王）の会話相手
- 王の意図を解釈し、大将軍に指示を出す
- エージェントの spawn（起動）を管理する
- 指示書: `instructions/honjin.md`

### 大将軍（Daishogun）— テックリード

- サービス全体を俯瞰する技術責任者
- GitHub Issue の作成、設計レビュー、進捗管理を行う
- `context/{service}/` の技術知見を守護する
- 自分ではコーディングしない（管理に徹する）
- 指示書: `instructions/daishogun.md`

### 軍師（Gunshi）— 設計・タスク管理

- 機能単位で spawn される
- 設計を行い、タスクを分解して兵に指示を出す
- 兵の進捗を管理し、大将軍に報告する
- 指示書: `instructions/gunshi.md`

### 兵（Hei）— 実装担当

- タスク単位で spawn される
- コーディング・テスト・コミット・PR 作成を行う
- `implementation_log.yaml` に実装の引き継ぎ情報を記録する
- 指示書: `instructions/hei.md`
- 兵には専門家（Frontend Developer、Backend Architect 等）の定義を適用できます。[obra/superpowers](https://github.com/obra/superpowers) でカスタムエージェント定義を管理するのがおすすめです

### 通信ルール

エージェント間の通信は指揮系統に従います。飛び級は禁止です。

```
王 ←→ 本陣 ←→ 大将軍 ←→ 軍師 ←→ 兵
```

## スキル一覧

`skills/` 配下に再利用可能な作業パターンが定義されています。スキルは `.gitignore` で除外されているため、**各個人のローカル環境での利用** となります。

スキルの作成は本陣（Honjin）に「〜〜のスキルを作ってほしい」と指示すれば自動で作成されます。使い込むほど、あなたの開発パターンに最適化されたスキルが蓄積されていきます。

## Wiki 連携

jin は技術知見を GitHub Wiki に同期する機能を持っています。

### 仕組み

1. エージェントが PR マージ後処理で `context/{service}/` に知見を蓄積する
2. サービスリポジトリに `wiki/` submodule が存在すれば、知見を Wiki 向けに整形して push する
3. GitHub Actions が週次で submodule 参照を最新化する PR を自動作成する

### セットアップ

Wiki 連携を有効にするには、対象サービスのリポジトリで以下を実行します:

```bash
# 1. GitHub の Web UI で Wiki を有効化し、Home ページを作成する

# 2. Wiki リポジトリを submodule として追加
cd /path/to/your-service
git submodule add git@github.com:{owner}/{repo}.wiki.git wiki

# 3. GitHub Actions ワークフローを配置
# skills/wiki-submodule-setup/SKILL.md の Step 4 を参照
```

詳細な手順は `skills/wiki-submodule-setup/SKILL.md` を参照してください。

### Wiki が不要な場合

`wiki/` submodule を追加しなければ、Wiki 連携は一切動作しません。全ての Wiki 操作は `wiki/` ディレクトリの存在チェック付きです。
