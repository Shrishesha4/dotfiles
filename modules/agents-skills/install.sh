#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/lib/link.sh"

mkdir -p "$HOME/.agents"
backup_and_link "$DIR/skills" "$HOME/.agents/skills"
