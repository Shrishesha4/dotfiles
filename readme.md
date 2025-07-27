# macOS Developer Environment Setup

This repository contains a one-command setup script to bootstrap a complete macOS developer environment with your preferred dotfiles, tools, and applications.

## Features
- **Dotfiles management**: Clones and symlinks your dotfiles for a consistent environment.
- **Homebrew**: Installs Homebrew and all packages from your Brewfile or a default set.
- **Python & Ruby**: Installs and configures `pyenv` and `rbenv` with your preferred versions.
- **SSH keys**: Sets up SSH keys for GitHub and other services.
- **Fonts**: Installs MesloLGS NF fonts for a beautiful terminal experience.
- **Oh My Zsh & Powerlevel10k**: Installs and configures Zsh, themes, and plugins.
- **macOS customizations**: Applies useful system tweaks (Dock, screenshots, etc).
- **Terminal profile**: Optionally imports a custom Terminal profile.
- **Code editors**: Installs Cursor and/or VS Code, with CLI tools.
- **Optional apps**: Installs Xcode, Docker, Brave Browser, Android Studio (interactive choice).
- **Idempotent**: Safe to re-run; skips or updates already-installed tools.

## Prerequisites
- macOS 12 or later
- Internet connection
- (Optional) [Xcode Command Line Tools](https://developer.apple.com/download/more/) (the script will prompt to install if missing)
- (Optional) [mas-cli](https://github.com/mas-cli/mas) if you want to automate App Store installs (e.g., Xcode)

## Usage
Run this command in your terminal:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Shrishesha4/dotfiles/public/macos_setup.sh)"
```

The script will:
1. Prompt for any required choices (editors, optional apps)
2. Clone your dotfiles and back up any existing config
3. Install Homebrew, packages, and developer tools
4. Set up your shell, fonts, and system preferences
5. Optionally install Xcode, Docker, Brave, Android Studio

**You can safely re-run the script at any time.**

## What Gets Installed/Configured?
- Homebrew & packages (from `Brewfile` or defaults)
- pyenv, rbenv, Python, Ruby
- Oh My Zsh, Powerlevel10k, plugins
- MesloLGS NF fonts
- SSH keys (from dotfiles or generate new)
- Cursor and/or VS Code (with CLI tools)
- Xcode (via App Store, if selected)
- Docker, Brave Browser, Android Studio (if selected)
- macOS system tweaks (Dock, screenshots, etc)
- Symlinks for `.zshrc`, `.gitconfig`, `.p10k.zsh`, etc.

## Troubleshooting
- If the script fails, check the log output for details. Most steps are idempotent and can be retried.
- For App Store installs (Xcode), you must be signed in to the App Store and have [mas-cli](https://github.com/mas-cli/mas) installed.
- Some steps (e.g., VS Code CLI) may require manual confirmation.
- If you want to skip certain steps, you can comment them out in `macos_setup.sh` or answer prompts accordingly.

## Customization
- Edit `macos_setup.sh` to add/remove packages, apps, or custom steps.
- Place your dotfiles in this repo for automatic symlinking.
- Update the Brewfile for your preferred Homebrew packages.

## License
MIT