#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found on PATH — skipping global package install."
  exit 0
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
