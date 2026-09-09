#!/usr/bin/env bash
set -Eeuo pipefail

art="$HOME/.local/share/gengar/art.txt"

if [[ ! -s "$art" ]]; then
  echo "Save your artwork to $art first."
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python - "$art" "$work/art.png" <<'PY'
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

source, destination = sys.argv[1:]
lines = Path(source).read_text().splitlines()

font = ImageFont.truetype(
    "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
    22,
)
label_font = ImageFont.truetype(
    "/usr/share/fonts/TTF/DejaVuSans.ttf",
    24,
)

probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
cell_width = max(
    probe.textlength(character, font=font)
    for line in lines
    for character in line
)
ascent, descent = font.getmetrics()
line_height = ascent + descent + 2

width = int(max(map(len, lines)) * cell_width) + 48
height = len(lines) * line_height + 96

image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

for row, line in enumerate(lines):
    for column, character in enumerate(line):
        draw.text(
            (24 + column * cell_width, 12 + row * line_height),
            character,
            font=font,
            fill="#c1c497",
        )

label = "♥ gengar"
label_width = draw.textlength(label, font=label_font)

draw.text(
    ((width - label_width) / 2, height - 54),
    label,
    font=label_font,
    fill="#2dd5b7",
)

image.save(destination)
PY

theme=/usr/share/plymouth/themes/gengar
sudo install -d "$theme"
sudo install -m 644 "$work/art.png" "$theme/art.png"

sudo tee "$theme/gengar.plymouth" >/dev/null <<'EOF'
[Plymouth Theme]
Name=gengar
Description=Personal Gengar splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/gengar
ScriptFile=/usr/share/plymouth/themes/gengar/gengar.script
EOF

sudo tee "$theme/gengar.script" >/dev/null <<'EOF'
Window.SetBackgroundTopColor(0.067, 0.110, 0.094);
Window.SetBackgroundBottomColor(0.067, 0.110, 0.094);

screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

art = Image("art.png");
scale = Math.Min(
    screen_width * 0.70 / art.GetWidth(),
    screen_height * 0.60 / art.GetHeight()
);
scale = Math.Min(scale, 1);

art = art.Scale(
    Math.Int(art.GetWidth() * scale),
    Math.Int(art.GetHeight() * scale)
);

logo = Sprite(art);
logo.SetX((screen_width - art.GetWidth()) / 2);
logo.SetY((screen_height - art.GetHeight()) / 2 - 45);

prompt_sprite = Sprite();
prompt_sprite.SetZ(10);

message_sprite = Sprite();
message_sprite.SetZ(10);

fun show_prompt(text) {
    image = Image.Text(text, 0.757, 0.769, 0.592);
    prompt_sprite.SetImage(image);
    prompt_sprite.SetX((Window.GetWidth() - image.GetWidth()) / 2);
    prompt_sprite.SetY(Window.GetHeight() * 0.82);
    prompt_sprite.SetOpacity(1);
}

fun display_normal() {
    prompt_sprite.SetOpacity(0);
}

fun display_password(prompt, bullets) {
    mask = "";
    for (i = 0; i < bullets; i++) {
        mask += "*";
    }
    show_prompt(prompt + " " + mask);
}

fun display_question(prompt, entry) {
    show_prompt(prompt + " " + entry);
}

fun display_message(text) {
    image = Image.Text(text, 0.757, 0.769, 0.592);
    message_sprite.SetImage(image);
    message_sprite.SetX((Window.GetWidth() - image.GetWidth()) / 2);
    message_sprite.SetY(Window.GetHeight() * 0.92);
}

Plymouth.SetDisplayNormalFunction(display_normal);
Plymouth.SetDisplayPasswordFunction(display_password);
Plymouth.SetDisplayQuestionFunction(display_question);
Plymouth.SetMessageFunction(display_message);
EOF

sudo plymouth-set-default-theme gengar

echo "♥ Plymouth theme installed and selected."
echo "Complete the initramfs and Limine steps before expecting it at boot."
