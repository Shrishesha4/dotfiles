#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fix zsh completion permission warnings on fresh installs (homebrew dirs often group-writable).
chmod -R go-w /opt/homebrew/share/zsh /opt/homebrew/share 2>/dev/null || true
rm -f "$HOME/.zcompdump" 2>/dev/null || true

bash "$DIR/defaults.sh"
