#!/usr/bin/env bash
# =============================================================================
#  config-setup.sh — Kali Linux Rice Config Setup
#  Scaffolds default configs then overlays dotfiles from 05t3/dotfiles
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

DOTFILES="$HOME/.config/dotfiles"
THEME="$DOTFILES/theme/colourful"

# =============================================================================
#  1. Create directory structure
# =============================================================================
scaffold_dirs() {
    log "Creating config directory structure..."

    mkdir -p ~/.config/{alacritty/themes,fastfetch,polybar,picom,dunst,bspwm,sxhkd,fish,sddm/themes,rofi}
    mkdir -p ~/.config/wallpaper/{jpeg,jpg,svg,png,fastfetch,sddm}

    success "Directories created"
}

# =============================================================================
#  2. Generate default configs from installed tools
# =============================================================================
generate_defaults() {
    log "Generating default configs..."

    # Alacritty
    touch ~/.config/alacritty/alacritty.toml
    if [[ ! -d ~/.config/alacritty/themes/.git ]]; then
        git clone --depth=1 https://github.com/alacritty/alacritty-theme \
            ~/.config/alacritty/themes \
            || warn "Failed to clone alacritty-theme — skipping"
    else
        warn "alacritty-theme already cloned — skipping"
    fi
    success "Alacritty scaffolded"

    # Fastfetch
    fastfetch --gen-config ~/.config/fastfetch/config.jsonc 2>/dev/null \
        || warn "fastfetch --gen-config failed — skipping"
    success "Fastfetch config generated"

    # Picom
    if [[ -f /etc/xdg/picom.conf ]]; then
        cp /etc/xdg/picom.conf ~/.config/picom/picom.conf
        success "Picom default config copied"
    else
        warn "/etc/xdg/picom.conf not found — skipping"
    fi

    # Polybar
    if [[ -f /etc/polybar/config.ini ]]; then
        cp /etc/polybar/config.ini ~/.config/polybar/config.ini
        success "Polybar default config copied"
    else
        warn "/etc/polybar/config.ini not found — skipping"
    fi

    # Dunst
    if [[ -f /etc/dunst/dunstrc ]]; then
        cp /etc/dunst/dunstrc ~/.config/dunst/dunstrc
        success "Dunst default config copied"
    else
        warn "/etc/dunst/dunstrc not found — skipping"
    fi

    # bspwm
    local bspwm_example=/usr/share/doc/bspwm/examples/bspwmrc
    if [[ -f "$bspwm_example" ]]; then
        install -Dm755 "$bspwm_example" ~/.config/bspwm/bspwmrc
        success "bspwmrc installed"
    else
        warn "$bspwm_example not found — skipping"
    fi

    # sxhkd
    local sxhkd_example=/usr/share/doc/bspwm/examples/sxhkdrc
    if [[ -f "$sxhkd_example" ]]; then
        install -Dm644 "$sxhkd_example" ~/.config/sxhkd/sxhkdrc
        success "sxhkdrc installed"
    else
        warn "$sxhkd_example not found — skipping"
    fi

    # SDDM
    sddm --example-config > ~/.config/sddm/sddm.conf 2>/dev/null \
        || warn "sddm --example-config failed — skipping"
    success "SDDM example config generated"

    # Fish
    touch ~/.config/fish/config.fish
    success "Fish config touched"

    # Rofi
    rofi -dump-config > ~/.config/rofi/config.rasi 2>/dev/null \
        || warn "rofi -dump-config failed — skipping"
    success "Rofi config dumped"
}

# =============================================================================
#  3. Clone dotfiles repo
# =============================================================================
clone_dotfiles() {
    log "Cloning dotfiles repo..."

    if [[ -d "$DOTFILES/.git" ]]; then
        warn "Dotfiles repo already exists — pulling latest instead"
        git -C "$DOTFILES" pull --ff-only || warn "git pull failed — continuing with existing files"
    else
        git clone --depth=1 https://github.com/05t3/dotfiles.git "$DOTFILES" \
            || die "Failed to clone dotfiles repo"
    fi

    success "Dotfiles ready at $DOTFILES"
}

# =============================================================================
#  4. Apply dotfile overlays
# =============================================================================
apply_dotfiles() {
    log "Applying dotfile configs..."

    local files=(
        "alacritty/alacritty.toml:$HOME/.config/alacritty/alacritty.toml"
        "fastfetch/config.jsonc:$HOME/.config/fastfetch/config.jsonc"
        "picom/picom.conf:$HOME/.config/picom/picom.conf"
        "polybar/config.ini:$HOME/.config/polybar/config.ini"
        "dunst/dunstrc:$HOME/.config/dunst/dunstrc"
        "bspwm/bspwmrc:$HOME/.config/bspwm/bspwmrc"
        "sxhkd/sxhkdrc:$HOME/.config/sxhkd/sxhkdrc"
        "sddm/sddm.conf:$HOME/.config/sddm/sddm.conf"
        "fish/config.fish:$HOME/.config/fish/config.fish"
        "rofi/config.rasi:$HOME/.config/rofi/config.rasi"
    )

    for entry in "${files[@]}"; do
        local src="$THEME/${entry%%:*}"
        local dst="${entry##*:}"
        if [[ -f "$src" ]]; then
            cp "$src" "$dst"
            success "$(basename "$dst") applied"
        else
            warn "Source not found: $src — skipping"
        fi
    done
}

# =============================================================================
#  5. SDDM pixie theme customisation
# =============================================================================
apply_sddm_theme() {
    log "Customising pixie SDDM theme..."

    local pixie_src=/usr/share/sddm/themes/pixie
    local pixie_dst=~/.config/sddm/themes/pixie

    if [[ ! -d "$pixie_src" ]]; then
        warn "Pixie theme not found at $pixie_src — skipping SDDM customisation"
        return
    fi

    cp -r "$pixie_src" "$pixie_dst"
    success "Pixie theme copied to user config"

    # Swap background wallpaper reference
    sed -i 's|background=assets/background.jpg|background=assets/wallpaper.jpg|' \
        "$pixie_dst/theme.conf" \
        && success "theme.conf background updated"

    # Swap avatar reference
    sed -i 's|assets/avatar.jpg|assets/hacker.jpg|' \
        "$pixie_dst/Main.qml" \
        && success "Main.qml avatar updated"

    # Copy custom wallpaper assets
    local wallpaper_src="$THEME/wallpapers/sddm/assets"

    if [[ -f "$wallpaper_src/hacker.jpg" ]]; then
        cp "$wallpaper_src/hacker.jpg" "$pixie_dst/assets/hacker.jpg"
        success "hacker.jpg asset applied"
    else
        warn "hacker.jpg not found in dotfiles — skipping"
    fi

    if [[ -f "$wallpaper_src/012.jpg" ]]; then
        cp "$wallpaper_src/012.jpg" "$pixie_dst/assets/wallpaper.jpg"
        success "wallpaper.jpg asset applied"
    else
        warn "012.jpg not found in dotfiles — skipping"
    fi

    success "Pixie SDDM theme customised"
}

# =============================================================================
#  Main
# =============================================================================
main() {
    echo
    echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║     Kali Linux Config Setup              ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo

    read -rp "$(echo -e ${YELLOW}"This will scaffold and overwrite configs in ~/.config. Continue? [y/N] "${RESET})" confirm
    [[ "${confirm,,}" == "y" ]] || { warn "Aborted."; exit 0; }
    echo

    scaffold_dirs
    echo
    generate_defaults
    echo
    clone_dotfiles
    echo
    apply_dotfiles
    echo
    apply_sddm_theme
    echo

    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║   Config setup complete. Reboot/relogin  ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo
    warn "Start bspwm session and launch: alacritty, polybar, picom, dunst"
    warn "Switch shell to fish: chsh -s \$(which fish)"
}

main "$@"