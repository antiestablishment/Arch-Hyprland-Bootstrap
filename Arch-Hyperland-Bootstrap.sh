#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Hyprland desktop bootstrap for Arch Linux
# Stages 0-9: base tools -> Hyprland -> Plymouth+LUKS -> configs
#             -> wallpaper tool -> keybind reference menu
# Review before running. Designed to be safe to re-run (idempotent
# where practical) if a stage fails partway through.
# ============================================================

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log()  { echo -e "${BOLD}${GREEN}==>${RESET} $1"; }
warn() { echo -e "${BOLD}${YELLOW}!!${RESET} $1"; }
err()  { echo -e "${BOLD}${RED}XX${RESET} $1"; }

confirm() {
  read -rp "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

USER_NAME=$(whoami)
HOME_DIR="$HOME"

log "Running as user: $USER_NAME"
if ! confirm "Continue with this user?"; then
  echo "Aborting. Re-run as the correct user."
  exit 1
fi

# ------------------------------------------------------------
# Stage 0: Base prep
# ------------------------------------------------------------
log "Stage 0: System update + base-devel"
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git wget unzip nano

if ! command -v yay &>/dev/null; then
  log "Installing yay (AUR helper)"
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
else
  log "yay already installed, skipping"
fi

# ------------------------------------------------------------
# Stage 1: Hyprland + Wayland essentials
# ------------------------------------------------------------
log "Stage 1: Hyprland core + Wayland stack"
sudo pacman -S --needed --noconfirm \
  hyprland hyprpaper swww hypridle hyprlock \
  xdg-desktop-portal xdg-desktop-portal-hyprland \
  qt5-wayland qt6-wayland \
  polkit-gnome \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  wl-clipboard cliphist \
  brightnessctl playerctl

if [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
  warn "hyprland.desktop session file not found."
  warn "This usually resolves after reinstalling the hyprland package cleanly."
fi

# --- Checkpoint: verify Hyprland actually launches before going further ---
echo
warn "CHECKPOINT: Before continuing, you should verify Hyprland launches cleanly."
echo "You will be dropped into a bare Hyprland session with no bar/launcher yet -"
echo "that's expected. Exit with 'hyprctl dispatch exit' or SUPER+M once confirmed."
echo
if confirm "Launch 'Hyprland' now to test?"; then
  set +e
  Hyprland
  HYPR_EXIT=$?
  set -e
  if [ $HYPR_EXIT -ne 0 ]; then
    warn "Hyprland exited with a non-zero status ($HYPR_EXIT)."
    if ! confirm "Continue with the rest of the install anyway?"; then
      echo "Aborting. Fix the Hyprland launch issue and re-run this script."
      exit 1
    fi
  else
    log "Hyprland launched and exited cleanly."
  fi
else
  warn "Skipping the test launch at your own discretion."
fi

# ------------------------------------------------------------
# Stage 2: Terminal + fonts
# ------------------------------------------------------------
log "Stage 2: Terminal and fonts"
sudo pacman -S --needed --noconfirm \
  alacritty \
  ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji ttf-font-awesome

# ------------------------------------------------------------
# Stage 3: Bar, notifications, launcher, screenshots, file manager
# ------------------------------------------------------------
log "Stage 3: Waybar, dunst, screenshot tools, Nautilus"
sudo pacman -S --needed --noconfirm \
  waybar dunst \
  grim slurp swappy \
  nautilus gvfs gvfs-mtp

LAUNCHER="walker"
log "Attempting to install walker (AUR)"
if ! yay -S --noconfirm walker; then
  warn "walker failed to build. Falling back to fuzzel."
  sudo pacman -S --needed --noconfirm fuzzel
  LAUNCHER="fuzzel"
fi
log "Launcher selected: $LAUNCHER"

# ------------------------------------------------------------
# Stage 4: Network, Bluetooth, theming tools
# ------------------------------------------------------------
log "Stage 4: Network, Bluetooth, GTK/Qt theming tools"
sudo pacman -S --needed --noconfirm \
  networkmanager network-manager-applet \
  bluez bluez-utils blueman \
  nwg-look qt5ct qt6ct

sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth

# ------------------------------------------------------------
# Stage 5: Remove SDDM (replaced by Plymouth + TTY autologin)
# ------------------------------------------------------------
log "Stage 5: Removing SDDM and its theme"

if pacman -Qi sddm &>/dev/null; then
  sudo systemctl disable sddm --now || true
  sudo pacman -Rns --noconfirm sddm || warn "sddm removal reported an issue - check manually"
else
  log "sddm not installed, skipping removal"
fi

if pacman -Qi sddm-astronaut-theme &>/dev/null; then
  sudo pacman -Rns --noconfirm sddm-astronaut-theme || true
fi

sudo rm -rf /etc/sddm.conf.d
log "SDDM removed."

# ------------------------------------------------------------
# Stage 6: Shared wallpaper location + initial background
# ------------------------------------------------------------
log "Stage 6: Shared wallpaper setup"
sudo mkdir -p /usr/share/backgrounds/custom
sudo chown "$USER_NAME":"$USER_NAME" /usr/share/backgrounds/custom
sudo chmod 755 /usr/share/backgrounds/custom

WALLPAPER_TARGET="/usr/share/backgrounds/custom/desktop.jpg"

read -rp "Enter full path to a wallpaper image to use now (or leave blank to skip): " WALLPAPER_SRC
if [ -n "$WALLPAPER_SRC" ] && [ -f "$WALLPAPER_SRC" ]; then
  cp "$WALLPAPER_SRC" "$WALLPAPER_TARGET"
  chmod 644 "$WALLPAPER_TARGET"
  log "Wallpaper set: $WALLPAPER_TARGET"
else
  warn "No wallpaper set yet. Copy one manually later to $WALLPAPER_TARGET"
fi

# ------------------------------------------------------------
# Stage 6b: Choose wallpaper daemon - hyprpaper or swww
# ------------------------------------------------------------
echo
echo "Choose your wallpaper daemon:"
echo "  1) hyprpaper (Hyprland-native, simple, no transitions)"
echo "  2) swww (animated transitions, slightly heavier)"
read -rp "Enter 1 or 2 [default: 1]: " WP_CHOICE
WP_CHOICE=${WP_CHOICE:-1}

if [ "$WP_CHOICE" = "2" ]; then
  WP_DAEMON="swww"
else
  WP_DAEMON="hyprpaper"
fi
log "Wallpaper daemon selected: $WP_DAEMON"

# ------------------------------------------------------------
# Stage 7: Config files
# ------------------------------------------------------------
log "Stage 7: Writing Hyprland/Waybar/hyprlock/hypridle configs"
mkdir -p "$HOME_DIR/.config/hypr" "$HOME_DIR/.config/waybar" "$HOME_DIR/.config/dunst" "$HOME_DIR/.local/bin"

if [ -f "$HOME_DIR/.config/hypr/hyprland.conf" ]; then
  warn "Existing hyprland.conf found - backing up to hyprland.conf.bak"
  cp "$HOME_DIR/.config/hypr/hyprland.conf" "$HOME_DIR/.config/hypr/hyprland.conf.bak"
fi

if [ "$WP_DAEMON" = "swww" ]; then
  WP_EXEC_LINE="exec-once = swww-daemon"
else
  WP_EXEC_LINE="exec-once = hyprpaper"
fi

cat > "$HOME_DIR/.config/hypr/hyprland.conf" <<EOF
monitor=,preferred,auto,1

exec-once = waybar
exec-once = dunst
exec-once = hypridle
$WP_EXEC_LINE
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = nm-applet --indicator
exec-once = wl-paste --watch cliphist store

env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORMTHEME,qt5ct
env = ELECTRON_OZONE_PLATFORM_HINT,wayland

input {
    kb_layout = us
    follow_mouse = 1
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
}

decoration {
    rounding = 8
}

\$mainMod = SUPER

bind = \$mainMod, RETURN, exec, alacritty
bind = \$mainMod, E, exec, nautilus
bind = \$mainMod, SPACE, exec, $LAUNCHER
bind = \$mainMod, Q, killactive,
bind = \$mainMod, M, exit,
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, F, fullscreen,
bind = \$mainMod, L, exec, hyprlock
bind = \$mainMod, SLASH, exec, ~/.local/bin/show-keybinds.sh
bind = , PRINT, exec, grim -g "\$(slurp)" - | swappy -f -
bind = \$mainMod SHIFT, W, exec, ~/.local/bin/set-wallpaper.sh

bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3

bindl = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindl = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
EOF

if [ "$WP_DAEMON" = "hyprpaper" ]; then
  cat > "$HOME_DIR/.config/hypr/hyprpaper.conf" <<EOF
preload = $WALLPAPER_TARGET
wallpaper = ,$WALLPAPER_TARGET
EOF
fi

cat > "$HOME_DIR/.config/hypr/hypridle.conf" <<EOF
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}
EOF

cat > "$HOME_DIR/.config/hypr/hyprlock.conf" <<EOF
background {
    path = $WALLPAPER_TARGET
    blur_passes = 2
    blur_size = 7
}

input-field {
    monitor =
    size = 300, 60
    outline_thickness = 2
    dots_size = 0.25
    dots_spacing = 0.3
    outer_color = rgba(255, 255, 255, 0.6)
    inner_color = rgba(20, 20, 20, 0.6)
    font_color = rgb(255, 255, 255)
    placeholder_text = Enter password...
    position = 0, -60
    halign = center
    valign = center
}

label {
    text = cmd[update:1000] echo "\$(date +'%H:%M')"
    color = rgba(255, 255, 255, 0.9)
    font_size = 64
    position = 0, 100
    halign = center
    valign = center
}
EOF

cat > "$HOME_DIR/.config/waybar/config.jsonc" <<EOF
{
  "layer": "top",
  "position": "top",
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery"]
}
EOF

cat > "$HOME_DIR/.config/waybar/style.css" <<EOF
* {
  font-family: "JetBrainsMono Nerd Font";
  font-size: 13px;
}
window#waybar {
  background: rgba(20, 20, 20, 0.8);
  color: #ffffff;
}
EOF

# ------------------------------------------------------------
# Stage 8: Wallpaper picker script
# ------------------------------------------------------------
log "Stage 8: Installing wallpaper picker script"
mkdir -p "$HOME_DIR/Pictures/wallpapers"

cat > "$HOME_DIR/.local/bin/set-wallpaper.sh" <<PICKER
#!/usr/bin/env bash
set -euo pipefail

WALLPAPER_DIR="\$HOME/Pictures/wallpapers"
TARGET="$WALLPAPER_TARGET"
DAEMON="$WP_DAEMON"

mapfile -t FILES < <(find "\$WALLPAPER_DIR" -maxdepth 1 -type f \\
  \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) \\
  | sort)

if [ \${#FILES[@]} -eq 0 ]; then
  notify-send "Wallpaper" "No images found in \$WALLPAPER_DIR"
  exit 1
fi

CHOICE=\$(printf '%s\\n' "\${FILES[@]##*/}" | fuzzel --dmenu --prompt="Wallpaper: ")

if [ -z "\$CHOICE" ]; then
  exit 0
fi

SELECTED=""
for f in "\${FILES[@]}"; do
  if [ "\${f##*/}" = "\$CHOICE" ]; then
    SELECTED="\$f"
    break
  fi
done

if [ -z "\$SELECTED" ]; then
  notify-send "Wallpaper" "Selection not found"
  exit 1
fi

cp "\$SELECTED" "\$TARGET"
chmod 644 "\$TARGET"

if [ "\$DAEMON" = "swww" ]; then
  swww img "\$TARGET" --transition-type any
else
  hyprctl hyprpaper unload all
  hyprctl hyprpaper preload "\$TARGET"
  hyprctl hyprpaper wallpaper ",\$TARGET"
fi

notify-send "Wallpaper" "Set to \$(basename "\$SELECTED")"
PICKER

chmod +x "$HOME_DIR/.local/bin/set-wallpaper.sh"

if [ -n "$WALLPAPER_SRC" ] && [ -f "$WALLPAPER_SRC" ]; then
  cp "$WALLPAPER_SRC" "$HOME_DIR/Pictures/wallpapers/" 2>/dev/null || true
fi

# ------------------------------------------------------------
# Stage 8b: Keybind reference menu
# ------------------------------------------------------------
log "Stage 8b: Installing keybind reference script"

cat > "$HOME_DIR/.local/bin/show-keybinds.sh" <<'KEYBINDS'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/hypr/hyprland.conf"

if [ ! -f "$CONFIG" ]; then
  notify-send "Keybinds" "hyprland.conf not found"
  exit 1
fi

LIST=$(grep -E '^\s*bind[lme]?\s*=' "$CONFIG" | \
  sed -E 's/^\s*bind[lme]?\s*=\s*//' | \
  awk -F',' '{
    mod=$1; key=$2;
    gsub(/^ +| +$/, "", mod);
    gsub(/^ +| +$/, "", key);
    action="";
    for (i=3; i<=NF; i++) {
      action = action $i (i<NF ? "," : "");
    }
    gsub(/^ +| +$/, "", action);
    combo = (mod == "" ? key : mod " + " key);
    printf "%-28s %s\n", combo, action;
  }')

if [ -z "$LIST" ]; then
  notify-send "Keybinds" "No binds found in config"
  exit 1
fi

echo "$LIST" | fuzzel --dmenu --prompt="Keybinds: " --width=80 >/dev/null || true
KEYBINDS

chmod +x "$HOME_DIR/.local/bin/show-keybinds.sh"

# ------------------------------------------------------------
# Stage 9: Plymouth + LUKS splash + TTY autologin (HIGH RISK)
# ------------------------------------------------------------
echo
warn "=================================================================="
warn " STAGE 9: BOOT-CRITICAL CHANGES AHEAD"
warn "=================================================================="
echo "This stage modifies /etc/mkinitcpio.conf, rebuilds your initramfs,"
echo "and edits your Limine boot entry. A mistake here can leave the"
echo "system unable to boot."
echo
echo "Before continuing, confirm you have:"
echo "  1. A backup of /etc/mkinitcpio.conf"
echo "  2. A backup of your Limine config file"
echo "  3. A live USB (Arch ISO or similar) available to chroot and"
echo "     repair the system if something goes wrong"
echo
if ! confirm "Do you have all THREE of the above ready?"; then
  err "Aborting Stage 9. Re-run this script later once you're prepared -"
  err "everything up to this point (Stages 0-8b) is already installed and safe."
  exit 1
fi

log "Backing up mkinitcpio.conf"
sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak.$(date +%s)

LIMINE_CONF=""
for candidate in /boot/limine.conf /boot/limine.cfg /boot/EFI/limine/limine.conf; do
  if [ -f "$candidate" ]; then
    LIMINE_CONF="$candidate"
    break
  fi
done

if [ -z "$LIMINE_CONF" ]; then
  err "Could not auto-locate your Limine config file."
  read -rp "Enter the full path to your limine.conf/limine.cfg: " LIMINE_CONF
  if [ ! -f "$LIMINE_CONF" ]; then
    err "That path doesn't exist. Aborting Stage 9."
    exit 1
  fi
fi

log "Found Limine config: $LIMINE_CONF"
sudo cp "$LIMINE_CONF" "${LIMINE_CONF}.bak.$(date +%s)"
log "Backed up to ${LIMINE_CONF}.bak.*"

echo
log "Your current mkinitcpio HOOKS line:"
grep "^HOOKS=" /etc/mkinitcpio.conf
echo
warn "Plymouth must be inserted BEFORE your encrypt/sd-encrypt hook, and"
warn "AFTER 'base udev'. This script will NOT guess your hook order for you."
echo
if ! confirm "Have you manually reviewed the HOOKS line above and are ready to edit it yourself?"; then
  err "Aborting Stage 9. Edit /etc/mkinitcpio.conf HOOKS manually, adding"
  err "'plymouth' immediately before your encrypt hook, then re-run this"
  err "script - it will detect the manual edit and skip re-prompting if"
  err "'plymouth' is already present in HOOKS."
  exit 1
fi

if grep -q "plymouth" /etc/mkinitcpio.conf; then
  log "'plymouth' already present in HOOKS, skipping manual edit step."
else
  sudo nano /etc/mkinitcpio.conf
  echo
  if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
    err "'plymouth' still not found in HOOKS after edit. Aborting - rebuilding"
    err "initramfs without it would skip the splash entirely."
    exit 1
  fi
  log "Confirmed 'plymouth' is now present in HOOKS."
fi

log "Installing plymouth and a theme"
sudo pacman -S --needed --noconfirm plymouth

if ! yay -S --noconfirm plymouth-theme-arch-elegant; then
  warn "plymouth-theme-arch-elegant failed to build."
  warn "Falling back to the default plymouth theme (spinner)."
  PLYMOUTH_THEME="spinner"
else
  PLYMOUTH_THEME="arch-elegant"
fi

sudo plymouth-set-default-theme -R "$PLYMOUTH_THEME" || \
  warn "Could not set theme via plymouth-set-default-theme, check manually with 'plymouth-set-default-theme -l'"

log "Regenerating initramfs (this may take a minute)"
sudo mkinitcpio -P

echo
log "Current Limine config kernel command line entries (cmdline/CMDLINE):"
grep -iE "cmdline|CMDLINE" "$LIMINE_CONF" || warn "No cmdline lines found - check format manually"
echo
warn "You need to manually add 'splash' to the kernel cmdline in $LIMINE_CONF"
warn "(alongside your existing rd.luks.name=... or cryptdevice=... parameters)."
echo
if confirm "Open $LIMINE_CONF now to add 'splash' to the cmdline?"; then
  sudo nano "$LIMINE_CONF"
else
  warn "Skipped. You must add 'splash' manually before rebooting or the"
  warn "Plymouth splash will not appear."
fi

# ------------------------------------------------------------
# Stage 9b: TTY autologin (replaces SDDM login)
# ------------------------------------------------------------
echo
log "Stage 9b: Configuring TTY1 autologin for $USER_NAME"

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --noclear %I \$TERM
EOF

sudo systemctl daemon-reload
sudo systemctl enable getty@tty1.service

PROFILE_FILE="$HOME_DIR/.bash_profile"
if [ -f "$HOME_DIR/.zprofile" ]; then
  PROFILE_FILE="$HOME_DIR/.zprofile"
fi

if ! grep -q "exec Hyprland" "$PROFILE_FILE" 2>/dev/null; then
  cat >> "$PROFILE_FILE" <<'AUTOSTART'

# Auto-start Hyprland on tty1 only, and only if not already in a
# graphical session (prevents relaunch if you ssh in or switch TTYs)
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec Hyprland
fi
AUTOSTART
  log "Added Hyprland autostart to $PROFILE_FILE"
else
  log "Hyprland autostart already present in $PROFILE_FILE, skipping"
fi

warn "=================================================================="
warn "SECURITY NOTE: SDDM has been removed. LUKS passphrase is now the"
warn "ONLY prompt between power-on and a fully unlocked desktop session."
warn "hyprlock (SUPER+L, and hypridle's 300s timeout) is the only"
warn "protection for an already-running session. Adjust the hypridle"
warn "timeout in ~/.config/hypr/hypridle.conf if 300s doesn't match your"
warn "risk tolerance."
warn "=================================================================="

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
echo
log "Install complete."
echo "Summary:"
echo "  - Launcher installed: $LAUNCHER (bound to SUPER+SPACE)"
echo "  - Wallpaper daemon: $WP_DAEMON"
echo "  - Lock screen: SUPER+L (hyprlock)"
echo "  - Wallpaper picker: SUPER+SHIFT+W"
echo "  - Keybind reference menu: SUPER+/ (show-keybinds.sh)"
echo "  - Wallpaper source folder: ~/Pictures/wallpapers"
echo "  - Shared wallpaper file: $WALLPAPER_TARGET"
echo "  - SDDM: removed"
echo "  - Plymouth theme: $PLYMOUTH_THEME"
echo "  - TTY1 autologin -> exec Hyprland: enabled for $USER_NAME"
echo
warn "DO NOT reboot yet if you skipped adding 'splash' to $LIMINE_CONF."
echo "Next steps:"
echo "  1. Confirm 'splash' is in your Limine cmdline (see above)"
echo "  2. Reboot: sudo reboot"
echo "  3. Watch for the Plymouth splash + LUKS prompt during boot"
echo "  4. If it fails to boot, use your live USB to chroot in and restore:"
echo "     - /etc/mkinitcpio.conf.bak.* -> /etc/mkinitcpio.conf, then"
echo "       'mkinitcpio -P' again"
echo "     - ${LIMINE_CONF}.bak.* -> $LIMINE_CONF"
