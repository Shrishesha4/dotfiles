#!/usr/bin/env bash
set -euo pipefail
ICLOUD_SSH="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Github SSH Keys"

if [ ! -d "$ICLOUD_SSH" ]; then
  echo "iCloud SSH folder not found: $ICLOUD_SSH"
  echo "Make sure iCloud Drive has finished syncing (folder must not show a cloud placeholder icon in Finder)."
  exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

for f in "$ICLOUD_SSH"/*; do
  [ -e "$f" ] || continue
  cp -n "$f" "$HOME/.ssh/$(basename "$f")"
done

chmod 600 "$HOME"/.ssh/id_ed25519 "$HOME"/.ssh/*.pem "$HOME/.ssh/config" 2>/dev/null || true
chmod 644 "$HOME"/.ssh/*.pub 2>/dev/null || true

echo "SSH material synced from iCloud; permissions fixed."
