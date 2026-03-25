#!/usr/bin/env bash
# =============================================================================
#  fix-zephyr.sh — Zephyr 核心下載失敗救援腳本
#
#  症狀（遇到以下任一錯誤時使用）：
#    - error: RPC failed; curl 92 HTTP/2 stream was not closed cleanly
#    - error: RPC failed; curl 56 Recv failure: Connection timed out
#    - fatal: early EOF
#    - fatal: fetch-pack: invalid index-pack output
#
#  原理：完全放棄 git clone，改用 wget 下載 ZIP + west 本地認領
#
#  用法:
#    bash scripts/fix-zephyr.sh           # 從 ~/nanoclaw 執行
#    bash scripts/fix-zephyr.sh --resume  # 已有 main.zip 時跳過下載
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[FIX]${NC}   $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }

# ── 參數 ──────────────────────────────────────────────────────────────────────
RESUME=false
for arg in "$@"; do
  [[ "$arg" == "--resume" ]] && RESUME=true
done

# ── 路徑設定 ──────────────────────────────────────────────────────────────────
WORKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZEPHYR_DIR="$WORKDIR/zephyrproject"
VENV="$WORKDIR/.venv"

[[ -d "$WORKDIR" ]] || error "找不到工作目錄 $WORKDIR，請先執行 setup.sh"

# ── 啟動虛擬環境 ──────────────────────────────────────────────────────────────
if [[ -f "$VENV/bin/activate" ]]; then
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
else
  warn "找不到 .venv，建立新的虛擬環境..."
  python3 -m venv "$VENV"
  source "$VENV/bin/activate"
  pip install -q west
fi

command -v west   >/dev/null 2>&1 || pip install -q west
command -v wget   >/dev/null 2>&1 || sudo apt-get install -y -qq wget
command -v unzip  >/dev/null 2>&1 || sudo apt-get install -y -qq unzip

# ── Step 1：清除損壞殘骸 ──────────────────────────────────────────────────────
step "Step 1：清除損壞的下載殘骸"

mkdir -p "$ZEPHYR_DIR"
cd "$ZEPHYR_DIR"

if [[ "$RESUME" == "true" && -f "main.zip" ]]; then
  warn "--resume 模式：保留現有 main.zip，跳過下載"
else
  info "清除 zephyr/ 目錄與 .west 設定..."
  rm -rf zephyr zephyr-main .west
  [[ "$RESUME" == "true" ]] || rm -f main.zip
fi

success "清除完成"

# ── Step 2：ZIP 暴力下載 ──────────────────────────────────────────────────────
step "Step 2：wget 下載 Zephyr main.zip"

ZIP_URL="https://github.com/zephyrproject-rtos/zephyr/archive/refs/heads/main.zip"

if [[ -f "main.zip" ]]; then
  info "main.zip 已存在，跳過下載（如需重新下載請刪除後再執行）"
else
  info "開始下載（檔案較大，視網速需要 5–20 分鐘）..."
  wget --show-progress \
       --tries=5 \
       --retry-connrefused \
       --waitretry=10 \
       -O main.zip \
       "$ZIP_URL"
fi

success "ZIP 下載完成"

# ── Step 3：解壓縮並重新命名 ──────────────────────────────────────────────────
step "Step 3：解壓縮"

rm -rf zephyr zephyr-main
info "解壓縮 main.zip（需要數十秒）..."
unzip -q main.zip
mv zephyr-main zephyr
rm main.zip
success "解壓縮完成"

# ── Step 3.5：初始化虛擬 Git 儲存庫 ────────────────────────────────────────
step "Step 3.5：初始化虛擬 Git 儲存庫（west 依賴 Git）"

info "ZIP 解壓後無 .git 目錄，需補上才能讓 west 正常運作..."
cd zephyr
git init -q
# 用 commit --allow-empty 跳過 git add（70,000+ 檔案 add 在 Pi 上需要 10+ 分鐘）
# west 只需要 .git 目錄存在即可，不需要實際追蹤所有檔案
git commit -q --allow-empty -m "Initial commit from ZIP"
cd ..
success "Git 初始化完成（略過 git add，節省約 10 分鐘）"


# ── Step 4：west 本地認領 ─────────────────────────────────────────────────────
step "Step 4：west init -l（本地認領）"

west init -l zephyr
success "west 認領完成"

# ── Step 5：淺層更新附屬套件 ──────────────────────────────────────────────────
step "Step 5：west update（淺層，防斷線）"

info "這步驟會下載數十個附屬模組，使用 --depth=1 最小化流量..."
west update --narrow -o=--depth=1

success "west update 完成"

# ── 完成 ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Zephyr 核心修復完成！                  ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  下一步："
echo -e "    ${BOLD}1.${NC} cd ~/nanoclaw"
echo -e "    ${BOLD}2.${NC} bash setup.sh --skip-zephyr   ${YELLOW}# 繼續完成其餘安裝${NC}"
echo -e "    ${BOLD}3.${NC} 或直接執行 docker build"
echo ""
