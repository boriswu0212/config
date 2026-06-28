#!/bin/bash
set -eo pipefail

# Rotate Atuin encryption key
# 1. Logout + re-register
# 2. Update local ~/.secrets
# 3. Update Bitwarden
#
# Usage:
#   ./rotate-atuin-key.sh          # update dotfiles-secrets-home
#   ./rotate-atuin-key.sh work     # update dotfiles-secrets-work

PROFILE="${1:-home}"
ITEM_NAME="dotfiles-secrets-${PROFILE}"

echo "=== Rotate Atuin Key ($PROFILE) ==="
echo ""

echo "[1] Re-registering Atuin..."
atuin account logout 2>/dev/null || true

read -rp "Atuin username: " ATUIN_USER
read -rp "Atuin email: " ATUIN_EMAIL
atuin account register -u "$ATUIN_USER" -e "$ATUIN_EMAIL" || { echo "Error: atuin register failed."; exit 1; }

echo ""
echo "[2] Syncing..."
atuin sync

KEY_FILE=~/.local/share/atuin/key
[ -f "$KEY_FILE" ] || { echo "Error: $KEY_FILE not found after registration."; exit 1; }
NEW_KEY=$(cat "$KEY_FILE")
[ -n "$NEW_KEY" ] || { echo "Error: key file is empty."; exit 1; }

# Update ~/.secrets
echo ""
echo "[3] Updating ~/.secrets..."
if [ -f ~/.secrets ]; then
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT INT TERM
  if grep -q '^export ATUIN_KEY=' ~/.secrets; then
    grep -v '^export ATUIN_KEY=' ~/.secrets > "$tmp"
  else
    cp ~/.secrets "$tmp"
  fi
  printf "export ATUIN_KEY='%s'\n" "$NEW_KEY" >> "$tmp"
  mv "$tmp" ~/.secrets
  chmod 600 ~/.secrets
  echo "  ~/.secrets updated."
fi

# Update Bitwarden
echo ""
echo "[4] Updating Bitwarden..."
command -v bw &>/dev/null || { echo "Warning: bw not found, skip Bitwarden update."; exit 0; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/bw-auth.sh"
ITEM=$(bw get item "$ITEM_NAME")
ITEM_ID=$(echo "$ITEM" | jq -r '.id')
CURRENT=$(echo "$ITEM" | jq -r '.notes')
if echo "$CURRENT" | grep -q '^export ATUIN_KEY='; then
  NEW=$(printf '%s\n' "$CURRENT" | grep -v '^export ATUIN_KEY=')
  NEW="$NEW
export ATUIN_KEY='$NEW_KEY'"
else
  NEW="$CURRENT
export ATUIN_KEY='$NEW_KEY'"
fi
ENCODED=$(NOTES="$NEW" jq '.notes = env.NOTES' <<< "$ITEM" | bw encode)
bw edit item "$ITEM_ID" "$ENCODED" > /dev/null
unset BW_SESSION
echo "  Bitwarden updated ($ITEM_NAME)."

echo ""
echo "Done."
