#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prompt for user input
prompt_user() {
    local prompt_text="$1"
    local default_value="$2"
    local user_input
    
    if [ -n "$default_value" ]; then
        read -p "$prompt_text [$default_value]: " user_input
        echo "${user_input:-$default_value}"
    else
        read -p "$prompt_text: " user_input
        echo "$user_input"
    fi
}

# Main setup function
main() {
    log_info "Starting macOS Developer Environment Setup..."
    
    # Get dotfiles repo URL from user
    DOTFILES_REPO=$(prompt_user "Enter your dotfiles repository URL (SSH format)" "git@github.com:username/dotfiles.git")
    DOTFILES_DIR="$HOME/dotfiles"
    
    # 1. Clone Dotfiles Repository
    setup_dotfiles_repo
    
    # 2. Setup SSH Keys
    setup_ssh_keys
    
    # 3. Install Homebrew and packages
    setup_homebrew
    
    # 4. macOS Customizations
    setup_macos_customizations
    
    # 5. Python Setup (pyenv)
    setup_python
    
    # 6. Ruby Setup (rbenv)
    setup_ruby
    
    # 7. Install Fonts
    install_fonts
    
    # 8. Oh My Zsh + Powerlevel10k
    setup_oh_my_zsh
    
    # 9. Symlink Dotfiles
    symlink_dotfiles
    
    # 10. Final Steps
    final_steps
    
    log_success "Setup completed successfully!"
    log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}

setup_dotfiles_repo() {
    log_info "Setting up dotfiles repository..."
    
    if [ -d "$DOTFILES_DIR" ]; then
        log_warning "Dotfiles directory already exists at $DOTFILES_DIR"
        local overwrite=$(prompt_user "Do you want to remove and re-clone? (y/N)" "N")
        if [[ "$overwrite" =~ ^[Yy]$ ]]; then
            rm -rf "$DOTFILES_DIR"
        else
            log_info "Using existing dotfiles directory"
            return 0
        fi
    fi
    
    log_info "Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || {
        log_error "Failed to clone repository. Please check the URL and your SSH access."
        exit 1
    }
    
    log_success "Dotfiles repository cloned successfully"
}

setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Check if SSH keys exist in dotfiles repo
    if [ -f "$DOTFILES_DIR/id_ed25519" ] && [ -f "$DOTFILES_DIR/id_ed25519.pub" ]; then
        log_info "Found SSH keys in dotfiles repo"
        
        # Only copy if they don't already exist
        if [ ! -f ~/.ssh/id_ed25519 ]; then
            cp "$DOTFILES_DIR/id_ed25519" ~/.ssh/
            chmod 600 ~/.ssh/id_ed25519
            log_success "Private SSH key copied and permissions set"
        else
            log_warning "SSH private key already exists, skipping..."
        fi
        
        if [ ! -f ~/.ssh/id_ed25519.pub ]; then
            cp "$DOTFILES_DIR/id_ed25519.pub" ~/.ssh/
            chmod 644 ~/.ssh/id_ed25519.pub
            log_success "Public SSH key copied and permissions set"
        else
            log_warning "SSH public key already exists, skipping..."
        fi
        
        # Add key to ssh-agent
        ssh-add ~/.ssh/id_ed25519 2>/dev/null || log_warning "Could not add SSH key to agent"
    else
        log_warning "No SSH keys found in dotfiles repo"
    fi
}

setup_homebrew() {
    log_info "Setting up Homebrew..."
    
    # Install Homebrew if not present
    if ! command_exists brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed successfully"
    else
        log_info "Homebrew already installed"
    fi
    
    # Use brew bundle with Brewfile from dotfiles repo
    if [ -f "$DOTFILES_DIR/Brewfile" ]; then
        log_info "Installing packages from Brewfile..."
        cd "$DOTFILES_DIR"
        brew bundle || log_warning "Some packages might have failed to install"
        log_success "Homebrew packages installed"
    else
        log_error "Brewfile not found in dotfiles repo"
    fi
}

setup_macos_customizations() {
    log_info "Applying macOS customizations..."
    
    # Dock customizations
    log_info "Configuring Dock..."
    defaults write com.apple.dock autohide-delay -int 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    killall Dock
    log_success "Dock configured"
    
    # Screenshot folder setup
    log_info "Setting up screenshot folder..."
    mkdir -p ~/Pictures/Screenshots
    defaults write com.apple.screencapture location ~/Pictures/Screenshots
    killall SystemUIServer
    log_success "Screenshot folder configured"
}

setup_python() {
    log_info "Setting up Python with pyenv..."
    
    if ! command_exists pyenv; then
        log_info "Installing pyenv..."
        brew install pyenv || {
            log_error "Failed to install pyenv"
            return 1
        }
    fi
    
    # Add pyenv to shell
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    
    # Install Python versions
    log_info "Installing Python 3.13.5..."
    pyenv install -s 3.13.5
    
    log_info "Installing Python 3.9.23..."
    pyenv install -s 3.9.23
    
    # Set global Python version
    log_info "Setting Python 3.13.5 as global default..."
    pyenv global 3.13.5
    
    log_success "Python setup completed"
}

setup_ruby() {
    log_info "Setting up Ruby with rbenv..."
    
    if ! command_exists rbenv; then
        log_info "Installing rbenv..."
        brew install rbenv || {
            log_error "Failed to install rbenv"
            return 1
        }
    fi
    
    # Add rbenv to shell
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    # Install Ruby version
    log_info "Installing Ruby 3.2.7..."
    rbenv install -s 3.2.7
    
    # Set global Ruby version
    log_info "Setting Ruby 3.2.7 as global default..."
    rbenv global 3.2.7
    
    log_success "Ruby setup completed"
}

install_fonts() {
    log_info "Installing MesloLGS NF fonts..."
    
    # Create fonts directory
    mkdir -p ~/Library/Fonts
    
    # Font URLs from Powerlevel10k repo
    local fonts=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    for font_url in "${fonts[@]}"; do
        local font_name=$(basename "$font_url" | sed 's/%20/ /g')
        local font_path="$HOME/Library/Fonts/$font_name"
        
        if [ ! -f "$font_path" ]; then
            log_info "Downloading $font_name..."
            curl -fLo "$font_path" "$font_url"
            log_success "$font_name installed"
        else
            log_warning "$font_name already exists, skipping..."
        fi
    done
    
    log_success "All MesloLGS NF fonts installed"
}

setup_oh_my_zsh() {
    log_info "Setting up Oh My Zsh and Powerlevel10k..."
    
    # Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        log_success "Oh My Zsh installed"
    else
        log_info "Oh My Zsh already installed"
    fi
    
    # Install Powerlevel10k theme
    local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        log_info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_success "Powerlevel10k installed"
    else
        log_info "Powerlevel10k already installed"
    fi
    
    # Install zsh plugins
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    
    # zsh-autosuggestions
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        log_success "zsh-autosuggestions installed"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    fi
}

symlink_dotfiles() {
    log_info "Creating symlinks for dotfiles..."
    
    local dotfiles=(
        ".gitconfig"
        ".yarnrc"
        ".zshrc"
        ".p10k.zsh"
        ".zprofile"
    )
    
    for dotfile in "${dotfiles[@]}"; do
        local source_file="$DOTFILES_DIR/$dotfile"
        local target_file="$HOME/$dotfile"
        
        if [ -f "$source_file" ]; then
            # Backup existing file if it exists and isn't already a symlink
            if [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
                log_warning "Backing up existing $dotfile to ${dotfile}.backup"
                mv "$target_file" "${target_file}.backup"
            fi
            
            # Remove existing symlink if it exists
            [ -L "$target_file" ] && rm "$target_file"
            
            # Create symlink
            ln -s "$source_file" "$target_file"
            log_success "Symlinked $dotfile"
        else
            log_warning "$dotfile not found in dotfiles repo"
        fi
    done
}

final_steps() {
    log_info "Performing final setup steps..."
    
    # Change default shell to zsh if not already
    if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
        log_info "Changing default shell to zsh..."
        chsh -s /bin/zsh
        log_success "Default shell changed to zsh"
    fi
    
    # Terminal font configuration message
    log_info "=== MANUAL STEP REQUIRED ==="
    log_warning "Please configure your terminal to use 'MesloLGS NF' font:"
    log_warning "  - Terminal.app: Preferences > Profiles > Text > Font"
    log_warning "  - iTerm2: Preferences > Profiles > Text > Font"
    log_warning "  - Choose 'MesloLGS NF' and set size to 12pt or preferred size"
    log_info "================================"
}

# Run main function
main "$@"