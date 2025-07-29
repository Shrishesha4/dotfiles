#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_REPO="https://github.com/Shrishesha4/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

TOTAL_STEPS=12
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local percentage=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${GREEN}${percentage}%${NC} - $1"
}

show_step() {
    echo -e "\n${BLUE}▶${NC} $1"
}

show_success() {
    echo -e "${GREEN}✓${NC} $1"
}

show_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

show_error() {
    echo -e "${RED}✗${NC} $1"
}

execute_silently() {
    local description="$1"
    shift
    
    "$@" > /tmp/setup_output.log 2>&1 &
    local pid=$!
    
    local spinner='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}${spinner:$i:1}${NC} $description"
        i=$(((i + 1) % ${#spinner}))
        sleep 0.1
    done
    
    wait $pid
    local exit_code=$?
    
    printf "\r"
    if [ $exit_code -eq 0 ]; then
        show_success "$description"
    else
        show_error "$description failed"
        if [ -s /tmp/setup_output.log ]; then
            echo -e "${YELLOW}Error details:${NC}"
            tail -5 /tmp/setup_output.log
        fi
    fi
    
    return $exit_code
}

VERBOSE=0
for arg in "$@"; do
    if [[ "$arg" == "--v" || "$arg" == "--verbose" ]]; then
        VERBOSE=1
    fi
done

ICON_INFO="📄"      # 📄
ICON_SUCCESS="✅"    # ✅
ICON_WARNING="⚠️"    # ⚠️
ICON_ERROR="❌"      # ❌
ICON_STEP="⏳"       # ⏳
ICON_DONE="🎉"      # 🎉

log_info() {
    local msg="$1"
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}${ICON_INFO} [INFO]${NC} $msg"
    fi
}

log_success() {
    local msg="$1"
    echo -e "${GREEN}${ICON_SUCCESS} [SUCCESS]${NC} $msg"
}

log_warning() {
    local msg="$1"
    echo -e "${YELLOW}${ICON_WARNING} [WARNING]${NC} $msg"
}

log_error() {
    local msg="$1"
    echo -e "${RED}${ICON_ERROR} [ERROR]${NC} $msg"
}

log_step() {
    local msg="$1"
    echo -e "${BLUE}${ICON_STEP} [STEP]${NC} $msg"
}

log_done() {
    local msg="$1"
    echo -e "${GREEN}${ICON_DONE} [DONE]${NC} $msg"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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


cleanup() {
    if [ $? -ne 0 ]; then
        log_error "Script failed. Check the logs above for details."
        log_info "Backup directory: $BACKUP_DIR"
        log_info "You can continue the setup manually or re-run specific functions"
    fi
}

trap cleanup EXIT

main() {
    log_step "Starting macOS Developer Environment Setup..."
    log_info "Backup directory: $BACKUP_DIR"
    
    mkdir -p "$BACKUP_DIR"
    
    local setup_errors=0
    
    log_step "Checking Xcode Command Line Tools..."
    install_xcode_cli || ((setup_errors++))
    log_step "Cloning and setting up dotfiles..."
    setup_dotfiles_repo || ((setup_errors++))
    log_step "Symlinking dotfiles..."
    symlink_dotfiles || ((setup_errors++))
    log_step "Installing code editor(s)..."
    install_code_editor || ((setup_errors++))
    log_step "Installing fonts..."
    install_fonts || ((setup_errors++))
    log_step "Setting up Homebrew and packages..."
    setup_homebrew || ((setup_errors++))
    log_step "Configuring Oh My Zsh and Powerlevel10k..."
    setup_oh_my_zsh || ((setup_errors++))
    log_step "Setting up SSH keys..."
    setup_ssh_keys || ((setup_errors++))
    log_step "Installing Python..."
    setup_python || ((setup_errors++))
    log_step "Installing Ruby..."
    setup_ruby || ((setup_errors++))
    log_step "Installing additional applications..."
    install_additional_apps || ((setup_errors++))
    log_step "Configuring Terminal profile..."
    setup_terminal_profile || ((setup_errors++))
    log_step "Applying macOS customizations..."
    setup_macos_customizations || ((setup_errors++))
    log_step "Finalizing setup..."
    final_steps || ((setup_errors++))
    
    if [ $setup_errors -eq 0 ]; then
        log_done "Setup completed successfully with no errors!"
    else
        log_warning "Setup completed with $setup_errors function(s) having issues. Check the logs above for details."
    fi
    
    log_info "Please restart your terminal or run 'source ~/.zshrc' to apply changes."
}


install_xcode_cli() {
    log_step "Checking for Xcode Command Line Tools..."
    if ! xcode-select -p &>/dev/null; then
        log_info "Xcode Command Line Tools not found. Installing..."
        xcode-select --install
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_done "Xcode Command Line Tools installed."
    else
        log_done "Xcode Command Line Tools already installed."
    fi
}

install_code_editor() {
    log_step "Choosing code editor..."
    
    local cursor_installed=false
    local vscode_installed=false
    
    if [ -d "/Applications/Cursor.app" ]; then
        cursor_installed=true
        log_done "✓ Cursor is already installed"
    fi
    
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        vscode_installed=true
        log_done "✓ VS Code is already installed"
    fi
    
    if [ "$cursor_installed" = true ] && [ "$vscode_installed" = true ]; then
        log_info "Both editors are installed. Setting up CLI tools..."
        setup_editor_cli_tools
        return 0
    fi
    
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
    log_step "Installing Cursor editor..."
    
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
    
    MOUNT_OUTPUT=$(hdiutil attach "$CURSOR_DMG")
    log_info "hdiutil attach output: $MOUNT_OUTPUT"
    
    MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$MOUNT_DIR" ]; then
        log_error "Failed to determine mount directory."
        return 1
    fi
    
    log_info "Mount directory: $MOUNT_DIR"
    
    APP_PATH=$(find "$MOUNT_DIR" -name "Cursor.app" -type d -print -quit)
    
    if [ -z "$APP_PATH" ]; then
        log_error "Failed to find Cursor.app in mounted DMG. Contents:"
        ls -la "$MOUNT_DIR"
        hdiutil detach "$MOUNT_DIR"
        return 1
    fi
    
    log_info "Found Cursor.app at: $APP_PATH"
    log_info "Copying to /Applications/"
    
    cp -R "$APP_PATH" /Applications/
    
    if [ $? -eq 0 ]; then
        log_done "Cursor editor installed to /Applications."
    else
        log_error "Failed to copy Cursor.app to /Applications."
    fi
    
    hdiutil detach "$MOUNT_DIR"
    
    rm -f "$CURSOR_DMG"
}

install_vscode() {
    log_step "Installing VS Code..."
    
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
            log_done "VS Code installed to /Applications."
        else
            log_error "Failed to copy VS Code to /Applications."
        fi
        
        rm -rf "/tmp/Visual Studio Code.app"
    else
        log_error "Failed to extract VS Code properly."
    fi
    
    rm -f "$VSCODE_ZIP"
}

setup_editor_cli_tools() {
    log_step "Setting up CLI tools..."
    
    if [ -d "/Applications/Cursor.app" ]; then
        if [ -e "/Applications/Cursor.app/Contents/Resources/bin/cursor" ] && [ ! -L "/usr/local/bin/cursor" ]; then
            log_info "Linking Cursor CLI to /usr/local/bin/cursor..."
            sudo ln -sf "/Applications/Cursor.app/Contents/Resources/bin/cursor" /usr/local/bin/cursor
            log_done "'cursor' CLI linked to /usr/local/bin/cursor."
        fi
    fi
    
    if [ -d "/Applications/Visual Studio Code.app" ]; then
        log_info "Setting up VS Code CLI..."        

        if command -v code >/dev/null 2>&1; then
            log_done "VS Code CLI already installed and working"
        else
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
    log_step "Installing additional applications..."
    
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
    log_step "Installing Xcode from App Store..."

    if [ -d "/Applications/Xcode.app" ]; then
        log_done "Xcode is already installed"
        return 0
    fi
    
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
    
    mas install 497799835
    
    if [ $? -eq 0 ]; then
        log_done "Xcode installed successfully"
        
        log_info "Accepting Xcode license..."
        sudo xcodebuild -license accept
        
        log_info "Installing additional Xcode components..."
        sudo xcodebuild -runFirstLaunch
        
        log_done "Xcode setup completed"
    else
        log_error "Failed to install Xcode from App Store"
    fi
}

install_brave_browser() {
    log_step "Installing Brave Browser..."
    
    if [ -d "/Applications/Brave Browser.app" ]; then
        log_done "Brave Browser is already installed"
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
    
    log_info "Mounting Brave Browser DMG..."
    local mount_output=$(hdiutil attach "$brave_dmg")
    local mount_dir=$(echo "$mount_output" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$mount_dir" ]; then
        log_error "Failed to mount Brave Browser DMG"
        return 1
    fi
    
    local app_path=$(find "$mount_dir" -name "Brave Browser.app" -type d -print -quit)
    
    if [ -z "$app_path" ]; then
        log_error "Failed to find Brave Browser.app in mounted DMG"
        hdiutil detach "$mount_dir"
        return 1
    fi
    
    log_info "Installing Brave Browser to /Applications/"
    cp -R "$app_path" /Applications/
    
    if [ $? -eq 0 ]; then
        log_done "Brave Browser installed successfully"
    else
        log_error "Failed to install Brave Browser"
    fi
    
    hdiutil detach "$mount_dir"
    rm -f "$brave_dmg"
}

install_android_studio() {
    log_step "Installing Android Studio..."
    
    if [ -d "/Applications/Android Studio.app" ]; then
        log_done "Android Studio is already installed"
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
    
    log_info "Mounting Android Studio DMG..."
    local mount_output=$(hdiutil attach "$android_dmg")
    local mount_dir=$(echo "$mount_output" | grep '/Volumes/' | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/[[:space:]]*$//')
    
    if [ -z "$mount_dir" ]; then
        log_error "Failed to mount Android Studio DMG"
        return 1
    fi
    
    local app_path=$(find "$mount_dir" -name "Android Studio.app" -type d -print -quit)
    
    if [ -z "$app_path" ]; then
        log_error "Failed to find Android Studio.app in mounted DMG"
        hdiutil detach "$mount_dir"
        return 1
    fi
    
    log_info "Installing Android Studio to /Applications/ (this may take a moment)..."
    cp -R "$app_path" /Applications/
    
    if [ $? -eq 0 ]; then
        log_done "Android Studio installed successfully"
        log_info "Note: You'll need to complete Android Studio setup on first launch"
    else
        log_error "Failed to install Android Studio"
    fi
    
    hdiutil detach "$mount_dir"
    rm -f "$android_dmg"
}

setup_dotfiles_repo() {
    log_step "Setting up dotfiles repository..."

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
        log_done "Dotfiles repository setup completed"
    else
        log_error "Failed to setup dotfiles repository"
        exit 1
    fi
}

setup_homebrew() {
    log_step "Setting up Homebrew..."

    if command_exists brew; then
        log_done "Homebrew is already installed. Skipping installation."
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
        log_done "Homebrew updated"
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [[ $(uname -m) == "arm64" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        log_done "Homebrew installed successfully"
    fi

    if [ -f "$DOTFILES_DIR/Brewfile" ]; then
        log_info "Installing packages from Brewfile..."
        cd "$DOTFILES_DIR"
        brew bundle install || log_warning "Some packages might have failed to install"
        log_done "Homebrew packages installed from Brewfile"
    else
        log_warning "Brewfile not found in dotfiles repo, installing essential packages manually..."

        local essential_packages=(
            "git" "wget" "curl" "pyenv" "rbenv" "fzf" "gh" "htop" "neovim" "tmux"
            "tree" "jq" "node" "yarn" "postgresql@15"
        )

        for package in "${essential_packages[@]}"; do
            if ! brew list "$package" >/dev/null 2>&1; then
                log_info "Installing $package..."
                brew install "$package" || log_warning "Failed to install $package"
            else
                log_done "$package already installed"
            fi
        done
    fi
}

setup_ssh_keys() {
    log_step "Setting up SSH keys..."

    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    if [ -f "$DOTFILES_DIR/id_ed25519" ] && [ -f "$DOTFILES_DIR/id_ed25519.pub" ]; then
        log_info "Copying SSH keys from dotfiles..."

        if [ -f ~/.ssh/id_ed25519 ]; then
            log_warning "Backing up existing SSH private key..."
            cp ~/.ssh/id_ed25519 "$BACKUP_DIR/id_ed25519.backup"
        fi

        if [ -f ~/.ssh/id_ed25519.pub ]; then
            log_warning "Backing up existing SSH public key..."
            cp ~/.ssh/id_ed25519.pub "$BACKUP_DIR/id_ed25519.pub.backup"
        fi

        cp "$DOTFILES_DIR/id_ed25519" ~/.ssh/id_ed25519
        cp "$DOTFILES_DIR/id_ed25519.pub" ~/.ssh/id_ed25519.pub

        chmod 600 ~/.ssh/id_ed25519
        chmod 644 ~/.ssh/id_ed25519.pub

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

        log_info "Adding SSH key to agent..."
        eval "$(ssh-agent -s)"
        ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || ssh-add ~/.ssh/id_ed25519

        log_done "SSH keys configured successfully"
    else
        log_warning "SSH keys not found in dotfiles repo"
        log_info "You can generate new SSH keys with: ssh-keygen -t ed25519 -C \"your_email@example.com\""
    fi

    if [ -d "$DOTFILES_DIR/.git" ]; then
        log_info "Switching dotfiles repo remote to SSH..."
        cd "$DOTFILES_DIR"
        git remote set-url origin git@github.com:Shrishesha4/dotfiles.git
        log_done "Dotfiles repo remote set to SSH"
    fi
}

setup_python() {
    log_step "Setting up Python with pyenv..."

    if ! command_exists pyenv; then
        log_error "pyenv not found. Make sure Homebrew installation completed successfully."
        return 1
    fi

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

    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"

    local python_versions=("3.13.5" "3.9.23")

    for version in "${python_versions[@]}"; do
        if ! pyenv versions | grep -q "$version"; then
            log_info "Installing Python $version..."
            pyenv install "$version" || log_warning "Failed to install Python $version"
        else
            log_done "Python $version already installed"
        fi
    done

    log_info "Setting Python 3.13.5 as global default..."
    pyenv global 3.13.5 || log_warning "Failed to set global Python version"

    log_done "Python setup completed"
}

setup_ruby() {
    log_step "Setting up Ruby with rbenv..."

    if ! command_exists rbenv; then
        log_error "rbenv not found. Make sure Homebrew installation completed successfully."
        return 1
    fi

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

    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"

    local ruby_version="3.2.7"

    if ! rbenv versions | grep -q "$ruby_version"; then
        log_info "Installing Ruby $ruby_version..."
        rbenv install "$ruby_version" || log_warning "Failed to install Ruby $ruby_version"
    else
        log_done "Ruby $ruby_version already installed"
    fi

    log_info "Setting Ruby $ruby_version as global default..."
    rbenv global "$ruby_version" || log_warning "Failed to set global Ruby version"

    log_done "Ruby setup completed"
}

install_fonts() {
    log_step "Installing MesloLGS NF fonts..."

    mkdir -p ~/Library/Fonts

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
                log_done "$font_name installed"
            fi
        else
            log_done "$font_name already exists, skipping..."
        fi
    done

    log_done "MesloLGS NF fonts installation completed"
}

setup_oh_my_zsh() {
    log_step "Setting up Oh My Zsh and Powerlevel10k..."

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_info "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
        log_done "Oh My Zsh installed"
    else
        log_done "Oh My Zsh already installed"
    fi

    local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        log_info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        log_done "Powerlevel10k installed"
    else
        log_done "Powerlevel10k already installed"
    fi

    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"

    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        log_done "zsh-autosuggestions installed"
    else
        log_done "zsh-autosuggestions already installed"
    fi

    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        log_done "zsh-syntax-highlighting installed"
    else
        log_done "zsh-syntax-highlighting already installed"
    fi

    log_done "Oh My Zsh and Powerlevel10k setup completed"
}

symlink_dotfiles() {
    log_step "Creating symlinks for dotfiles..."
    
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
            if [ "$dotfile" = ".zshrc" ] && [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
                log_warning "Backing up existing $dotfile (likely Oh My Zsh default) to $BACKUP_DIR"
                cp "$target_file" "$BACKUP_DIR/$dotfile.backup"
            elif [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
                log_warning "Backing up existing $dotfile to $BACKUP_DIR"
                cp "$target_file" "$BACKUP_DIR/$dotfile.backup"
            fi
            
            [ -e "$target_file" ] && rm "$target_file"
            
            ln -s "$source_file" "$target_file"
            log_done "Symlinked $dotfile"
        else
            log_warning "$dotfile not found in dotfiles repo"
        fi
    done
    
    log_done "Dotfiles symlinked successfully"
}

setup_macos_customizations() {
    log_step "Applying macOS customizations..."
    
    log_info "Configuring Dock..."
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock autohide-delay -int 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    killall Dock
    
    log_done "Dock configured"
    
    log_info "Setting up screenshot folder..."
    mkdir -p ~/Documents/Screenshots
    defaults write com.apple.screencapture location ~/Documents/Screenshots
    killall SystemUIServer
    log_done "Screenshot folder configured"
    
    log_done "macOS customizations applied"
}

setup_terminal_profile() {
    log_step "Setting up terminal profile..."

    local profile_file="$DOTFILES_DIR/terminal/CustomProfile.terminal"

    if [ -f "$profile_file" ]; then
        log_info "Importing Terminal profile..."
        open "$profile_file"
        sleep 2

        log_info "Setting Terminal profile as default..."
        osascript <<EOF
tell application "Terminal"
    set default settings to settings set "CustomProfile"
end tell
EOF
        log_done "Terminal profile configured"
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
    log_step "Performing final setup steps..."

    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Changing default shell to zsh..."
        chsh -s "$(which zsh)"
        log_done "Default shell changed to zsh"
    else
        log_done "Default shell is already zsh"
    fi

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

    log_done "Final setup steps completed"
}

main "$@"
