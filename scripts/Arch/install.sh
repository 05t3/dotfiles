#!/usr/bin/env bash
# =============================================================================
#  rice-install-arch.sh — Arch Linux Ricing Setup
#  Components: xorg, plasma, sddm, bspwm, alacritty, eza, fish, starship,
#              polybar, picom, dunst, rofi, feh, fastfetch, yay (AUR),
#              brave, shell-color-scripts, pixie-sddm
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

# Must NOT be run as root (makepkg requirement)
[[ "$EUID" -eq 0 ]] && die "Do not run this script as root. Use a regular user with sudo."

# Working directory for AUR builds
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log "Temporary workdir: $WORKDIR"
echo

# =============================================================================
#  1. Pacman packages
# =============================================================================
install_pacman_packages() {
    log "Installing pacman packages..."

    local packages=(
        # Xorg
        xorg-server
        xorg-apps
        xorg-xinit
        xorg-twm
        xorg-xclock
        xterm

        # Desktop / Display
        plasma
        sddm
        bspwm
        sxhkd

        # Graphics
        mesa
        vulkan-swrast

        # Virtualbox guest (safe to install; ignored if not in VM)
        virtualbox-guest-utils

        # Terminal & Shell
        alacritty
        fish
        starship
        zsh

        # Fonts
        ttf-jetbrains-mono-nerd

        # CLI tools
        eza
        fastfetch
        git
        openssh
        dmenu

        # Rice components
        polybar
        picom
        dunst
        feh
        rofi

        # Qt6 (required for pixie-sddm)
        qt6-declarative
        qt6-svg
    )

    sudo pacman -Syu --needed --noconfirm "${packages[@]}" \
        || die "pacman package installation failed"

    success "All pacman packages installed"
}

# =============================================================================
#  2. Enable & start services
# =============================================================================
enable_services() {
    log "Enabling and starting services..."

    local services=(vboxservice sshd sddm)

    for svc in "${services[@]}"; do
        if systemctl list-unit-files --quiet "$svc.service" &>/dev/null; then
            sudo systemctl enable "$svc" 2>/dev/null || warn "Could not enable $svc"
            # Don't start sddm here — it will take over the session
            if [[ "$svc" != "sddm" ]]; then
                sudo systemctl start "$svc" 2>/dev/null || warn "Could not start $svc"
            fi
            success "$svc enabled"
        else
            warn "$svc.service not found — skipping"
        fi
    done

    warn "sddm will start on next reboot (not started now to avoid dropping session)"
}

# =============================================================================
#  3. Install yay (AUR helper)
# =============================================================================
install_yay() {
    if command -v yay &>/dev/null; then
        warn "yay already installed ($(yay --version | head -1)) — skipping"
        return
    fi

    log "Installing yay (AUR helper)..."
    local yay_dir="$WORKDIR/yay"

    git clone --depth=1 https://aur.archlinux.org/yay.git "$yay_dir" \
        || die "Failed to clone yay"

    (cd "$yay_dir" && makepkg -si --noconfirm) \
        || die "Failed to build/install yay"

    command -v yay &>/dev/null || die "yay not found after install"
    success "yay installed: $(yay --version | head -1)"
}

# =============================================================================
#  4. AUR packages
# =============================================================================
install_aur_packages() {
    log "Installing AUR packages via yay..."

    local aur_packages=(
        brave-bin
        shell-color-scripts-git
        pixie-sddm-git
    )

    yay -Sy --needed --noconfirm "${aur_packages[@]}" \
        || die "AUR package installation failed"

    success "AUR packages installed"
}

# =============================================================================
#  Main
# =============================================================================
main() {
    echo
    echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║    Arch Linux Rice Installer             ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo

    read -rp "$(echo -e ${YELLOW}"This will install system packages and AUR packages. Continue? [y/N] "${RESET})" confirm
    [[ "${confirm,,}" == "y" ]] || { warn "Aborted."; exit 0; }
    echo

    install_pacman_packages
    echo
    enable_services
    echo
    install_yay
    echo
    install_aur_packages
    echo

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║   Done! Reboot to start SDDM & bspwm.   ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo
    warn "Next step: run config-setup.sh to apply dotfiles"
    warn "Then reboot: sudo reboot"
}

main "$@"