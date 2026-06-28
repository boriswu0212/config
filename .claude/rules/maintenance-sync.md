修改這個 repo 時，確保以下同步：

- 新增/刪除 chezmoi managed 檔案 → 更新 README.md 結構表
- 新增 brew 工具 → 同步 Brewfile 和 run_once_before_01-setup.sh.tmpl 的 verify 區塊
- 刪除 brew 工具 → 同步移除 Brewfile、verify、以及 dot_zshrc 中的相關 source/alias
- 新增/修改 Bitwarden note → 更新 README.md 的 Bitwarden Secure Notes 表
- 修改 scripts/ 下的腳本名稱 → 搜尋所有引用處（README、zshrc alias、其他腳本）同步更新
