# Claude Code 設定筆記

## 認證方式

目前使用 Claude Max 訂閱的 OAuth 登入（`claude login`），不需要設定任何 token 環境變數。

Claude Code 也支援其他認證方式：

| 認證方式 | Header | 設定方式 | 適用場景 |
|----------|--------|----------|----------|
| OAuth 登入 | 自動處理 | `claude login` | Claude Max / Team / Enterprise |
| `ANTHROPIC_API_KEY` | `X-Api-Key: sk-...` | env 或 `apiKeyHelper` | 直接用 Anthropic API |
| `ANTHROPIC_AUTH_TOKEN` | `Authorization: Bearer eyJ...` | **只能用 env** | 公司 API proxy / OAuth |

## settings.json 結構

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": { ... },
  "hooks": { ... },
  "permissions": { ... },
  "enabledPlugins": { ... },
  "statusLine": { ... }
}
```

### `$schema`

加上後 VS Code / Cursor 編輯 settings.json 時會有 key 自動補全和驗證。

### env 常用變數

| 變數 | 說明 |
|------|------|
| `ANTHROPIC_BASE_URL` | API endpoint（搭配 API key 或第三方 proxy 時使用） |
| `ANTHROPIC_MODEL` | 主模型 |
| `ANTHROPIC_SMALL_FAST_MODEL` | 輕量模型（subagent 用） |
| `CLAUDE_CODE_EFFORT_LEVEL` | `low` / `medium` / `max` |
| `CLAUDE_CODE_SUBAGENT_MODEL` | subagent 模型 |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | 啟用 agent teams |

`DISABLE_NON_ESSENTIAL_MODEL_CALLS` 已移除 — 開啟後會自動生成對話標題，方便搜尋歷史對話。

### permissions

deny 優先於 allow。`Bash(ls *)` 的空格是 word boundary，不會 match `lsof`。

注意：`Read`/`Edit` deny rules 只擋 Claude 內建工具，**不擋 `Bash(cat .env)`** — 需要 sandbox 才能做到 OS 層級阻擋。

### hooks

可用的 hook 事件：

| 事件 | 觸發時機 | 用法 |
|------|----------|------|
| `PreToolUse` | 執行工具前 | 攔截危險操作（exit 2 = 阻擋） |
| `PostToolUse` | 執行工具後 | 自動 lint/format |
| `Notification` | 需要使用者注意時 | macOS 通知 |
| `Stop` | agent 停止時 | 跑測試確認沒壞 |
| `SessionStart` | session 開始 | 初始化環境 |
| `UserPromptSubmit` | 使用者送出 prompt 時 | 注入額外 context |

目前啟用的 hooks：
- **Notification** — macOS 桌面通知
- **PostToolUse** — JS/TS 檔案編輯後自動 `eslint --fix`
- **PreToolUse: main-branch guard** — 擋住在 main/master 上寫檔與 `git commit`（見下）

#### main-branch guard

腳本：`home/private_dot_claude/hooks/executable_block-main-writes.sh`（chezmoi 管理，apply 後為 `~/.claude/hooks/block-main-writes.sh`）。

行為：repo 在 `main`/`master` 時，擋 Edit/Write/NotebookEdit 與 `git commit`（含 `-C <dir>` 形式）。豁免：gitignored 路徑、`~/.claude/`、非 repo 目錄、detached HEAD。逃生口：命令內 `ALLOW_MAIN=1`，或環境變數 `CLAUDE_ALLOW_MAIN=1`。

**佈線（settings.json 由 Bitwarden 供應，需手動更新兩個 note：`claude-settings-work` 與 `claude-settings-home`）**——在 `hooks.PreToolUse` 陣列加入：

```json
{
  "matcher": "Edit|Write|NotebookEdit",
  "hooks": [
    { "type": "command", "command": "bash ~/.claude/hooks/block-main-writes.sh", "timeout": 10, "statusMessage": "main-branch guard" }
  ]
},
{
  "matcher": "Bash",
  "hooks": [
    { "type": "command", "command": "bash ~/.claude/hooks/block-main-writes.sh", "timeout": 10, "statusMessage": "main-branch guard" }
  ]
}
```

⚠️ 2026-07-21：work host 的 live `~/.claude/settings.json` 已直接加上此佈線，但 Bitwarden note 尚未更新——在更新 `claude-settings-work` 之前執行 `chezmoi apply` 會把佈線洗掉。

### statusLine

自訂底部狀態列，執行 shell 腳本輸出文字：

```json
"statusLine": {
  "type": "command",
  "command": "bash ~/.claude/statusline-command.sh"
}
```

## 踩坑記錄

### 1. settings.json 用 cp 不用 symlink

`settings.json` 包含實際 token 值（由 chezmoi template 展開），
所以用 `cp` 而不是 `ln -sf`，避免 token 寫回 repo。

### 2. statusLine ANSI 色碼

status line 腳本用 `echo -e` 輸出 ANSI 色碼。`printf` 會把 `%` 當格式符導致錯誤。
256-color ANSI（`\033[38;5;NNm`）在 Claude Code 中可能不渲染。

### 3. settings.json 分層

Claude Code 的 settings 有三層，由上到下合併：

| 層級 | 位置 | 用途 |
|------|------|------|
| Enterprise | MDM 或管理平台 | 公司級強制策略 |
| User | `~/.claude/settings.json` | 個人全域設定 |
| Project | `.claude/settings.json`（repo 內） | 專案級設定 |
