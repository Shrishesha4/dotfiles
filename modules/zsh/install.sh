#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

backup_and_link "$DIR/zshrc" "$HOME/.zshrc"
backup_and_link "$DIR/zprofile" "$HOME/.zprofile"

touch -a "$HOME/.zshrc.local"
chmod 600 "$HOME/.zshrc.local"
