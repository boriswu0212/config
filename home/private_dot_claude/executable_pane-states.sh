#!/usr/bin/env bash
# Collect agent states from all panes in a given window, output colored dots.
# Usage: pane-states.sh <window_id>

WINDOW_ID="${1:-}"
[ -z "$WINDOW_ID" ] && exit 0

DOTS=""
while IFS= read -r line; do
    state="${line}"
    case "$state" in
        running)      DOTS="${DOTS}#[fg=#{@thm_blue}]●" ;;
        needs-input)  DOTS="${DOTS}#[fg=#{@thm_yellow}]●" ;;
        done)         DOTS="${DOTS}#[fg=#{@thm_green}]●" ;;
    esac
done < <(tmux list-panes -t "$WINDOW_ID" -F '#{@pane_agent_state}' 2>/dev/null)

printf '%s' "$DOTS"
