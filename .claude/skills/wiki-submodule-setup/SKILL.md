---
name: wiki-submodule-setup
description: 任意のリポジトリに GitHub Wiki を git submodule として追加し、AI エージェントが知見を直接 push できる環境を構築する。週次で submodule 参照を最新化する GitHub Actions ワークフローも含む。
---

# Wiki Submodule Setup - GitHub Wiki のサブモジュール統合

## Overview

GitHub Wiki リポジトリを `wiki/` サブモジュールとしてメインリポジトリに含め、AI エージェントが技術知見を直接 push できる環境を構築する。submodule 参照の最新化は GitHub Actions が週次で行い、PR を自動作成する。

## When to Use

- 新しいリポジトリに wiki submodule を追加するとき
- 「wiki をセットアップしたい」「知見を wiki で共有したい」等のキーワードが出たとき

## Prerequisites

- 対象リポジトリに GitHub Wiki が有効化されていること
- Wiki に最低1ページ（Home.md）が存在すること（GitHub Wiki は初回ページ作成前は clone できない）

## Instructions

### Step 1: Wiki リポジトリの確認

```bash
# Wiki リポジトリが clone 可能か確認
git ls-remote https://github.com/{owner}/{repo}.wiki.git
```

エラーになる場合、GitHub の Web UI から Wiki を有効化し、Home ページを作成すること。

### Step 2: submodule として追加

```bash
cd {repo_path}
git submodule add https://github.com/{owner}/{repo}.wiki.git wiki
git commit -m "docs: wiki submodule を追加"
git push
```

### Step 3: wiki/ のディレクトリ構成を作成

```bash
cd wiki/
```

以下の構成を基本とする:

```
wiki/
  Home.md           # 目次（全ページへのリンク）
  Base.md            # 基本情報・コーディング規約・運用ルール
  {Domain}.md        # 領域別の技術知見（OpenAPI, Design, E2E, Deploy 等）
```

**Home.md のテンプレート:**

```markdown
# {project} 技術 Wiki

> この Wiki は AI エージェントが管理する技術知見です。PRマージ時に自動で知見が蓄積・更新されます。

---

## 目次

- [[Base]] — 基本情報・コーディング規約・運用ルール（全開発者必読）
- [[{Domain}]] — {領域の説明}
```

**各ページの冒頭テンプレート:**

```markdown
# {project} {ページタイトル}

> このページは AI エージェントが管理する技術知見です。{対象読者の説明}。
> 基本ルールは [[Base]] を必ず先に読んでください。
```

### Step 4: GitHub Actions ワークフローの作成

メインリポジトリに `.github/workflows/update-wiki-submodule.yml` を作成する:

```yaml
name: Update Wiki Submodule

on:
  schedule:
    # 毎週月曜 09:00 JST（日曜 24:00 UTC）
    - cron: '0 0 * * 1'
  workflow_dispatch:

permissions:
  contents: write
  pull-requests: write

jobs:
  update-wiki-submodule:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update wiki submodule
        run: |
          cd wiki
          git fetch origin
          git checkout master
          git pull origin master
          cd ..

      - name: Check for changes
        id: check
        run: |
          if git diff --quiet wiki; then
            echo "changed=false" >> $GITHUB_OUTPUT
          else
            echo "changed=true" >> $GITHUB_OUTPUT
          fi

      - name: Create PR
        if: steps.check.outputs.changed == 'true'
        run: |
          BRANCH="chore/update-wiki-submodule-$(date +%Y%m%d)"
          git checkout -b "$BRANCH"
          git add wiki
          git commit -m "chore: wiki submodule 参照を最新化"
          git push origin "$BRANCH"
          gh pr create \
            --title "chore: wiki submodule 参照を最新化" \
            --body "wiki submodule の参照を最新の commit に更新します。自動生成 PR です。" \
            --base main
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Step 5: 初回の wiki コンテンツを push

```bash
cd wiki/
git add -A
git commit -m "docs: 技術知見の初期構築"
git push origin master
```

**注意**: Wiki リポジトリのデフォルトブランチは `master`（`main` ではない）。

### Step 6: 完了確認

```bash
# submodule が正しく登録されているか
git submodule status

# wiki リポジトリに push されているか
cd wiki/ && git log --oneline -5

# GitHub の Web UI で Wiki ページが表示されるか確認
```

## Guidelines

### wiki/ が存在する場合のみ操作する

- 全ての wiki 操作は `wiki/` ディレクトリの存在を前提とする
- `wiki/` が存在しないリポジトリでは wiki 関連の処理を一切行わない
- 存在チェック: `[ -d wiki/ ]` または `test -d wiki/`

### context → wiki の変換ルール

context ファイルを wiki に変換する際は以下を適用する:

- エージェント向けの表現を人間向けに言い換える
  - 「兵は〜」「軍師は〜」→ 「開発者は〜」
  - 「〜せよ」→ 「〜すること」
  - 「base.md を先読みせよ」→ 「[[Base]] を必ず先に読んでください」
- ファイル参照を Wiki リンクに変換: `context/{service}/xxx.md` → `[[Xxx]]`
- 内容そのものは変えない。表現だけ調整する

### submodule 参照の更新は兵の責務ではない

- 兵は `wiki/` 内で commit → push するだけ
- メインリポジトリの submodule 参照（`.gitmodules` のコミットハッシュ）は更新しない
- 参照の最新化は GitHub Actions が週次で行う

### Wiki リポジトリのブランチ

- GitHub Wiki のデフォルトブランチは `master`（GitHub の仕様）
- `main` ではないので注意すること

## Examples

### Input
「myapp に wiki submodule をセットアップしてほしい」

### Output
1. `git submodule add https://github.com/{owner}/{repo}.wiki.git wiki`
2. `context/{service}/` 配下のファイルを wiki 向けに整形して `wiki/` に配置
3. `.github/workflows/update-wiki-submodule.yml` を作成
4. wiki リポジトリに push、メインリポジトリに commit
