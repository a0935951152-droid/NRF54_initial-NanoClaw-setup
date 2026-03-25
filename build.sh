#!/usr/bin/env bash
# =============================================================================
#  NanoClaw Build & Flash Helper
#  用法: bash scripts/build.sh [BOARD] [--flash] [--clean]
#
#  範例:
#    bash scripts/build.sh                            # 預設 nRF54L15，只編譯
#    bash scripts/build.sh nrf54l15 --flash           # 編譯 + 燒錄
#    bash scripts/build.sh nrf52840 --flash           # 編譯 nRF52840 + 燒錄
#    bash scripts/build.sh nrf54l15 --clean --flash   # 清除後重新編譯 + 燒錄
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[BUILD]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERR]${NC}   $*"; exit 1; }

# ── 目標板對照表 ──────────────────────────────────────────────────────────────
declare -A BOARD_MAP=(
  [nrf54l15]="nrf54l15dk/nrf54l15/cpuapp"
  [nrf52840]="nrf52840dk/nrf52840"
  [nrf52833]="nrf52833dk/nrf52833"
  [nrf52]="nrf52dk/nrf52"
)

declare -A FLASH_CORE=(
  [nrf54l15]="--core Application"
  [nrf52840]=""
  [nrf52833]=""
  [nrf52]=""
)

# ── 參數解析 ──────────────────────────────────────────────────────────────────
BOARD_KEY="nrf54l15"
DO_FLASH=false
DO_CLEAN=false

for arg in "$@"; do
  case "$arg" in
    --flash)  DO_FLASH=true ;;
    --clean)  DO_CLEAN=true ;;
    --help|-h)
      echo "用法: bash scripts/build.sh [BOARD] [--flash] [--clean]"
      echo "BOARD 可選: ${!BOARD_MAP[*]}"
      exit 0 ;;
    nrf*) BOARD_KEY="$arg" ;;
    *) warn "未知參數: $arg" ;;
  esac
done

# ── 驗證目標板 ────────────────────────────────────────────────────────────────
if [[ -z "${BOARD_MAP[$BOARD_KEY]+_}" ]]; then
  error "不支援的目標板 '$BOARD_KEY'。可選: ${!BOARD_MAP[*]}"
fi

BOARD_SPEC="${BOARD_MAP[$BOARD_KEY]}"
FLASH_ARGS="${FLASH_CORE[$BOARD_KEY]}"

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$WORKDIR/build"
SRC_DIR="$WORKDIR/src"

# ── 前置檢查 ──────────────────────────────────────────────────────────────────
[[ -d "$SRC_DIR" ]]          || error "找不到 src/ 目錄：$SRC_DIR"
[[ -f "$SRC_DIR/CMakeLists.txt" ]] || error "找不到 src/CMakeLists.txt，請先建立專案"
docker image inspect nordic-build-arm64 >/dev/null 2>&1 \
  || error "找不到 Docker 映像檔 nordic-build-arm64，請先執行 setup.sh"

info "目標板: ${BOLD}$BOARD_KEY${NC} → $BOARD_SPEC"

# ── 清除 ──────────────────────────────────────────────────────────────────────
if [[ "$DO_CLEAN" == "true" ]]; then
  info "清除 build 目錄..."
  rm -rf "$BUILD_DIR"
fi

# ── 編譯 ──────────────────────────────────────────────────────────────────────
info "開始編譯..."
docker run --rm \
  -v "$WORKDIR:/workspace" \
  -w /workspace/zephyrproject \
  nordic-build-arm64 \
  west build -p always \
    -d /workspace/build \
    -b "$BOARD_SPEC" \
    /workspace/src

success "編譯完成！產物位於: $BUILD_DIR/zephyr/"

# ── 燒錄 ──────────────────────────────────────────────────────────────────────
if [[ "$DO_FLASH" == "true" ]]; then
  info "偵測開發板..."

  if ! command -v nrfutil >/dev/null 2>&1; then
    error "找不到 nrfutil，請先執行 setup.sh 的第四階段"
  fi

  if nrfutil device list 2>/dev/null | grep -qi "j-link\|segger\|serial"; then
    if [[ -f "$BUILD_DIR/zephyr/merged.hex" ]]; then
      HEX="$BUILD_DIR/zephyr/merged.hex"
    elif [[ -f "$BUILD_DIR/zephyr/zephyr.hex" ]]; then
      HEX="$BUILD_DIR/zephyr/zephyr.hex"
    else
      error "找不到 .hex 燒錄檔，請確認編譯成功"
    fi

    info "燒錄 $HEX ..."
    # shellcheck disable=SC2086
    nrfutil device program --firmware "$HEX" $FLASH_ARGS
    success "燒錄完成！"
  else
    warn "未偵測到開發板，已略過燒錄。請確認 USB 連線後重新執行。"
  fi
fi
