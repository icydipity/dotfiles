#!/bin/bash

# --- Strict Mode ---
set -euo pipefail


# --- Environment & Paths ---
DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ZSH_DIR="$HOME/.zsh"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


# --- Logging & Error Trap ---
info()    { echo -e "${BLUE}info${NC}  $1"; }
success() { echo -e "${GREEN}success${NC} $1"; }
warn()    { echo -e "${YELLOW}warn${NC}  $1"; }

trap 'echo -e "${RED}❌ Script failed at line $LINENO${NC}"' ERR


# --- Dependency Installer ---
install_required_tools() {
    info "Installing system dependencies..."

    sudo apt-get update -qq || warn "Some repositories failed to update, but proceeding anyway..."
    sudo apt-get install -y -qq git fzf gpg

    # Install eza (Modern ls)
    if ! command -v eza &> /dev/null; then
        info "Configuring eza repository..."

        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt-get update -qq || warn "Some repositories failed to update, proceeding to install eza..."
        sudo apt-get install -y -qq eza

        success "eza installed successfully."
    fi

    # Cleanup apt cache to save space
    sudo apt-get autoremove -y -qq
    sudo apt-get clean -qq
    sudo rm -rf /var/lib/apt/lists/*
}


# --- Helper Functions ---

# Plugin Installer: Clones if missing, updates if present
install_plugin() {
    local name=$1
    local url=$2
    local target="$ZSH_DIR/$name"

    if [ ! -d "$target" ]; then
        info "📥 Installing $name..."
        git clone --depth=1 "$url" "$target"
    else
        success "✅ $name already exists, skipping clone."
    fi
}

# Linker: Backs up existing files to prevent data loss
link_file() {
    local src="$DOTFILES_DIR/$1"
    local dest="$HOME/$1"

    if [ -f "$src" ]; then
        # Back up real files, but not existing symlinks
        if [ -f "$dest" ] && [ ! -L "$dest" ]; then
            warn "📦 Backing up existing $1 to $1.bak"
            mv "$dest" "$dest.bak"
        fi

        ln -sf "$src" "$dest"
        success "🔗 Linked $1"
    else
        warn "⚠️  Source $1 not found, skipping link."
    fi
}


# --- Execution ---

echo -e "${BLUE}🚀 Starting dotfiles installation...${NC}"

install_required_tools

# Setup Directories
if [ ! -d "$ZSH_DIR" ]; then
    info "Creating directory: $ZSH_DIR"
    mkdir -p "$ZSH_DIR"
fi


# Install Plugins
install_plugin "powerlevel10k" "https://github.com/romkatv/powerlevel10k.git"
install_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
install_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
install_plugin "fzf-tab" "https://github.com/Aloxaf/fzf-tab"

# Symlink config files
info "Setting up symlinks..."
link_file ".zshrc"
link_file ".p10k.zsh"

# --- Cleanup & Instructions ---
echo -e "\n${GREEN}✨ All set!${NC}"
echo -e "1. Restart your terminal or run: ${YELLOW}source ~/.zshrc${NC}"
echo -e "2. If icons look weird, ensure you have a ${BLUE}Nerd Font${NC} installed."
