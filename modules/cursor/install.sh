#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
backup_and_link "$DIR/settings.json" "$CURSOR_USER_DIR/settings.json"
backup_and_link "$DIR/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"

[ -f "$DIR/mcp.json" ] && backup_and_link "$DIR/mcp.json" "$CURSOR_USER_DIR/mcp.json"
[ -f "$DIR/hooks.json" ] && backup_and_link "$DIR/hooks.json" "$CURSOR_USER_DIR/hooks.json"
