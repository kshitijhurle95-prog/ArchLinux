#!/usr/bin/env bash
# ==============================================================================
# Unified Single-Tick Small Floating Window & Tile Restore
# Executes float, resize, and center in one unified atomic batch.
# ==============================================================================

if hyprctl activewindow | grep -q 'floating: 0'; then
    # Small floating window dimensions (~58% screen scale)
    W=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.width / .scale) * 0.58) | floor')
    H=$(hyprctl monitors -j | jq '.[] | select(.focused) | ((.height / .scale) * 0.58) | floor')
    # Single atomic batch call for perfect frame synchronization
    hyprctl --batch "dispatch hl.dsp.window.float({action='set'}); dispatch hl.dsp.window.resize({x=${W}, y=${H}, relative=false}); dispatch hl.dsp.window.center()"
else
    hyprctl dispatch "hl.dsp.window.float({action='unset'})"
fi
