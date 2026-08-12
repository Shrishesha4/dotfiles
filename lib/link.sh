#!/usr/bin/env bash
# Sourced by module install.sh scripts. Provides backup_and_link().

backup_and_link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    mkdir -p "$DOTFILES_DIR/.backup"
    mv "$dest" "$DOTFILES_DIR/.backup/$(basename "$dest").$(date +%s).bak"
    echo "Backed up existing $dest -> .backup/"
  fi
  ln -s "$src" "$dest"
  echo "Linked $dest -> $src"
}

# For files that embed absolute $HOME paths (e.g. plugin install manifests) —
# the consuming tool doesn't expand env vars itself, so render a real file
# instead of symlinking. Template source uses the literal placeholder __HOME__.
render_template() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -e "$dest" ]; then
    mkdir -p "$DOTFILES_DIR/.backup"
    mv "$dest" "$DOTFILES_DIR/.backup/$(basename "$dest").$(date +%s).bak"
    echo "Backed up existing $dest -> .backup/"
  fi
  sed "s|__HOME__|$HOME|g" "$src" > "$dest"
  echo "Rendered $dest <- $src"
}
