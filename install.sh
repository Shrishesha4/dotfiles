#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR
source "$DOTFILES_DIR/lib/link.sh"

command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Run scripts/bootstrap.sh first."; exit 1; }
command -v gum >/dev/null 2>&1 || brew install gum >/dev/null

MODULES=(zsh git ghostty starship claude-code agents-skills vscode cursor brew npm macos gui)

# Pick modules:
#   DOTFILES_MODULES="zsh brew"     -> install only these (space-separated)
#   DOTFILES_PICK=1 ./install.sh    -> use gum picker (interactive)
#   (default)                        -> install ALL modules, no prompt
if [ -n "${DOTFILES_MODULES:-}" ]; then
  SELECTED=$DOTFILES_MODULES
elif [ "${DOTFILES_PICK:-0}" = "1" ] && command -v gum >/dev/null; then
  SELECTED=$(printf '%s\n' "${MODULES[@]}" | gum choose --no-limit)
else
  SELECTED="${MODULES[*]}"
fi

if [ -z "$SELECTED" ]; then
  echo "Nothing selected, exiting."
  exit 0
fi

for m in $SELECTED; do
  if [ ! -f "$DOTFILES_DIR/modules/$m/install.sh" ]; then
    echo "SKIP (no install.sh): $m"
    continue
  fi
  echo "==> Installing module: $m"
  bash "$DOTFILES_DIR/modules/$m/install.sh"
done

echo "Done. Run: source ~/.zshrc"
echo "Note: SSH keys are handled separately — run scripts/sync-ssh-keys.sh once iCloud has synced."
