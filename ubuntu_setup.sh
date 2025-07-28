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
SETUP_ERRORS=0

# Enhanced logging functions with progress
show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local pc=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    echo -e "${BLUE}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} ${GREEN}${pc}%${NC} – $1"
}

# Using printf (recommended for Unicode)
show_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
show_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
show_error() { echo -e "${RED}✗${NC} $1"; }

# Spinner wrapper that honours --verbose
execute_silently() {
    local job="$1"; shift
    if $VERBOSE; then
        echo -e "${BLUE}▶${NC} $job"
        if "$@"; then
            show_success "$job"
            return 0
        else
            show_error "$job failed"
            ((SETUP_ERRORS++))
            return 1
        fi
    fi

    "$@" > /tmp/setup_output.log 2>&1 & local pid=$!
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r${BLUE}${spin:i++%${#spin}:1}${NC} $job"; sleep 0.1
    done; wait $pid; local rc=$?
    printf "\r"

    if [[ $rc -eq 0 ]]; then
        show_success "$job"
    else
        show_error "$job failed"
        ((SETUP_ERRORS++))
        if [ -s /tmp/setup_output.log ]; then
            echo -e "${YELLOW}Error details:${NC}"
            tail -5 /tmp/setup_output.log
        fi
    fi
    return $rc
}

# Classic log functions (kept for backward compat)
log_info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_success() { echo -e "${GREEN}[ OK ]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_warning() { echo -e "${YELLOW}[WARN ]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }
log_error() { echo -e "${RED}[FAIL ]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Enhanced internet connectivity check with multiple methods
check_internet() {
    local hosts=("google.com" "8.8.8.8" "1.1.1.1" "wikipedia.org")
    
    # Method 1: Try wget (most reliable)
    if command_exists wget; then
        for host in "${hosts[@]}"; do
            if wget -q --spider --timeout=10 "http://$host" 2>/dev/null; then
                log_info "Internet connectivity verified using wget"
                return 0
            fi
        done
    fi
    
    # Method 2: Try curl as fallback
    if command_exists curl; then
        for host in "${hosts[@]}"; do
            if curl -Is --connect-timeout 10 --max-time 15 "http://$host" >/dev/null 2>&1; then
                log_info "Internet connectivity verified using curl"
                return 0
            fi
        done
    fi
    
    # Method 3: Try ping as last resort
    for host in "${hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log_info "Internet connectivity verified using ping"
            return 0
        fi
    done
    
    # Method 4: Check using netcat (if available)
    if command_exists nc; then
        if echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 >/dev/null 2>&1; then
            log_info "Internet connectivity verified using netcat"
            return 0
        fi
    fi
    
    log_error "No internet connection detected after trying multiple methods"
    log_info "Please check your network connection and try again"
    return 1
}

# Check if running as root (which we don't want)
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        log_info "Please run as a regular user. sudo will be used when needed."
        exit 1
    fi
}

# Check minimum system requirements
check_system_requirements() {
    # Check available disk space (need at least 5GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=5242880  # 5GB in KB

    if [[ $available_space -lt $required_space ]]; then
        log_warning "Low disk space detected. Available: $(($available_space/1024/1024))GB, Recommended: 5GB+"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Setup cancelled by user"
            exit 0
        fi
    fi

    # Check if we can create directories in home
    if ! mkdir -p "$HOME/.test_permissions" 2>/dev/null; then
        log_error "Cannot create directories in home folder"
        exit 1
    fi
    rmdir "$HOME/.test_permissions" 2>/dev/null

    # Check Ubuntu version compatibility
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            log_warning "This script is designed for Ubuntu. Detected: $ID $VERSION_ID"
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Setup cancelled by user"
                exit 0
            fi
        fi
    fi
}

# Detect system architecture
get_architecture() {
    local arch=$(uname -m)
    log_info "Detected system architecture: $arch"
    case $arch in
        x86_64)
            echo "x64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            log_error "Unknown architecture: $arch"
            echo "unknown"
            ;;
    esac
}

# Safe package installation with retry
safe_apt_install() {
    local packages=("$@")
    local max_retries=3
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if sudo apt install -y "${packages[@]}"; then
            return 0
        else
            ((retry_count++))
            log_warning "Package installation failed (attempt $retry_count/$max_retries)"
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Retrying in 10 seconds..."
                sleep 10
                sudo apt update
            fi
        fi
    done

    log_error "Failed to install packages after $max_retries attempts: ${packages[*]}"
    return 1
}

# Cleanup function for trap
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Setup interrupted or failed (exit code: $exit_code)"
        log_info "Backup directory: $BACKUP_DIR"
        log_info "You can check logs at: /tmp/setup_output.log"

        # Clean up any partial downloads
        rm -f /tmp/*.deb /tmp/*.tar.gz /tmp/*.dmg 2>/dev/null
        
        # Kill any background processes
        jobs -p | xargs -r kill 2>/dev/null
    else
        # Clean up temporary files on success
        rm -f /tmp/setup_output.log 2>/dev/null
    fi
}

# Set multiple traps for cleanup
trap cleanup EXIT
trap 'log_warning "Setup interrupted by user"; exit 130' INT
trap 'log_error "Setup terminated"; exit 143' TERM

# Main setup function
main() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║    Ubuntu Developer Setup Tool      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
    echo

    # Pre-flight checks
    check_not_root
    check_internet || exit 1
    check_system_requirements

    mkdir -p "$BACKUP_DIR"
    log_info "Backup directory: $BACKUP_DIR"

    # Execute setup steps with error handling
    show_progress "System packages";          execute_silently "System Update"        update_system || true
    show_progress "Clone dotfiles repo";      execute_silently "Dotfiles"            setup_dotfiles_repo || true
    show_progress "Symlink dotfiles";         execute_silently "Symlinking"          symlink_dotfiles || true
    show_progress "Code editor";              execute_silently "Editor install"      install_code_editor || true
    show_progress "Fonts";                    execute_silently "Meslo NF fonts"      install_fonts || true
    show_progress "Development tools";        execute_silently "Dev tools"           install_dev_tools || true
    show_progress "Oh-My-Zsh & theme";        execute_silently "Oh My Zsh"           setup_oh_my_zsh || true
    show_progress "SSH keys";                 execute_silently "SSH keys"            setup_ssh_keys || true
    show_progress "Python (pyenv)";           execute_silently "Python/pyenv"        setup_python || true
    show_progress "Ruby (rbenv)";             execute_silently "Ruby/rbenv"          setup_ruby || true
    show_progress "Node.js";                  execute_silently "Node.js"             setup_nodejs || true
    show_progress "Extra apps";               execute_silently "Extra apps"          install_additional_apps || true

    echo
    if [[ $SETUP_ERRORS -eq 0 ]]; then
        show_success "Setup completed successfully with no errors!"
    else
        show_warning "Setup completed with $SETUP_ERRORS error(s)"
        log_info "Check the messages above for details on what failed"
    fi

    echo
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            Next Steps                ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo -e "${GREEN}1.${NC} Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC}"
    echo -e "${GREEN}2.${NC} Configure your theme: ${YELLOW}p10k configure${NC}"
    echo -e "${GREEN}3.${NC} Set terminal font to: ${YELLOW}MesloLGS NF${NC}"

    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        echo -e "${GREEN}4.${NC} Add SSH key to GitHub:"
        echo -e "${YELLOW}$(cat ~/.ssh/id_ed25519.pub)${NC}"
    fi

    echo
    echo -e "${GREEN}Happy coding! 🚀${NC}"
}

update_system() {
    log_info "Updating system packages..."

    # Configure non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    # Update package list with retry
    local max_retries=3
    local retry_count=0

    while [[ $retry_count -lt $max_retries ]]; do
        if sudo apt update; then
            break
        else
            ((retry_count++))
            log_warning "apt update failed (attempt $retry_count/$max_retries)"
            if [[ $retry_count -lt $max_retries ]]; then
                sleep 5
            else
                log_error "Failed to update package lists after $max_retries attempts"
                return 1
            fi
        fi
    done

    # Install essential packages
    local essential_packages=(
        curl wget git build-essential software-properties-common
        apt-transport-https ca-certificates gnupg lsb-release
        zsh unzip tree htop neovim tmux jq fzf snapd
    )

    # Install PostgreSQL only if not already installed
    if ! command_exists psql; then
        essential_packages+=(postgresql postgresql-contrib)
    fi

    safe_apt_install "${essential_packages[@]}"

    log_success "System packages updated and essential tools installed"
}

setup_dotfiles_repo() {
    log_info "Setting up dotfiles repository..."

    # Validate git is available
    if ! command_exists git; then
        log_error "Git is not installed"
        return 1
    fi

    if [[ -d "$DOTFILES_DIR" ]]; then
        log_warning "Dotfiles directory already exists at $DOTFILES_DIR"
        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            log_info "Updating existing dotfiles repository..."
            cd "$DOTFILES_DIR" || return 1
            
            # Stash any local changes
            git stash push -m "Auto-stash before setup update" 2>/dev/null || true
            
            # Try to pull from both main and master branches
            if ! git pull origin main 2>/dev/null && ! git pull origin master 2>/dev/null; then
                log_warning "Could not update dotfiles repo - continuing with existing version"
            fi
        else
            log_warning "Directory exists but is not a git repository. Moving to backup..."
            if ! mv "$DOTFILES_DIR" "$BACKUP_DIR/dotfiles_existing"; then
                log_error "Failed to backup existing dotfiles directory"
                return 1
            fi
            log_info "Cloning dotfiles repository..."
            if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
                log_error "Failed to clone dotfiles repository"
                return 1
            fi
        fi
    else
        log_info "Cloning dotfiles repository..."
        if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
            log_error "Failed to clone dotfiles repository"
            return 1
        fi
    fi

    if [[ -d "$DOTFILES_DIR" ]]; then
        log_success "Dotfiles repository setup completed"
        return 0
    else
        log_error "Failed to setup dotfiles repository"
        return 1
    fi
}

install_code_editor() {
    log_info "Choosing code editor..."

    # Ensure jq is available
    if ! command_exists jq; then
        log_info "Installing jq for API parsing..."
        if ! safe_apt_install jq; then
            log_error "Failed to install jq - cannot proceed with Cursor installation"
        fi
    fi

    # Check if either editor is already installed
    local cursor_installed=false
    local vscode_installed=false

    if command_exists cursor || [[ -f "$HOME/.local/bin/cursor" ]]; then
        cursor_installed=true
        log_info "✓ Cursor is already installed"
    fi

    if command_exists code; then
        vscode_installed=true
        log_info "✓ VS Code is already installed"
    fi

    # If both are installed, return success
    if [[ "$cursor_installed" = true && "$vscode_installed" = true ]]; then
        log_info "Both editors are installed."
        return 0
    fi

    local arch=$(get_architecture)

    # Show architecture-aware options
    echo
    if [[ "$arch" = "arm64" ]]; then
        echo "Architecture: ARM64 detected"
        echo "Note: Cursor is not available for ARM64 Linux"
        echo
        echo "Choose your code editor:"
        echo "1) VS Code (supports ARM64)"
        echo "2) Skip editor installation"
        echo
        read -p "Enter your choice (1-2): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                install_vscode || log_warning "VS Code installation failed, continuing..."
                ;;
            2)
                log_info "Skipping editor installation"
                ;;
            *)
                log_info "Invalid choice. Installing VS Code as default..."
                install_vscode || log_warning "VS Code installation failed, continuing..."
                ;;
        esac
    else
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
    fi

    return 0  # Always return success to prevent script termination
}

install_cursor() {
    log_info "Installing Cursor editor..."

    local arch=$(get_architecture)

    # Cursor only supports x64 on Linux
    if [[ "$arch" != "x64" ]]; then
        log_warning "Cursor only supports x64 architecture on Linux. Current architecture: $arch"
        log_info "You can use VS Code instead, or use Cursor via web at cursor.com"
        return 1
    fi

    local cursor_url="https://cursor.com/api/download?platform=linux-x64&releaseTrack=stable"

    log_info "Downloading Cursor for x64 architecture..."

    # Get the actual download URL from the API with better error handling
    local api_response
    if ! api_response=$(curl -s --connect-timeout 30 --max-time 60 "$cursor_url"); then
        log_error "Failed to fetch Cursor API response - network error"
        return 1
    fi

    if [[ -z "$api_response" ]]; then
        log_error "Empty response from Cursor API"
        return 1
    fi

    local download_url
    if ! download_url=$(echo "$api_response" | jq -r '.downloadUrl // empty' 2>/dev/null); then
        log_error "Failed to parse JSON response from Cursor API"
        log_info "Raw API Response: $api_response"
        return 1
    fi

    if [[ -z "$download_url" || "$download_url" = "null" ]]; then
        log_error "No download URL found in Cursor API response"
        log_info "API Response: $api_response"
        return 1
    fi

    local cursor_appimage="$HOME/.local/bin/cursor.appimage"

    # Create local bin directory
    mkdir -p "$HOME/.local/bin" || {
        log_error "Failed to create $HOME/.local/bin directory"
        return 1
    }

    # Download Cursor AppImage with progress and timeout
    log_info "Downloading Cursor AppImage..."
    if ! curl -L --connect-timeout 30 --max-time 600 -o "$cursor_appimage" "$download_url"; then
        log_error "Failed to download Cursor editor"
        rm -f "$cursor_appimage"
        return 1
    fi

    # Verify download
    if [[ ! -f "$cursor_appimage" ]] || [[ ! -s "$cursor_appimage" ]]; then
        log_error "Downloaded Cursor file is missing or empty"
        rm -f "$cursor_appimage"
        return 1
    fi

    # Make it executable
    chmod +x "$cursor_appimage" || {
        log_error "Failed to make Cursor AppImage executable"
        return 1
    }

    # Create wrapper script
    cat > "$HOME/.local/bin/cursor" << 'EOF'
#!/bin/bash
exec "$HOME/.local/bin/cursor.appimage" "$@"
EOF

    if [[ $? -ne 0 ]]; then
        log_error "Failed to create Cursor wrapper script"
        return 1
    fi

    chmod +x "$HOME/.local/bin/cursor"

    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc 2>/dev/null || true
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
    fi

    log_success "Cursor editor installed successfully"
    return 0
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
    if ! curl -L --connect-timeout 30 --max-time 600 -o "$vscode_deb" "$vscode_url"; then
        log_error "Failed to download VS Code"
        rm -f "$vscode_deb"
        return 1
    fi

    # Verify download
    if [[ ! -f "$vscode_deb" ]] || [[ ! -s "$vscode_deb" ]]; then
        log_error "Downloaded VS Code file is missing or empty"
        rm -f "$vscode_deb"
        return 1
    fi

    # Install the .deb package
    if ! sudo dpkg -i "$vscode_deb"; then
        log_warning "dpkg installation failed, trying to fix dependencies..."
        if ! sudo apt-get install -f -y; then
            log_error "Failed to install VS Code and fix dependencies"
            rm -f "$vscode_deb"
            return 1
        fi
    fi

    # Clean up
    rm -f "$vscode_deb"

    # Verify installation
    if command_exists code; then
        log_success "VS Code installed successfully"
        return 0
    else
        log_error "VS Code installation completed but command not found"
        return 1
    fi
}

install_fonts() {
    log_info "Installing MesloLGS NF fonts..."

    # Create fonts directory
    mkdir -p ~/.local/share/fonts || {
        log_error "Failed to create fonts directory"
        return 1
    }

    # Font URLs from Powerlevel10k repo
    local fonts=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    local downloaded_count=0

    for font_url in "${fonts[@]}"; do
        local font_name=$(basename "$font_url" | sed 's/%20/ /g')
        local font_path="$HOME/.local/share/fonts/$font_name"
        
        if [[ ! -f "$font_path" ]]; then
            log_info "Downloading $font_name..."
            if curl -fLo "$font_path" --connect-timeout 30 --max-time 60 "$font_url"; then
                if [[ -f "$font_path" && -s "$font_path" ]]; then
                    log_success "$font_name installed"
                    ((downloaded_count++))
                else
                    log_warning "Downloaded $font_name is empty or invalid"
                    rm -f "$font_path"
                fi
            else
                log_warning "Failed to download $font_name"
            fi
        else
            log_info "$font_name already exists, skipping..."
            ((downloaded_count++))
        fi
    done

    if [[ $downloaded_count -eq 0 ]]; then
        log_error "Failed to install any fonts"
        return 1
    fi

    # Refresh font cache
    if command_exists fc-cache; then
        fc-cache -fv >/dev/null 2>&1 || log_warning "Failed to refresh font cache"
    else
        log_warning "fc-cache not found - fonts may not be immediately available"
    fi

    log_success "MesloLGS NF fonts installation completed ($downloaded_count/4 fonts)"
    return 0
}

install_dev_tools() {
    log_info "Installing development tools..."

    local tools_installed=0

    # Install Docker
    if ! command_exists docker; then
        log_info "Installing Docker..."
        
        # Add Docker's official GPG key
        if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null; then
            # Add the repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Update and install
            if sudo apt update && safe_apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin; then
                # Add user to docker group
                if sudo usermod -aG docker "$USER"; then
                    log_success "Docker installed (logout/login required for group changes)"
                    ((tools_installed++))
                else
                    log_warning "Docker installed but failed to add user to docker group"
                fi
            else
                log_warning "Failed to install Docker"
            fi
        else
            log_warning "Failed to add Docker GPG key"
        fi
    else
        log_info "Docker already installed"
        ((tools_installed++))
    fi

    # Install GitHub CLI
    if ! command_exists gh; then
        log_info "Installing GitHub CLI..."
        
        if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null; then
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            
            if sudo apt update && safe_apt_install gh; then
                log_success "GitHub CLI installed"
                ((tools_installed++))
            else
                log_warning "Failed to install GitHub CLI"
            fi
        else
            log_warning "Failed to add GitHub CLI GPG key"
        fi
    else
        log_info "GitHub CLI already installed"
        ((tools_installed++))
    fi

    if [[ $tools_installed -gt 0 ]]; then
        log_success "Development tools installation completed ($tools_installed tools)"
        return 0
    else
        log_warning "No development tools were installed successfully"
        return 1
    fi
}

setup_oh_my_zsh() {
    log_info "Setting up Oh My Zsh and Powerlevel10k..."

    # Ensure zsh is installed
    if ! command_exists zsh; then
        log_error "Zsh is not installed"
        return 1
    fi

    # Install Oh My Zsh if not present
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        
        # Download and run installer with error handling
        local omz_installer="/tmp/omz_install.sh"
        if curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"; then
            if RUNZSH=no CHSH=no bash "$omz_installer"; then
                log_success "Oh My Zsh installed"
                rm -f "$omz_installer"
            else
                log_error "Oh My Zsh installation failed"
                rm -f "$omz_installer"
                return 1
            fi
        else
            log_error "Failed to download Oh My Zsh installer"
            return 1
        fi
    else
        log_info "Oh My Zsh already installed"
    fi

    # Install Powerlevel10k theme
    local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    if [[ ! -d "$p10k_dir" ]]; then
        log_info "Installing Powerlevel10k theme..."
        if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"; then
            log_success "Powerlevel10k installed"
        else
            log_warning "Failed to install Powerlevel10k theme"
        fi
    else
        log_info "Powerlevel10k already installed"
    fi

    # Install zsh plugins
    local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    mkdir -p "$plugins_dir"

    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        log_info "Installing zsh-autosuggestions..."
        if git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"; then
            log_success "zsh-autosuggestions installed"
        else
            log_warning "Failed to install zsh-autosuggestions"
        fi
    else
        log_info "zsh-autosuggestions already installed"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        log_info "Installing zsh-syntax-highlighting..."
        if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"; then
            log_success "zsh-syntax-highlighting installed"
        else
            log_warning "Failed to install zsh-syntax-highlighting"
        fi
    else
        log_info "zsh-syntax-highlighting already installed"
    fi

    # Change default shell to zsh
    if [[ "$SHELL" != "/usr/bin/zsh" && "$SHELL" != "/bin/zsh" ]]; then
        log_info "Changing default shell to zsh..."
        local zsh_path
        zsh_path=$(which zsh)
        if [[ -n "$zsh_path" ]] && chsh -s "$zsh_path"; then
            log_success "Default shell changed to zsh (restart required)"
        else
            log_warning "Failed to change default shell to zsh"
        fi
    fi

    log_success "Oh My Zsh and Powerlevel10k setup completed"
    return 0
}

# Enhanced SSH keys setup with interactive generation
setup_ssh_keys() {
    log_info "Setting up SSH keys..."

    # Create .ssh directory if it doesn't exist
    mkdir -p ~/.ssh || {
        log_error "Failed to create .ssh directory"
        return 1
    }
    chmod 700 ~/.ssh

    # Copy SSH keys from dotfiles repo
    if [[ -f "$DOTFILES_DIR/id_ed25519" && -f "$DOTFILES_DIR/id_ed25519.pub" ]]; then
        log_info "Copying SSH keys from dotfiles..."
        
        # Backup existing keys if they exist
        if [[ -f ~/.ssh/id_ed25519 ]]; then
            log_warning "Backing up existing SSH private key..."
            cp ~/.ssh/id_ed25519 "$BACKUP_DIR/id_ed25519.backup" || log_warning "Failed to backup SSH private key"
        fi
        
        if [[ -f ~/.ssh/id_ed25519.pub ]]; then
            log_warning "Backing up existing SSH public key..."
            cp ~/.ssh/id_ed25519.pub "$BACKUP_DIR/id_ed25519.pub.backup" || log_warning "Failed to backup SSH public key"
        fi
        
        # Copy new keys
        if cp "$DOTFILES_DIR/id_ed25519" ~/.ssh/id_ed25519 && cp "$DOTFILES_DIR/id_ed25519.pub" ~/.ssh/id_ed25519.pub; then
            # Set correct permissions
            chmod 600 ~/.ssh/id_ed25519
            chmod 644 ~/.ssh/id_ed25519.pub
            log_success "SSH keys configured successfully"
        else
            log_error "Failed to copy SSH keys from dotfiles"
            return 1
        fi
    else
        # SSH keys not found in dotfiles - offer to generate new ones
        log_warning "SSH keys not found in dotfiles repo"
        
        if [[ ! -f ~/.ssh/id_ed25519 ]]; then
            echo
            echo "No SSH keys found on this system."
            read -p "Would you like to generate a new SSH key pair? (y/N) " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Get user email for SSH key
                read -p "Enter your email address for the SSH key: " user_email
                
                if [[ -n "$user_email" ]]; then
                    log_info "Generating new SSH key..."
                    if ssh-keygen -t ed25519 -C "$user_email" -f ~/.ssh/id_ed25519 -N ""; then
                        chmod 600 ~/.ssh/id_ed25519
                        chmod 644 ~/.ssh/id_ed25519.pub
                        log_success "New SSH key generated successfully"
                        
                        # Display the public key
                        echo
                        echo -e "${GREEN}Your new SSH public key:${NC}"
                        echo -e "${YELLOW}$(cat ~/.ssh/id_ed25519.pub)${NC}"
                        echo
                        echo -e "${BLUE}Add this key to your GitHub account at: https://github.com/settings/ssh/new${NC}"
                    else
                        log_error "Failed to generate SSH key"
                        return 1
                    fi
                else
                    log_warning "No email provided. Skipping SSH key generation"
                    log_info "You can generate SSH keys manually with: ssh-keygen -t ed25519 -C \"your_email@example.com\""
                fi
            else
                log_info "Skipping SSH key generation"
                log_info "Generate new SSH keys manually with: ssh-keygen -t ed25519 -C \"your_email@example.com\""
            fi
        else
            log_info "Existing SSH key found at ~/.ssh/id_ed25519"
        fi
    fi

    # Create SSH config if it doesn't exist
    if [[ -f ~/.ssh/id_ed25519 && ! -f ~/.ssh/config ]]; then
        log_info "Creating SSH config..."
        cat > ~/.ssh/config << EOF
Host github.com
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

Host *
    AddKeysToAgent yes
EOF
        if [[ $? -eq 0 ]]; then
            chmod 600 ~/.ssh/config 2>/dev/null
        else
            log_warning "Failed to create SSH config"
        fi
    fi

    # Add key to SSH agent if key exists
    if [[ -f ~/.ssh/id_ed25519 ]]; then
        log_info "Adding SSH key to agent..."
        if command_exists ssh-agent && command_exists ssh-add; then
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            ssh-add ~/.ssh/id_ed25519 >/dev/null 2>&1 || log_warning "Failed to add key to SSH agent"
        fi
    fi

    # Switch dotfiles repo to SSH if possible and key exists
    if [[ -d "$DOTFILES_DIR/.git" && -f ~/.ssh/id_ed25519.pub ]]; then
        log_info "Switching dotfiles repo remote to SSH..."
        cd "$DOTFILES_DIR" || return 1
        if git remote set-url origin git@github.com:Shrishesha4/dotfiles.git; then
            log_success "Dotfiles repo remote set to SSH"
        else
            log_warning "Failed to switch dotfiles repo to SSH"
        fi
    fi

    return 0
}

setup_python() {
    log_info "Setting up Python with pyenv..."

    # Install pyenv dependencies
    local pyenv_deps=(
        make build-essential libssl-dev zlib1g-dev libbz2-dev
        libreadline-dev libsqlite3-dev wget curl llvm libncursesw5-dev
        xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
    )

    if ! safe_apt_install "${pyenv_deps[@]}"; then
        log_warning "Some pyenv dependencies failed to install"
    fi

    # Install pyenv
    if [[ ! -d "$HOME/.pyenv" ]]; then
        log_info "Installing pyenv..."
        if curl https://pyenv.run | bash; then
            log_success "pyenv installed"
        else
            log_error "Failed to install pyenv"
            return 1
        fi
    else
        log_info "pyenv already installed"
    fi

    # Initialize pyenv for current session
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    # Check if pyenv command is available
    if command_exists pyenv; then
        eval "$(pyenv init --path)" 2>/dev/null || true
        eval "$(pyenv init -)" 2>/dev/null || true
        
        # Install Python versions
        local python_versions=("3.13.5" "3.9.23")
        local installed_count=0
        
        for version in "${python_versions[@]}"; do
            if ! pyenv versions 2>/dev/null | grep -q "$version"; then
                log_info "Installing Python $version..."
                if pyenv install "$version"; then
                    log_success "Python $version installed"
                    ((installed_count++))
                else
                    log_warning "Failed to install Python $version"
                fi
            else
                log_info "Python $version already installed"
                ((installed_count++))
            fi
        done
        
        # Set global Python version if any were installed
        if [[ $installed_count -gt 0 ]]; then
            log_info "Setting Python 3.13.5 as global default..."
            pyenv global 3.13.5 2>/dev/null || pyenv global 3.9.23 2>/dev/null || log_warning "Failed to set global Python version"
        fi
    else
        log_error "pyenv command not found after installation"
        return 1
    fi

    log_success "Python setup completed"
    return 0
}

setup_ruby() {
    log_info "Setting up Ruby with rbenv..."

    # Install rbenv dependencies
    local rbenv_deps=(
        libssl-dev libreadline-dev zlib1g-dev autoconf bison
        build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
    )

    if ! safe_apt_install "${rbenv_deps[@]}"; then
        log_warning "Some rbenv dependencies failed to install"
    fi

    # Install rbenv
    if [[ ! -d "$HOME/.rbenv" ]]; then
        log_info "Installing rbenv..."
        if git clone https://github.com/rbenv/rbenv.git ~/.rbenv && 
           git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build; then
            log_success "rbenv installed"
        else
            log_error "Failed to install rbenv"
            return 1
        fi
    else
        log_info "rbenv already installed"
    fi

    # Initialize rbenv for current session
    export PATH="$HOME/.rbenv/bin:$PATH"

    if command_exists rbenv; then
        eval "$(rbenv init -)" 2>/dev/null || true
        
        # Install Ruby version
        local ruby_version="3.2.7"
        if ! rbenv versions 2>/dev/null | grep -q "$ruby_version"; then
            log_info "Installing Ruby $ruby_version..."
            if rbenv install "$ruby_version"; then
                log_success "Ruby $ruby_version installed"
                
                # Set global Ruby version
                log_info "Setting Ruby $ruby_version as global default..."
                rbenv global "$ruby_version" || log_warning "Failed to set global Ruby version"
            else
                log_warning "Failed to install Ruby $ruby_version"
            fi
        else
            log_info "Ruby $ruby_version already installed"
        fi
    else
        log_error "rbenv command not found after installation"
        return 1
    fi

    log_success "Ruby setup completed"
    return 0
}

setup_nodejs() {
    log_info "Setting up Node.js with nvm..."

    # Install nvm
    if [[ ! -d "$HOME/.nvm" ]]; then
        log_info "Installing nvm..."
        if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash; then
            log_success "nvm installed"
        else
            log_error "Failed to install nvm"
            return 1
        fi
    else
        log_info "nvm already installed"
    fi

    # Load nvm
    export NVM_DIR="$HOME/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
    [[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"

    # Install latest LTS Node.js
    if command_exists nvm; then
        log_info "Installing latest LTS Node.js..."
        if nvm install --lts && nvm use --lts && nvm alias default node; then
            # Install global packages
            if npm install -g yarn pnpm; then
                log_success "Node.js and package managers installed"
            else
                log_warning "Node.js installed but failed to install global packages"
            fi
        else
            log_warning "Failed to install Node.js via nvm"
            return 1
        fi
    else
        log_warning "nvm not found, skipping Node.js installation"
        return 1
    fi

    return 0
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
            install_brave_browser || true
            install_discord || true
            install_spotify || true
            install_android_studio || true
            install_postman || true
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

    return 0
}

select_individual_apps() {
    echo
    read -p "Install Brave Browser? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && { install_brave_browser || true; }

    echo
    read -p "Install Discord? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && { install_discord || true; }

    echo
    read -p "Install Spotify? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && { install_spotify || true; }

    echo
    read -p "Install Android Studio? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && { install_android_studio || true; }

    echo
    read -p "Install Postman? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && { install_postman || true; }
}

install_brave_browser() {
    log_info "Installing Brave Browser..."

    if command_exists brave-browser || snap list brave >/dev/null 2>&1; then
        log_success "Brave Browser is already installed"
        return 0
    fi

    # Install Brave via snap (supports all architectures)
    log_info "Installing Brave Browser via snap..."

    # Ensure snapd is running
    if ! systemctl is-active --quiet snapd; then
        sudo systemctl start snapd 2>/dev/null || log_warning "Failed to start snapd service"
        sleep 5
    fi

    if sudo snap install brave; then
        log_success "Brave Browser installed successfully"
        return 0
    else
        log_error "Failed to install Brave Browser via snap"
        return 1
    fi
}

install_discord() {
    log_info "Installing Discord..."

    if command_exists discord; then
        log_success "Discord is already installed"
        return 0
    fi

    local arch=$(get_architecture)

    case $arch in
        x64)
            # Use .deb package for x64
            local discord_deb="/tmp/discord.deb"
            log_info "Downloading Discord for x64 architecture..."
            
            if wget --timeout=60 -O "$discord_deb" "https://discord.com/api/download?platform=linux&format=deb"; then
                if [[ -f "$discord_deb" && -s "$discord_deb" ]]; then
                    if sudo dpkg -i "$discord_deb"; then
                        sudo apt-get install -f -y || log_warning "Failed to fix Discord dependencies"
                        rm -f "$discord_deb"
                        log_success "Discord installed successfully"
                        return 0
                    else
                        log_error "Failed to install Discord .deb package"
                        rm -f "$discord_deb"
                        return 1
                    fi
                else
                    log_error "Downloaded Discord file is empty or missing"
                    rm -f "$discord_deb"
                    return 1
                fi
            else
                log_error "Failed to download Discord"
                return 1
            fi
            ;;
        arm64)
            # Use Flatpak for ARM64
            log_info "ARM64 system detected. Installing Discord via Flatpak..."
            
            # Install flatpak if not present
            if ! command_exists flatpak; then
                log_info "Installing Flatpak..."
                if safe_apt_install flatpak; then
                    if flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
                        log_success "Flatpak installed and configured"
                    else
                        log_warning "Flatpak installed but failed to add Flathub repository"
                    fi
                else
                    log_error "Failed to install Flatpak"
                    return 1
                fi
            fi
            
            # Install Discord via Flatpak
            if flatpak install -y flathub com.discordapp.Discord; then
                # Create a wrapper script for easier access
                sudo tee /usr/local/bin/discord > /dev/null << 'EOF'
#!/bin/bash
exec flatpak run com.discordapp.Discord "$@"
EOF
                if [[ $? -eq 0 ]]; then
                    sudo chmod +x /usr/local/bin/discord
                    log_success "Discord installed via Flatpak with command wrapper"
                    return 0
                else
                    log_warning "Discord installed but failed to create command wrapper"
                    return 0
                fi
            else
                log_warning "Flatpak installation failed. You can use Discord in your browser at discord.com/app"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

install_spotify() {
    log_info "Installing Spotify..."

    if command_exists spotify || snap list spotify >/dev/null 2>&1; then
        log_success "Spotify is already installed"
        return 0
    fi

    # Install Spotify via snap (more reliable across architectures)
    log_info "Installing Spotify via snap..."

    # Ensure snapd is running
    if ! systemctl is-active --quiet snapd; then
        sudo systemctl start snapd 2>/dev/null || log_warning "Failed to start snapd service"
        sleep 5
    fi

    if sudo snap install spotify; then
        log_success "Spotify installed successfully"
        return 0
    else
        log_error "Failed to install Spotify via snap"
        return 1
    fi
}

install_android_studio() {
    log_info "Installing Android Studio..."

    # Check if Android Studio is already installed
    if [[ -d "/opt/android-studio" ]] || command_exists android-studio; then
        log_success "Android Studio is already installed"
        return 0
    fi

    local arch=$(get_architecture)

    # Android Studio only supports x64 architecture
    if [[ "$arch" != "x64" ]]; then
        log_error "Android Studio only supports x64 architecture. Current architecture: $arch"
        return 1
    fi

    local android_url="https://redirector.gvt1.com/edgedl/android/studio/ide-zips/2025.1.1.14/android-studio-2025.1.1.14-linux.tar.gz"
    local android_tar="/tmp/android-studio.tar.gz"

    log_info "Downloading Android Studio..."
    log_warning "Android Studio is a large download (~1GB) and may take time"

    if curl -L --connect-timeout 30 --max-time 1800 -o "$android_tar" "$android_url"; then
        if [[ -f "$android_tar" && -s "$android_tar" ]]; then
            # Extract to /opt
            log_info "Extracting Android Studio to /opt/..."
            if sudo tar -xzf "$android_tar" -C /opt/; then
                # Create desktop entry
                log_info "Creating desktop entry..."
                if sudo tee /usr/share/applications/android-studio.desktop > /dev/null << EOF
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
                then
                    # This block runs ONLY if the desktop entry was created successfully
                    sudo ln -sf /opt/android-studio/bin/studio.sh /usr/local/bin/android-studio
                    sudo chown -R "$USER:$USER" /opt/android-studio
                    rm -f "$android_tar"
                    log_success "Android Studio installed successfully"
                    log_info "Note: You'll need to complete Android Studio setup on first launch"
                    return 0
                else
                    # This block runs if creating the desktop entry failed
                    log_warning "Android Studio extracted but failed to create desktop entry"
                    rm -f "$android_tar" # Still clean up the downloaded file
                    return 1
                fi
            else
                log_error "Failed to extract Android Studio"
                rm -f "$android_tar"
                return 1
            fi
        else
            log_error "Downloaded Android Studio file is empty or missing"
            rm -f "$android_tar"
            return 1
        fi
    else
        log_error "Failed to download Android Studio"
        return 1
    fi
}

install_postman() {
    log_info "Installing Postman..."

    # Check if Postman is already installed
    if command_exists postman || snap list postman >/dev/null 2>&1; then
        log_success "Postman is already installed"
        return 0
    fi

    # Install snapd if not present
    if ! command_exists snap; then
        log_info "Installing snapd..."
        if ! safe_apt_install snapd; then
            log_error "Failed to install snapd"
            return 1
        fi
    fi

    # Ensure snapd is running
    if ! systemctl is-active --quiet snapd; then
        sudo systemctl start snapd 2>/dev/null || log_warning "Failed to start snapd service"
        sleep 5
    fi

    # Install Postman via snap
    log_info "Installing Postman via snap..."
    if sudo snap install postman; then
        log_success "Postman installed successfully"
        return 0
    else
        log_error "Failed to install Postman"
        return 1
    fi
}

symlink_dotfiles() {
    log_info "Creating symlinks for dotfiles..."

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        log_error "Dotfiles directory does not exist: $DOTFILES_DIR"
        return 1
    fi

    local dotfiles=(
        ".gitconfig"
        ".yarnrc"
        ".zshrc"
        ".p10k.zsh"
        ".zprofile"
    )

    local symlinked_count=0

    for dotfile in "${dotfiles[@]}"; do
        local source_file="$DOTFILES_DIR/$dotfile"
        local target_file="$HOME/$dotfile"
        
        if [[ -f "$source_file" ]]; then
            # Backup existing files
            if [[ -f "$target_file" && ! -L "$target_file" ]]; then
                if [[ "$dotfile" = ".zshrc" ]]; then
                    log_warning "Backing up existing $dotfile (likely Oh My Zsh default) to $BACKUP_DIR"
                else
                    log_warning "Backing up existing $dotfile to $BACKUP_DIR"
                fi
                cp "$target_file" "$BACKUP_DIR/$dotfile.backup" || log_warning "Failed to backup $dotfile"
            fi
            
            # Remove existing file/symlink
            [[ -e "$target_file" ]] && rm "$target_file"
            
            # Create symlink
            if ln -s "$source_file" "$target_file"; then
                log_success "Symlinked $dotfile"
                ((symlinked_count++))
            else
                log_warning "Failed to symlink $dotfile"
            fi
        else
            log_warning "$dotfile not found in dotfiles repo"
        fi
    done

    if [[ $symlinked_count -gt 0 ]]; then
        log_success "Dotfiles symlinked successfully ($symlinked_count files)"
        return 0
    else
        log_error "No dotfiles were symlinked successfully"
        return 1
    fi
}

# Run main function - THIS MUST BE THE LAST LINE
main "$@"