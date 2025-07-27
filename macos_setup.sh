#!/bin/bash

set -e # Exit on any error

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

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
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

safe_execute() {
    local description="$1"
    shift
    log_info "$description"
    
    if "$@"; then
        return 0
    else
        log_warning "$description failed, but continuing with setup..."
        return 1
    fi
}


# Cleanup function for trap
cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Script failed. Check the logs above for details."
        log_info "Backup directory: $BACKUP_DIR"
        log_info "You can continue the setup manually or re-run specific functions"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main setup function
main() {
    log_info "Starting macOS Developer Environment Setup..."
    log_info "Backup directory: $BACKUP_DIR"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Track overall success
    local setup_errors=0
    
    install_xcode_cli || ((setup_errors++))
    setup_dotfiles_repo || ((setup_errors++))
    symlink_dotfiles || ((setup_errors++))
    install_code_editor || ((setup_errors++))
    install_fonts || ((setup_errors++))
    setup_homebrew || ((setup_errors++))
    setup_oh_my_zsh || ((setup_errors++))
    setup_ssh_keys || ((setup_errors++))
    setup_python || ((setup_errors++))
    setup_ruby || ((setup_errors++))
    setup_terminal_profile || ((setup_errors++))
    setup_macos_customizations || ((setup_errors++))
    install_additional_apps || ((setup_errors++))
    final_steps || ((setup_errors++))
    
    if [ $setup_errors -eq 0 ]; then
        log_success "Setup completed successfully with no errors!"
    else
        log_warning "Setup completed with $setup_errors function(s) having issues"
        log_info "Check the logs above for details on what failed"
    fi
    
    log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}


install_xcode_cli() {
    log_info "Checking for Xcode Command Line Tools..."
    if ! xcode-select -p &>/dev/null; then
        log_info "Xcode Command Line Tools not found. Installing..."
        xcode-select --install
        # Wait until the tools are installed
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_success "Xcode Command Line Tools installed."
    else
        log_info "Xcode Command Line Tools already installed."
    fi
}

install_code_editor() {
    log_info "Choosing code editor..."
    
    # Check if either editor is already installed
    local cursor_installed=false
    local vscode_installed=false
    
    if [ -d "/Applications/Cursor.app" ]; then
        cursor_installed=true
        log_info "✓ Cursor is already installed"
    fi
    
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        vscode_installed=true
        log_info "✓ VS Code is already installed"
    fi
    
    # If both are installed, ask which one to use as default
    if [ "$cursor_installed" = true ] && [ "$vscode_installed" = true ]; then
        log_info "Both editors are installed. Setting up CLI tools..."
        setup_editor_cli_tools
        return 0
    fi
    
    # If one is installed, ask if user wants the other
    if [ "$cursor_installed" = true ]; then
        echo
        read -p "Cursor is already installed. Do you also want to install VS Code? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_vscode
        fi
        setup_editor_cli_tools
        return 0
    fi
    
    if [ "$vscode_installed" = true ]; then
        echo
        read -p "VS Code is already installed. Do you also want to install Cursor? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_cursor
        fi
        setup_editor_cli_tools
        return 0
    fi
    
    # Neither is installed, ask user to choose
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
            log_info "Installing Cursor..."
            install_cursor
            ;;
        2)
            log_info "Installing VS Code..."
            install_vscode
            ;;
        3)
            log_info "Installing both editors..."
            install_cursor
            install_vscode
            ;;
        4)
            log_info "Skipping editor installation"
            return 0
            ;;
        *)
            log_warning "Invalid choice. Defaulting to Cursor..."
            install_cursor
            ;;
    esac
    
    setup_editor_cli_tools
}

install_cursor() {
    log_info "Installing Cursor editor..."
    
    # Fetch latest Cursor download URL from API
    CURSOR_API_URL="https://cursor.com/api/download?platform=darwin-universal&releaseTrack=stable"
    log_info "Fetching latest Cursor download URL from $CURSOR_API_URL ..."
    
    CURSOR_JSON=$(curl -fsSL "$CURSOR_API_URL")
    if [ $? -ne 0 ] || [ -z "$CURSOR_JSON" ]; then
        log_error "Failed to fetch Cursor download info."
        return 1
    fi
    
    CURSOR_DMG_URL=$(echo "$CURSOR_JSON" | grep -o '"downloadUrl":"[^"]*' | head -1 | cut -d'"' -f4)
    if [ -z "$CURSOR_DMG_URL" ]; then
        log_error "Could not parse download URL from Cursor API response."
        return 1
    fi
    
    log_info "Downloading Cursor from $CURSOR_DMG_URL ..."
    CURSOR_DMG="/tmp/Cursor.dmg"
    curl -L -o "$CURSOR_DMG" "$CURSOR_DMG_URL"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Cursor editor."
        return 1
    fi
    
    # Mount the DMG and get the mount point
    MOUNT_OUTPUT=$(hdiutil attach "$CURSOR_DMG")
    log_info "hdiutil attach output: $MOUNT_OUTPUT"
    
    # Extract the actual mount directory from hdiutil output
    MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$MOUNT_DIR" ]; then
        log_error "Failed to determine mount directory."
        return 1
    fi
    
    log_info "Mount directory: $MOUNT_DIR"
    
    # Look for Cursor.app recursively in the mount directory
    APP_PATH=$(find "$MOUNT_DIR" -name "Cursor.app" -type d -print -quit)
    
    if [ -z "$APP_PATH" ]; then
        log_error "Failed to find Cursor.app in mounted DMG. Contents:"
        ls -la "$MOUNT_DIR"
        hdiutil detach "$MOUNT_DIR"
        return 1
    fi
    
    log_info "Found Cursor.app at: $APP_PATH"
    log_info "Copying to /Applications/"
    
    # Copy the application
    cp -R "$APP_PATH" /Applications/
    
    if [ $? -eq 0 ]; then
        log_success "Cursor editor installed to /Applications."
    else
        log_error "Failed to copy Cursor.app to /Applications."
    fi
    
    # Unmount the DMG
    hdiutil detach "$MOUNT_DIR"
    
    # Clean up
    rm -f "$CURSOR_DMG"
}

install_vscode() {
    log_info "Installing VS Code..."
    
    VSCODE_ZIP="/tmp/VSCode.zip"
    VSCODE_URL="https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal"
    
    log_info "Downloading VS Code from $VSCODE_URL ..."
    curl -L -o "$VSCODE_ZIP" "$VSCODE_URL"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download VS Code."
        return 1
    fi
    
    log_info "Extracting VS Code..."
    unzip -q "$VSCODE_ZIP" -d /tmp/
    
    if [ -d "/tmp/Visual Studio Code.app" ]; then
        log_info "Copying VS Code to /Applications/"
        cp -R "/tmp/Visual Studio Code.app" /Applications/
        
        if [ $? -eq 0 ]; then
            log_success "VS Code installed to /Applications."
        else
            log_error "Failed to copy VS Code to /Applications."
        fi
        
        # Clean up
        rm -rf "/tmp/Visual Studio Code.app"
    else
        log_error "Failed to extract VS Code properly."
    fi
    
    # Clean up
    rm -f "$VSCODE_ZIP"
}

setup_editor_cli_tools() {
    log_info "Setting up CLI tools..."
    
    # Setup Cursor CLI if Cursor is installed
    if [ -d "/Applications/Cursor.app" ]; then
        if [ -e "/Applications/Cursor.app/Contents/Resources/bin/cursor" ] && [ ! -L "/usr/local/bin/cursor" ]; then
            log_info "Linking Cursor CLI to /usr/local/bin/cursor..."
            sudo ln -sf "/Applications/Cursor.app/Contents/Resources/bin/cursor" /usr/local/bin/cursor
            log_success "'cursor' CLI linked to /usr/local/bin/cursor."
        fi
    fi
    
    # Setup VS Code CLI using proper method
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        log_info "Setting up VS Code CLI..."
        
        # Check if code command already exists and works
        if command -v code >/dev/null 2>&1; then
            log_success "VS Code CLI already installed and working"
        else
            # Remove any existing broken symlink
            if [ -L "/usr/local/bin/code" ]; then
                log_info "Removing existing broken VS Code CLI symlink..."
                sudo rm -f "/usr/local/bin/code" 2>/dev/null || true
            fi
            
            log_warning "VS Code CLI requires manual setup:"
            log_info "1. Open VS Code"
            log_info "2. Press Cmd+Shift+P to open Command Palette"
            log_info "3. Type 'Shell Command: Install code command in PATH'"
            log_info "4. Select that option and enter your password when prompted"
        fi
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
            install_xcode_from_appstore
            install_docker
            install_brave_browser
            install_android_studio
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
    read -p "Install Xcode from App Store? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_xcode_from_appstore
    fi
    
    echo
    read -p "Install Docker? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_docker
    fi
    
    echo
    read -p "Install Brave Browser? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_brave_browser
    fi
    
    echo
    read -p "Install Android Studio? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_android_studio
    fi
}

install_xcode_from_appstore() {
    log_info "Installing Xcode from App Store..."
    
    # Check if Xcode is already installed
    if [ -d "/Applications/Xcode.app" ]; then
        log_success "Xcode is already installed"
        return 0
    fi
    
    # Check if user is signed in to App Store
    if ! mas account >/dev/null 2>&1; then
        log_warning "Not signed in to App Store. Manual installation required:"
        log_info "1. Open App Store"
        log_info "2. Sign in with your Apple ID"
        log_info "3. Search for 'Xcode' and install it"
        log_info "Note: Xcode is a large download (~15GB) and may take time"
        return 1
    fi
    
    log_info "Installing Xcode via App Store (this may take a while)..."
    log_warning "Xcode is ~15GB and may take 30+ minutes depending on your connection"
    
    # Install Xcode using mas (Mac App Store CLI)
    mas install 497799835 # Xcode App Store ID
    
    if [ $? -eq 0 ]; then
        log_success "Xcode installed successfully"
        
        # Accept Xcode license
        log_info "Accepting Xcode license..."
        sudo xcodebuild -license accept
        
        # Install additional components
        log_info "Installing additional Xcode components..."
        sudo xcodebuild -runFirstLaunch
        
        log_success "Xcode setup completed"
    else
        log_error "Failed to install Xcode from App Store"
    fi
}

install_docker() {
    log_info "Installing Docker..."
    
    # Check if Docker is already installed
    if [ -d "/Applications/Docker.app" ]; then
        log_success "Docker is already installed"
        return 0
    fi
    
    local docker_dmg="/tmp/Docker.dmg"
    local docker_url="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    
    log_info "Downloading Docker from $docker_url ..."
    curl -L -o "$docker_dmg" "$docker_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Docker"
        return 1
    fi
    
    # Mount the DMG
    log_info "Mounting Docker DMG..."
    local mount_output=$(hdiutil attach "$docker_dmg")
    local mount_dir=$(echo "$mount_output" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$mount_dir" ]; then
        log_error "Failed to mount Docker DMG"
        return 1
    fi
    
    # Find Docker.app and copy it
    local app_path=$(find "$mount_dir" -name "Docker.app" -type d -print -quit)
    
    if [ -z "$app_path" ]; then
        log_error "Failed to find Docker.app in mounted DMG"
        hdiutil detach "$mount_dir"
        return 1
    fi
    
    log_info "Installing Docker to /Applications/"
    cp -R "$app_path" /Applications/
    
    if [ $? -eq 0 ]; then
        log_success "Docker installed successfully"
    else
        log_error "Failed to install Docker"
    fi
    
    # Clean up
    hdiutil detach "$mount_dir"
    rm -f "$docker_dmg"
}

install_brave_browser() {
    log_info "Installing Brave Browser..."
    
    # Check if Brave is already installed
    if [ -d "/Applications/Brave Browser.app" ]; then
        log_success "Brave Browser is already installed"
        return 0
    fi
    
    local brave_dmg="/tmp/Brave-Browser.dmg"
    local brave_url="https://referrals.brave.com/latest/Brave-Browser.dmg"
    
    log_info "Downloading Brave Browser from $brave_url ..."
    curl -L -o "$brave_dmg" "$brave_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Brave Browser"
        return 1
    fi
    
    # Mount the DMG
    log_info "Mounting Brave Browser DMG..."
    local mount_output=$(hdiutil attach "$brave_dmg")
    local mount_dir=$(echo "$mount_output" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$mount_dir" ]; then
        log_error "Failed to mount Brave Browser DMG"
        return 1
    fi
    
    # Find Brave Browser.app and copy it
    local app_path=$(find "$mount_dir" -name "Brave Browser.app" -type d -print -quit)
    
    if [ -z "$app_path" ]; then
        log_error "Failed to find Brave Browser.app in mounted DMG"
        hdiutil detach "$mount_dir"
        return 1
    fi
    
    log_info "Installing Brave Browser to /Applications/"
    cp -R "$app_path" /Applications/
    
    if [ $? -eq 0 ]; then
        log_success "Brave Browser installed successfully"
    else
        log_error "Failed to install Brave Browser"
    fi
    
    # Clean up
    hdiutil detach "$mount_dir"
    rm -f "$brave_dmg"
}

install_android_studio() {
    log_info "Installing Android Studio..."
    
    # Check if Android Studio is already installed
    if [ -d "/Applications/Android Studio.app" ]; then
        log_success "Android Studio is already installed"
        return 0
    fi
    
    local android_dmg="/tmp/android-studio.dmg"
    local android_url="https://redirector.gvt1.com/edgedl/android/studio/install/2025.1.1.14/android-studio-2025.1.1.14-mac_arm.dmg"
    
    log_info "Downloading Android Studio from $android_url ..."
    log_warning "Android Studio is a large download (~1GB) and may take time"
    curl -L -o "$android_dmg" "$android_url"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to download Android Studio"
        return 1
    fi
    
    # Mount the DMG
    log_info "Mounting Android Studio DMG..."
    local mount_output=$(hdiutil attach "$android_dmg")
    local mount_dir=$(echo "$mount_output" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$mount_dir" ]; then
        log_error "Failed to mount Android Studio DMG"
        return 1
    fi
    
    # Find Android Studio.app and copy it
    local app_path=$(find "$mount_dir" -name "Android Studio.app" -type d -print -quit)
    
    if [ -z "$app_path" ]; then
        log_error "Failed to find Android Studio.app in mounted DMG"
        hdiutil detach "$mount_dir"
        return 1
    fi
    
    log_info "Installing Android Studio to /Applications/ (this may take a moment)..."
    cp -R "$app_path" /Applications/
    
    if [ $? -eq 0 ]; then
        log_success "Android Studio installed successfully"
        log_info "Note: You'll need to complete Android Studio setup on first launch"
    else
        log_error "Failed to install Android Studio"
    fi
    
    # Clean up
    hdiutil detach "$mount_dir"
    rm -f "$android_dmg"
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

setup_homebrew() {
    log_info "Setting up Homebrew..."

    # Check if Homebrew is already installed
    if command_exists brew; then
        log_info "Homebrew is already installed. Skipping installation."
        # Add Homebrew to PATH for Apple Silicon Macs if not already present
        if [[ $(uname -m) == "arm64" ]]; then
            if ! grep -q '/opt/homebrew/bin' ~/.zprofile 2>/dev/null; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        else
            if ! grep -q '/usr/local/bin' ~/.zprofile 2>/dev/null; then
                echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
        brew update
        log_success "Homebrew updated"
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        log_success "Homebrew installed successfully"
    fi

    # Use brew bundle with Brewfile from dotfiles repo
    if [ -f "$DOTFILES_DIR/Brewfile" ]; then
        log_info "Installing packages from Brewfile..."
        cd "$DOTFILES_DIR"
        brew bundle install || log_warning "Some packages might have failed to install"
        log_success "Homebrew packages installed from Brewfile"
    else
        log_warning "Brewfile not found in dotfiles repo, installing essential packages manually..."

        # Install essential packages
        local essential_packages=(
            "git" "wget" "curl" "pyenv" "rbenv" "fzf" "gh" "htop" "neovim" "tmux"
            "tree" "jq" "node" "yarn" "postgresql@15"
        )

        for package in "${essential_packages[@]}"; do
            if ! brew list "$package" >/dev/null 2>&1; then
                log_info "Installing $package..."
                brew install "$package" || log_warning "Failed to install $package"
            else
                log_info "$package already installed"
            fi
        done
    fi
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
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519

Host *
    AddKeysToAgent yes
    UseKeychain yes
EOF
            chmod 600 ~/.ssh/config
        fi

        # Add key to SSH agent
        log_info "Adding SSH key to agent..."
        eval "$(ssh-agent -s)"
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || ssh-add ~/.ssh/id_ed25519

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

    if ! command_exists pyenv; then
        log_error "pyenv not found. Make sure Homebrew installation completed successfully."
        return 1
    fi

    # Add pyenv to shell profile if not already present
    local shell_profile=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bash_profile"
    fi

    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        if ! grep -q "pyenv init" "$shell_profile"; then
            log_info "Adding pyenv initialization to $shell_profile..."
            echo '' >> "$shell_profile"
            echo '# Pyenv configuration' >> "$shell_profile"
            echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$shell_profile"
            echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$shell_profile"
            echo 'eval "$(pyenv init --path)"' >> "$shell_profile"
            echo 'eval "$(pyenv init -)"' >> "$shell_profile"
        fi
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

    if ! command_exists rbenv; then
        log_error "rbenv not found. Make sure Homebrew installation completed successfully."
        return 1
    fi

    # Add rbenv to shell profile if not already present
    local shell_profile=""
    if [ -n "$ZSH_VERSION" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_profile="$HOME/.bash_profile"
    fi

    if [ -n "$shell_profile" ] && [ -f "$shell_profile" ]; then
        if ! grep -q "rbenv init" "$shell_profile"; then
            log_info "Adding rbenv initialization to $shell_profile..."
            echo '' >> "$shell_profile"
            echo '# Rbenv configuration' >> "$shell_profile"
            echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$shell_profile"
            echo 'eval "$(rbenv init -)"' >> "$shell_profile"
        fi
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
            curl -fLo "$font_path" "$font_url" || log_warning "Failed to download $font_name"
            if [ -f "$font_path" ]; then
                log_success "$font_name installed"
            fi
        else
            log_info "$font_name already exists, skipping..."
        fi
    done

    log_success "MesloLGS NF fonts installation completed"
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

    log_success "Oh My Zsh and Powerlevel10k setup completed"
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

setup_macos_customizations() {
    log_info "Applying macOS customizations..."
    
    # Dock customizations
    log_info "Configuring Dock..."
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock autohide-delay -int 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    killall Dock
    
    log_success "Dock configured"
    
    # Screenshot folder setup
    log_info "Setting up screenshot folder..."
    mkdir -p ~/Documents/Screenshots
    defaults write com.apple.screencapture location ~/Documents/Screenshots
    killall SystemUIServer
    log_success "Screenshot folder configured"
    
    log_success "macOS customizations applied"
}

setup_terminal_profile() {
    log_info "Setting up terminal profile..."

    # Check if terminal profile exists in dotfiles
    local profile_file="$DOTFILES_DIR/terminal/CustomProfile.terminal"

    if [ -f "$profile_file" ]; then
        log_info "Importing Terminal profile..."
        open "$profile_file"
        sleep 2

        # Set the default profile using AppleScript
        log_info "Setting Terminal profile as default..."
        osascript <<EOF
tell application "Terminal"
    set default settings to settings set "CustomProfile"
end tell
EOF
        log_success "Terminal profile configured"
    else
        log_warning "Terminal profile not found at $profile_file"
        log_info "=== MANUAL STEP REQUIRED ==="
        log_warning "Please manually configure your terminal:"
        log_warning " - Set font to 'MesloLGS NF' (size 12pt or preferred)"
        log_warning " - Import any custom terminal profiles from your dotfiles"
        log_info "================================"
    fi
}

final_steps() {
    log_info "Performing final setup steps..."

    # Change default shell to zsh if not already
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Changing default shell to zsh..."
        chsh -s "$(which zsh)"
        log_success "Default shell changed to zsh"
    else
        log_info "Default shell is already zsh"
    fi

    # Final manual steps reminder
    log_info "=== MANUAL STEPS REQUIRED ==="
    log_warning "1. Configure your terminal to use 'MesloLGS NF' font:"
    log_warning "   - Terminal.app: Preferences > Profiles > Text > Font"
    log_warning "   - iTerm2: Preferences > Profiles > Text > Font"
    log_warning "   - Choose 'MesloLGS NF' and set size to 12pt or preferred"
    log_warning "2. If this is a new machine, add your SSH public key to GitHub:"
    log_warning "   - Copy: pbcopy < ~/.ssh/id_ed25519.pub"
    log_warning "   - Add to: https://github.com/settings/keys"
    log_warning "3. Test SSH connection: ssh -T git@github.com"
    log_warning "4. Run 'p10k configure' to customize your Powerlevel10k theme"
    log_info "================================"

    log_success "Final setup steps completed"
}

# Run main function
main "$@"
