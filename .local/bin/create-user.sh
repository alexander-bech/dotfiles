#!/bin/bash
#
# Create a new user with SSH access and optionally set up dotfiles
# Based on instructions from README
#
# Usage: ./create-user.sh <username> [--with-setup]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_info() { echo -e "[INFO] $1"; }

usage() {
    echo "Usage: $0 <username> [--with-setup]"
    echo ""
    echo "Arguments:"
    echo "  username      The username for the new user"
    echo ""
    echo "Options:"
    echo "  --with-setup  Also install software and configure dotfiles"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 john                  # Create user 'john' with SSH access"
    echo "  $0 john --with-setup     # Create user and set up environment"
    exit 1
}

# Check if running as root or with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v 2>/dev/null; then
            print_error "This script requires sudo privileges"
            exit 1
        fi
    fi
}

# Create the user with home directory and bash shell
create_user() {
    local username="$1"
    
    if id "$username" &>/dev/null; then
        print_warn "User '$username' already exists"
        return 0
    fi
    
    print_info "Creating user '$username'..."
    sudo useradd -m -s /bin/bash "$username"
    sudo usermod -aG sudo "$username"
    print_success "User '$username' created and added to sudo group"
}

# Set up password for the user
setup_password() {
    local username="$1"
    
    print_info "Setting password for '$username'..."
    echo "Please enter a password for the new user:"
    sudo passwd "$username"
    print_success "Password set for '$username'"
}

# Set up SSH access for the user
setup_ssh() {
    local username="$1"
    local user_home="/home/$username"
    local ssh_dir="$user_home/.ssh"
    local source_keys="$HOME/.ssh/authorized_keys"
    
    print_info "Setting up SSH access for '$username'..."
    
    # Check if source authorized_keys exists
    if [[ ! -f "$source_keys" ]]; then
        print_warn "No authorized_keys found at $source_keys"
        print_warn "Skipping SSH key copy - you'll need to set up SSH keys manually"
        return 0
    fi
    
    # Create .ssh directory
    sudo mkdir -p "$ssh_dir"
    sudo chmod 700 "$ssh_dir"
    
    # Copy authorized_keys
    sudo cp "$source_keys" "$ssh_dir/authorized_keys"
    sudo chmod 600 "$ssh_dir/authorized_keys"
    
    # Set ownership
    sudo chown -R "$username:$username" "$ssh_dir"
    
    print_success "SSH access configured for '$username'"
}

# Install base software packages
install_base_software() {
    print_info "Installing base software (git, tmux, curl)..."
    sudo apt update
    sudo apt install -y git tmux curl
    print_success "Base software installed"
}

# Set up the user environment (run as the new user)
setup_user_environment() {
    local username="$1"
    local user_home="/home/$username"
    
    print_info "Setting up environment for '$username'..."
    
    # Create setup script to run as the new user
    local setup_script=$(mktemp)
    cat > "$setup_script" << 'SETUP_EOF'
#!/bin/bash
set -e

echo "[INFO] Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo "[INFO] Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

echo "[INFO] Setting up dotfiles..."
# Add config alias
echo "alias config='/usr/bin/git --git-dir=\$HOME/.cfg/ --work-tree=\$HOME'" >> ~/.bashrc

# Ignore .cfg directory
echo ".cfg" >> ~/.gitignore

# Clone dotfiles as bare repo
if [[ ! -d "$HOME/.cfg" ]]; then
    git clone git@github.com:alexander-bech/dotfiles.git "$HOME/.cfg" --bare
    
    # Remove conflicting files
    rm -f ~/.bashrc ~/.bash_logout ~/.bash_history ~/.profile 2>/dev/null || true
    
    # Checkout dotfiles
    /usr/bin/git --git-dir="$HOME/.cfg/" --work-tree="$HOME" checkout
    
    # Configure git to not show untracked files
    /usr/bin/git --git-dir="$HOME/.cfg/" --work-tree="$HOME" config --local status.showUntrackedFiles no
fi

echo "[OK] User environment setup complete"
SETUP_EOF

    chmod +x "$setup_script"
    
    # Run the setup script as the new user
    sudo -u "$username" bash "$setup_script"
    
    # Cleanup
    rm -f "$setup_script"
    
    print_success "Environment configured for '$username'"
}

# Main script
main() {
    local username=""
    local with_setup=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --with-setup)
                with_setup=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                ;;
            *)
                if [[ -z "$username" ]]; then
                    username="$1"
                else
                    print_error "Too many arguments"
                    usage
                fi
                shift
                ;;
        esac
    done
    
    # Validate username
    if [[ -z "$username" ]]; then
        print_error "Username is required"
        usage
    fi
    
    # Validate username format (alphanumeric, underscore, hyphen, starting with letter)
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid username format. Use lowercase letters, numbers, underscore, and hyphen."
        exit 1
    fi
    
    echo "======================================"
    echo "  Creating user: $username"
    echo "  With setup: $with_setup"
    echo "======================================"
    echo ""
    
    # Check sudo access
    check_sudo
    
    # Create user
    create_user "$username"
    
    # Set password
    setup_password "$username"
    
    # Setup SSH
    setup_ssh "$username"
    
    # Optional: full environment setup
    if [[ "$with_setup" == true ]]; then
        install_base_software
        setup_user_environment "$username"
    fi
    
    echo ""
    echo "======================================"
    print_success "User '$username' has been created!"
    echo "======================================"
    echo ""
    echo "Next steps:"
    echo "  1. SSH into the server as the new user:"
    echo "     ssh $username@<server> -A"
    if [[ "$with_setup" == false ]]; then
        echo ""
        echo "  2. To set up the environment, run:"
        echo "     $0 $username --with-setup"
        echo "     (or follow the manual steps in README)"
    fi
    echo ""
    echo "To delete this user later:"
    echo "  sudo deluser --remove-home $username"
}

main "$@"
