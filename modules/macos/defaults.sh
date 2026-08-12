#!/usr/bin/env bash
set -euo pipefail
echo "macOS defaults module: this file only runs commands you've uncommented below."
echo "Edit modules/macos/defaults.sh, uncomment what you want, then re-run this module."

# --- EXAMPLES (uncomment to apply; verify current value first with 'defaults read <domain> <key>') ---
# defaults write com.apple.dock autohide -bool true
# defaults write com.apple.finder AppleShowAllFiles -bool true
# defaults write com.apple.screencapture location -string "$HOME/Desktop/Screenshots"
# defaults write NSGlobalDomain KeyRepeat -int 2
# killall Dock Finder 2>/dev/null || true
