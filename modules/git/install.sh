#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

backup_and_link "$DIR/gitconfig" "$HOME/.gitconfig"
backup_and_link "$DIR/gitignore_global" "$HOME/.config/git/ignore"
