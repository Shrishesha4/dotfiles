#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/link.sh"

# Ensure Homebrew on PATH for child module scripts. install.sh may run in a
# non-interactive shell that skips zprofile, so brew/npm/node may be missing
# even when the user's interactive shell has them.
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Homebrew not found. Run scripts/bootstrap.sh first."; exit 1
  fi
fi
command -v gum >/dev/null 2>&1 || brew install gum

MODULES=(zsh git ghostty starship claude-code agents-skills vscode cursor brew npm macos gui)

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
