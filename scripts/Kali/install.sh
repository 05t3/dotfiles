#!/usr/bin/env bash
# =============================================================================
#  rice-install.sh — Kali Linux Ricing Setup
#  Components: JetBrains Mono NF, shell-color-scripts, eza, alacritty,
#              bspwm, sxhkd, dunst, fastfetch, fish, picom, polybar,
#              rofi, sddm, feh, starship, pixie-sddm theme
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}${BOLD}[*]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[!]${RESET} $*"; }
die()     { echo -e "${RED}${BOLD}[✗]${RESET} $*"; exit 1; }

# Working directory for git clones
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log "Temporary workdir: $WORKDIR"
echo

# =============================================================================
#  1. JetBrains Mono Nerd Font
# =============================================================================
install_font() {
    log "Installing JetBrains Mono Nerd Font..."
    local font_dir="$HOME/.local/share/fonts"
    mkdir -p "$font_dir"

    wget -q --show-progress \
        -P "$font_dir" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
        || die "Failed to download JetBrains Mono font"

    unzip -qo "$font_dir/JetBrainsMono.zip" -d "$font_dir" \
        || die "Failed to unzip font"

    rm -f "$font_dir/JetBrainsMono.zip"
    fc-cache -fv > /dev/null 2>&1
    success "JetBrains Mono Nerd Font installed"
}

# =============================================================================
#  2. shell-color-scripts
# =============================================================================
install_color_scripts() {
    log "Installing shell-color-scripts..."
    local repo_dir="$WORKDIR/shell-color-scripts"

    git clone --depth=1 https://gitlab.com/dwt1/shell-color-scripts.git "$repo_dir" \
        || die "Failed to clone shell-color-scripts"

    sudo make -C "$repo_dir" install \
        || die "Failed to install shell-color-scripts"

    # ZSH completions
    if [[ -d "$repo_dir/completions" ]]; then
        if [[ -d /usr/share/zsh/site-functions ]]; then
            sudo cp "$repo_dir/completions/_colorscript" /usr/share/zsh/site-functions/
            success "ZSH completions installed"
        else
            warn "ZSH site-functions dir not found — skipping ZSH completions"
        fi

        # Fish completions (installed after fish below, but copy now)
        sudo mkdir -p /usr/share/fish/vendor_completions.d
        sudo cp "$repo_dir/completions/colorscript.fish" /usr/share/fish/vendor_completions.d/
        success "Fish completions installed"
    else
        warn "Completions directory not found in repo — skipping"
    fi

    success "shell-color-scripts installed"
}

# =============================================================================
#  3. eza APT repo + package installs
# =============================================================================
setup_eza_repo() {
    log "Setting up eza APT repository..."
    sudo mkdir -p /etc/apt/keyrings

    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
        || die "Failed to import eza GPG key"

    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null

    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update -qq
    success "eza repo configured"
}

install_packages() {
    log "Installing APT packages..."
    local packages=(
        eza
        alacritty
        bspwm
        sxhkd
        dunst
        libnotify-bin
        fastfetch
        fish
        picom
        polybar
        rofi
        sddm
        feh
        starship
        libqt6quick6
        libqt6qml6
        libqt6svg6
        libqt6quickcontrols2-6
    )

    sudo apt install -y "${packages[@]}" \
        || die "APT package installation failed"

    success "All packages installed"
}

# =============================================================================
#  4. pixie-sddm theme
# =============================================================================
install_sddm_theme() {
    log "Installing pixie-sddm theme..."
    local repo_dir="$WORKDIR/pixie-sddm"

    git clone --depth=1 https://github.com/xCaptaiN09/pixie-sddm.git "$repo_dir" \
        || die "Failed to clone pixie-sddm"

    [[ -x "$repo_dir/install.sh" ]] || chmod +x "$repo_dir/install.sh"

    cd "$repo_dir"
    yes 2>/dev/null | sudo bash install.sh
    [[ ${PIPESTATUS[1]} -eq 0 ]] || die "pixie-sddm install.sh failed"
    cd - > /dev/null

    success "pixie-sddm theme installed"
}

# =============================================================================
#  Main
# =============================================================================
main() {
    echo
    echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║      Kali Linux Rice Installer           ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo

    # Confirm before proceeding
    read -rp "$(echo -e ${YELLOW}"This will install system packages and themes. Continue? [y/N] "${RESET})" confirm
    [[ "${confirm,,}" == "y" ]] || { warn "Aborted."; exit 0; }
    echo

    install_font
    echo
    install_color_scripts
    echo
    setup_eza_repo
    install_packages
    echo
    install_sddm_theme
    echo

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║   All done! Log out and enjoy the rice.  ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo
    warn "Remember to set 'pixie' as your SDDM theme in /etc/sddm.conf"
    warn "and configure bspwm/sxhkd configs in ~/.config/ if not already done."
}

main "$@"