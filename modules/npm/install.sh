#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install nvm if missing
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "Installing nvm..."
  mkdir -p "$NVM_DIR"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
fi

# Load nvm into this shell (it's normally only added to interactive zsh/bash rc)
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

# Install node LTS if not present
if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node.js LTS via nvm..."
  nvm install --lts
  nvm use --lts
  nvm alias default 'lts/*'
fi

echo "Installing global npm packages from $DIR/global-packages.json..."
pkgs=$(node -e "
const data = require('$DIR/global-packages.json');
const deps = (data.dependencies) || {};
console.log(Object.keys(deps).filter(p => p !== 'npm' && p !== 'corepack').join('\n'));
")

while IFS= read -r pkg; do
  [ -z "$pkg" ] && continue
  npm install -g "$pkg"
done <<< "$pkgs"
