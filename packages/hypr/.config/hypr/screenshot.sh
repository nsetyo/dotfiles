#!/usr/bin/env bash
# Screenshot Hyprland: grim + slurp.
# Pakai: screenshot.sh area | full
# Hasilnya disimpan ke ~/Pictures/Screenshots/ dan disalin ke clipboard,
# lalu mako menampilkan notifikasi.
set -euo pipefail

mkdir -p "$HOME/Pictures/Screenshots"
file="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"

if [ "${1:-area}" = "full" ]; then
  grim "$file"
else
  grim -g "$(slurp)" "$file"
fi

wl-copy < "$file"
notify-send "Screenshot tersimpan" "$file"
