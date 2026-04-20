#!/bin/bash
# ============================================================
# first_setup.sh — multi-agent-jin 初回セットアップスクリプト
# ============================================================
#
# Usage:
#   ./first_setup.sh
#
# Description:
#   前提条件の確認とランタイムディレクトリ・設定ファイルの初期化を行う。
#   冪等設計のため、再実行しても安全。

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

CHECKS_PASSED=0
CHECKS_WARNED=0
CHECKS_FAILED=0

check_pass() { info "$1"; CHECKS_PASSED=$((CHECKS_PASSED + 1)); }
check_warn() { warn "$1"; CHECKS_WARNED=$((CHECKS_WARNED + 1)); }
check_fail() { error "$1"; CHECKS_FAILED=$((CHECKS_FAILED + 1)); }

# ============================================================
# バナー
# ============================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   multi-agent-jin 初回セットアップ   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ============================================================
# Step 1: OS検出
# ============================================================
echo -e "${CYAN}--- Step 1: OS検出 ---${NC}"

OS_TYPE="unknown"
case "$(uname -s)" in
    Darwin) OS_TYPE="macOS" ;;
    Linux)  OS_TYPE="Linux" ;;
    *)      OS_TYPE="unknown" ;;
esac

if [[ "$OS_TYPE" == "unknown" ]]; then
    check_warn "未対応のOS: $(uname -s)（続行は可能）"
else
    check_pass "OS: $OS_TYPE ($(uname -m))"
fi
echo ""

# ============================================================
# Step 2: Agent CLI
# ============================================================
echo -e "${CYAN}--- Step 2: Agent CLI ---${NC}"

CLI_FOUND=false

if command -v claude &>/dev/null; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null || echo "不明")
    check_pass "Claude Code CLI: $CLAUDE_VERSION"
    CLI_FOUND=true
else
    info "Claude Code CLI: 未検出"
fi

if command -v codex &>/dev/null; then
    CODEX_VERSION=$(codex --version 2>/dev/null || echo "不明")
    check_pass "Codex CLI: $CODEX_VERSION"
    CLI_FOUND=true
else
    info "Codex CLI: 未検出"
fi

if [[ "$CLI_FOUND" != true ]]; then
    check_fail "Claude Code CLI も Codex CLI も見つかりません"
    echo ""
    echo "  Claude Code のインストール方法:"
    echo "    curl -fsSL https://claude.ai/install.sh | bash"
    echo ""
    echo "  Codex CLI は別途インストールしてください。"
    echo "  すでに Claude Code か Codex CLI のどちらかを入れてから再実行してください。"
    echo ""
fi
echo ""

# ============================================================
# Step 3: Node.js
# ============================================================
echo -e "${CYAN}--- Step 3: Node.js ---${NC}"

if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/^v//' | cut -d. -f1)
    if [[ "$NODE_MAJOR" -ge 18 ]]; then
        check_pass "Node.js: $NODE_VERSION"
    else
        check_warn "Node.js $NODE_VERSION は古い可能性があります（18+ 推奨）"
    fi
else
    check_warn "Node.js が見つかりません（Memory MCP に必要）"
    echo ""
    echo "  インストール方法:"
    echo "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash"
    echo "    nvm install 20"
    echo ""
fi
echo ""

# ============================================================
# Step 4: ディレクトリ作成
# ============================================================
echo -e "${CYAN}--- Step 4: ディレクトリ作成 ---${NC}"

DIRS=("config" "context" "projects" "logs")
for dir in "${DIRS[@]}"; do
    target="$SCRIPT_DIR/$dir"
    if [[ -d "$target" ]]; then
        info "$dir/ — 既に存在"
    else
        mkdir -p "$target"
        check_pass "$dir/ — 作成"
    fi
done
echo ""

# ============================================================
# Step 5: config/services.yaml テンプレート
# ============================================================
echo -e "${CYAN}--- Step 5: config/services.yaml ---${NC}"

SERVICES_FILE="$SCRIPT_DIR/config/services.yaml"
if [[ -f "$SERVICES_FILE" ]]; then
    info "config/services.yaml — 既に存在（スキップ）"
else
    cat > "$SERVICES_FILE" <<'EOF'
services: []
# 例:
#  - id: myapp
#    name: myapp
#    path: /path/to/myapp
#    status: active
#    description: サービスの説明
EOF
    check_pass "config/services.yaml — テンプレート生成"
fi
echo ""

# ============================================================
# Step 6: Memory MCP
# ============================================================
echo -e "${CYAN}--- Step 6: Memory MCP ---${NC}"

if command -v claude &>/dev/null; then
    if claude mcp list 2>/dev/null | grep -q "memory"; then
        check_pass "Memory MCP: 設定済み"
    else
        check_warn "Memory MCP: 未設定"
        echo ""
        echo "  設定方法:"
        echo "    claude mcp add memory \\"
        echo "      -e MEMORY_FILE_PATH=\"\$HOME/.claude/memory/jin_memory.jsonl\" \\"
        echo "      -- npx -y @modelcontextprotocol/server-memory"
        echo ""
    fi
else
    warn "Claude Code CLI がないため Memory MCP の確認をスキップ"
fi
echo ""

# ============================================================
# Step 7: スクリプト実行権限
# ============================================================
echo -e "${CYAN}--- Step 7: スクリプト実行権限 ---${NC}"

SCRIPTS=("first_setup.sh" "add_service.sh" "shutsujin.sh")
for script in "${SCRIPTS[@]}"; do
    target="$SCRIPT_DIR/$script"
    if [[ -f "$target" ]]; then
        chmod +x "$target"
        info "$script — 実行権限付与"
    fi
done
echo ""

# ============================================================
# Step 8: サービス追加
# ============================================================
echo -e "${CYAN}--- Step 8: サービス追加 ---${NC}"

# services.yaml が空（サービスなし）かチェック
if grep -q "^services: \[\]$" "$SERVICES_FILE" 2>/dev/null; then
    echo ""
    read -rp "サービスを追加しますか？ [y/N]: " add_service
    if [[ "$add_service" == "y" || "$add_service" == "Y" ]]; then
        "$SCRIPT_DIR/add_service.sh"
    else
        info "サービス追加をスキップ（後で ./add_service.sh で追加できます）"
    fi
else
    info "サービスが既に登録されています"
fi
echo ""

# ============================================================
# 完了サマリー
# ============================================================
echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          セットアップ完了                ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}✓ 成功: $CHECKS_PASSED${NC}"
if [[ $CHECKS_WARNED -gt 0 ]]; then
    echo -e "  ${YELLOW}! 警告: $CHECKS_WARNED${NC}"
fi
if [[ $CHECKS_FAILED -gt 0 ]]; then
    echo -e "  ${RED}✗ 失敗: $CHECKS_FAILED${NC}"
fi
echo ""
echo "次のステップ:"
echo "  1. サービス追加:  ./add_service.sh"
echo "  2. セッション起動: ./shutsujin.sh <service_name>"
echo "  3. Codex で起動:   ./shutsujin.sh <service_name> --cli codex"
echo ""
