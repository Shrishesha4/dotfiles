#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/link.sh"

command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Run scripts/bootstrap.sh first."; exit 1; }
command -v gum >/dev/null 2>&1 || brew install gum

MODULES=(zsh git ghostty starship claude-code agents-skills vscode cursor brew npm macos)

SELECTED=$(printf '%s\n' "${MODULES[@]}" | gum choose --no-limit \
  --header "Select modules to install (space=toggle, enter=confirm)")

if [ -z "$SELECTED" ]; then
  echo "Nothing selected, exiting."
  exit 0
fi

while IFS= read -r m; do
  echo "==> Installing module: $m"
  bash "$DOTFILES_DIR/modules/$m/install.sh"
done <<< "$SELECTED"

echo "Done. Run: source ~/.zshrc"
echo "Note: SSH keys are handled separately — run scripts/sync-ssh-keys.sh once iCloud has synced."
