#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found — install it first (scripts/bootstrap.sh does this on a fresh machine)."
  exit 1
fi

echo "Installing packages from $DOTFILES_DIR/Brewfile..."
brew bundle install --file="$DOTFILES_DIR/Brewfile"
