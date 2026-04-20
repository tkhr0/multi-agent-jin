#!/bin/bash
# ============================================================
# shutsujin.sh — multi-agent-jin 出陣スクリプト
# ============================================================
#
# Usage:
#   ./shutsujin.sh <service_name> [OPTIONS]
#
# Options:
#   --cli CLAUDE|CODEX
#   --model MODEL    本陣のモデル指定（デフォルト: opus）
#   --clean          サービス状態をリセットして起動
#   --yolo           --dangerously-skip-permissions を付与して起動
#   --help           ヘルプ表示
#
# Description:
#   指定サービスの本陣（Honjin）セッションを起動する。
#   Claude Code の Agent Teams を使い、本陣 → 大将軍 → 軍師 → 兵 の階層を構築する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================
# 色・ログ
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ============================================================
# ヘルプ
# ============================================================
show_help() {
    cat <<'HELP'
Usage: ./shutsujin.sh <service_name> [OPTIONS]

Arguments:
  service_name     起動するサービスのID（config/services.yaml に登録済みであること）

Options:
  --cli CLAUDE|CODEX  起動する CLI を指定（デフォルト: CLAUDE）
  --model MODEL    本陣のモデル指定（opus, sonnet, haiku / デフォルト: opus）
  --clean          サービス状態をリセットして起動
  --yolo           --dangerously-skip-permissions を付与して起動
  --help           このヘルプを表示

Examples:
  ./shutsujin.sh myapp                  # myapp サービスを起動
  ./shutsujin.sh myapp --cli codex      # Codex で起動
  ./shutsujin.sh myapp --model sonnet   # モデルを sonnet に指定
  ./shutsujin.sh myapp --clean          # 状態リセットして起動
  ./shutsujin.sh myapp --yolo           # 権限確認なしで起動
HELP
    exit 0
}

# ============================================================
# YAML パースユーティリティ
# ============================================================

# config/services.yaml から指定サービスのフィールドを取得
get_service_field() {
    local service_id="$1"
    local field="$2"
    local in_service=false

    while IFS= read -r line; do
        if echo "$line" | grep -q "^  - id: ${service_id}$"; then
            in_service=true
            continue
        fi
        if [[ "$in_service" == true ]]; then
            # 次のサービスエントリに到達したら終了
            if echo "$line" | grep -q "^  - id:"; then
                break
            fi
            if echo "$line" | grep -q "^    ${field}:"; then
                echo "$line" | sed "s/^    ${field}: *//" | tr -d '"' | tr -d "'"
                return 0
            fi
        fi
    done < "$SERVICES_FILE"

    return 1
}

# config/services.yaml から全サービスIDを一覧
list_services() {
    grep "^  - id:" "$SERVICES_FILE" 2>/dev/null | sed 's/^  - id: *//' || true
}

# ============================================================
# 引数パース
# ============================================================
SERVICE_NAME=""
CLI="claude"
MODEL="opus"
CLEAN_MODE=false
YOLO_MODE=false

# 引数なしならヘルプ
if [[ $# -eq 0 ]]; then
    show_help
fi

# 最初の引数がオプションでなければサービス名
if [[ "$1" != --* ]]; then
    SERVICE_NAME="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cli)
            if [[ $# -lt 2 ]]; then
                error "--cli には CLAUDE または CODEX を指定してください"
                exit 1
            fi
            CLI="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
            shift 2
            ;;
        --model)
            if [[ $# -lt 2 ]]; then
                error "--model にはモデル名を指定してください"
                exit 1
            fi
            MODEL="$2"
            shift 2
            ;;
        --clean)
            CLEAN_MODE=true
            shift
            ;;
        --yolo)
            YOLO_MODE=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            error "不明な引数: $1"
            echo ""
            show_help
            ;;
    esac
done

if [[ -z "$SERVICE_NAME" ]]; then
    error "サービス名が指定されていません"
    echo ""
    show_help
fi

# ============================================================
# サービス検証
# ============================================================
SERVICES_FILE="$SCRIPT_DIR/config/services.yaml"

if [[ ! -f "$SERVICES_FILE" ]]; then
    error "config/services.yaml が見つかりません"
    echo "先に ./first_setup.sh を実行してください"
    exit 1
fi

SERVICE_PATH=$(get_service_field "$SERVICE_NAME" "path" || true)
SERVICE_STATUS=$(get_service_field "$SERVICE_NAME" "status" || true)
SERVICE_DESC=$(get_service_field "$SERVICE_NAME" "description" || true)

if [[ -z "$SERVICE_PATH" ]]; then
    error "サービス '$SERVICE_NAME' が config/services.yaml に見つかりません"
    echo ""
    echo "登録済みサービス:"
    AVAILABLE=$(list_services)
    if [[ -n "$AVAILABLE" ]]; then
        echo "$AVAILABLE" | while read -r svc; do echo "  - $svc"; done
    else
        echo "  （なし — ./add_service.sh でサービスを追加してください）"
    fi
    exit 1
fi

if [[ "$SERVICE_STATUS" != "active" ]]; then
    warn "サービス '$SERVICE_NAME' のステータスは '$SERVICE_STATUS' です"
fi

# サービスパス存在確認
if [[ ! -d "$SERVICE_PATH" ]]; then
    warn "サービスのディレクトリが存在しません: $SERVICE_PATH"
fi

# モデル検証
case "$MODEL" in
    opus|sonnet|haiku) ;;
    *)
        error "不正なモデル: ${MODEL} （opus, sonnet, haiku のいずれかを指定）"
        exit 1
        ;;
esac

# CLI 検証
case "$CLI" in
    claude|codex) ;;
    *)
        error "不正な CLI: ${CLI} （claude, codex のいずれかを指定）"
        exit 1
        ;;
esac

# ============================================================
# クリーンモード
# ============================================================
if [[ "$CLEAN_MODE" == true ]]; then
    info "クリーンモード: サービス状態をリセットします"

    # バックアップ
    BACKUP_DIR="$SCRIPT_DIR/logs/backup_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$BACKUP_DIR"

    AGENTS_FILE="$SCRIPT_DIR/projects/${SERVICE_NAME}/agents.yaml"
    DASHBOARD_FILE="$SCRIPT_DIR/dashboard.md"

    if [[ -f "$AGENTS_FILE" ]]; then
        cp "$AGENTS_FILE" "$BACKUP_DIR/"
        cat > "$AGENTS_FILE" <<EOF
service: ${SERVICE_NAME}
agents:
  daishogun: null
  gunshis: []
EOF
        info "projects/${SERVICE_NAME}/agents.yaml をリセット"
    fi

    if [[ -f "$DASHBOARD_FILE" ]]; then
        cp "$DASHBOARD_FILE" "$BACKUP_DIR/"
        cat > "$DASHBOARD_FILE" <<EOF
# Dashboard

> 大将軍が更新する進捗ダッシュボード

## ${SERVICE_NAME}

（初期化済み）
EOF
        info "dashboard.md をリセット"
    fi

    info "バックアップ: $BACKUP_DIR"
    echo ""
fi

# ============================================================
# 環境変数でサービス情報を渡す
# ============================================================
export JIN_SERVICE_ID="${SERVICE_NAME}"
export JIN_SERVICE_PATH="${SERVICE_PATH}"

# ============================================================
# バナー
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║         ⚔  出陣  ⚔                     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  サービス: ${CYAN}${SERVICE_NAME}${NC}"
echo -e "  パス:     ${SERVICE_PATH}"
echo -e "  説明:     ${SERVICE_DESC}"
echo -e "  CLI:      ${CYAN}${CLI}${NC}"
echo -e "  モデル:   ${CYAN}${MODEL}${NC}"
echo ""
if [[ "$CLI" == "claude" ]]; then
    echo -e "  ${YELLOW}Claude Code を起動します...${NC}"
    echo -e "  ${YELLOW}CLAUDE.md → honjin.md の順で初期化が行われます${NC}"
else
    echo -e "  ${YELLOW}Codex CLI を起動します...${NC}"
    echo -e "  ${YELLOW}AGENT.md → CLAUDE.md → honjin.md の順で初期化が行われます${NC}"
fi
echo ""

# ============================================================
# 起動
# ============================================================
cd "$SCRIPT_DIR"
if [[ "$CLI" == "claude" ]]; then
    if ! command -v claude >/dev/null 2>&1; then
        error "claude コマンドが見つかりません"
        exit 1
    fi

    CLAUDE_ARGS=(--model "$MODEL")
    if [[ "$YOLO_MODE" == true ]]; then
        CLAUDE_ARGS+=(--dangerously-skip-permissions)
    fi

    exec claude "${CLAUDE_ARGS[@]}"
fi

if [[ ! -f "$SCRIPT_DIR/AGENT.md" ]]; then
    error "AGENT.md が見つかりません。Codex 起動には AGENT.md が必要です。"
    exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
    error "codex コマンドが見つかりません"
    exit 1
fi

CODEX_PROMPT=$(cat <<EOF
multi-agent-jin の本陣として振る舞ってください。

まずリポジトリの指示に従ってください:
1. AGENT.md を読む
2. CLAUDE.md を読む
3. instructions/honjin.md を読む
4. 環境変数 JIN_SERVICE_ID と JIN_SERVICE_PATH を確認する
5. config/services.yaml を読む
6. 大将軍を spawn し、instructions/daishogun.md を読ませる
7. 大将軍の spawn 完了後、王に「起動完了」と報告する

担当サービス:
- service_id: ${SERVICE_NAME}
- service_path: ${SERVICE_PATH}

起動後は、このリポジトリの指示体系に従って、王の指示を解釈して対応してください。
EOF
)

CODEX_ARGS=(--model "$MODEL" --sandbox workspace-write)
if [[ "$YOLO_MODE" == true ]]; then
    CODEX_ARGS+=(--sandbox danger-full-access)
fi

exec codex "${CODEX_ARGS[@]}" "$CODEX_PROMPT"
