#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
backup_and_link "$DIR/settings.json" "$VSCODE_USER_DIR/settings.json"

if command -v code >/dev/null 2>&1; then
  echo "Installing VSCode extensions from $DIR/extensions.txt..."
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    code --install-extension "$ext" || true
  done < "$DIR/extensions.txt"
else
  echo "code CLI not found on PATH — skipping extension install. Run manually later: cat $DIR/extensions.txt | xargs -L1 code --install-extension"
fi
