#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

mkdir -p "$HOME/.claude/plugins"
backup_and_link "$DIR/settings.json" "$HOME/.claude/settings.json"
backup_and_link "$DIR/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
backup_and_link "$DIR/plugins/installed_plugins.json" "$HOME/.claude/plugins/installed_plugins.json"
backup_and_link "$DIR/plugins/known_marketplaces.json" "$HOME/.claude/plugins/known_marketplaces.json"
