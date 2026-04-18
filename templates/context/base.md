# {service} 基本コンテキスト（全兵必読）

> このファイルはあらゆるタスクを担当する兵が実装前に必ず読むべき共通ルールを記載する。
> 領域別の詳細知見は `context/{service}/` 配下の各ファイルを参照せよ。

最終更新: YYYY-MM-DD

---

## 基本情報

- **プロジェクトID**: {service}
- **正式名称**: {service} — （サービスの説明）
- **パス**: /path/to/{service}
- **技術スタック**: （例: NestJS + Next.js + PostgreSQL）

---

## コーディング規約

### コミット

- Conventional Commits 形式（`feat:`, `fix:`, `refactor:` 等）
- メッセージは日本語で記述
- `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` を必ず付与

### PR

- タイトル・本文は日本語で記載
- 本文には概要・変更内容・テスト計画を含める

### コードスタイル

<!-- プロジェクト固有のルールを記載 -->
<!-- 例: -->
<!-- - `as` によるキャストは禁止。if ブロックによる早期リターンで型を絞り込め -->
<!-- - ESLint / Prettier の設定に従う -->

---

## 開発環境

<!-- 開発用 URL やセットアップ手順を記載 -->
<!-- 例: -->
<!-- - API: http://localhost:3000 -->
<!-- - Admin: http://localhost:3001 -->

---

## 運用上の注意

<!-- ハマりやすい落とし穴やプロジェクト固有の制約を記載 -->
