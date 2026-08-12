#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

PLIST_LABEL="com.dotfiles.gui"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents"
render_template "$DOTFILES_DIR/gui/$PLIST_LABEL.plist.tmpl" "$PLIST_DEST"

launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Dotfiles GUI installed as a login item, running at http://127.0.0.1:4444"
echo "Auth token: $HOME/.dotfiles-gui-token (page needs it, curl the file if scripting)"
echo "Logs: $HOME/.dotfiles-gui.log / $HOME/.dotfiles-gui.err.log"
