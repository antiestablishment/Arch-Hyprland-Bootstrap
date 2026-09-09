#!/usr/bin/env python3

from pathlib import Path
import subprocess
import sys

directory = Path(__file__).resolve().parent

sources = [
    directory / "gengar-setup.sh",
    directory / "gengar-plymouth.sh",
]

for source in sources:
    if not source.is_file():
        sys.exit(f"Missing source script: {source}")

    result = subprocess.run(
        ["bash", "-n", str(source)],
        check=False,
    )

    if result.returncode:
        sys.exit(f"Bash syntax check failed: {source}")

artwork = """\
⠀⠀⠀⠀⢸⠓⢄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⠀⠀⠑⢤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⡆⠀⠀⠀⠙⢤⡷⣤⣦⣀⠤⠖⠚⡿⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⣠⡿⠢⢄⡀⠀⡇⠀⠀⠀⠀⠀⠉⠀⠀⠀⠀⠀⠸⠷⣶⠂⠀⠀⠀⣀⣀⠀⠀⠀
⢸⣃⠀⠀⠉⠳⣷⠞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠉⠉⠉⠉⢉⡭⠋
⠀⠘⣆⠀⠀⠀⠁⠀⢀⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡴⠋⠀⠀
⠀⠀⠘⣦⠆⠀⠀⢀⡎⢹⡀⠀⠀⠀⠀⠀⠀⠀⠀⡀⠀⠀⡀⣠⠔⠋⠀⠀⠀⠀
⠀⠀⠀⡏⠀⠀⣆⠘⣄⠸⢧⠀⠀⠀⠀⢀⣠⠖⢻⠀⠀⠀⣿⢥⣄⣀⣀⣀⠀⠀
⠀⠀⢸⠁⠀⠀⡏⢣⣌⠙⠚⠀⠀⠠⣖⡛⠀⣠⠏⠀⠀⠀⠇⠀⠀⠀⠀⢙⣣⠄
⠀⠀⢸⡀⠀⠀⠳⡞⠈⢻⠶⠤⣄⣀⣈⣉⣉⣡⡔⠀⠀⢀⠀⠀⣀⡤⠖⠚⠀⠀
⠀⠀⡼⣇⠀⠀⠀⠙⠦⣞⡀⠀⢀⡏⠀⢸⣣⠞⠀⠀⠀⡼⠚⠋⠁⠀⠀⠀⠀⠀
⠀⢰⡇⠙⠀⠀⠀⠀⠀⠀⠉⠙⠚⠒⠚⠉⠀⠀⠀⠀⡼⠁⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⢧⡀⠀⢠⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⣞⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠙⣶⣶⣿⠢⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠉⠀⠀⠀⠙⢿⣳⠞⠳⡄⠀⠀⠀⢀⡞⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀⠹⣄⣀⡤⠋⠀⠀⠀⠀⠀⠀
"""

header = """\
#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

trap 'echo "Installation failed at line $LINENO." >&2' ERR

if [[ "$EUID" -eq 0 || "$(id -un)" != "gengar" ]]; then
  echo "Run this as gengar, not with sudo."
  exit 1
fi

if [[ ! -d /sys/firmware/efi ]]; then
  echo "Boot the installed system in UEFI mode first."
  exit 1
fi

if [[ "$(findmnt -no FSTYPE /)" != "btrfs" ]]; then
  echo "This installer requires a Btrfs root filesystem."
  exit 1
fi

echo "♥ gengar — combined post-install setup"
echo
echo "This does not partition disks or install/configure Limine."
echo "Arch must already boot successfully through Limine."
echo "The intended storage layout is Btrfs on LUKS2, without LVM."
echo

sudo -v

# Required by the desktop script's browser association commands.
sudo pacman -Syu --needed xdg-utils

"""

art_section = """\
mkdir -p "$HOME/.local/share/gengar"

if [[ -e "$HOME/.local/share/gengar/art.txt" ]]; then
  cp -a \
    "$HOME/.local/share/gengar/art.txt" \
    "$HOME/.local/share/gengar/art.txt.$(date +%s).bak"
fi

cat >"$HOME/.local/share/gengar/art.txt" <<'GENGAR_ART_EOF'
"""

footer = """\

echo
echo "♥ gengar — combined setup completed"
echo
echo "The desktop and custom Plymouth theme are installed."
echo
echo "Before enabling the splash at boot:"
echo "1. Add plymouth to your existing mkinitcpio HOOKS."
echo "   Place it after systemd/udev and before the encryption hook."
echo "   Preserve your existing encrypt or sd-encrypt approach."
echo "2. Run: sudo mkinitcpio -P"
echo "3. Resolve any errors before rebooting."
echo "4. Append quiet splash to the existing Limine command line."
echo "   Preserve all encryption, root and subvolume arguments."
echo
echo "Snapper snapshots are configured."
echo "Automatic Limine snapshot boot entries are NOT configured."
echo
echo "The theme and shortcuts are Osaka Jade/Omarchy inspired,"
echo "not a verified reproduction of Omarchy 3.8.5."
"""


def embedded_script(source: Path, delimiter: str) -> str:
    content = source.read_text(encoding="utf-8")

    if delimiter in content.splitlines():
        sys.exit(f"Unexpected delimiter collision in {source}")

    return (
        f"\n# Embedded source: {source.name}\n"
        f"bash -s <<'{delimiter}'\n"
        f"{content.rstrip()}\n"
        f"{delimiter}\n"
    )


combined = (
    header
    + embedded_script(sources[0], "GENGAR_DESKTOP_SCRIPT_EOF")
    + "\n"
    + art_section
    + artwork
    + "GENGAR_ART_EOF\n"
    + embedded_script(sources[1], "GENGAR_PLYMOUTH_SCRIPT_EOF")
    + footer
)

output = directory / "gengar-install.sh"

if output.exists():
    sys.exit(
        f"Refusing to overwrite {output}. "
        "Move or delete the existing file first."
    )

output.write_text(combined, encoding="utf-8")
output.chmod(0o700)

result = subprocess.run(
    ["bash", "-n", str(output)],
    check=False,
)

if result.returncode:
    output.unlink()
    sys.exit("Combined script failed its Bash syntax check.")

print(f"Created: {output}")
print("Run as gengar: ./gengar-install.sh")
