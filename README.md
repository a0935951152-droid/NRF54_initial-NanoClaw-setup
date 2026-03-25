# NanoClaw 兵工廠

> Raspberry Pi 5 (ARM64) × nRF54L15 × Zephyr RTOS × Claude Code  
> 一鍵建置的嵌入式 AI 開發環境

---

## 硬體需求

| 元件 | 規格 |
|------|------|
| 主機 | Raspberry Pi 5（ARM64，建議 4GB+） |
| 作業系統 | Ubuntu 24.04 / Debian 12 ARM64 |
| 開發板 | nRF54L15-DK（或 nRF52840-DK） |
| 燒錄介面 | SEGGER J-Link（板載） |

---

## 快速開始

### 1. 取得專案

```bash
git clone https://github.com/YOUR_USERNAME/nanoclaw.git
cd nanoclaw
```

### 2. 一鍵建置

```bash
bash setup.sh
```

腳本會自動完成：
- 安裝系統依賴（docker、nodejs、python3-venv 等）
- 下載 Zephyr 源碼（淺層複製，省時省空間）
- 建置 ARM64 專用 Docker 編譯映像檔（`nordic-build-arm64`）
- 安裝 nrfutil 燒錄工具與 udev 規則

可用旗標：

```bash
bash setup.sh --skip-zephyr   # 跳過 Zephyr 下載（已有時使用）
bash setup.sh --skip-docker   # 跳過 Docker 建置
bash setup.sh --skip-flash    # 跳過 nrfutil 安裝
```

### 3. 啟動 AI 開發代理

```bash
cd ~/nanoclaw
source .venv/bin/activate
claude login   # 首次需要
claude
```

然後直接用中文下指令：

```
請幫我在 src/ 建立一個 0-2-3-1 流水燈專案，寫完後直接編譯並燒錄！
```

---

## 手動編譯 / 燒錄

```bash
# 只編譯（預設 nRF54L15）
bash scripts/build.sh

# 編譯 + 燒錄
bash scripts/build.sh nrf54l15 --flash

# 編譯 nRF52840 + 燒錄
bash scripts/build.sh nrf52840 --flash

# 清除後重新編譯 + 燒錄
bash scripts/build.sh nrf54l15 --clean --flash
```

支援的目標板：

| 短名 | 完整 Board String |
|------|-------------------|
| `nrf54l15`（預設） | `nrf54l15dk/nrf54l15/cpuapp` |
| `nrf52840` | `nrf52840dk/nrf52840` |
| `nrf52833` | `nrf52833dk/nrf52833` |

---

## 專案結構

```
nanoclaw/
├── setup.sh             ← 一鍵建置腳本
├── Dockerfile.nordic    ← ARM64 編譯容器（請勿手動修改）
├── CLAUDE.md            ← AI 代理指導原則
├── scripts/
│   └── build.sh         ← 編譯 & 燒錄輔助腳本
├── src/                 ← 你的應用程式（範例：流水燈）
│   ├── CMakeLists.txt
│   ├── prj.conf
│   └── src/
│       └── main.c
└── .gitignore
```

> `zephyrproject/` 與 `build/` 由工具自動產生，不納入版控。

---

## 架構說明

```
Raspberry Pi 5 (Host)
├── .venv/          Python 虛擬環境，管理 west
├── zephyrproject/  Zephyr 源碼（west 管理）
└── Docker Container (nordic-build-arm64)
    ├── Ubuntu 24.04 + CMake + Ninja
    ├── Zephyr SDK 1.0.0 (arm-zephyr-eabi)
    └── west build → build/zephyr/zephyr.hex
         ↓
    nrfutil device program → nRF54L15-DK (USB/J-Link)
```

---

## AI 代理規則摘要（CLAUDE.md）

Claude Code 在此工作區遵守以下硬性規則：

- 修改 `src/` 前必須確認備份
- 禁止修改 `Dockerfile.nordic` 或執行 `docker build`
- 禁止修改 Zephyr 官方源碼
- `prj.conf` 布林值只能用 `=y` / `=n`
- 偵測到開發板時自動燒錄

詳細規則見 [CLAUDE.md](./CLAUDE.md)。

---

## 授權

MIT License — 詳見 [LICENSE](./LICENSE)
