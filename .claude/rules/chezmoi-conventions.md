在這個 repo 新增或修改檔案時：

- 所有 managed config 放在 `home/` 下，用 chezmoi 命名（`dot_`, `private_`, `.tmpl`）
- 不要直接建 `~/.xxx` 路徑的檔案
- 需要 template 變數時加 `.tmpl` 後綴，用 `{{ }}` 語法
- Profile 差異用 `.chezmoiignore` 或 template `{{ if eq .profile "home" }}` / `{{ if eq .profile "work" }}`
- Template 中取 secrets 用 `(bitwarden "item" "name")` function，不寫明文
