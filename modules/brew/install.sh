#!/usr/bin/env bash
set -euo pipefail

command -v brew >/dev/null 2>&1 || { echo "Homebrew not found — install it first (scripts/bootstrap.sh does this on a fresh machine)."; exit 1; }
command -v gum >/dev/null 2>&1 || brew install gum

BREWFILE="$DOTFILES_DIR/Brewfile"
N_FORMULAE=$(grep -c '^brew ' "$BREWFILE" || true)
N_CASKS=$(grep -c '^cask ' "$BREWFILE" || true)

if gum confirm "Install everything from Brewfile ($N_FORMULAE formulae, $N_CASKS casks)?"; then
  brew bundle install --file="$BREWFILE"
  exit 0
fi

echo "Picking packages individually (space=toggle, enter=confirm, empty=skip that group)..."

TAPS=$(grep '^tap ' "$BREWFILE" || true)
FORMULAE=$(grep '^brew ' "$BREWFILE" | sed -E 's/^brew "([^"]+)".*/\1/')
CASKS=$(grep '^cask ' "$BREWFILE" | sed -E 's/^cask "([^"]+)".*/\1/')

SELECTED_FORMULAE=$(printf '%s\n' "$FORMULAE" | gum choose --no-limit --height 20 --header "Select formulae to install")
SELECTED_CASKS=$(printf '%s\n' "$CASKS" | gum choose --no-limit --height 20 --header "Select casks to install")

if [ -z "$SELECTED_FORMULAE" ] && [ -z "$SELECTED_CASKS" ]; then
  echo "Nothing selected, skipping brew install."
  exit 0
fi

TMP_BREWFILE=$(mktemp)
trap 'rm -f "$TMP_BREWFILE"' EXIT

[ -n "$TAPS" ] && printf '%s\n' "$TAPS" >> "$TMP_BREWFILE"
[ -n "$SELECTED_FORMULAE" ] && while IFS= read -r f; do echo "brew \"$f\"" >> "$TMP_BREWFILE"; done <<< "$SELECTED_FORMULAE"
[ -n "$SELECTED_CASKS" ] && while IFS= read -r c; do echo "cask \"$c\"" >> "$TMP_BREWFILE"; done <<< "$SELECTED_CASKS"

brew bundle install --file="$TMP_BREWFILE"
