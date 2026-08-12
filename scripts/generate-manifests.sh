#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Refreshing Brewfile..."
brew bundle dump --file="$DOTFILES_DIR/Brewfile" --force

if command -v code >/dev/null 2>&1; then
  echo "Refreshing VSCode extensions list..."
  code --list-extensions > "$DOTFILES_DIR/modules/vscode/extensions.txt"
fi

if command -v npm >/dev/null 2>&1; then
  echo "Refreshing npm global packages list..."
  npm list -g --depth=0 --json > "$DOTFILES_DIR/modules/npm/global-packages.json"
fi

echo "Manifests refreshed. Review with 'git -C $DOTFILES_DIR status' and commit when ready."
