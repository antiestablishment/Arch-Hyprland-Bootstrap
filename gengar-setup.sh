#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

trap 'printf "\nFailed at line %s. Review the output above.\n" "$LINENO"' ERR

if [[ "$EUID" -eq 0 || "$(id -un)" != "gengar" ]]; then
  echo "Run this as gengar, not as root."
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo "This build expects a working UEFI installation."
  exit 1
fi

if [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
  echo "The root filesystem must be Btrfs."
  exit 1
fi

sudo -v

echo "This script does not configure Limine or disk encryption."
echo "Your encrypted Arch installation must already boot using Limine."
read -r -p "Type READY to continue: " answer
[[ "$answer" == "READY" ]] || exit 1

packages=(
  base-devel
  git
  sudo
  btrfs-progs
  intel-ucode
  mesa
  vulkan-intel
  intel-media-driver
  hyprland
  hyprlock
  hypridle
  waybar
  ghostty
  firefox
  fuzzel
  mako
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  polkit
  polkit-gnome
  pipewire
  pipewire-alsa
  pipewire-pulse
  wireplumber
  networkmanager
  bluez
  bluez-utils
  blueman
  brightnessctl
  playerctl
  pavucontrol
  grim
  slurp
  wl-clipboard
  cliphist
  libnotify
  jq
  noto-fonts
  noto-fonts-emoji
  ttf-dejavu
  ttf-jetbrains-mono-nerd
  snapper
  snap-pac
  zram-generator
  plymouth
  python-pillow
)

sudo pacman -Syu --needed "${packages[@]}"

sudo hostnamectl set-hostname arch
sudo timedatectl set-timezone Europe/London
sudo localectl set-keymap uk
sudo localectl set-x11-keymap gb

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable fstrim.timer

systemctl --user enable --now pipewire.socket
systemctl --user enable --now pipewire-pulse.socket
systemctl --user enable --now wireplumber.service

mkdir -p \
  "$HOME/.config/hypr" \
  "$HOME/.config/waybar" \
  "$HOME/.config/ghostty" \
  "$HOME/.config/fuzzel" \
  "$HOME/.config/mako" \
  "$HOME/.local/bin" \
  "$HOME/.local/share/gengar" \
  "$HOME/Pictures/Screenshots"

backup="$HOME/.local/share/gengar/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"

for item in hypr waybar ghostty fuzzel mako; do
  cp -a "$HOME/.config/$item" "$backup/$item"
done

if [[ -e "$HOME/.bash_profile" ]]; then
  cp -a "$HOME/.bash_profile" "$backup/bash_profile"
fi

if ! command -v yay >/dev/null 2>&1; then
  build="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$build/yay"

  echo
  echo "Review the yay PKGBUILD before building."
  less "$build/yay/PKGBUILD"
  read -r -p "Build yay? [y/N] " answer

  if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    (
      cd "$build/yay"
      makepkg -si
    )
  else
    echo "Skipping yay."
  fi

  rm -rf "$build"
fi

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

if [[ ! -e /etc/snapper/configs/root ]]; then
  if findmnt --mountpoint /.snapshots >/dev/null 2>&1; then
    echo "/.snapshots is already mounted."
    echo "Refusing to alter an existing snapshot layout."
    exit 1
  fi

  if [[ -e /.snapshots ]]; then
    sudo rmdir /.snapshots
  fi

  sudo snapper -c root create-config /
fi

sudo snapper -c root set-config \
  ALLOW_USERS=gengar \
  TIMELINE_CREATE=no \
  NUMBER_LIMIT=10 \
  NUMBER_LIMIT_IMPORTANT=5 \
  EMPTY_PRE_POST_CLEANUP=yes

sudo systemctl enable --now snapper-cleanup.timer

cat >"$HOME/.config/ghostty/config" <<'EOF'
font-family = JetBrainsMono Nerd Font
font-size = 11
background = 111c18
foreground = c1c497
cursor-color = d7c995
selection-background = 394b35
selection-foreground = e1e5bc
window-padding-x = 12
window-padding-y = 12

palette = 0=#23372b
palette = 1=#ff5345
palette = 2=#549e6a
palette = 3=#d7c995
palette = 4=#509475
palette = 5=#d2689c
palette = 6=#2dd5b7
palette = 7=#c1c497
palette = 8=#53685b
palette = 9=#ff7367
palette = 10=#75b987
palette = 11=#e5d9ad
palette = 12=#74b99a
palette = 13=#e291b6
palette = 14=#72e6ce
palette = 15=#e1e5bc
EOF

cat >"$HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
font=JetBrainsMono Nerd Font:size=11
prompt="♥ "
width=42
lines=12
terminal=ghostty -e

[colors]
background=111c18ff
text=c1c497ff
match=2dd5b7ff
selection=23372bff
selection-text=e1e5bcff
selection-match=2dd5b7ff
border=549e6aff

[border]
width=2
radius=10
EOF

cat >"$HOME/.config/mako/config" <<'EOF'
font=JetBrainsMono Nerd Font 11
background-color=#111c18
text-color=#c1c497
border-color=#549e6a
border-size=2
border-radius=10
padding=12
default-timeout=5000
EOF

cat >"$HOME/.config/hypr/hyprlock.conf" <<'EOF'
general {
    hide_cursor = true
}

background {
    monitor =
    color = rgb(111c18)
}

label {
    monitor =
    text = ♥ gengar
    color = rgb(c1c497)
    font_size = 36
    font_family = DejaVu Sans
    position = 0, 110
    halign = center
    valign = center
}

input-field {
    monitor =
    size = 300, 55
    outline_thickness = 2
    outer_color = rgb(549e6a)
    inner_color = rgb(23372b)
    font_color = rgb(c1c497)
    placeholder_text = Unlock
    position = 0, 0
    halign = center
    valign = center
}
EOF

cat >"$HOME/.config/hypr/hypridle.conf" <<'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 360
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1200
    on-timeout = systemctl suspend
}
EOF

cat >"$HOME/.config/waybar/config.jsonc" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "spacing": 12,
  "modules-left": ["custom/gengar", "hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": [
    "tray",
    "network",
    "pulseaudio",
    "backlight",
    "battery"
  ],
  "custom/gengar": {
    "format": "♥",
    "tooltip-format": "gengar",
    "on-click": "~/.local/bin/gengar-menu"
  },
  "hyprland/workspaces": {
    "format": "{name}",
    "on-click": "activate"
  },
  "clock": {
    "format": "{:%a %d %b  %H:%M}",
    "tooltip-format": "{:%Y-%m-%d}"
  },
  "network": {
    "format-wifi": "Wi-Fi {signalStrength}%",
    "format-ethernet": "Ethernet",
    "format-disconnected": "Offline",
    "on-click": "ghostty -e nmtui"
  },
  "pulseaudio": {
    "format": "Vol {volume}%",
    "format-muted": "Muted",
    "on-click": "pavucontrol"
  },
  "backlight": {
    "format": "Light {percent}%"
  },
  "battery": {
    "format": "Bat {capacity}%",
    "format-charging": "+ {capacity}%",
    "states": {
      "warning": 25,
      "critical": 10
    }
  },
  "tray": {
    "spacing": 8
  }
}
EOF

cat >"$HOME/.config/waybar/style.css" <<'EOF'
* {
  font-family: "JetBrainsMono Nerd Font";
  font-size: 12px;
  min-height: 0;
}

window#waybar {
  background: #111c18;
  color: #c1c497;
  border-bottom: 2px solid #23372b;
}

#custom-gengar {
  color: #2dd5b7;
  padding: 0 14px;
  font-size: 19px;
}

#workspaces button {
  color: #c1c497;
  padding: 0 8px;
  border-radius: 0;
}

#workspaces button.active {
  background: #23372b;
  color: #2dd5b7;
}

#tray,
#network,
#pulseaudio,
#backlight,
#battery,
#clock {
  padding: 0 6px;
}

#battery.critical {
  color: #ff5345;
}
EOF

cat >"$HOME/.local/bin/gengar-update" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

echo "♥ gengar — system update"
echo
echo "Check Arch news before approving updates:"
echo "https://archlinux.org/news/"
echo
read -r -p "Continue? [y/N] " answer

if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
  exit 0
fi

if command -v yay >/dev/null 2>&1; then
  yay -Syu
  status=$?
else
  sudo pacman -Syu
  status=$?
fi

echo
printf "Update command exited with status %s.\n" "$status"
read -r -p "Press Enter to close."
exit "$status"
EOF

cat >"$HOME/.local/bin/gengar-shot" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

region="$(slurp)" || exit 0
file="$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

grim -g "$region" "$file"
wl-copy --type image/png <"$file"
notify-send "♥ Screenshot" "Saved and copied to clipboard."
EOF

cat >"$HOME/.local/bin/gengar-keys" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

hyprctl binds -j |
  jq -r '
    .[] |
    select(.description != null and .description != "") |
    .description
  ' |
  sort -u |
  fuzzel --dmenu --prompt="♥ Keybindings: " >/dev/null || true
EOF

cat >"$HOME/.local/bin/gengar-menu" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

choose() {
  fuzzel --dmenu --prompt="♥ gengar: "
}

confirm() {
  local answer
  answer="$(printf "Cancel\nConfirm\n" | choose)" || return 1
  [[ "$answer" == "Confirm" ]]
}

choice="$(
  printf '%s\n' \
    "System Options" \
    "Update" \
    "About" \
    "Keybindings" \
    "Wi-Fi" \
    "Bluetooth" \
    "Audio" |
    choose
)" || exit 0

case "$choice" in
  "System Options")
    action="$(
      printf '%s\n' \
        "Lock" \
        "Suspend" \
        "Log out" \
        "Reboot" \
        "Shut down" |
        choose
    )" || exit 0

    case "$action" in
      "Lock") loginctl lock-session ;;
      "Suspend") systemctl suspend ;;
      "Log out")
        if confirm; then
          hyprctl dispatch exit
        fi
        ;;
      "Reboot")
        if confirm; then
          systemctl reboot
        fi
        ;;
      "Shut down")
        if confirm; then
          systemctl poweroff
        fi
        ;;
    esac
    ;;
  "Update")
    ghostty -e "$HOME/.local/bin/gengar-update"
    ;;
  "About")
    {
      printf "♥ gengar\n"
      printf "Host: %s\n" "$(hostname)"
      printf "Kernel: %s\n" "$(uname -r)"
      printf "Desktop: Hyprland\n"
      printf "Theme: Osaka Jade inspired\n"
      printf "Independent Arch configuration\n"
    } | fuzzel --dmenu --prompt="About: " >/dev/null || true
    ;;
  "Keybindings")
    "$HOME/.local/bin/gengar-keys"
    ;;
  "Wi-Fi") ghostty -e nmtui ;;
  "Bluetooth") blueman-manager ;;
  "Audio") pavucontrol ;;
esac
EOF

chmod +x "$HOME/.local/bin"/gengar-*

cat >"$HOME/.config/hypr/hyprland.conf" <<'EOF'
monitor = , preferred, auto, 1

$terminal = ghostty
$browser = firefox
$tools = ~/.local/bin

env = XCURSOR_SIZE,24

exec-once = dbus-update-activation-environment --systemd --all
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = waybar
exec-once = mako
exec-once = hypridle
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store

input {
    kb_layout = gb
    follow_mouse = 1

    touchpad {
        natural_scroll = true
        tap-to-click = true
        disable_while_typing = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgb(549e6a)
    col.inactive_border = rgb(23372b)
    layout = dwindle
}

decoration {
    rounding = 8

    blur {
        enabled = true
        size = 3
        passes = 2
    }

    shadow {
        enabled = true
        range = 12
        render_power = 3
        color = rgba(00000055)
    }
}

animations {
    enabled = true
    bezier = gentle, 0.2, 0.8, 0.2, 1.0
    animation = windows, 1, 3, gentle
    animation = fade, 1, 3, default
    animation = workspaces, 1, 3, gentle
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    background_color = rgb(111c18)
}

bindd = SUPER, Return, Super+Enter — Terminal, exec, $terminal
bindd = SUPER, B, Super+B — Firefox, exec, $browser
bindd = SUPER, Space, Super+Space — Applications, exec, fuzzel
bindd = SUPER ALT, Space, Super+Alt+Space — Menu, exec, $tools/gengar-menu
bindd = SUPER, K, Super+K — Keybindings, exec, $tools/gengar-keys
bindd = SUPER, W, Super+W — Close window, killactive,
bindd = SUPER, F, Super+F — Fullscreen, fullscreen, 0
bindd = SUPER, T, Super+T — Floating, togglefloating,
bindd = SUPER, J, Super+J — Toggle split, togglesplit,
bindd = SUPER, P, Super+P — Pseudotile, pseudo,
bindd = SUPER CTRL, L, Super+Ctrl+L — Lock, exec, loginctl lock-session
bindd = , Print, Print — Screenshot region, exec, $tools/gengar-shot
bindd = SUPER, V, Super+V — Clipboard history, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy

bindd = SUPER, left, Super+Left — Focus left, movefocus, l
bindd = SUPER, right, Super+Right — Focus right, movefocus, r
bindd = SUPER, up, Super+Up — Focus up, movefocus, u
bindd = SUPER, down, Super+Down — Focus down, movefocus, d

bindd = SUPER SHIFT, left, Super+Shift+Left — Move left, movewindow, l
bindd = SUPER SHIFT, right, Super+Shift+Right — Move right, movewindow, r
bindd = SUPER SHIFT, up, Super+Shift+Up — Move up, movewindow, u
bindd = SUPER SHIFT, down, Super+Shift+Down — Move down, movewindow, d

bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl = , XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous

bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow

source = ~/.config/hypr/workspaces.conf
source = ~/.config/hypr/personal.conf
EOF

: >"$HOME/.config/hypr/workspaces.conf"

for workspace in {1..10}; do
  key="$workspace"
  [[ "$workspace" == "10" ]] && key=0

  printf \
    'bindd = SUPER, %s, Super+%s — Workspace %s, workspace, %s\n' \
    "$key" "$key" "$workspace" "$workspace" \
    >>"$HOME/.config/hypr/workspaces.conf"

  printf \
    'bindd = SUPER SHIFT, %s, Super+Shift+%s — Send to %s, movetoworkspace, %s\n' \
    "$key" "$key" "$workspace" "$workspace" \
    >>"$HOME/.config/hypr/workspaces.conf"
done

touch "$HOME/.config/hypr/personal.conf"

if ! grep -q '# gengar session' "$HOME/.bash_profile" 2>/dev/null; then
  cat >>"$HOME/.bash_profile" <<'EOF'

# gengar session
export PATH="$HOME/.local/bin:$PATH"

if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" ]]; then
  if [[ "$(tty)" == "/dev/tty1" ]]; then
    exec Hyprland
  fi
fi
EOF
fi

xdg-mime default firefox.desktop x-scheme-handler/http || true
xdg-mime default firefox.desktop x-scheme-handler/https || true
xdg-mime default firefox.desktop text/html || true

sudo snapper -c root create \
  --description "gengar desktop installed" \
  --cleanup-algorithm number

echo
echo "♥ Desktop installation complete."
echo "Configuration backup: $backup"
echo
echo "Reboot to activate zram and start the desktop on tty1 login."
echo "Plymouth artwork and boot activation are the next steps."
