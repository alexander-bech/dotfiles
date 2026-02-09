#!/bin/bash
#
# Dotfiles Installation Script
# Installs and configures dotfiles with all dependencies
#
# Usage: curl -fsSL <raw-url> | bash
#    or: ./install-dotfiles.sh [OPTIONS]
#
# Options:
#   --no-extras    Skip optional software (starship, uv, nvm, neovim, go)
#   --https        Use HTTPS instead of SSH for git clone
#   --help         Show this help message
#

set -euo pipefail

# Configuration
DOTFILES_REPO_SSH="git@github.com:alexander-bech/dotfiles.git"
DOTFILES_REPO_HTTPS="https://github.com/alexander-bech/dotfiles.git"
DOTFILES_DIR="$HOME/.cfg"
NVM_VERSION="v0.40.4"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State tracking
INSTALL_EXTRAS=true
USE_HTTPS=false
ERRORS=()

# Output functions
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; ERRORS+=("$1"); }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_info() { echo -e "[INFO] $1"; }

# Show usage
usage() {
    cat << EOF
Dotfiles Installation Script

Usage: $0 [OPTIONS]

Options:
  --no-extras    Skip optional software (starship, uv, nvm, neovim, go)
  --https        Use HTTPS instead of SSH for git clone
  --help         Show this help message

Examples:
  $0                    # Full installation with SSH
  $0 --https            # Full installation with HTTPS (no SSH key needed)
  $0 --no-extras        # Just dotfiles, no extra software

EOF
    exit 0
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-extras)
                INSTALL_EXTRAS=false
                shift
                ;;
            --https)
                USE_HTTPS=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Detect OS and package manager
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    else
        OS="unknown"
    fi
    
    case "$OS" in
        ubuntu|debian|pop)
            PKG_MANAGER="apt"
            PKG_INSTALL="sudo apt install -y"
            PKG_UPDATE="sudo apt update"
            ;;
        fedora|rhel|centos)
            PKG_MANAGER="dnf"
            PKG_INSTALL="sudo dnf install -y"
            PKG_UPDATE="sudo dnf check-update || true"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            PKG_INSTALL="sudo pacman -S --noconfirm"
            PKG_UPDATE="sudo pacman -Sy"
            ;;
        macos)
            if command -v brew &>/dev/null; then
                PKG_MANAGER="brew"
                PKG_INSTALL="brew install"
                PKG_UPDATE="brew update"
            else
                print_error "Homebrew not found. Please install it first: https://brew.sh"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported OS: $OS"
            exit 1
            ;;
    esac
    
    print_info "Detected OS: $OS (package manager: $PKG_MANAGER)"
}

# Detect CPU architecture
detect_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64|amd64)
            ARCH_NVIM="x86_64"
            ;;
        aarch64|arm64)
            ARCH_NVIM="arm64"
            ;;
        *)
            print_warn "Unknown architecture: $ARCH - neovim may not install correctly"
            ARCH_NVIM="x86_64"
            ;;
    esac
    print_info "Detected architecture: $ARCH"
}

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Install base dependencies
install_base_deps() {
    print_header "Installing Base Dependencies"
    
    local packages=()
    
    # Check what's already installed
    cmd_exists git || packages+=(git)
    cmd_exists tmux || packages+=(tmux)
    cmd_exists curl || packages+=(curl)
    cmd_exists zsh || packages+=(zsh)
    cmd_exists wget || packages+=(wget)
    cmd_exists rg || packages+=(ripgrep)
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        print_success "All base dependencies already installed"
        return 0
    fi
    
    print_info "Installing: ${packages[*]}"
    $PKG_UPDATE
    $PKG_INSTALL "${packages[@]}"
    print_success "Base dependencies installed"
}

# Create necessary directories
create_directories() {
    print_header "Creating Directories"
    
    local dirs=(
        "$HOME/.local/bin"
        "$HOME/.config"
        "$HOME/.cache/zsh"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            print_success "Created $dir"
        else
            print_info "Directory exists: $dir"
        fi
    done
}

# Test SSH connection to GitHub
test_github_ssh() {
    print_info "Testing SSH connection to GitHub..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        return 0
    elif ssh -T git@github.com 2>&1 | grep -q "Hi"; then
        return 0
    else
        return 1
    fi
}

# Clone dotfiles as bare repository
clone_dotfiles() {
    print_header "Setting Up Dotfiles"
    
    local repo_url
    if [[ "$USE_HTTPS" == true ]]; then
        repo_url="$DOTFILES_REPO_HTTPS"
        print_info "Using HTTPS for git clone"
    else
        # Test SSH first
        if test_github_ssh; then
            repo_url="$DOTFILES_REPO_SSH"
            print_info "Using SSH for git clone"
        else
            print_warn "SSH connection to GitHub failed, falling back to HTTPS"
            repo_url="$DOTFILES_REPO_HTTPS"
        fi
    fi
    
    # Check if already cloned
    if [[ -d "$DOTFILES_DIR" ]]; then
        print_warn "Dotfiles directory already exists at $DOTFILES_DIR"
        print_info "Attempting to update..."
        git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" fetch origin
        git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" reset --hard origin/master
        print_success "Dotfiles updated"
        return 0
    fi
    
    # Add .cfg to gitignore to avoid recursion
    echo ".cfg" >> "$HOME/.gitignore" 2>/dev/null || true
    
    # Clone as bare repo
    print_info "Cloning dotfiles repository..."
    git clone --bare "$repo_url" "$DOTFILES_DIR"
    
    # Backup existing files that would conflict
    print_info "Checking for conflicting files..."
    local conflicts
    conflicts=$(git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout 2>&1 | grep -oP '^\t\K.*' || true)
    
    if [[ -n "$conflicts" ]]; then
        local backup_dir="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        print_warn "Backing up conflicting files to $backup_dir"
        
        while IFS= read -r file; do
            if [[ -n "$file" && -e "$HOME/$file" ]]; then
                mkdir -p "$backup_dir/$(dirname "$file")"
                mv "$HOME/$file" "$backup_dir/$file"
                print_info "  Backed up: $file"
            fi
        done <<< "$conflicts"
    fi
    
    # Checkout dotfiles
    git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout
    
    # Configure to not show untracked files
    git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" config --local status.showUntrackedFiles no
    
    print_success "Dotfiles installed"
}

# Install starship prompt
install_starship() {
    print_header "Installing Starship"
    
    if cmd_exists starship; then
        print_info "Starship already installed"
        return 0
    fi
    
    print_info "Installing starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    print_success "Starship installed"
}

# Install uv (Python package manager)
install_uv() {
    print_header "Installing uv"
    
    if cmd_exists uv; then
        print_info "uv already installed"
        return 0
    fi
    
    print_info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    print_success "uv installed"
}

# Install nvm and Node.js
install_nvm() {
    print_header "Installing nvm and Node.js"
    
    export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"
    
    if [[ -d "$NVM_DIR" ]]; then
        print_info "nvm already installed"
    else
        print_info "Installing nvm..."
        mkdir -p "$NVM_DIR"
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
        print_success "nvm installed"
    fi
    
    # Source nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install latest Node.js if nvm is available
    if cmd_exists nvm; then
        if ! nvm ls node &>/dev/null; then
            print_info "Installing Node.js..."
            nvm install node
            print_success "Node.js installed"
        else
            print_info "Node.js already installed"
        fi
    fi
}

# Install Neovim
install_neovim() {
    print_header "Installing Neovim"
    
    if cmd_exists nvim; then
        print_info "Neovim already installed"
        return 0
    fi
    
    local nvim_url
    local nvim_archive
    local nvim_dir
    
    case "$(uname -s)" in
        Linux)
            nvim_archive="nvim-linux-${ARCH_NVIM}.tar.gz"
            nvim_url="https://github.com/neovim/neovim/releases/latest/download/$nvim_archive"
            nvim_dir="nvim-linux-${ARCH_NVIM}"
            ;;
        Darwin)
            nvim_archive="nvim-macos-${ARCH_NVIM}.tar.gz"
            nvim_url="https://github.com/neovim/neovim/releases/latest/download/$nvim_archive"
            nvim_dir="nvim-macos-${ARCH_NVIM}"
            ;;
        *)
            print_error "Unsupported OS for Neovim installation"
            return 1
            ;;
    esac
    
    print_info "Downloading Neovim..."
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if ! wget -q "$nvim_url"; then
        print_error "Failed to download Neovim"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_info "Extracting Neovim..."
    tar -xzf "$nvim_archive"
    
    # Move to home directory and create symlink
    if [[ -d "$HOME/$nvim_dir" ]]; then
        rm -rf "$HOME/$nvim_dir"
    fi
    mv "$nvim_dir" "$HOME/"
    
    # Create symlink
    ln -sf "$HOME/$nvim_dir/bin/nvim" "$HOME/.local/bin/nvim"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    print_success "Neovim installed"
}

# Install Go (Golang)
install_golang() {
    print_header "Installing Go"
    
    if cmd_exists go; then
        print_info "Go already installed: $(go version)"
        return 0
    fi
    
    local go_version
    local go_archive
    local go_url
    local go_install_dir="$HOME/.local/go"
    
    # Fetch latest Go version from go.dev
    print_info "Fetching latest Go version..."
    go_version=$(curl -sL 'https://go.dev/VERSION?m=text' | head -1)
    
    if [[ -z "$go_version" ]]; then
        print_error "Failed to fetch Go version"
        return 1
    fi
    
    print_info "Latest version: $go_version"
    
    # Determine archive name based on platform
    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64)
            go_archive="${go_version}.linux-amd64.tar.gz"
            ;;
        Linux-aarch64)
            go_archive="${go_version}.linux-arm64.tar.gz"
            ;;
        Darwin-x86_64)
            go_archive="${go_version}.darwin-amd64.tar.gz"
            ;;
        Darwin-arm64)
            go_archive="${go_version}.darwin-arm64.tar.gz"
            ;;
        *)
            print_error "Unsupported platform: $(uname -s)-$(uname -m)"
            return 1
            ;;
    esac
    
    go_url="https://go.dev/dl/${go_archive}"
    
    print_info "Downloading Go from $go_url..."
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if ! wget -q "$go_url"; then
        print_error "Failed to download Go"
        cd - > /dev/null
        rm -rf "$temp_dir"
        return 1
    fi
    
    print_info "Extracting Go..."
    tar -xzf "$go_archive"
    
    # Remove existing Go installation if present
    if [[ -d "$go_install_dir" ]]; then
        rm -rf "$go_install_dir"
    fi
    
    # Move to installation directory
    mv go "$go_install_dir"
    
    # Create symlinks for go binaries
    ln -sf "$go_install_dir/bin/go" "$HOME/.local/bin/go"
    ln -sf "$go_install_dir/bin/gofmt" "$HOME/.local/bin/gofmt"
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    print_success "Go installed ($go_version)"
    print_info "GOROOT: $go_install_dir"
    print_info "Make sure \$HOME/.local/bin is in your PATH"
}

# Change default shell to zsh
change_shell() {
    print_header "Configuring Shell"
    
    local current_shell
    current_shell=$(basename "$SHELL")
    
    if [[ "$current_shell" == "zsh" ]]; then
        print_info "zsh is already the default shell"
        return 0
    fi
    
    local zsh_path
    zsh_path=$(which zsh)
    
    if [[ -z "$zsh_path" ]]; then
        print_error "zsh not found in PATH"
        return 1
    fi
    
    print_info "Changing default shell to zsh..."
    print_warn "You may be prompted for your password"
    
    if chsh -s "$zsh_path"; then
        print_success "Default shell changed to zsh"
        print_info "Please log out and back in for the change to take effect"
    else
        print_error "Failed to change shell. You can do it manually with: chsh -s $zsh_path"
    fi
}

# Set up environment variables for this session
setup_env() {
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_CACHE_HOME="$HOME/.cache"
    export PATH="$HOME/.local/bin:$PATH"
}

# Print summary
print_summary() {
    echo ""
    print_header "Installation Complete"
    
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Completed with warnings:${NC}"
        for err in "${ERRORS[@]}"; do
            echo "  - $err"
        done
        echo ""
    fi
    
    echo "Next steps:"
    echo "  1. Log out and back in (or run: exec zsh)"
    echo "  2. Your dotfiles are managed with the 'config' alias:"
    echo "     config status"
    echo "     config add <file>"
    echo "     config commit -m 'message'"
    echo "     config push"
    echo ""
    
    if [[ "$INSTALL_EXTRAS" == true ]]; then
        echo "Installed software:"
        echo "  - starship (prompt)"
        echo "  - uv (Python)"
        echo "  - nvm + Node.js"
        echo "  - neovim"
        echo "  - go (golang)"
    fi
}

# Main installation
main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════╗"
    echo "║     Dotfiles Installation Script      ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${NC}"
    
    parse_args "$@"
    
    setup_env
    detect_os
    detect_arch
    
    install_base_deps
    create_directories
    clone_dotfiles
    
    if [[ "$INSTALL_EXTRAS" == true ]]; then
        install_starship
        install_uv
        install_nvm
        install_neovim
        install_golang
    fi
    
    change_shell
    print_summary
}

main "$@"
