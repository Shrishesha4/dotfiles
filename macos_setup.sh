#!/bin/bash

set -e

SUDO_PASSWORD=""

initialize_sudo() {
    echo "This script requires administrator privileges."
    echo "Please enter your password. You will NOT be asked again during this session."
    echo -n "Password: "
    read -s SUDO_PASSWORD
    echo
    
    if ! echo "$SUDO_PASSWORD" | sudo -S -v 2>/dev/null; then
        echo "❌ Invalid password"
        exit 1
    fi
    echo "✅ Password verified. Running setup..."
}

run_sudo() {
    echo "$SUDO_PASSWORD" | sudo -S "$@" 2>/dev/null
    return $?
}

cleanup_password() {
    SUDO_PASSWORD=""
    unset SUDO_PASSWORD
}

trap cleanup_password EXIT

initialize_sudo

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_REPO=""
DOTFILES_DIR="$HOME/dotfiles"
USE_DEFAULT_SETUP=false
INSTALL_RUBY=false

BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
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

ICON_INFO="📄"
ICON_SUCCESS="✅"
ICON_WARNING="⚠️"
ICON_ERROR="❌"
ICON_STEP="⏳"
ICON_DONE="🎉"

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

get_user_setup_choices() {
    echo
    log_step "🚀 Welcome to macOS Developer Environment Setup!"
    echo
    log_info "This script can help you set up a complete development environment."
    echo "Let's customize your setup based on your needs."
    echo
    
    log_step "📁 Dotfiles Configuration"
    echo "Choose your dotfiles setup:"
    echo
    echo "1. 📦 Use the default setup (includes common dev tools, apps, and configurations)"
    echo "   - Includes: Homebrew packages, VS Code, Git config, Terminal setup, etc."
    echo "   - Repository: https://github.com/Shrishesha4/dotfiles.git"
    echo "   - Good for: Quick start with sensible defaults"
    echo
    echo "2. 🔧 Use your own dotfiles repository"
    echo "   - Provide your own GitHub repository URL"
    echo "   - The script will clone and use your configurations"
    echo "   - Good for: Custom setups and existing dotfiles"
    echo
    echo "3. ⚙️  Minimal setup (no dotfiles repository)"
    echo "   - Only installs basic tools (Homebrew, Python, etc.)"
    echo "   - No custom configurations or dotfiles"
    echo "   - Good for: Clean start or manual configuration"
    echo

    while true; do
        read -p "Choose your dotfiles option (1/2/3): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                log_success "✅ Using default setup with pre-configured dotfiles"
                DOTFILES_REPO="https://github.com/Shrishesha4/dotfiles.git"
                USE_DEFAULT_SETUP=true
                break
                ;;
            2)
                log_success "✅ Using custom dotfiles repository"
                echo
                while true; do
                    read -p "Enter your dotfiles repository URL (HTTPS or SSH): " user_repo
                    if [ -z "$user_repo" ]; then
                        log_error "❌ Repository URL cannot be empty"
                        continue
                    fi
                    
                    if [[ "$user_repo" =~ ^https://github\.com/[^/]+/[^/]+\.git$ ]] || [[ "$user_repo" =~ ^git@github\.com:[^/]+/[^/]+\.git$ ]]; then
                        DOTFILES_REPO="$user_repo"
                        USE_DEFAULT_SETUP=false
                        log_success "✅ Repository set: $user_repo"
                        break
                    else
                        log_error "❌ Invalid GitHub repository URL format"
                        log_info "Expected format: https://github.com/username/repo.git or git@github.com:username/repo.git"
                        continue
                    fi
                done
                break
                ;;
            3)
                log_success "✅ Minimal setup selected - no dotfiles repository"
                DOTFILES_REPO=""
                USE_DEFAULT_SETUP=false
                break
                ;;
            *)
                echo "Please choose 1, 2, or 3."
                ;;
        esac
    done
    
    # Ask about Ruby/rbenv
    echo
    log_step "💎 Ruby Development Setup"
    log_info "Ruby is useful for Jekyll sites, Rails development, and various automation tools."
    echo
    while true; do
        read -p "Do you want to install Ruby and rbenv? (y/n): " -n 1 -r
        echo
        case $REPLY in
            [Yy]*)
                log_success "✅ Ruby and rbenv will be installed"
                INSTALL_RUBY=true
                break
                ;;
            [Nn]*)
                log_success "✅ Skipping Ruby installation"
                INSTALL_RUBY=false
                log_info "💡 You can install Ruby later with: brew install rbenv"
                break
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    
    echo
    log_info "🎯 Setup Summary:"
    if [ -n "$DOTFILES_REPO" ]; then
        log_info "📁 Dotfiles repository: $DOTFILES_REPO"
    else
        log_info "📁 Minimal setup: No dotfiles repository"
    fi
    
    if [ "$INSTALL_RUBY" = true ]; then
        log_info "💎 Ruby: Will be installed with rbenv"
    else
        log_info "💎 Ruby: Skipped"
    fi
    
    log_info "🐍 Python: Will be installed with pyenv (always included)"
    log_info "💾 Backup directory: $BACKUP_DIR"
    echo
    
    read -p "Continue with this setup? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user"
        exit 0
    fi
}

install_xcode_cli() {
    log_step "Checking for Xcode Command Line Tools..."
    
    if ! xcode-select -p &>/dev/null; then
        log_info "Xcode Command Line Tools not found. Installing..."
        softwareupdate --install-rosetta --agree-to-license
        xcode-select --install
        
        until xcode-select -p &>/dev/null; do
            sleep 5
        done
        log_done "Xcode Command Line Tools installed."
    else
        log_done "Xcode Command Line Tools already installed."
    fi
}

setup_dotfiles_repo() {
    if [ -z "$DOTFILES_REPO" ]; then
        log_step "Skipping dotfiles repository setup (minimal setup chosen)"
        return 0
    fi
    
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
    
    if [ -n "$DOTFILES_REPO" ] && [ -f "$DOTFILES_DIR/Brewfile" ]; then
        log_info "Installing packages from Brewfile..."
        cd "$DOTFILES_DIR"
        brew bundle install || log_warning "Some packages might have failed to install"
        log_done "Homebrew packages installed from Brewfile"
    else
        log_info "No Brewfile found or minimal setup chosen. Installing essential packages..."
        
        # Essential packages for development (always include pyenv, conditionally include rbenv)
        local essential_packages=(
            "git"
            "curl"
            "wget"
            "pyenv"
            "node"
            "yarn"
            "zsh"
            "vim"
            "tree"
            "htop"
            "jq"
        )
        
        if [ "$INSTALL_RUBY" = true ]; then
            essential_packages+=("rbenv")
        fi
        
        for package in "${essential_packages[@]}"; do
            if ! brew list "$package" &>/dev/null; then
                log_info "Installing $package..."
                brew install "$package" || log_warning "Failed to install $package"
            else
                log_info "$package already installed"
            fi
        done
        
        log_done "Essential packages installed"
    fi
    
    log_step "Accepting Xcode license..."
    if run_sudo xcodebuild -license check &>/dev/null; then
        log_done "Xcode license already accepted"
    else
        log_info "Xcode license not accepted. Accepting now..."
        run_sudo xcodebuild -license accept || log_warning "Failed to accept Xcode license"
    fi
    
    log_info "Running brew cleanup..."
    brew cleanup --prune=all || log_warning "Failed to clean up Homebrew"
    log_done "Homebrew setup completed"
    
    log_info "Checking for Homebrew services..."
    if command_exists "brew services"; then
        log_step "Starting essential services..."
        brew services start postgresql@15 || log_warning "Failed to start PostgreSQL service"
        log_done "Essential services started"
    else
        log_warning "brew services not found, skipping service management"
    fi
}

setup_ssh_config_and_agent() {
    log_info "Setting up SSH configuration and agent..."
    
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
    
    log_done "SSH configuration and agent setup completed"
}

test_github_connection() {
    log_info "🧪 Testing SSH connection to GitHub..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        local github_user=$(ssh -T git@github.com 2>&1 | grep -o "Hi [^!]*" | cut -d' ' -f2)
        log_success "✅ SSH connection to GitHub successful for user: $github_user!"
        return 0
    else
        log_warning "⚠️ SSH connection test failed"
        log_info "This is normal if you haven't added the public key to GitHub yet"
        return 1
    fi
}

provide_github_instructions() {
    echo
    log_info "🚀 NEXT STEPS - Add your SSH key to GitHub:"
    echo
    echo "1. 📋 Copy the public key displayed above (or it's already in your clipboard)"
    echo "2. 🌐 Open GitHub SSH settings: https://github.com/settings/keys"
    echo "3. 🆕 Click the green 'New SSH key' button"
    echo "4. 📝 Fill in the form:"
    echo "   • Title: Give it a descriptive name (e.g., '$(hostname) - $(date +%Y-%m-%d)')"
    echo "   • Key type: Authentication Key (default)"
    echo "   • Key: Paste your public key here"
    echo "5. ✅ Click 'Add SSH key'"
    echo "6. 🔐 Enter your GitHub password if prompted"
    echo
    
    read -p "Press Enter when you've added the SSH key to GitHub and want to test the connection..." -r
    
    test_github_connection
}

create_new_ssh_keys() {
    echo
    log_info "📧 Please enter your email address for the SSH key:"
    log_info " (This should be the email associated with your GitHub account)"
    while true; do
        read -p "Email: " user_email
        if [ -z "$user_email" ]; then
            log_error "❌ Email is required for SSH key generation"
            echo "Please enter a valid email address."
            continue
        fi
        if [[ "$user_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            log_success "✅ Email accepted: $user_email"
            break
        else
            log_error "❌ Invalid email format. Please enter a valid email address."
            continue
        fi
    done
    
    log_info "🔐 Generating new ED25519 SSH key pair for: $user_email"
    
    if ssh-keygen -t ed25519 -C "$user_email" -f ~/.ssh/id_ed25519 -N ""; then
        log_success "✅ SSH key pair generated successfully!"
        chmod 600 ~/.ssh/id_ed25519
        chmod 644 ~/.ssh/id_ed25519.pub
        
        setup_ssh_config_and_agent
        
        echo
        log_info "🔑 Your new SSH public key (copy this):"
        log_info "Generated for: $user_email"
        echo "----------------------------------------"
        cat ~/.ssh/id_ed25519.pub
        echo "----------------------------------------"
        
        if command -v pbcopy >/dev/null 2>&1; then
            pbcopy < ~/.ssh/id_ed25519.pub
            log_success "✅ Public key copied to clipboard!"
        fi
        
        provide_github_instructions
        
        log_done "New SSH keys created and configured successfully for $user_email"
    else
        log_error "❌ Failed to generate SSH keys"
        return 1
    fi
}

setup_existing_ssh_keys() {
    log_info "Setting up your existing SSH keys..."
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    echo
    log_info "📝 Please paste your SSH PRIVATE key content:"
    log_info "   (This is the content of your id_ed25519 file - the one WITHOUT .pub extension)"
    log_warning "⚠️  Make sure you're in a secure environment before pasting private key content"
    echo
    echo "Paste your private key and press Ctrl+D when done:"
    
    private_key_content=""
    while IFS= read -r line; do
        private_key_content+="$line"$'\n'
    done
    
    if [ -z "$private_key_content" ]; then
        log_error "❌ No private key content provided"
        return 1
    fi
    
    echo "$private_key_content" > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    
    echo
    log_info "📝 Now please paste your SSH PUBLIC key content:"
    log_info "   (This is the content of your id_ed25519.pub file)"
    echo
    echo "Paste your public key and press Enter:"
    read -r public_key_content
    
    if [ -z "$public_key_content" ]; then
        log_error "❌ No public key content provided"
        return 1
    fi
    
    echo "$public_key_content" > ~/.ssh/id_ed25519.pub
    chmod 644 ~/.ssh/id_ed25519.pub
    
    if ssh-keygen -y -f ~/.ssh/id_ed25519 > /tmp/derived_public_key 2>/dev/null; then
        if cmp -s ~/.ssh/id_ed25519.pub /tmp/derived_public_key; then
            log_success "✅ SSH key pair validated successfully!"
        else
            log_warning "⚠️ Public and private keys don't match, but proceeding anyway"
        fi
        rm -f /tmp/derived_public_key
    else
        log_warning "⚠️ Could not validate private key, but proceeding anyway"
    fi
    
    setup_ssh_config_and_agent
    
    echo
    log_info "🔑 Your SSH public key:"
    echo "----------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    
    test_github_connection || {
        log_info "If the connection failed, you may need to add this public key to GitHub"
        provide_github_instructions
    }
    
    log_done "Existing SSH keys configured successfully"
}

setup_ssh_keys() {
    log_step "Setting up SSH keys..."
    
    echo
    log_info "🔑 SSH Key Setup"
    echo "SSH keys allow secure, password-free authentication with Git repositories (GitHub, GitLab, etc.)"
    echo
    echo "Options:"
    echo "1. Set up SSH keys now (recommended for Git workflow)"
    echo "2. Skip SSH setup (you can set up manually later)"
    echo
    
    while true; do
        read -p "Do you want to set up SSH keys? (y/n): " -n 1 -r
        echo
        case $REPLY in
            [Yy]*)
                log_info "✅ Proceeding with SSH key setup..."
                break
                ;;
            [Nn]*)
                log_warning "⏭️ Skipping SSH key setup"
                log_info "💡 You can set up SSH keys later with:"
                log_info "   ssh-keygen -t ed25519 -C \"your_email@example.com\""
                log_info "   ssh-add --apple-use-keychain ~/.ssh/id_ed25519"
                log_info "   Then add the public key to GitHub: https://github.com/settings/keys"
                return 0
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    if [ -f ~/.ssh/id_ed25519 ] && [ -f ~/.ssh/id_ed25519.pub ]; then
        log_info "✅ SSH keys already exist locally at ~/.ssh/id_ed25519"
        echo
        while true; do
            read -p "Use existing SSH keys? (y/n): " -n 1 -r
            echo
            case $REPLY in
                [Yy]*)
                    log_info "Using existing SSH keys..."
                    setup_ssh_config_and_agent
                    
                    echo
                    log_info "🔑 Your existing SSH public key:"
                    echo "----------------------------------------"
                    cat ~/.ssh/id_ed25519.pub
                    echo "----------------------------------------"
                    
                    test_github_connection || provide_github_instructions
                    break
                    ;;
                [Nn]*)
                    log_info "Creating new SSH keys..."
                    cp ~/.ssh/id_ed25519 "$BACKUP_DIR/id_ed25519.existing.backup"
                    cp ~/.ssh/id_ed25519.pub "$BACKUP_DIR/id_ed25519.pub.existing.backup"
                    create_new_ssh_keys
                    break
                    ;;
                *)
                    echo "Please answer y (yes) or n (no)."
                    ;;
            esac
        done
    else
        echo
        while true; do
            read -p "Do you have existing SSH keys to paste? (y/n): " -n 1 -r
            echo
            case $REPLY in
                [Yy]*)
                    setup_existing_ssh_keys
                    break
                    ;;
                [Nn]*)
                    log_info "Creating new SSH keys..."
                    create_new_ssh_keys
                    break
                    ;;
                *)
                    echo "Please answer y (yes) or n (no)."
                    ;;
            esac
        done
    fi
    
    if [ -n "$DOTFILES_REPO" ] && [ "$USE_DEFAULT_SETUP" = false ] && [ -d "$DOTFILES_DIR/.git" ]; then
        echo
        read -p "🔄 Switch dotfiles repository to use SSH? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Switching dotfiles repo remote to SSH..."
            cd "$DOTFILES_DIR"
            if [[ "$DOTFILES_REPO" =~ https://github\.com/([^/]+)/([^/]+)\.git ]]; then
                local ssh_url="git@github.com:${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git"
                git remote set-url origin "$ssh_url"
                log_done "Dotfiles repo remote set to SSH: $ssh_url"
            else
                log_warning "Could not convert HTTPS URL to SSH format"
            fi
        else
            log_info "Keeping dotfiles repo on HTTPS"
        fi
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
    if [ "$INSTALL_RUBY" = false ]; then
        log_step "Skipping Ruby setup (user chose not to install)"
        return 0
    fi
    
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
    
    # Install Ruby version (change as needed)
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
    if [ -z "$DOTFILES_REPO" ]; then
        log_step "Skipping dotfiles symlinking (minimal setup chosen)"
        return 0
    fi
    
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
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock autohide-delay -int 0
    defaults write com.apple.dock autohide-time-modifier -float 0.4
    defaults write com.apple.dock tilesize -int 64
    defaults write com.apple.dock magnification -bool true
    defaults write com.apple.dock magnification -int 44
    defaults write com.apple.dock showAppExposeGestureEnabled -bool true
    defaults -currentHost write NSGlobalDomain com.apple.trackpad.threeFingerVertSwipeGesture -int 2
    killall Dock
    
    if [ "$USE_DEFAULT_SETUP" = true ] && command_exists dockutil; then
        log_info "Configuring Dock with default applications..."
        dockutil --remove all
        dockutil --add /Applications/Spark\ Desktop.app
        dockutil --add /Applications/Brave\ Browser.app
        dockutil --add /System/Applications/Reminders.app
        dockutil --add /Applications/Notion.app
        dockutil --add /Applications/Visual\ Studio\ Code.app
        dockutil --add /System/Applications/Utilities/Terminal.app
        dockutil --add ~/Downloads --view grid --display stack
        log_done "Default Dock applications configured"
    elif command_exists dockutil; then
        log_info "dockutil available but using custom setup - skipping specific app configuration"
        log_info "You can customize your Dock manually with dockutil commands"
    else
        log_warning "dockutil not found, skipping Dock app configuration"
        log_info "You can install dockutil via Homebrew: brew install dockutil"
    fi
    
    log_done "Dock configured"
    
    log_info "Applying System Settings..."
    
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
    run_sudo defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    run_sudo defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    
    log_done "System Settings applied"
    
    log_info "Setting up screenshot folder..."
    mkdir -p ~/Pictures/Screenshots
    defaults write com.apple.screencapture location ~/Pictures/Screenshots
    killall SystemUIServer
    log_done "Screenshot folder configured"
    
    log_done "macOS customizations applied"
}

setup_terminal_profile() {
    if [ -z "$DOTFILES_REPO" ]; then
        log_step "Skipping terminal profile setup (minimal setup chosen)"
        return 0
    fi
    
    log_step "Setting up terminal profile..."
    
    touch ~/.hushlogin
    
    local profile_file="$DOTFILES_DIR/terminal/CustomProfile.terminal"
    if [ -f "$profile_file" ]; then
        log_info "Importing Terminal profile..."
        sleep 2
        
        log_info "Setting Terminal profile as default..."
        osascript << EOF
tell application "Terminal"
    local theProfile
    set theProfile to (load settings from POSIX file "$profile_file")
    set name of theProfile to "CustomProfile"
    set default settings to theProfile
    set startup settings to theProfile
end tell
EOF
        log_done "Terminal profile configured"
    else
        log_warning "Terminal profile not found at $profile_file"
        log_info "You can manually configure your terminal settings"
    fi
    
    log_done "Terminal profile setup completed"
}

final_steps() {
    log_step "Setup completed! 🎉"
    
    echo
    log_info "================================"
    log_info "🎯 SETUP SUMMARY"
    log_info "================================"
    log_success "✅ Xcode Command Line Tools installed"
    log_success "✅ Homebrew and essential packages installed"
    
    if [ -n "$DOTFILES_REPO" ]; then
        log_success "✅ Dotfiles repository cloned and configured"
        log_success "✅ Configuration files symlinked"
    else
        log_success "✅ Minimal setup completed - no dotfiles configured"
    fi
    
    log_success "✅ Oh My Zsh and Powerlevel10k installed"
    log_success "✅ Python environment configured with pyenv"
    
    if [ "$INSTALL_RUBY" = true ]; then
        log_success "✅ Ruby environment configured with rbenv"
    else
        log_info "ℹ️  Ruby setup was skipped"
    fi
    
    log_success "✅ SSH keys configured"
    log_success "✅ macOS customizations applied"
    
    echo
    log_info "🔧 NEXT STEPS:"
    log_warning "1. Configure terminal font for Powerlevel10k:"
    log_warning "   - Terminal: Preferences > Profiles > Text > Font"
    log_warning "   - iTerm2: Preferences > Profiles > Text > Font"
    log_warning "   - Choose 'MesloLGS NF' and set size to 12pt or preferred"
    
    if [ -f ~/.ssh/id_ed25519.pub ]; then
        log_warning "2. If this is a new machine, add your SSH public key to GitHub:"
        log_warning "   - Copy: pbcopy < ~/.ssh/id_ed25519.pub"
        log_warning "   - Add to: https://github.com/settings/keys"
        log_warning "3. Test SSH connection: ssh -T git@github.com"
    fi
    
    log_warning "4. Run 'p10k configure' to customize your Powerlevel10k theme"
    log_info "================================"
    
    log_done "Final setup steps completed"
    
    log_step "A restart is recommended to ensure all changes take effect properly."
    read -p "Would you like to restart now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_sudo shutdown -r now
    else
        log_warning "Please restart your Mac manually when convenient."
        log_warning "Run 'sudo shutdown -r now' to restart via terminal"
    fi
}

main() {
    log_step "Starting macOS Developer Environment Setup..."
    
    get_user_setup_choices
    
    log_info "Backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    local setup_errors=0
    
    log_step "Checking Xcode Command Line Tools..."
    install_xcode_cli || ((setup_errors++))
    
    log_step "Cloning and setting up dotfiles..."
    setup_dotfiles_repo || ((setup_errors++))
    
    log_step "Symlinking dotfiles..."
    symlink_dotfiles || ((setup_errors++))
    
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

main "$@"
