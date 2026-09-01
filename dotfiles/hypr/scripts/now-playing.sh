#!/bin/bash
MAX_CHARS=40
if playerctl status 2>/dev/null | grep -q Playing; then
    title="$(playerctl metadata --format '{{ title }}' 2>/dev/null)"
    artist="$(playerctl metadata --format '{{ artist }}' 2>/dev/null)"
    text="$title - $artist"
    if [ "${#text}" -gt "$MAX_CHARS" ]; then
        text="${text:0:$((MAX_CHARS - 1))}…"
    fi
    text="$text     "
    len=${#text}
    if [ "$len" -gt 0 ]; then
        pos=$(( $(date +%s) % len ))
        echo "♪  ${text:$pos}${text:0:$pos}"
    else
        echo " "
    fi
else
    echo " "
fi
