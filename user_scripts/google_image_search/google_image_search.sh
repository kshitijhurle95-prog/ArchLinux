#!/usr/bin/env bash
set -euo pipefail
GEOM=$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1 2>/dev/null) || exit 0
TMP=$(mktemp /tmp/lens-XXXXXX.png)
trap 'rm -f "$TMP"' EXIT
grim -g "$GEOM" "$TMP"
notify-send -a "Google Lens" "Uploading..." "Uploading screenshot for visual search"
RESPONSE=$(curl -sSf -F "files[]=@${TMP}" 'https://uguu.se/upload' 2>/dev/null || true)
if [[ -n "$RESPONSE" ]]; then
    URL=$(echo "$RESPONSE" | jq -r '.files[0].url // empty')
    if [[ -n "$URL" ]]; then
        xdg-open "https://lens.google.com/uploadbyurl?url=${URL}" &
        exit 0
    fi
fi
wl-copy < "$TMP"
notify-send -a "Google Lens" "Ready" "Screenshot copied. Paste (Ctrl+V) into Google Lens."
xdg-open "https://lens.google.com/" &
