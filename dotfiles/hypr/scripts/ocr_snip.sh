#!/usr/bin/env bash
set -euo pipefail
GEOM=$(slurp -b 00000033 -c 7aa2f7aa -s 00000000 -w 1 2>/dev/null) || exit 0
TMP=$(mktemp /tmp/ocr-XXXXXX.png)
trap 'rm -f "$TMP" "${TMP}.txt"' EXIT
grim -g "$GEOM" "$TMP"
tesseract "$TMP" "$TMP" -l eng --oem 1 -c tessedit_create_txt=1 &>/dev/null
if [[ -f "${TMP}.txt" ]]; then
    cat "${TMP}.txt" | wl-copy
    TEXT_PREVIEW=$(head -n 2 "${TMP}.txt" | tr '\n' ' ' | sed 's/^[ \t]*//;s/[ \t]*$//')
    notify-send -a "OCR" -i "edit-copy" "Text Extracted & Copied" "${TEXT_PREVIEW:-Text copied to clipboard}"
else
    notify-send -a "OCR" -u critical "OCR Error" "Could not extract text from selected region."
fi
