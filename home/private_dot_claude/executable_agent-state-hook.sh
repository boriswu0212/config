#!/usr/bin/env bash
# Wrapper: calls tmux-agent-indicator's hook, then stamps @agent_state on the window
# so window-status-format can read it for color switching.

set -euo pipefail

EVENT="${1:-}"
INDICATOR_DIR="${TMUX_AGENT_INDICATOR_DIR:-$HOME/.tmux/plugins/tmux-agent-indicator}"

# Forward to original hook
"$INDICATOR_DIR/scripts/agent-state.sh" --agent claude --state "$EVENT" 2>/dev/null || true

# Map hook event to agent state
case "$EVENT" in
    running)      STATE="running" ;;
    needs-input)  STATE="needs-input" ;;
    done)         STATE="done" ;;
    off)          STATE="" ;;
    *)            STATE="" ;;
esac

# Stamp @agent_state on the current window and @pane_agent_state on the current pane
if command -v tmux >/dev/null 2>&1 && [ -n "${TMUX:-}" ]; then
    if [ -n "$STATE" ]; then
        tmux set-option -w @agent_state "$STATE"
        tmux set-option -p @pane_agent_state "$STATE"
    else
        tmux set-option -wu @agent_state
        tmux set-option -pu @pane_agent_state
    fi
fi
