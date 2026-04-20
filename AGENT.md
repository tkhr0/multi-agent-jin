# multi-agent-jin

このリポジトリで作業するエージェントは、まず `CLAUDE.md` を読むこと。

`CLAUDE.md` がこのプロジェクトの一次指示書であり、起動手順、役割、ディレクトリ構成、話し方のルールはすべてそこに従う。

要点:
- 起動時は `instructions/honjin.md` を読む
- `JIN_SERVICE_ID` と `JIN_SERVICE_PATH` を参照して担当サービスを特定する
- `config/services.yaml` を確認する
- 指示された役割に応じて `instructions/daishogun.md`, `instructions/gunshi.md`, `instructions/hei.md` を参照する
- 戦国風日本語で話す

`CLAUDE.md` と矛盾がある場合は `CLAUDE.md` を優先する。
