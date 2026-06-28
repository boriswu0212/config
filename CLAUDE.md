# chezmoi dotfiles repo

macOS 開發環境設定檔，由 chezmoi 管理。

## 結構

- `.chezmoiroot` 指向 `home/`，所有 chezmoi managed 檔案在 `home/` 下
- `scripts/` — 自動化腳本（bw-auth.sh, bw-secrets.sh）
- `Brewfile` — Homebrew 套件清單
- `setup.sh` — Stage 1 bootstrap（裝 Homebrew + chezmoi init）
- `home/run_once_before_01-setup.sh.tmpl` — chezmoi 首次 apply 時執行（brew bundle、mise、verify）
- `test/` — E2E 測試（Tart VM）

## chezmoi 命名慣例

| 前綴/後綴 | 意義 |
|-----------|------|
| `dot_` | 部署時變成 `.`（dot_zshrc → ~/.zshrc） |
| `private_` | 權限 0700/0600 |
| `.tmpl` | chezmoi template，用 `{{ }}` 語法 |
| `run_once_before_` | 首次 apply 時執行的腳本 |

## Profile 系統

`chezmoi init` 時選 `home` 或 `work`，存在 `~/.config/chezmoi/chezmoi.toml` 的 `.profile`。
Template 用 `{{ if eq .profile "home" }}`，ignore 用 `.chezmoiignore`。

## Secrets

- 不 commit secrets 明文，template 用 `(bitwarden "item" "name")` 取值
- Bitwarden notes：`dotfiles-secrets-{home,work}`（環境變數）、`git-identity`（git user info）
