#!/bin/bash
# ============================================================
# add_service.sh — multi-agent-kingdom サービス追加スクリプト
# ============================================================
#
# Usage:
#   ./add_service.sh                                    # 対話モード
#   ./add_service.sh --id myapp --path /path/to/myapp   # 非対話モード
#   ./add_service.sh --help
#
# Description:
#   kingdom にサービスを登録し、必要なファイル・ディレクトリを生成する。
#   - config/services.yaml にエントリ追加
#   - context/{service}.md テンプレート生成
#   - projects/{service}/agents.yaml 初期化

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================
# 色・ログ
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# ============================================================
# 引数パース
# ============================================================
SERVICE_ID=""
SERVICE_PATH=""
SERVICE_DESC=""

show_help() {
    cat <<'HELP'
Usage: ./add_service.sh [OPTIONS]

Options:
  --id ID          サービスID（英数字・ハイフンのみ）
  --path PATH      サービスの作業ディレクトリ（絶対パス）
  --desc DESC      サービスの説明（省略可）
  --help           このヘルプを表示

Examples:
  ./add_service.sh                                          # 対話モード
  ./add_service.sh --id myapp --path /path/to/myapp         # 非対話モード
  ./add_service.sh --id myapp --path /path/to/myapp --desc "My App"
HELP
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)    SERVICE_ID="$2";   shift 2 ;;
        --path)  SERVICE_PATH="$2"; shift 2 ;;
        --desc)  SERVICE_DESC="$2"; shift 2 ;;
        --help)  show_help ;;
        *)       error "不明な引数: $1"; show_help ;;
    esac
done

# ============================================================
# 対話モード（引数未指定時）
# ============================================================
if [[ -z "$SERVICE_ID" ]]; then
    echo -e "${CYAN}=== サービス追加 ===${NC}"
    echo ""

    read -rp "サービスID（英数字・ハイフン）: " SERVICE_ID
    if [[ -z "$SERVICE_ID" ]]; then
        error "サービスIDが空です"
        exit 1
    fi

    read -rp "作業ディレクトリ（絶対パス）: " SERVICE_PATH
    if [[ -z "$SERVICE_PATH" ]]; then
        error "パスが空です"
        exit 1
    fi

    read -rp "説明（省略可）: " SERVICE_DESC
fi

# ============================================================
# バリデーション
# ============================================================

# サービスID: 英数字・ハイフンのみ
if ! echo "$SERVICE_ID" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9-]*$'; then
    error "サービスIDは英数字・ハイフンのみ使用可能: $SERVICE_ID"
    exit 1
fi

# パス: 絶対パスか確認
if [[ "$SERVICE_PATH" != /* ]]; then
    error "パスは絶対パスで指定してください: $SERVICE_PATH"
    exit 1
fi

# パス: 存在確認
if [[ ! -d "$SERVICE_PATH" ]]; then
    warn "ディレクトリが存在しません: $SERVICE_PATH"
    read -rp "続行しますか？ [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "中断しました"
        exit 0
    fi
fi

# config/services.yaml 存在確認
SERVICES_FILE="$SCRIPT_DIR/config/services.yaml"
if [[ ! -f "$SERVICES_FILE" ]]; then
    error "config/services.yaml が見つかりません。先に ./first_setup.sh を実行してください"
    exit 1
fi

# 重複チェック
if grep -q "^  - id: ${SERVICE_ID}$" "$SERVICES_FILE" 2>/dev/null; then
    error "サービス '$SERVICE_ID' は既に登録されています"
    exit 1
fi

# ============================================================
# サービス登録
# ============================================================

# 説明のデフォルト値
if [[ -z "$SERVICE_DESC" ]]; then
    SERVICE_DESC="$SERVICE_ID"
fi

info "サービス '$SERVICE_ID' を登録します..."

# --- config/services.yaml にエントリ追加 ---

# services: [] の場合、空配列を消してエントリを追加
if grep -q "^services: \[\]$" "$SERVICES_FILE"; then
    sed -i.bak "s/^services: \[\]$/services:/" "$SERVICES_FILE"
    rm -f "${SERVICES_FILE}.bak"
fi

cat >> "$SERVICES_FILE" <<EOF
  - id: ${SERVICE_ID}
    name: ${SERVICE_ID}
    path: ${SERVICE_PATH}
    status: active
    description: ${SERVICE_DESC}
EOF

info "config/services.yaml にエントリ追加"

# --- context/{service}.md テンプレート生成 ---
CONTEXT_DIR="$SCRIPT_DIR/context"
CONTEXT_FILE="$CONTEXT_DIR/${SERVICE_ID}.md"
mkdir -p "$CONTEXT_DIR"

if [[ -f "$CONTEXT_FILE" ]]; then
    warn "context/${SERVICE_ID}.md は既に存在します（スキップ）"
else
    cat > "$CONTEXT_FILE" <<EOF
# ${SERVICE_ID} 技術コンテキスト

> このファイルは大将軍が管理する。兵は実装前に必ず読め。

## アーキテクチャ

（記入待ち）

## コーディング規約

（記入待ち）

## 注意事項

（記入待ち）
EOF
    info "context/${SERVICE_ID}.md を生成"
fi

# --- projects/{service}/agents.yaml 初期化 ---
PROJECT_DIR="$SCRIPT_DIR/projects/${SERVICE_ID}"
AGENTS_FILE="$PROJECT_DIR/agents.yaml"
mkdir -p "$PROJECT_DIR"

if [[ -f "$AGENTS_FILE" ]]; then
    warn "projects/${SERVICE_ID}/agents.yaml は既に存在します（スキップ）"
else
    cat > "$AGENTS_FILE" <<EOF
service: ${SERVICE_ID}
agents:
  daishogun: null
  gunshis: []
EOF
    info "projects/${SERVICE_ID}/agents.yaml を生成"
fi

# ============================================================
# 完了
# ============================================================
echo ""
echo -e "${GREEN}=== サービス追加完了 ===${NC}"
echo ""
echo "  サービスID: $SERVICE_ID"
echo "  パス:       $SERVICE_PATH"
echo "  説明:       $SERVICE_DESC"
echo ""
echo "  生成ファイル:"
echo "    - config/services.yaml（エントリ追加）"
echo "    - context/${SERVICE_ID}.md"
echo "    - projects/${SERVICE_ID}/agents.yaml"
echo ""
echo -e "起動: ${CYAN}./shutsujin.sh ${SERVICE_ID}${NC}"
