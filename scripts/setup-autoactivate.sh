#!/usr/bin/env bash
# =============================================================================
#  scripts/setup-autoactivate.sh
#  將 NanoClaw 虛擬環境的自動 activate 寫入 ~/.bashrc
#
#  用法:
#    bash scripts/setup-autoactivate.sh          # 安裝
#    bash scripts/setup-autoactivate.sh --remove # 移除
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[AUTO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

BASHRC="$HOME/.bashrc"
MARKER="# >>> NanoClaw venv auto-activate <<<"
END_MARKER="# <<< NanoClaw venv auto-activate <<<"
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PATH="$WORKDIR/.venv/bin/activate"

# ── 移除模式 ──────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--remove" ]]; then
  if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    # 用 sed 刪除從 MARKER 到 END_MARKER 之間的所有行
    sed -i "/$MARKER/,/$END_MARKER/d" "$BASHRC"
    success "已從 $BASHRC 移除 NanoClaw auto-activate 設定"
  else
    warn "找不到 NanoClaw auto-activate 設定，無需移除"
  fi
  exit 0
fi

# ── 安裝模式 ──────────────────────────────────────────────────────────────────
if [[ ! -f "$VENV_PATH" ]]; then
  warn "找不到虛擬環境：$VENV_PATH"
  warn "請先執行 setup.sh 建立環境，或確認路徑是否正確"
  exit 1
fi

if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
  info "auto-activate 設定已存在，略過（移除請加 --remove）"
  exit 0
fi

# 用無引號 BASHRC_BLOCK，讓 $WORKDIR 在安裝時鎖定
cat >> "$BASHRC" << BASHRC_BLOCK

# >>> NanoClaw venv auto-activate <<<
# 每次開啟新 shell 自動啟用 NanoClaw 虛擬環境
_NANOCLAW_VENV="$WORKDIR/.venv/bin/activate"
if [[ -f "\$_NANOCLAW_VENV" ]]; then
  source "\$_NANOCLAW_VENV"
fi
unset _NANOCLAW_VENV
# <<< NanoClaw venv auto-activate <<<
BASHRC_BLOCK

success "已寫入 $BASHRC"
echo ""
echo -e "  立即套用（無需重開機）："
echo -e "    ${BOLD}source ~/.bashrc${NC}"
echo ""
echo -e "  確認已啟用："
echo -e "    ${BOLD}which python3${NC}  ${CYAN}# 應顯示 ~/nanoclaw/.venv/bin/python3${NC}"
echo ""
echo -e "  日後若想移除："
echo -e "    ${BOLD}bash scripts/setup-autoactivate.sh --remove${NC}"
echo ""
