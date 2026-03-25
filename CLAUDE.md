# 🤖 NanoClaw Agent — 多目標 Zephyr 開發最高指導原則

你是這個工作區的 AI 嵌入式開發助理。請絕對遵守以下規範，不可有任何例外。

---

## 🛡️ 第一天條：防覆寫與環境禁區

1. **修改前必檢查：** 在生成或修改 `src/` 之前，必須先讀取目錄內容。
   若有舊程式碼，必須提問：「已有專案檔案，需備份還是直接覆蓋？」取得授權後才能動作。
2. **禁止動系統架構：** 絕對禁止修改或建立任何 `Dockerfile`，也絕對禁止執行 `docker build`。
3. **禁止動底層源碼：** Zephyr 核心已就緒，不要修改官方 code。

---

## 🎯 第二天條：開發板定義檔 (Board Profiles)

請先確認人類指定的目標開發板。若未特別指定，**預設為 nRF54L15**。

| 短名 | 開發板 | 完整 Board String |
|------|--------|-------------------|
| `nrf54l15`（預設） | nRF54L15-DK | `nrf54l15dk/nrf54l15/cpuapp` |
| `nrf52840` | nRF52840-DK | `nrf52840dk/nrf52840` |
| `nrf52833` | nRF52833-DK | `nrf52833dk/nrf52833` |
| `nrf52832` | nRF52-DK | `nrf52dk/nrf52832` |

---

## 🛠️ 第三天條：編譯與自動化燒錄 (Build & Flash)

**禁止直接呼叫 `docker` 或 `nrfutil` 指令！** 本專案已封裝專屬編譯腳本。
當人類要求「編譯」或「燒錄」時，請一律呼叫 `scripts/build.sh`。

| 情境 | 指令 |
|------|------|
| 只編譯（預設 nRF54L15） | `bash scripts/build.sh nrf54l15` |
| 編譯 + 燒錄 | `bash scripts/build.sh nrf54l15 --flash` |
| 清除後重新編譯 + 燒錄 | `bash scripts/build.sh nrf54l15 --clean --flash` |
| 其他板子 | `bash scripts/build.sh nrf52840 --flash` |

> 腳本會自動掛載 Docker 執行 `west build`，`--flash` 時自動偵測開發板並燒錄，無需手動操作。

---

## 🧱 第四天條：Zephyr 語法防呆

| 規則 | 正確 | 錯誤 |
|------|------|------|
| 布林值 | `CONFIG_FOO=y` / `CONFIG_FOO=n` | `CONFIG_FOO=true` |
| 字串 | `CONFIG_BT_DEVICE_NAME="MyDevice"` | `CONFIG_BT_DEVICE_NAME=MyDevice` |
| 數字 | `CONFIG_BT_MAX_CONN=4` | `CONFIG_BT_MAX_CONN="4"` |
| GPIO 節點 | `DT_ALIAS(led0)` | 自行猜測 node path |

---

## 📁 工作區結構

```
~/nanoclaw/
├── src/               ← 你的應用程式源碼（AI 可修改）
├── build/             ← 編譯產物（自動生成，勿手動修改）
├── zephyrproject/     ← Zephyr 源碼（禁止修改）
├── .venv/             ← Python 虛擬環境
├── scripts/
│   ├── build.sh       ← 編譯 & 燒錄（唯一入口）
│   ├── fix-zephyr.sh  ← 下載失敗救援
│   └── setup-autoactivate.sh
├── Dockerfile.nordic  ← 編譯容器定義（禁止修改）
└── CLAUDE.md          ← 本文件（AI 規範）
```
