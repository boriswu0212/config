#!/bin/bash
# Guardrail: block writing files / git commit while on main|master.
# Enforces the global rule "Always create a worktree before writing code."
# Escape hatches:
#   - inline:  include ALLOW_MAIN=1 in the bash command (explicit user intent)
#   - session: export CLAUDE_ALLOW_MAIN=1 before launching claude
# Exemptions: paths under ~/.claude (agent memory/settings), gitignored paths.
set -u
input=$(cat)

[ "${CLAUDE_ALLOW_MAIN:-0}" = "1" ] && exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' \
    "$(printf '%s' "$1" | jq -Rs .)"
  exit 0
}

branch_of() { # $1 = dir; prints branch, rc=1 if not a repo
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  git -C "$1" branch --show-current 2>/dev/null
}

case "$tool" in
  Edit|Write|NotebookEdit)
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -n "$fp" ] || exit 0
    case "$fp" in "$HOME/.claude/"*) exit 0 ;; esac
    dir=$(dirname "$fp")
    while [ ! -d "$dir" ] && [ "$dir" != "/" ]; do dir=$(dirname "$dir"); done
    [ -d "$dir" ] || exit 0
    br=$(branch_of "$dir") || exit 0
    case "$br" in
      main|master)
        git -C "$dir" check-ignore -q "$fp" 2>/dev/null && exit 0
        deny "Blocked by main-branch guard: $fp is in a git repo on '$br'. Global rule: create a worktree/branch before writing (EnterWorktree or git checkout -b). Gitignored paths are exempt. If editing on $br is truly intended, the user can run with CLAUDE_ALLOW_MAIN=1 or disable this hook via /hooks."
        ;;
    esac
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
    [ -n "$cmd" ] || exit 0
    case "$cmd" in *ALLOW_MAIN=1*) exit 0 ;; esac
    printf '%s' "$cmd" | grep -qE '\bgit(\s+-[A-Za-z-]+(\s+\S+)?)*\s+commit\b' || exit 0
    # repo dir: explicit -C wins (unquoted paths), else the session cwd from hook input
    dir=$(printf '%s' "$cmd" | grep -oE 'git[[:space:]]+-C[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $3}' | tr -d '"'"'")
    [ -n "$dir" ] || dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
    [ -n "$dir" ] || dir=$PWD
    br=$(branch_of "$dir") || exit 0
    case "$br" in
      main|master)
        deny "Blocked by main-branch guard: git commit while '$dir' is on '$br'. Create a worktree/branch first (EnterWorktree or git checkout -b). If committing on $br is truly intended, re-run prefixed with ALLOW_MAIN=1 (asks the user's explicit intent)."
        ;;
    esac
    ;;
esac
exit 0
