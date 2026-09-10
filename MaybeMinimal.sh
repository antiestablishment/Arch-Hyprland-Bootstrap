#!/usr/bin/env bash
#
# Arch Linux + Hyprland Bootstrap
#
# Installs a clean, minimally-configured Hyprland desktop on an
# existing Arch Linux installation.
#
# It deliberately does NOT:
#   - repartition disks
#   - configure bootloaders
#   - configure Btrfs/Snapper
#   - install a theme
#   - install Plymouth
#   - install a display manager
#   - overwrite existing Hyprland configuration
#
# Run as the normal user with sudo privileges.
#
# Usage:
#   chmod +x hyprland-bootstrap.sh
#   ./hyprland-bootstrap.sh
#

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

trap 'echo; echo "ERROR: $SCRIPT_NAME failed at line $LINENO."; exit 1' ERR

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
    printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2
}

die() {
    printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2
    exit 1
}

backup_file() {
    local file="$1"

    if [[ -e "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp -a "$file" "$backup"
        echo "Backed up:"
        echo "  $file"
        echo "  -> $backup"
    fi
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

[[ "$EUID" -ne 0 ]] ||
    die "Do not run this script as root. Run it as your normal user."

command -v sudo >/dev/null 2>&1 ||
    die "sudo is required."

command -v pacman >/dev/null 2>&1 ||
    die "This script is intended for Arch Linux."

sudo -v

USER_HOME="$HOME"

log "Arch + Hyprland bootstrap"

echo
echo "This script will install a minimal Hyprland desktop environment."
echo
echo "It will NOT:"
echo "  - repartition your disks"
echo "  - change your bootloader"
echo "  - install a display manager"
echo "  - install a theme"
echo "  - replace existing Hyprland configuration"
echo
read -r -p "Continue? [y/N] " answer

[[ "$answer" =~ ^[Yy]$ ]] || exit 0

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

log "Installing Hyprland and Wayland desktop packages"

PACKAGES=(
    # Compositor
    hyprland
    hyprlock
    hypridle

    # Launcher / notifications
    fuzzel
    mako

    # Bar
    waybar

    # Terminal
    foot

    # Wayland integration
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    # Authentication
    polkit
    polkit-gnome

    # Audio
    pipewire
    pipewire-alsa
    pipewire-pulse
    wireplumber
    pavucontrol

    # Network
    networkmanager
    network-manager-applet

    # Bluetooth
    bluez
    bluez-utils
    blueman

    # Brightness / media keys
    brightnessctl
    playerctl

    # Screenshots
    grim
    slurp

    # Clipboard
    wl-clipboard
    cliphist

    # Notifications
    libnotify

    # Utilities
    jq

    # Fonts
    noto-fonts
    noto-fonts-emoji
    ttf-dejavu
    ttf-jetbrains-mono-nerd
)

sudo pacman -Syu --needed "${PACKAGES[@]}"

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------

log "Enabling required system services"

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service

log "Enabling PipeWire user services"

systemctl --user enable --now pipewire.socket
systemctl --user enable --now pipewire-pulse.socket
systemctl --user enable --now wireplumber.service

# ---------------------------------------------------------------------------
# Directories
# ---------------------------------------------------------------------------

log "Creating configuration directories"

mkdir -p \
    "$USER_HOME/.config/hypr" \
    "$USER_HOME/.config/fuzzel" \
    "$USER_HOME/.config/mako" \
    "$USER_HOME/.config/waybar" \
    "$USER_HOME/.config/foot" \
    "$USER_HOME/.local/bin" \
    "$USER_HOME/Pictures/Screenshots"

# ---------------------------------------------------------------------------
# Hyprland configuration
# ---------------------------------------------------------------------------

HYPR="$USER_HOME/.config/hypr"

backup_file "$HYPR/hyprland.conf"

log "Installing Hyprland configuration"

cat > "$HYPR/hyprland.conf" <<'EOF'
# ============================================================================
# Hyprland
# Minimal Arch configuration
#
# Main configuration:
#   ~/.config/hypr/hyprland.conf
#
# Keybinds:
#   ~/.config/hypr/keybinds.conf
#
# Personal settings:
#   ~/.config/hypr/personal.conf
#
# Workspaces:
#   ~/.config/hypr/workspaces.conf
# ============================================================================

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

$terminal = foot
$launcher = fuzzel
$browser = firefox
$fileManager = foot -e yazi

$mainMod = SUPER

# ---------------------------------------------------------------------------
# Monitor
# ---------------------------------------------------------------------------
#
# "preferred" lets Hyprland choose the monitor's preferred mode.
#
# Once your system is working, this is one of the first things you may want
# to customise.
#

monitor = , preferred, auto, 1

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

env = XCURSOR_SIZE,24

# ---------------------------------------------------------------------------
# Autostart
# ---------------------------------------------------------------------------

exec-once = dbus-update-activation-environment --systemd --all
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

exec-once = waybar
exec-once = mako
exec-once = hypridle

exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

input {
    kb_layout = gb

    follow_mouse = 1

    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
#
# These values are deliberately conservative.
# Change them to suit your preferred look.
#

general {
    gaps_in = 5
    gaps_out = 10

    border_size = 2

    layout = dwindle

    # Placeholder colours.
    # Change these when creating your own theme.
    col.active_border = rgb(888888)
    col.inactive_border = rgb(444444)
}

# ---------------------------------------------------------------------------
# Decoration
# ---------------------------------------------------------------------------

decoration {
    rounding = 6

    blur {
        enabled = true
        size = 3
        passes = 2
    }

    shadow {
        enabled = true
        range = 10
        render_power = 2
    }
}

# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

animations {
    enabled = true

    bezier = default, 0.2, 0.8, 0.2, 1.0

    animation = windows, 1, 3, default
    animation = fade, 1, 3, default
    animation = workspaces, 1, 3, default
}

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------

dwindle {
    pseudotile = true
    preserve_split = true
}

# ---------------------------------------------------------------------------
# Miscellaneous
# ---------------------------------------------------------------------------

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

# ---------------------------------------------------------------------------
# External configuration
# ---------------------------------------------------------------------------

source = ~/.config/hypr/keybinds.conf
source = ~/.config/hypr/workspaces.conf
source = ~/.config/hypr/personal.conf
EOF

# ---------------------------------------------------------------------------
# Keybindings
# ---------------------------------------------------------------------------

backup_file "$HYPR/keybinds.conf"

log "Installing Hyprland keybindings"

cat > "$HYPR/keybinds.conf" <<'EOF'
# ============================================================================
# Hyprland keybindings
#
# SUPER = Windows / Meta key
#
# This file is intended to be customised.
# ============================================================================

# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------

bindd = $mainMod, RETURN, Launch terminal, exec, $terminal
bindd = $mainMod, D, Launch application launcher, exec, $launcher
bindd = $mainMod, B, Launch browser, exec, $browser

# File manager
bindd = $mainMod, E, Launch file manager, exec, $fileManager

# ---------------------------------------------------------------------------
# Window management
# ---------------------------------------------------------------------------

bindd = $mainMod, Q, Close active window, killactive
bindd = $mainMod, F, Toggle fullscreen, fullscreen, 0
bindd = $mainMod, SPACE, Toggle floating, togglefloating

# Toggle split
bindd = $mainMod, J, Toggle split orientation, togglesplit

# Toggle pseudo-tile
bindd = $mainMod, P, Toggle pseudotile, pseudo

# ---------------------------------------------------------------------------
# Focus
# ---------------------------------------------------------------------------

bindd = $mainMod, LEFT, Focus left, movefocus, l
bindd = $mainMod, RIGHT, Focus right, movefocus, r
bindd = $mainMod, UP, Focus up, movefocus, u
bindd = $mainMod, DOWN, Focus down, movefocus, d

# ---------------------------------------------------------------------------
# Move windows
# ---------------------------------------------------------------------------

bindd = $mainMod SHIFT, LEFT, Move window left, movewindow, l
bindd = $mainMod SHIFT, RIGHT, Move window right, movewindow, r
bindd = $mainMod SHIFT, UP, Move window up, movewindow, u
bindd = $mainMod SHIFT, DOWN, Move window down, movewindow, d

# ---------------------------------------------------------------------------
# Mouse
# ---------------------------------------------------------------------------

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

# ---------------------------------------------------------------------------
# Clipboard
# ---------------------------------------------------------------------------

bindd = $mainMod, V, Clipboard history, exec, \
    cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

# ---------------------------------------------------------------------------
# Screenshots
# ---------------------------------------------------------------------------

bindd = , PRINT, Screenshot selection, exec, ~/.local/bin/hypr-screenshot

# ---------------------------------------------------------------------------
# Lock screen
# ---------------------------------------------------------------------------

bindd = $mainMod CTRL, L, Lock screen, exec, loginctl lock-session

# ---------------------------------------------------------------------------
# Hyprland
# ---------------------------------------------------------------------------

bindd = $mainMod SHIFT, R, Reload Hyprland configuration, exec, hyprctl reload

# ---------------------------------------------------------------------------
# Audio
# ---------------------------------------------------------------------------

bindel = , XF86AudioRaiseVolume, Volume up, exec, \
    wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+

bindel = , XF86AudioLowerVolume, Volume down, exec, \
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-

bindl = , XF86AudioMute, Toggle mute, exec, \
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

bindl = , XF86AudioMicMute, Toggle microphone mute, exec, \
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

# ---------------------------------------------------------------------------
# Brightness
# ---------------------------------------------------------------------------

bindel = , XF86MonBrightnessUp, Brightness up, exec, \
    brightnessctl set +5%

bindel = , XF86MonBrightnessDown, Brightness down, exec, \
    brightnessctl set 5%-

# ---------------------------------------------------------------------------
# Media
# ---------------------------------------------------------------------------

bindl = , XF86AudioPlay, Play/pause, exec, playerctl play-pause
bindl = , XF86AudioNext, Next track, exec, playerctl next
bindl = , XF86AudioPrev, Previous track, exec, playerctl previous
EOF

# ---------------------------------------------------------------------------
# Workspaces
# ---------------------------------------------------------------------------

backup_file "$HYPR/workspaces.conf"

log "Creating workspace keybindings"

: > "$HYPR/workspaces.conf"

for workspace in {1..10}; do
    key="$workspace"

    if [[ "$workspace" == "10" ]]; then
        key="0"
    fi

    cat >> "$HYPR/workspaces.conf" <<EOF
bindd = \$mainMod, $key, Switch to workspace $workspace, workspace, $workspace
bindd = \$mainMod SHIFT, $key, Move window to workspace $workspace, movetoworkspace, $workspace
EOF
done

# Workspace scrolling
cat >> "$HYPR/workspaces.conf" <<'EOF'

bindd = $mainMod, mouse_down, Next workspace, workspace, e+1
bindd = $mainMod, mouse_up, Previous workspace, workspace, e-1
EOF

# ---------------------------------------------------------------------------
# Personal configuration
# ---------------------------------------------------------------------------

if [[ ! -e "$HYPR/personal.conf" ]]; then
    log "Creating personal Hyprland configuration"

    cat > "$HYPR/personal.conf" <<'EOF'
# ============================================================================
# Personal Hyprland configuration
#
# Put your own monitor rules, window rules, themes, special workspaces,
# application rules, etc. here.
#
# This file is intentionally NOT populated by the bootstrap script.
# ============================================================================

# Example:
#
# monitor = DP-1, 2560x1440@144, 0x0, 1
#
# Example window rule:
#
# windowrulev2 = float, class:^(pavucontrol)$
#
# Example application:
#
# $editor = nvim
EOF
fi

# ---------------------------------------------------------------------------
# Hypridle
# ---------------------------------------------------------------------------

backup_file "$HYPR/hypridle.conf"

log "Installing minimal Hypridle configuration"

cat > "$HYPR/hypridle.conf" <<'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

# Lock after 5 minutes.
listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

# Turn displays off after 6 minutes.
listener {
    timeout = 360
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
EOF

# ---------------------------------------------------------------------------
# Hyprlock
# ---------------------------------------------------------------------------

if [[ ! -e "$HYPR/hyprlock.conf" ]]; then
    log "Creating minimal Hyprlock configuration"

    cat > "$HYPR/hyprlock.conf" <<'EOF'
general {
    hide_cursor = true
}

background {
    monitor =
    color = rgb(111111)
}

input-field {
    monitor =

    size = 300, 55
    outline_thickness = 2

    outer_color = rgb(888888)
    inner_color = rgb(222222)

    font_color = rgb(ffffff)

    placeholder_text = <i>Enter password...</i>

    position = 0, 0
    halign = center
    valign = center
}
EOF
else
    echo "Existing hyprlock.conf found; leaving it untouched."
fi

# ---------------------------------------------------------------------------
# Fuzzel
# ---------------------------------------------------------------------------

if [[ ! -e "$USER_HOME/.config/fuzzel/fuzzel.ini" ]]; then
    log "Creating minimal Fuzzel configuration"

    cat > "$USER_HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
width=40
lines=12
terminal=foot -e

[border]
width=2
radius=6
EOF
else
    echo "Existing fuzzel.ini found; leaving it untouched."
fi

# ---------------------------------------------------------------------------
# Mako
# ---------------------------------------------------------------------------

if [[ ! -e "$USER_HOME/.config/mako/config" ]]; then
    log "Creating minimal Mako configuration"

    cat > "$USER_HOME/.config/mako/config" <<'EOF'
font=JetBrainsMono Nerd Font 11

background-color=#222222
text-color=#ffffff

border-color=#888888
border-size=2
border-radius=6

padding=10
default-timeout=5000
EOF
else
    echo "Existing Mako configuration found; leaving it untouched."
fi

# ---------------------------------------------------------------------------
# Foot
# ---------------------------------------------------------------------------

if [[ ! -e "$USER_HOME/.config/foot/foot.ini" ]]; then
    log "Creating minimal Foot configuration"

    cat > "$USER_HOME/.config/foot/foot.ini" <<'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
pad=8x8

[scrollback]
lines=10000
EOF
else
    echo "Existing Foot configuration found; leaving it untouched."
fi

# ---------------------------------------------------------------------------
# Waybar
# ---------------------------------------------------------------------------

if [[ ! -e "$USER_HOME/.config/waybar/config.jsonc" ]]; then
    log "Creating minimal Waybar configuration"

    cat > "$USER_HOME/.config/waybar/config.jsonc" <<'EOF'
{
    "layer": "top",
    "position": "top",

    "modules-left": [
        "hyprland/workspaces"
    ],

    "modules-center": [
        "clock"
    ],

    "modules-right": [
        "network",
        "pulseaudio",
        "battery",
        "tray"
    ],

    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },

    "clock": {
        "format": "{:%a %d %b %H:%M}"
    },

    "network": {
        "format-wifi": "{essid} {signalStrength}%",
        "format-ethernet": "Ethernet",
        "format-disconnected": "Offline"
    },

    "pulseaudio": {
        "format": "󰕾 {volume}%",
        "format-muted": "󰖁 Muted"
    },

    "battery": {
        "format": "{capacity}%"
    },

    "tray": {
        "spacing": 8
    }
}
EOF
else
    echo "Existing Waybar config found; leaving it untouched."
fi

if [[ ! -e "$USER_HOME/.config/waybar/style.css" ]]; then
    log "Creating neutral Waybar stylesheet"

    cat > "$USER_HOME/.config/waybar/style.css" <<'EOF'
/*
 * Minimal neutral Waybar stylesheet.
 *
 * This is deliberately boring.
 * Change it to create your own desktop aesthetic.
 */

* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
}

window#waybar {
    background: rgba(20, 20, 20, 0.90);
    color: #ffffff;
}

#workspaces button {
    padding: 0 8px;
    color: #aaaaaa;
}

#workspaces button.active {
    color: #ffffff;
}

#clock,
#network,
#pulseaudio,
#battery,
#tray {
    padding: 0 8px;
}
EOF
else
    echo "Existing Waybar stylesheet found; leaving it untouched."
fi

# ---------------------------------------------------------------------------
# Screenshot helper
# ---------------------------------------------------------------------------

log "Installing screenshot helper"

cat > "$USER_HOME/.local/bin/hypr-screenshot" <<'EOF'
#!/usr/bin/env bash

set -euo pipefail

mkdir -p "$HOME/Pictures/Screenshots"

region="$(slurp)" || exit 0

file="$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

grim -g "$region" "$file"

wl-copy --type image/png < "$file"

notify-send \
    "Screenshot saved" \
    "$file"
EOF

chmod +x "$USER_HOME/.local/bin/hypr-screenshot"

# ---------------------------------------------------------------------------
# Shell PATH
# ---------------------------------------------------------------------------

if ! grep -q 'HOME/.local/bin' "$USER_HOME/.bashrc" 2>/dev/null; then
    log "Adding ~/.local/bin to PATH"

    cat >> "$USER_HOME/.bashrc" <<'EOF'

# User-local executables
export PATH="$HOME/.local/bin:$PATH"
EOF
fi

# ---------------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------------

log "Fixing ownership"

sudo chown -R "$USER:$(id -gn)" \
    "$USER_HOME/.config/hypr" \
    "$USER_HOME/.config/fuzzel" \
    "$USER_HOME/.config/mako" \
    "$USER_HOME/.config/waybar" \
    "$USER_HOME/.config/foot" \
    "$USER_HOME/.local/bin"

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

log "Validating Hyprland configuration"

if command -v Hyprland >/dev/null 2>&1; then
    Hyprland -c "$HYPR/hyprland.conf" -d >/tmp/hyprland-bootstrap-check.log 2>&1 || true

    if grep -qiE 'error|invalid' /tmp/hyprland-bootstrap-check.log; then
        warn "Hyprland reported possible configuration problems."
        warn "Check /tmp/hyprland-bootstrap-check.log"
    fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo
echo "=============================================================="
echo " Hyprland bootstrap complete"
echo "=============================================================="
echo
echo "Installed:"
echo "  Hyprland"
echo "  Hyprlock / Hypridle"
echo "  Waybar"
echo "  Fuzzel"
echo "  Mako"
echo "  Foot"
echo "  PipeWire / WirePlumber"
echo "  NetworkManager"
echo "  Bluetooth"
echo "  wl-clipboard / cliphist"
echo "  grim / slurp"
echo
echo "Configuration:"
echo "  $HYPR/hyprland.conf"
echo "  $HYPR/keybinds.conf"
echo "  $HYPR/workspaces.conf"
echo "  $HYPR/personal.conf"
echo "  $HYPR/hyprlock.conf"
echo "  $HYPR/hypridle.conf"
echo
echo "Other configuration:"
echo "  ~/.config/waybar/"
echo "  ~/.config/fuzzel/"
echo "  ~/.config/mako/"
echo "  ~/.config/foot/"
echo
echo "Useful commands:"
echo "  hyprctl reload"
echo "  hyprctl monitors"
echo "  hyprctl clients"
echo "  hyprctl binds"
echo
echo "Start Hyprland from a TTY with:"
echo
echo "  Hyprland"
echo
echo "Or configure your preferred display/login manager separately."
echo
echo "Enjoy building your own desktop."
