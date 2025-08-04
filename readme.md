# macOS Developer Environment Setup

This repository contains a comprehensive, interactive setup script to bootstrap a complete macOS developer environment with your preferred dotfiles, tools, and configurations.

## Features

- **Interactive Setup**: Choose between default dotfiles, custom repository, or minimal setup
- **Dotfiles Management**: Clones and symlinks your dotfiles for a consistent environment
- **Flexible Configuration**: Use pre-configured defaults or bring your own dotfiles repository
- **SSH Key Management**: Interactive SSH key setup - paste existing keys or generate new ones
- **Development Tools**: Python (pyenv), Ruby (rbenv - optional), Node.js, Git, and essential CLI tools
- **Beautiful Terminal**: Oh My Zsh, Powerlevel10k theme, and MesloLGS NF fonts
- **Package Management**: Homebrew with Brewfile support or essential packages
- **macOS Optimizations**: Dock customization, system preferences, and productivity tweaks
- **Secure**: Password handling with session management and proper cleanup
- **Idempotent**: Safe to re-run; skips or updates already-installed tools

## Prerequisites

- macOS 12 or later (Intel or Apple Silicon)
- Internet connection
- Administrator privileges (script will prompt for password once)

## Usage

### Quick Start

## Mac OS (Apple Silicon)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Shrishesha4/dotfiles/main/macos_setup.sh)"
```

### What the Script Does

The script will interactively ask you to:

1. **Choose your dotfiles setup:**

   - **Default setup**: Uses pre-configured dotfiles with common tools and apps
   - **Custom repository**: Provide your own GitHub dotfiles repository URL
   - **Minimal setup**: Install only basic tools without custom configurations

2. **Ruby development setup:**

   - Choose whether to install Ruby and rbenv (useful for Jekyll, Rails, etc.)

3. **SSH key configuration:**
   - Use existing local SSH keys
   - Paste your existing SSH keys from another machine
   - Generate new SSH keys with your email

### Setup Options

#### 1. Default Setup

- Repository: `https://github.com/Shrishesha4/dotfiles.git`
- Includes: VS Code, Git config, terminal setup, dock applications
- Best for: Quick start with sensible defaults

#### 2. Custom Repository

- Provide your own GitHub repository URL (HTTPS or SSH)
- The script clones and uses your configurations
- Best for: Existing dotfiles users

#### 3. Minimal Setup

- Installs only essential development tools
- No custom configurations or dotfiles
- Best for: Clean start or manual configuration

## What Gets Installed

### Always Installed

- ✅ Xcode Command Line Tools
- ✅ Homebrew package manager
- ✅ Python with pyenv (versions 3.13.5, 3.9.23)
- ✅ Oh My Zsh with Powerlevel10k theme
- ✅ Essential CLI tools (git, curl, wget, vim, tree, htop, jq)
- ✅ MesloLGS NF fonts for terminal
- ✅ SSH key configuration

### Optional (Based on Your Choices)

- 💎 Ruby with rbenv (version 3.2.7)
- 📁 Your dotfiles repository and symlinks
- 🚀 VS Code or other applications (if in your Brewfile)
- ⚙️ macOS customizations and dock setup

### macOS Customizations Applied

- Dock auto-hide settings and app management
- Trackpad tap-to-click enabled
- Screenshots folder organization
- System UI improvements

## SSH Key Setup

The script provides flexible SSH key management:

1. **Existing Keys**: Use SSH keys already on your system
2. **Paste Keys**: Paste private and public key content from another machine
3. **Generate New**: Create new ED25519 keys with your email
4. **GitHub Integration**: Automatic instructions for adding keys to GitHub

## File Structure

```
Your dotfiles repository should include:
dotfiles/
├── .zshrc
├── .gitconfig
├── .p10k.zsh
├── .vimrc
├── Brewfile (optional)
└── terminal/
└── CustomProfile.terminal (optional)
```

## Troubleshooting

### Common Issues

**Permission Errors:**

- Ensure you have administrator privileges
- Don't run the script with `sudo` - it will prompt for password when needed

**Network Issues:**

- Check your internet connection
- Some corporate networks may block GitHub or Homebrew

**SSH Key Problems:**

- Verify your public key is added to GitHub: https://github.com/settings/keys
- Test connection: `ssh -T git@github.com`

**Font Issues:**

- Set terminal font to "MesloLGS NF" in Terminal preferences
- Run `p10k configure` to customize your prompt

### Re-running the Script

The script is idempotent and safe to re-run:

- Existing installations are detected and skipped
- Configuration files are backed up before changes
- You can update your setup by running the script again

### Logs and Debugging

- Run with verbose mode: `bash macos_setup.sh --verbose`
- Check backup directory: `~/.dotfiles_backup_YYYYMMDD_HHMMSS`
- Review error messages in the terminal output

## Customization

### Adding Your Own Dotfiles

1. Fork this repository or create your own
2. Add your configuration files (.zshrc, .gitconfig, etc.)
3. Update the repository URL when prompted

### Modifying Installed Packages

- Edit your `Brewfile` in your dotfiles repository
- For minimal setup, packages are hardcoded in the script

### Custom macOS Settings

- Modify the `setup_macos_customizations()` function
- Add your preferred system defaults commands

## Security Features

- 🔐 Secure password handling (prompted once, cleared after use)
- 🔑 SSH key validation and secure generation
- 💾 Automatic backups of existing configurations
- 🛡️ No hardcoded credentials or sensitive data

## Contributing

1. Fork the repository
2. Make your changes
3. Test thoroughly on a fresh macOS installation
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Credits

- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [Homebrew](https://brew.sh)
- [pyenv](https://github.com/pyenv/pyenv)
- [rbenv](https://github.com/rbenv/rbenv)

---

**Happy coding! 🚀**

_Last updated: August 2025_
