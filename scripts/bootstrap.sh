#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew install git gh gum

if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

if [ ! -d "$HOME/dotfiles" ]; then
  GH_USER=$(gh api user -q .login)
  gh repo clone "$GH_USER/dotfiles" "$HOME/dotfiles"
fi

cd "$HOME/dotfiles"
exec ./install.sh
