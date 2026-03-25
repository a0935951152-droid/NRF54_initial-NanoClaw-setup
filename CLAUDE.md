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

| Profile | 開發板 | 編譯參數 `<BOARD>` | 燒錄參數 |
|---------|--------|-------------------|---------|
| **A（預設）** | nRF54L15 | `nrf54l15dk/nrf54l15/cpuapp` | `--core Application` |
| **B** | nRF52840 | `nrf52840dk/nrf52840` | 無需額外參數 |
| **B** | nRF52833 | `nrf52833dk/nrf52833` | 無需額外參數 |

---

## 🛠️ 第三天條：模組化編譯指令 (West Build)

只能呼叫外部 Docker 容器代勞。請使用以下相對路徑指令（`<BOARD>` 替換為上方 Profile 中的參數）：

```bash
docker run --rm \
  -v $PWD:/workspace \
  -w /workspace/zephyrproject \
  nordic-build-arm64 \
  west build -p always \
    -d /workspace/build \
    -b <BOARD> \
    /workspace/src
```

---

## 🧱 第四天條：Zephyr 語法防呆

| 規則 | 正確 | 錯誤 |
|------|------|------|
| 布林值 | `CONFIG_FOO=y` / `CONFIG_FOO=n` | `CONFIG_FOO=true` |
| 字串 | `CONFIG_BT_DEVICE_NAME="MyDevice"` | `CONFIG_BT_DEVICE_NAME=MyDevice` |
| 數字 | `CONFIG_BT_MAX_CONN=4` | `CONFIG_BT_MAX_CONN="4"` |
| GPIO 節點 | `DT_ALIAS(led0)` | 自行猜測 node path |

---

## ⚡ 第五天條：自動化燒錄腳本 (Auto-Flash)

當人類要求「編譯並燒錄」或「測試」時，在 Docker 編譯成功後，於**本機端**執行以下腳本：

```bash
if nrfutil device list | grep -qi "j-link\|segger\|serial"; then
    echo "[Auto-Flash] 偵測到開發板，開始燒錄..."
    if [ -f "$PWD/build/zephyr/merged.hex" ]; then
        nrfutil device program \
          --firmware "$PWD/build/zephyr/merged.hex" \
          --core Application
    else
        nrfutil device program \
          --firmware "$PWD/build/zephyr/zephyr.hex" \
          --core Application
    fi
else
    echo "[Auto-Flash] ⚠️ 未偵測到開發板，已取消燒錄。"
fi
```

---

## 📁 工作區結構

```
~/nanoclaw/
├── src/            ← 你的應用程式源碼（AI 可修改）
├── build/          ← 編譯產物（自動生成，勿手動修改）
├── zephyrproject/  ← Zephyr 源碼（禁止修改）
├── .venv/          ← Python 虛擬環境
├── Dockerfile.nordic  ← 編譯容器定義（禁止修改）
└── CLAUDE.md       ← 本文件（AI 規範）
```
