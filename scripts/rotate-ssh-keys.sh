#!/bin/bash
set -eo pipefail

# Rotate SSH keys for this machine
# 1. Generate new key pairs (temp dir, then move)
# 2. Add to Keychain
# 3. Update per-host Bitwarden backup
# 4. Upload personal key to GitHub

HOSTNAME=$(scutil --get LocalHostName 2>/dev/null || hostname -s)
HOSTNAME=$(echo "$HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | sed 's/--*/-/g; s/^-//; s/-$//')
HOSTNAME=${HOSTNAME:-mac-$(date +%s | tail -c 7)}

SSH_KEYS=(
  "personal_ed25519:${HOSTNAME}-personal"
  "work_ed25519:${HOSTNAME}-work"
)

echo "=== Rotate SSH Keys ($HOSTNAME) ==="
echo ""

# Generate new keys (to temp first, then move — avoids losing keys if keygen fails)
echo "[1] Generating new keys..."
tmp_dir=$(mktemp -d)
passfile=$(mktemp)
askpass=$(mktemp)
trap 'rm -rf "$tmp_dir" "$passfile" "$askpass"' EXIT

while true; do
  read -rsp "  Enter passphrase for SSH keys: " SSH_PASSPHRASE; echo
  read -rsp "  Confirm passphrase: " SSH_PASSPHRASE_CONFIRM; echo
  if [ "$SSH_PASSPHRASE" = "$SSH_PASSPHRASE_CONFIRM" ]; then
    if [ -z "$SSH_PASSPHRASE" ]; then
      echo "  Error: passphrase cannot be empty."
    else
      break
    fi
  else
    echo "  Error: passphrases do not match."
  fi
done

chmod 600 "$passfile"
printf '%s' "$SSH_PASSPHRASE" > "$passfile"
chmod 700 "$askpass"
printf '#!/bin/sh\ncat "%s"\n' "$passfile" > "$askpass"
unset SSH_PASSPHRASE SSH_PASSPHRASE_CONFIRM

for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  KEY_COMMENT="${entry##*:}"
  SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$tmp_dir/$KEY_FILE"
done

for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  mv "$tmp_dir/$KEY_FILE" "$HOME/.ssh/$KEY_FILE"
  mv "$tmp_dir/$KEY_FILE.pub" "$HOME/.ssh/$KEY_FILE.pub"
done

# Add to Keychain
echo ""
echo "[2] Adding to Keychain..."
for entry in "${SSH_KEYS[@]}"; do
  ssh-add --apple-use-keychain "$HOME/.ssh/${entry%%:*}"
done

# Upload to GitHub
echo ""
echo "[3] Re-upload SSH keys to GitHub hosts."
echo "  Rotated keys:"
for entry in "${SSH_KEYS[@]}"; do
  KEY_FILE="${entry%%:*}"
  echo "    ~/.ssh/$KEY_FILE.pub"
done
echo ""
echo "  Remove old keys and re-upload:"
echo "    gh ssh-key add ~/.ssh/<key>.pub --title \"${HOSTNAME}-<purpose>\""
echo "  For GHES/EMU:"
echo "    GH_HOST=github.example.com gh ssh-key add ~/.ssh/work_ed25519.pub --title \"${HOSTNAME}-work\""

# Verify
echo ""
echo "[4] Verifying..."
ssh -T git@github.com 2>&1 | grep -q "successfully" && echo "  GitHub SSH: OK" || echo "  GitHub SSH: FAIL"

echo ""
echo "Done. Remember to:"
echo "  - Deploy personal key to homelab: ssh-copy-id -i ~/.ssh/personal_ed25519.pub root@<server-ip>"
echo "  - Upload work key to work GitHub org (if applicable)"
