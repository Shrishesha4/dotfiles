#!/bin/bash

# Exit on error unless --no-exit is passed
if [[ "$1" != "--no-exit" ]]; then
    set -e
fi

# Optional verbose flag for full command output
VERBOSE=false
[[ "$1" == "-v" || "$2" == "-v" ]] && VERBOSE=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DOTFILES_REPO="https://github.com/Shrishesha4/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Progress tracking variables
TOTAL_STEPS=12
CURRENT_STEP=0

# Enhanced logging functions with progress
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pc=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${GREEN}${pc}%${NC} – $1"
}

show_success() { echo -e "${GREEN}✓${NC} $1"; }
show_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
show_error()   { echo -e "${RED}✗${NC} $1"; }

# Spinner wrapper that honours --verbose
execute_silently() {
    local job="$1"; shift
    if $VERBOSE; then
        echo -e "${BLUE}▶${NC} $job"
        "$@"
        return $?
    fi
    "$@" > /tmp/setup_output.log 2>&1 & local pid=$!
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}${spin:i++%${#spin}:1}${NC} $job"; sleep 0.1
    done; wait $pid; local rc=$?
    printf "\r"
    [[ $rc -eq 0 ]] && show_success "$job" \
                    || { show_error "$job"; tail -5 /tmp/setup_output.log; }
    return $rc
}

# Classic log functions (kept for backward compat)
log_info()    { echo -e "${BLUE}[INFO ]${NC} $1"; }
log_success() { echo -e "${GREEN}[ OK  ]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARN ]${NC} $1"; }
log_error()   { echo -e "${RED}[FAIL ]${NC} $1"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect system architecture
get_architecture() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "x64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Cleanup function for trap
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Script failed. Check the logs above for details."
        log_info "Backup directory: $BACKUP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main setup function
main() {
    clear
    echo -e "${GREEN}Ubuntu Developer Setup${NC}\n"

    mkdir -p "$BACKUP_DIR"

    show_progress "System packages";          execute_silently "System Update"        update_system
    show_progress "Clone dotfiles repo";      execute_silently "Dotfiles"            setup_dotfiles_repo
    show_progress "Symlink dotfiles";         execute_silently "Symlinking"          symlink_dotfiles
    show_progress "Code editor";              execute_silently "Editor install"      install_code_editor
    show_progress "Fonts";                    execute_silently "Meslo NF fonts"      install_fonts
    show_progress "Development tools";        execute_silently "Dev tools"           install_dev_tools
    show_progress "Oh-My-Zsh & theme";        execute_silently "Oh My Zsh"           setup_oh_my_zsh
    show_progress "SSH keys";                 execute_silently "SSH keys"            setup_ssh_keys
    show_progress "Python (pyenv)";           execute_silently "Python/pyenv"        setup_python
    show_progress "Ruby (rbenv)";             execute_silently "Ruby/rbenv"          setup_ruby
    show_progress "Node.js";                  execute_silently "Node.js"             setup_nodejs
    show_progress "Extra apps";               execute_silently "Extra apps"          install_additional_apps

    echo; show_success "Setup finished! Run: ${YELLOW}source ~/.zshrc${NC} ➜ ${YELLOW}p10k configure${NC}"
}

update_system() {
    log_info "Updating system packages..."
    
    # Update package list
    sudo apt update
    
    # Install essential packages
    sudo apt install -y \
        curl \
        wget \
        git \
        build-essential \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        zsh \
        unzip \
        tree \
        htop \
        neovim \
        tmux \
        jq \
        fzf \
        postgresql \
        postgresql-contrib \
        snapd
    
    log_success "System packages updated and essential tools installed"
}

setup_dotfiles_repo() {
    log_info "Setting up dotfiles repository..."
    
    if [ -d "$DOTFILES_DIR" ]; then
        log_warning "Dotfiles directory already exists at $DOTFILES_DIR"
        if [ -d "$DOTFILES_DIR/.git" ]; then
            log_info "Updating existing dotfiles repository..."
            cd "$DOTFILES_DIR"
            git pull origin main || git pull origin master || log_warning "Could not update dotfiles repo"
        else
            log_warning "Directory exists but not a git repository. Moving to backup..."
            mv "$DOTFILES_DIR" "$BACKUP_DIR/dotfiles_existing"
            log_info "Cloning dotfiles repository..."
            git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        fi
    else
        log_info "Cloning dotfiles repository..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    
    if [ -d "$DOTFILES_DIR" ]; then
        log_success "Dotfiles repository setup completed"
    else
        log_error "Failed to setup dotfiles repository"
        exit 1
    fi
}

install_code_editor() {
    log_info "Choosing code editor..."
    
    # Ensure jq is available
    if ! command_exists jq; then
        log_info "Installing jq for API parsing..."
        sudo apt update && sudo apt install -y jq
    fi
    
    # Check if either editor is already installed
    local cursor_installed=false
    local vscode_installed=false
    
    if command_exists cursor || [ -f "$HOME/.local/bin/cursor" ]; then
        cursor_installed=true
        log_info "✓ Cursor is already installed"
    fi
    
    if command_exists code; then
        vscode_installed=true
        log_info "✓ VS Code is already installed"
    fi
    
    # If both are installed, return success
    if [ "$cursor_installed" = true ] && [ "$vscode_installed" = true ]; then
        log_info "Both editors are installed."
        return 0
    fi
    
    # Show choice menu for missing editors
    echo
    echo "Choose your preferred code editor:"
    echo "1) Cursor (AI-powered code editor)"
    echo "2) VS Code (Microsoft's code editor)"  
    echo "3) Both"
    echo "4) Skip editor installation"
    echo
    read -p "Enter your choice (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            install_cursor || log_warning "Cursor installation failed, continuing..."
            ;;
        2)
            install_vscode || log_warning "VS Code installation failed, continuing..."
            ;;
        3)
            install_cursor || log_warning "Cursor installation failed, continuing..."
            install_vscode || log_warning "VS Code installation failed, continuing..."
            ;;
        4)
            log_info "Skipping editor installation"
            ;;
        *)
            log_warning "Invalid choice. Installing VS Code as default..."
            install_vscode || log_warning "VS Code installation failed, continuing..."
            ;;
    esac
    
    return 0  # Always return success to prevent script termination
}


install_cursor() {
    log_info "Installing Cursor editor..."
    
    local arch=$(get_architecture)
    local cursor_url=""
    
    case $arch in
        x64)
            cursor_url="https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
            ;;
        arm64)
            cursor_url="https://cursor.com/api/download?platform=linux-arm64&releaseTrack=stable"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    log_info "Downloading Cursor for $arch architecture..."
    
    # Get the actual download URL from the API
    local download_url=$(curl -s "$cursor_url" | jq -r '.url // empty')
    
    if [ -z "$download_url" ]; then
        log_error "Failed to get Cursor download URL"
        return 1
    fi
    
    local cursor_appimage="$HOME/.local/bin/cursor.appimage"
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    
    # Download Cursor AppImage
    curl -L -o "$cursor_appimage" "$download_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Cursor editor"
        return 1
    fi
    
    # Make it executable
    chmod +x "$cursor_appimage"
    
    # Create wrapper script
    cat > "$HOME/.local/bin/cursor" << 'EOF'
#!/bin/bash
exec "$HOME/.local/bin/cursor.appimage" "$@"
EOF
    
    chmod +x "$HOME/.local/bin/cursor"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
    fi
    
    log_success "Cursor editor installed successfully"
}

install_vscode() {
    log_info "Installing VS Code..."
    
    local arch=$(get_architecture)
    local vscode_url=""
    
    case $arch in
        x64)
            vscode_url="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
            ;;
        arm64)
            vscode_url="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    
    local vscode_deb="/tmp/vscode.deb"
    
    log_info "Downloading VS Code for $arch architecture..."
    curl -L -o "$vscode_deb" "$vscode_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download VS Code"
        return 1
    fi
    
    # Install the .deb package
    sudo dpkg -i "$vscode_deb"
    
    # Fix any dependency issues
    sudo apt-get install -f -y
    
    # Clean up
    rm -f "$vscode_deb"
    
    log_success "VS Code installed successfully"
}

install_fonts() {
    log_info "Installing MesloLGS NF fonts..."
    
    # Create fonts directory
    mkdir -p ~/.local/share/fonts
    
    # Font URLs from Powerlevel10k repo
    local fonts=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    for font_url in "${fonts[@]}"; do
        local font_name=$(basename "$font_url" | sed 's/%20/ /g')
        local font_path="$HOME/.local/share/fonts/$font_name"
        
        if [ ! -f "$font_path" ]; then
            log_info "Downloading $font_name..."
            curl -fLo "$font_path" "$font_url" || log_warning "Failed to download $font_name"
            
            if [ -f "$font_path" ]; then
                log_success "$font_name installed"
            fi
        else
            log_info "$font_name already exists, skipping..."
        fi
    done
    
    # Refresh font cache
    fc-cache -fv
    
    log_success "MesloLGS NF fonts installation completed"
}

install_dev_tools() {
    log_info "Installing development tools..."
    
    # Install Docker
    if ! command_exists docker; then
        log_info "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        log_success "Docker installed (logout/login required for group changes)"
    else
        log_info "Docker already installed"
    fi
    
    # Install GitHub CLI
    if ! command_exists gh; then
        log_info "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install -y gh
        log_success "GitHub CLI installed"
    else
        log_info "GitHub CLI already installed"
    fi
    
    log_success "Development tools installation completed"
}

setup_oh_my_zsh() {
    log_info "Setting up Oh My Zsh and Powerlevel10k..."
    
    # Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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
    else
        log_info "zsh-autosuggestions already installed"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        log_success "zsh-syntax-highlighting installed"
    else
        log_info "zsh-syntax-highlighting already installed"
    fi
    
    # Change default shell to zsh
    if [ "$SHELL" != "/usr/bin/zsh" ] && [ "$SHELL" != "/bin/zsh" ]; then
        log_info "Changing default shell to zsh..."
        chsh -s $(which zsh)
        log_success "Default shell changed to zsh (restart required)"
    fi
    
    log_success "Oh My Zsh and Powerlevel10k setup completed"
}

setup_ssh_keys() {
    log_info "Setting up SSH keys..."
    
    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Copy SSH keys from dotfiles repo
    if [ -f "$DOTFILES_DIR/id_ed25519" ] && [ -f "$DOTFILES_DIR/id_ed25519.pub" ]; then
        log_info "Copying SSH keys from dotfiles..."
        
        # Backup existing keys if they exist
        if [ -f ~/.ssh/id_ed25519 ]; then
            log_warning "Backing up existing SSH private key..."
            cp ~/.ssh/id_ed25519 "$BACKUP_DIR/id_ed25519.backup"
        fi
        
        if [ -f ~/.ssh/id_ed25519.pub ]; then
            log_warning "Backing up existing SSH public key..."
            cp ~/.ssh/id_ed25519.pub "$BACKUP_DIR/id_ed25519.pub.backup"
        fi
        
        # Copy new keys
        cp "$DOTFILES_DIR/id_ed25519" ~/.ssh/id_ed25519
        cp "$DOTFILES_DIR/id_ed25519.pub" ~/.ssh/id_ed25519.pub
        
        # Set correct permissions
        chmod 600 ~/.ssh/id_ed25519
        chmod 644 ~/.ssh/id_ed25519.pub
        
        # Create SSH config if it doesn't exist
        if [ ! -f ~/.ssh/config ]; then
            log_info "Creating SSH config..."
            cat > ~/.ssh/config << EOF
Host github.com
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

Host *
    AddKeysToAgent yes
EOF
            chmod 600 ~/.ssh/config
        fi
        
        # Add key to SSH agent
        log_info "Adding SSH key to agent..."
        eval "$(ssh-agent -s)"
        ssh-add ~/.ssh/id_ed25519
        
        log_success "SSH keys configured successfully"
    else
        log_warning "SSH keys not found in dotfiles repo"
        log_info "You can generate new SSH keys with: ssh-keygen -t ed25519 -C \"your_email@example.com\""
    fi
    
    if [ -d "$DOTFILES_DIR/.git" ]; then
        log_info "Switching dotfiles repo remote to SSH..."
        cd "$DOTFILES_DIR"
        git remote set-url origin git@github.com:Shrishesha4/dotfiles.git
        log_success "Dotfiles repo remote set to SSH"
    fi
}

setup_python() {
    log_info "Setting up Python with pyenv..."
    
    # Install pyenv dependencies
    sudo apt install -y make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
        libffi-dev liblzma-dev
    
    # Install pyenv
    if [ ! -d "$HOME/.pyenv" ]; then
        log_info "Installing pyenv..."
        curl https://pyenv.run | bash
        log_success "pyenv installed"
    else
        log_info "pyenv already installed"
    fi
    
    # Initialize pyenv for current session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    
    # Install Python versions
    local python_versions=("3.13.5" "3.9.23")
    for version in "${python_versions[@]}"; do
        if ! pyenv versions | grep -q "$version"; then
            log_info "Installing Python $version..."
            pyenv install "$version" || log_warning "Failed to install Python $version"
        else
            log_info "Python $version already installed"
        fi
    done
    
    # Set global Python version
    log_info "Setting Python 3.13.5 as global default..."
    pyenv global 3.13.5 || log_warning "Failed to set global Python version"
    
    log_success "Python setup completed"
}

setup_ruby() {
    log_info "Setting up Ruby with rbenv..."
    
    # Install rbenv dependencies
    sudo apt install -y libssl-dev libreadline-dev zlib1g-dev autoconf bison \
        build-essential libyaml-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-dev
    
    # Install rbenv
    if [ ! -d "$HOME/.rbenv" ]; then
        log_info "Installing rbenv..."
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
        git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
        log_success "rbenv installed"
    else
        log_info "rbenv already installed"
    fi
    
    # Initialize rbenv for current session
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"
    
    # Install Ruby version
    local ruby_version="3.2.7"
    if ! rbenv versions | grep -q "$ruby_version"; then
        log_info "Installing Ruby $ruby_version..."
        rbenv install "$ruby_version" || log_warning "Failed to install Ruby $ruby_version"
    else
        log_info "Ruby $ruby_version already installed"
    fi
    
    # Set global Ruby version
    log_info "Setting Ruby $ruby_version as global default..."
    rbenv global "$ruby_version" || log_warning "Failed to set global Ruby version"
    
    log_success "Ruby setup completed"
}

setup_nodejs() {
    log_info "Setting up Node.js with nvm..."
    
    # Install nvm
    if [ ! -d "$HOME/.nvm" ]; then
        log_info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
        log_success "nvm installed"
    else
        log_info "nvm already installed"
    fi
    
    # Load nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    # Install latest LTS Node.js
    if command_exists nvm; then
        log_info "Installing latest LTS Node.js..."
        nvm install --lts
        nvm use --lts
        nvm alias default node
        
        # Install global packages
        npm install -g yarn pnpm
        log_success "Node.js and package managers installed"
    else
        log_warning "nvm not found, skipping Node.js installation"
    fi
}

install_additional_apps() {
    log_info "Installing additional applications..."
    
    echo
    echo "Choose which applications to install:"
    echo "1) All applications"
    echo "2) Select individually"
    echo "3) Skip additional apps"
    echo
    read -p "Enter your choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            install_brave_browser
            install_discord
            install_spotify
            install_android_studio
            install_postman
            ;;
        2)
            select_individual_apps
            ;;
        3)
            log_info "Skipping additional applications"
            return 0
            ;;
        *)
            log_warning "Invalid choice. Skipping additional applications..."
            ;;
    esac
}

select_individual_apps() {
    echo
    read -p "Install Brave Browser? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_brave_browser
    fi
    
    echo
    read -p "Install Discord? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_discord
    fi
    
    echo
    read -p "Install Spotify? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_spotify
    fi
    
    echo
    read -p "Install Android Studio? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_android_studio
    fi
    
    echo
    read -p "Install Postman? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_postman
    fi
}

install_brave_browser() {
    log_info "Installing Brave Browser..."
    
    if command_exists brave-browser; then
        log_success "Brave Browser is already installed"
        return 0
    fi
    
    # Add Brave repository
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    
    # Install Brave
    sudo apt update
    sudo apt install -y brave-browser
    
    log_success "Brave Browser installed successfully"
}

install_discord() {
    log_info "Installing Discord..."
    
    if command_exists discord; then
        log_success "Discord is already installed"
        return 0
    fi
    
    # Download and install Discord
    wget -O /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
    sudo dpkg -i /tmp/discord.deb
    sudo apt-get install -f -y  # Fix any dependency issues
    
    # Clean up
    rm /tmp/discord.deb
    
    log_success "Discord installed successfully"
}

install_spotify() {
    log_info "Installing Spotify..."
    
    if command_exists spotify; then
        log_success "Spotify is already installed"
        return 0
    fi
    
    # Add Spotify repository
    curl -sS https://download.spotify.com/debian/pubkey_7A3A762FAFD4A51F.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    
    # Install Spotify
    sudo apt update
    sudo apt install -y spotify-client
    
    log_success "Spotify installed successfully"
}

install_android_studio() {
    log_info "Installing Android Studio..."
    
    # Check if Android Studio is already installed
    if [ -d "/opt/android-studio" ] || command_exists android-studio >/dev/null 2>&1; then
        log_success "Android Studio is already installed"
        return 0
    fi
    
    local arch=$(get_architecture)
    
    # Android Studio only supports x64 architecture
    if [ "$arch" != "x64" ]; then
        log_error "Android Studio only supports x64 architecture. Current architecture: $arch"
        return 1
    fi
    
    local android_url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2025.1.1.14/android-studio-2025.1.1.14-linux.tar.gz"
    local android_tar="/tmp/android-studio.tar.gz"
    
    log_info "Downloading Android Studio..."
    log_warning "Android Studio is a large download (~1GB) and may take time"
    
    curl -L -o "$android_tar" "$android_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Android Studio"
        return 1
    fi
    
    # Extract to /opt
    log_info "Extracting Android Studio to /opt/..."
    sudo tar -xzf "$android_tar" -C /opt/
    
    if [ $? -ne 0 ]; then
        log_error "Failed to extract Android Studio"
        return 1
    fi
    
    # Create desktop entry
    log_info "Creating desktop entry..."
    sudo tee /usr/share/applications/android-studio.desktop > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=The Drive to Develop
Exec=/opt/android-studio/bin/studio.sh %f
Icon=/opt/android-studio/bin/studio.png
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-studio
StartupNotify=true
EOF
    
    # Create symlink for command line access
    sudo ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio
    
    # Set permissions
    sudo chown -R $USER:$USER /opt/android-studio
    
    # Clean up
    rm -f "$android_tar"
    
    log_success "Android Studio installed successfully"
    log_info "Note: You'll need to complete Android Studio setup on first launch"
}

install_postman() {
    log_info "Installing Postman..."
    
    # Check if Postman is already installed
    if command_exists postman >/dev/null 2>&1 || snap list postman >/dev/null 2>&1; then
        log_success "Postman is already installed"
        return 0
    fi
    
    # Install snapd if not present
    if ! command_exists snap >/dev/null 2>&1; then
        log_info "Installing snapd..."
        sudo apt update
        sudo apt install -y snapd
    fi
    
    # Install Postman via snap
    log_info "Installing Postman via snap..."
    sudo snap install postman
    
    if [ $? -eq 0 ]; then
        log_success "Postman installed successfully"
    else
        log_error "Failed to install Postman"
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
            # Special handling for .zshrc to prevent Oh My Zsh conflicts
            if [ "$dotfile" = ".zshrc" ] && [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
                log_warning "Backing up existing $dotfile (likely Oh My Zsh default) to $BACKUP_DIR"
                cp "$target_file" "$BACKUP_DIR/$dotfile.backup"
            elif [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
                log_warning "Backing up existing $dotfile to $BACKUP_DIR"
                cp "$target_file" "$BACKUP_DIR/$dotfile.backup"
            fi
            
            # Remove existing file/symlink
            [ -e "$target_file" ] && rm "$target_file"
            
            # Create symlink
            ln -s "$source_file" "$target_file"
            log_success "Symlinked $dotfile"
        else
            log_warning "$dotfile not found in dotfiles repo"
        fi
    done
    
    log_success "Dotfiles symlinked successfully"
}

# Run main function
main "$@"
