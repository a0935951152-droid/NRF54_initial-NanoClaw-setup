# NanoClaw 兵工廠

> Raspberry Pi 5 (ARM64) × nRF54L15 × Zephyr RTOS × Claude Code  
> 一鍵建置的嵌入式 AI 開發環境

---

## ✨ 核心

* **AI 原生架構**：內建 `CLAUDE.md` 防呆大腦秘笈，規範 AI 代理行為，避免亂改底層架構。
* **隨處部署 (Location Agnostic)**：全動態路徑解析，專案 Clone 到任何目錄皆可無縫運作。
* **無塵編譯室**：透過 Docker 封裝 Ubuntu 24.04 與 Zephyr SDK 1.0.0，杜絕 Host 端版本衝突。
* **網路斷線免疫**：專為單板電腦設計的 ZIP 暴力下載 + 空提交 (Empty Commit) 偽裝術，徹底繞過 Git HTTP/2 斷線地雷。
* **智慧指令集**：一鍵編譯、自動偵測開發板與燒錄，指令極度簡化。

---

## 硬體需求

| 項目 | 規格要求 |
|------|------|
| 主機 | Raspberry Pi 5（ARM64，建議 4GB+ RAM） |
| 作業系統 | Ubuntu 24.04 / Debian 12 (aarch64) |
| 目標開發板 | nRF54L15-DK、nRF52840-DK、nRF52833-DK、nRF52-DK等更多 |
| 燒錄介面 | 板載 SEGGER J-Link (透過 Type-C 連接) |

---

## 快速開始

### 1. 取得專案

```bash
git clone https://github.com/a0935951152-droid/NRF54_initial-NanoClaw-setup
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
bash setup.sh --git           # Zephyr 改用 git clone（預設為 ZIP 防斷線模式）
```

> **預設行為：** Zephyr 核心使用 ZIP 下載 + `west init -l` 本地認領，避免 Pi 的網路環境在 git clone 時斷線。

### 3. 啟動 AI 開發代理

```bash
cd ~/nanoclaw
source ~/.bashrc
claude login   # 首次需要
claude
```

然後直接用中文下指令：

```
請幫我在 src/ 建立一個 nRF54L15 的 0-2-3-1 流水燈專案，寫完後呼叫編譯腳本直接編譯並燒錄！
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

## 🔧 Zephyr 下載斷線救援

遇到以下錯誤時：

```
error: RPC failed; curl 92 HTTP/2 stream was not closed cleanly
error: RPC failed; curl 56 Recv failure: Connection timed out
fatal: early EOF
```

執行一鍵救援腳本：

```bash
bash scripts/fix-zephyr.sh
```

已下載到一半的 ZIP 可用 `--resume` 跳過重新下載：

```bash
bash scripts/fix-zephyr.sh --resume
```

**原理：** 完全放棄 `git clone`，改用 `wget` 下載整包 ZIP，解壓後透過 `west init -l`（本地認領）讓 west 接管，再用 `--depth=1` 淺層更新附屬套件，大幅降低網路要求。

---

## 專案結構

```
nanoclaw/
├── setup.sh                 # 主建置腳本
├── Dockerfile.nordic        # ARM64 隔離編譯容器藍圖
├── CLAUDE.md                # AI 代理防呆規範與技能庫
├── scripts/
│   ├── build.sh             # 一鍵編譯與燒錄腳本 (AI 與人類通用)
│   ├── fix-zephyr.sh        # 網路斷線救援腳本
│   └── setup-autoactivate.sh# Bashrc 虛擬環境自動掛載工具
├── src/                     # 你的應用程式原始碼 (AI 工作區)
│   ├── CMakeLists.txt
│   ├── prj.conf
│   └── main.c
├── build/                   # Docker 編譯產物輸出區 (自動產生)
└── zephyrproject/           # Zephyr RTOS 底層核心 (自動產生)
```
> Host (src/) ➡️ 掛載至 Docker (nordic-build-arm64) ➡️ 執行 west build ➡️ 輸出至 Host (build/) ➡️ nrfutil 燒錄至實體開發板。
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
