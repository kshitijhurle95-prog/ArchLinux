#!/usr/bin/env python3
"""
screen_rotate.py - Instant Screen Rotation Utility for Hyprland 0.56+
Rotates the focused display +90° or -90° using Hyprland 0.56 Lua API.
"""

import sys
import json
import subprocess

def get_focused_monitor():
    try:
        res = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True)
        monitors = json.loads(res.stdout)
        for m in monitors:
            if m.get("focused", False):
                return m
        if monitors:
            return monitors[0]
    except Exception:
        pass
    return {"name": "eDP-1", "transform": 0}

def rotate(delta):
    mon = get_focused_monitor()
    name = mon.get("name", "eDP-1")
    current_transform = mon.get("transform", 0)

    # 0: Normal (0°), 1: 90°, 2: 180°, 3: 270°
    if delta in ("+90", "90", "clockwise", "+1"):
        new_transform = (current_transform + 1) % 4
    elif delta in ("-90", "counterclockwise", "anticlockwise", "-1"):
        new_transform = (current_transform - 1) % 4
    else:
        new_transform = 0

    transform_names = {0: "Normal (0°)", 1: "90° Clockwise", 2: "180° Inverted", 3: "270° Counter-Clockwise"}
    
    lua_code = f"hl.monitor({{ output = '{name}', transform = {new_transform} }})"
    res = subprocess.run(["hyprctl", "eval", lua_code], capture_output=True, text=True)
    
    label = transform_names.get(new_transform, f"{new_transform}")
    subprocess.run(["notify-send", "-a", "Screen Rotation", "-i", "display", "Screen Rotated", f"Display: {name}\nOrientation: {label}"], capture_output=True)

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "+90"
    rotate(arg)
