#!/usr/bin/env bash
# =============================================================================
#  NanoClaw Setup — 一鍵建置腳本
#  用法: bash setup.sh [--skip-zephyr] [--skip-docker] [--skip-flash] [--git]
# =============================================================================
set -euo pipefail

# ── 顏色輸出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${NC}"; }

# ── 旗標解析 ──────────────────────────────────────────────────────────────────
SKIP_ZEPHYR=false
SKIP_DOCKER=false
SKIP_FLASH=false

for arg in "$@"; do
  case $arg in
    --skip-zephyr) SKIP_ZEPHYR=true ;;
    --skip-docker) SKIP_DOCKER=true ;;
    --skip-flash)  SKIP_FLASH=true  ;;
    --help|-h)
      echo "用法: bash setup.sh [選項]"
      echo "  --skip-zephyr   跳過 Zephyr 源碼下載"
      echo "  --skip-docker   跳過 Docker 映像檔建置"
      echo "  --skip-flash    跳過 nrfutil 燒錄工具安裝"
      echo "  --git           Zephyr 改用 git clone（網路穩定時使用，預設為 ZIP）"
      exit 0 ;;
    *) warn "未知參數: $arg，略過" ;;
  esac
done

# ── 環境檢查 ──────────────────────────────────────────────────────────────────
step "環境前置檢查"

ARCH=$(uname -m)
if [[ "$ARCH" != "aarch64" ]]; then
  warn "目前架構為 $ARCH，此腳本針對 ARM64 (aarch64) 最佳化"
fi

command -v docker  >/dev/null 2>&1 || error "找不到 docker，請先安裝 docker.io"
command -v python3 >/dev/null 2>&1 || error "找不到 python3"
command -v git     >/dev/null 2>&1 || error "找不到 git"
command -v node    >/dev/null 2>&1 || warn "找不到 node/npm，Claude Code 安裝可能失敗"

success "基礎環境檢查通過 (arch: $ARCH)"

# ── 工作目錄 ──────────────────────────────────────────────────────────────────
WORKDIR="$HOME/nanoclaw"
step "建立工作目錄：$WORKDIR"
mkdir -p "$WORKDIR/src"
cd "$WORKDIR"
success "工作目錄就緒"

# ── 第一階段：系統套件 ────────────────────────────────────────────────────────
step "第一階段：安裝系統依賴套件"

sudo apt-get update -qq
sudo apt-get install -y -qq \
  docker.io nodejs npm picocom curl wget git \
  python3-venv python3-pip xz-utils

# docker 群組
if ! groups "$USER" | grep -q docker; then
  sudo usermod -aG docker "$USER"
  warn "已將 $USER 加入 docker 群組，本次 session 需執行 'newgrp docker' 或重新登入"
fi

# Claude Code
if ! command -v claude >/dev/null 2>&1; then
  info "安裝 Claude Code CLI..."
  sudo npm install -g @anthropic-ai/claude-code
else
  info "Claude Code 已安裝，略過"
fi

success "第一階段完成"

# ── 第二階段：Zephyr 源碼 ─────────────────────────────────────────────────────
if [[ "$SKIP_ZEPHYR" == "true" ]]; then
  warn "已跳過 Zephyr 下載 (--skip-zephyr)"
else
  step "第二階段：下載 Zephyr 核心"

  # 安裝 west（虛擬環境）
  python3 -m venv "$WORKDIR/.venv"
  # shellcheck disable=SC1091
  source "$WORKDIR/.venv/bin/activate"
  pip install -q west

  ZEPHYR_DIR="$WORKDIR/zephyrproject"
  mkdir -p "$ZEPHYR_DIR"

  if [[ -d "$ZEPHYR_DIR/.west" ]]; then
    info "zephyrproject 已存在，跳過下載直接 west update"
  else
    # ── 方法選擇：優先 ZIP，加上 --git 旗標可改用 git clone ──────────────────
    USE_GIT=false
    for arg in "$@"; do [[ "$arg" == "--git" ]] && USE_GIT=true; done

    if [[ "$USE_GIT" == "true" ]]; then
      # 方法 B：git clone（網路穩定時使用）
      info "方法 B：git clone 淺層複製..."
      west init \
        -m https://github.com/zephyrproject-rtos/zephyr \
        --mr main \
        "$ZEPHYR_DIR"
    else
      # 方法 A：ZIP 暴力下載（預設，斷線環境首選）
      info "方法 A：ZIP 暴力下載（防斷線模式）..."
      command -v unzip >/dev/null 2>&1 || sudo apt-get install -y -qq unzip

      cd "$ZEPHYR_DIR"
      info "下載 Zephyr main.zip（可能需要數分鐘）..."
      wget -q --show-progress \
        https://github.com/zephyrproject-rtos/zephyr/archive/refs/heads/main.zip \
        -O main.zip

      info "解壓縮..."
      unzip -q main.zip
      mv zephyr-main zephyr
      rm main.zip

      info "west 本地認領 (west init -l)..."
      west init -l zephyr
      cd "$WORKDIR"
    fi
  fi

  info "west update（淺層，防斷線）..."
  cd "$ZEPHYR_DIR"
  west update --narrow -o=--depth=1
  cd "$WORKDIR"
  success "第二階段完成"
fi

# ── 第三階段：Docker 編譯映像檔 ───────────────────────────────────────────────
if [[ "$SKIP_DOCKER" == "true" ]]; then
  warn "已跳過 Docker 建置 (--skip-docker)"
else
  step "第三階段：建置 Docker 編譯映像檔"

  if docker image inspect nordic-build-arm64 >/dev/null 2>&1; then
    info "映像檔 nordic-build-arm64 已存在，跳過 build"
  else
    if [[ ! -f "$WORKDIR/Dockerfile.nordic" ]]; then
      error "找不到 Dockerfile.nordic，請確認腳本與 Dockerfile 位於同一目錄"
    fi
    docker build -f "$WORKDIR/Dockerfile.nordic" -t nordic-build-arm64 "$WORKDIR"
  fi

  success "第三階段完成"
fi

# ── 第四階段：nrfutil 燒錄工具 ───────────────────────────────────────────────
if [[ "$SKIP_FLASH" == "true" ]]; then
  warn "已跳過燒錄工具安裝 (--skip-flash)"
else
  step "第四階段：安裝 nrfutil 燒錄工具"

  if ! command -v nrfutil >/dev/null 2>&1; then
    sudo curl -fsSL \
      "https://files.nordicsemi.com/artifactory/swtools/external/nrfutil/executables/aarch64-unknown-linux-gnu/nrfutil" \
      -o /usr/local/bin/nrfutil
    sudo chmod +x /usr/local/bin/nrfutil
    info "nrfutil 下載完成"
  else
    info "nrfutil 已安裝，略過"
  fi

  nrfutil install device || warn "nrfutil install device 失敗，請稍後手動執行"

  # udev 規則
  UDEV_RULE='SUBSYSTEM=="usb", ATTRS{idVendor}=="1366", MODE="0666"'
  UDEV_FILE="/etc/udev/rules.d/99-jlink.rules"
  if [[ ! -f "$UDEV_FILE" ]]; then
    echo "$UDEV_RULE" | sudo tee "$UDEV_FILE" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    success "udev 規則已寫入 $UDEV_FILE"
  else
    info "udev 規則已存在，略過"
  fi

  success "第四階段完成"
fi

# ── 第五階段：複製 CLAUDE.md ──────────────────────────────────────────────────
step "第五階段：部署 CLAUDE.md 指導原則"

if [[ -f "$WORKDIR/CLAUDE.md" ]]; then
  info "CLAUDE.md 已存在，略過"
else
  if [[ -f "$(dirname "$0")/CLAUDE.md" ]]; then
    cp "$(dirname "$0")/CLAUDE.md" "$WORKDIR/CLAUDE.md"
    success "CLAUDE.md 已複製至 $WORKDIR"
  else
    warn "找不到 CLAUDE.md，請手動放置至 $WORKDIR/CLAUDE.md"
  fi
fi

# ── 第六階段：自動 activate（寫入 .bashrc）────────────────────────────────────
step "第六階段：設定開機自動 activate 虛擬環境"

BASHRC="$HOME/.bashrc"
MARKER="# >>> NanoClaw venv auto-activate <<<"
ACTIVATE_BLOCK="${MARKER}
# 若在 ~/nanoclaw 目錄下或其子目錄，自動啟用虛擬環境
_NANOCLAW_VENV=\"\$HOME/nanoclaw/.venv/bin/activate\"
if [[ -f \"\$_NANOCLAW_VENV\" ]]; then
  source \"\$_NANOCLAW_VENV\"
  # 進入 nanoclaw 時自動 cd（選用：若想每次開 shell 都在工作目錄可取消註解）
  # cd \"\$HOME/nanoclaw\"
fi
unset _NANOCLAW_VENV
# <<< NanoClaw venv auto-activate <<<"

if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
  info ".bashrc 已有 NanoClaw auto-activate 設定，略過"
else
  echo "" >> "$BASHRC"
  echo "$ACTIVATE_BLOCK" >> "$BASHRC"
  success "已寫入 $BASHRC，下次開 shell 自動 activate"
fi

# ── 完成摘要 ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   NanoClaw 建置完成！                    ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  工作目錄: ${CYAN}$WORKDIR${NC}"
echo -e "  下一步:"
echo -e "    ${BOLD}1.${NC} newgrp docker        ${YELLOW}# 若剛加入 docker 群組${NC}"
echo -e "    ${BOLD}2.${NC} source ~/.bashrc      ${YELLOW}# 立即套用 auto-activate${NC}"
echo -e "    ${BOLD}3.${NC} cd ~/nanoclaw"
echo -e "    ${BOLD}4.${NC} claude login"
echo -e "    ${BOLD}5.${NC} claude                ${YELLOW}# 開始開發！${NC}"
echo ""
