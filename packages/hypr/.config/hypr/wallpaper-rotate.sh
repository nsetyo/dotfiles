#!/usr/bin/env bash
# wallpaper-rotate — download foto acak dari Unsplash API, set sebagai wallpaper via hyprpaper.
#
# Konfigurasi (file lokal, JANGAN di-commit ke repo):
#   ~/.config/hypr/wallpaper.env
#     UNSPLASH_ACCESS_KEY=...         # Access Key dari https://unsplash.com/developers
#     UNSPLASH_QUERY="dark mountains"  # tema foto (default: dark landscape)
#     WALLPAPER_WIDTH=1920            # default 1920
#     WALLPAPER_HEIGHT=1080           # default 1080
#
# Dijalankan harian oleh wallpaper-rotate.timer (systemd user).
# Manual: bash ~/.config/hypr/wallpaper-rotate.sh
set -euo pipefail

ENV_FILE="$HOME/.config/hypr/wallpaper.env"
if [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

: "${UNSPLASH_ACCESS_KEY:?UNSPLASH_ACCESS_KEY belum di-set di $ENV_FILE}"

QUERY="${UNSPLASH_QUERY:-dark landscape}"
WIDTH="${WALLPAPER_WIDTH:-1920}"
HEIGHT="${WALLPAPER_HEIGHT:-1080}"
OUT="$HOME/Pictures/wallpaper.jpg"
INFO="$HOME/Pictures/wallpaper.txt"

# hyprctl butuh HYPRLAND_INSTANCE_SIGNATURE; systemd user service tidak
# mewarisinya dari sesi Hyprland, jadi cari dari runtime dir.
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  for d in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hyprland/*/; do
    [ -S "$d/.socket.sock" ] && { export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$d")"; break; }
  done
fi

TMP="$(mktemp --suffix=.jpg)"
trap 'rm -f "$TMP"' EXIT

JSON="$(curl -fsSL -G "https://api.unsplash.com/photos/random" \
  --data-urlencode "client_id=$UNSPLASH_ACCESS_KEY" \
  --data-urlencode "query=$QUERY" \
  --data-urlencode "orientation=landscape" \
  --data-urlencode "content_filter=high")"

URL="$(printf '%s' "$JSON" | python3 -c 'import sys, json; print(json.load(sys.stdin)["urls"]["raw"])')"
PHOTOGRAPHER="$(printf '%s' "$JSON" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(d["user"]["name"] + " — " + d["links"]["html"])')"

curl -fsSL "$URL&fm=jpg&w=$WIDTH&h=$HEIGHT&fit=crop" -o "$TMP"
[ -s "$TMP" ] || { echo "Download gagal: file kosong" >&2; exit 1; }

mv "$TMP" "$OUT"
printf '%s\nTema: %s\n' "$PHOTOGRAPHER" "$QUERY" > "$INFO"

# Terapkan ke hyprpaper yang sedang jalan; fallback: restart hyprpaper.
hyprctl hyprpaper reload ",$OUT" || { pkill hyprpaper; nohup hyprpaper >/dev/null 2>&1 & disown; }
echo "Wallpaper baru: $PHOTOGRAPHER"
