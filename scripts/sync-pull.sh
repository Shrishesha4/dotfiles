#!/usr/bin/env bash
set -euo pipefail
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES_DIR"

OLD_HEAD=$(git rev-parse HEAD)
git pull --ff-only
NEW_HEAD=$(git rev-parse HEAD)

if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
  echo "Already up to date. (Symlinked config modules already reflect the repo live — nothing else to do.)"
  exit 0
fi

echo "Changed since last pull:"
git diff --stat "$OLD_HEAD" "$NEW_HEAD"
echo
echo "Note: symlinked config modules (zsh/git/ghostty/starship/claude-code/cursor/agents-skills) need no action —"
echo "the live file already points into the repo. Only new brew/npm/vscode-extension entries need installing below."
echo

command -v gum >/dev/null 2>&1 || brew install gum

# --- Brewfile: new tap/brew/cask lines only ---
NEW_BREW_LINES=$(git diff "$OLD_HEAD" "$NEW_HEAD" -- Brewfile | grep -E '^\+(tap|brew|cask) ' | sed 's/^\+//' || true)
if [ -n "$NEW_BREW_LINES" ]; then
  echo "New Brewfile entries:"
  echo "$NEW_BREW_LINES"
  if gum confirm "Install these now?"; then
    TMP=$(mktemp)
    printf '%s\n' "$NEW_BREW_LINES" > "$TMP"
    brew bundle install --file="$TMP"
    rm -f "$TMP"
  fi
  echo
fi

# --- VSCode: new extension lines only ---
NEW_EXT=$(git diff "$OLD_HEAD" "$NEW_HEAD" -- modules/vscode/extensions.txt | grep '^\+' | grep -v '^+++' | sed 's/^\+//' || true)
if [ -n "$NEW_EXT" ] && command -v code >/dev/null 2>&1; then
  echo "New VSCode extensions:"
  echo "$NEW_EXT"
  if gum confirm "Install these now?"; then
    while IFS= read -r ext; do
      [ -z "$ext" ] && continue
      code --install-extension "$ext"
    done <<< "$NEW_EXT"
  fi
  echo
fi

# --- npm globals: new package keys only (needs jq) ---
if command -v jq >/dev/null 2>&1; then
  OLD_NPM=$(git show "$OLD_HEAD:modules/npm/global-packages.json" 2>/dev/null | jq -r '.dependencies | keys[]' 2>/dev/null || true)
  NEW_NPM=$(jq -r '.dependencies | keys[]' modules/npm/global-packages.json 2>/dev/null || true)
  NEW_NPM_PKGS=$(comm -13 <(printf '%s\n' "$OLD_NPM" | sort) <(printf '%s\n' "$NEW_NPM" | sort) | grep -v '^$' || true)
  if [ -n "$NEW_NPM_PKGS" ] && command -v npm >/dev/null 2>&1; then
    echo "New npm global packages:"
    echo "$NEW_NPM_PKGS"
    if gum confirm "Install these now?"; then
      while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        npm install -g "$pkg"
      done <<< "$NEW_NPM_PKGS"
    fi
    echo
  fi
else
  echo "(jq not found — skipping npm global-packages diff. brew install jq to enable this check.)"
fi

echo "Sync done."
