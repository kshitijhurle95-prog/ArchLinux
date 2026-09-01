#!/usr/bin/env python3
"""
hypr-minmax.py - Safe Minimize/Maximize controller for Hyprland using JSON IPC
Avoids any internal Lua C++ eval crashes.
"""

import os
import sys
import json
import subprocess

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
STATE_FILE = os.path.join(RUNTIME_DIR, "hypr_minimized.json")

def hyprctl_json(cmd_args):
    try:
        res = subprocess.run(["hyprctl", "-j"] + cmd_args, capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return None

def hyprctl_dispatch(*args):
    try:
        subprocess.run(["hyprctl", "dispatch"] + list(args), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def is_overview_active():
    return os.path.exists("/tmp/ryoku_overview_active")

def load_state():
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return []

def save_state(windows):
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(windows, f)
    except Exception:
        pass

def sync_state():
    clients = hyprctl_json(["clients"]) or []
    minimized = []
    for c in clients:
        ws_name = c.get("workspace", {}).get("name", "")
        if ws_name.startswith("special:minimized"):
            minimized.append({
                "address": c.get("address"),
                "class": c.get("class", ""),
                "initialClass": c.get("initialClass", ""),
                "title": c.get("title", "")
            })
    save_state(minimized)
    return minimized

def ensure_dock_running():
    try:
        subprocess.Popen(["systemctl", "--user", "start", "hypr-minimized-dock.service"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def minimize(force_direct=False):
    if is_overview_active():
        return

    win = hyprctl_json(["activewindow"])
    if not win or not win.get("address"):
        return

    ws_name = win.get("workspace", {}).get("name", "")
    if ws_name.startswith("special:"):
        return

    addr = win.get("address")
    fullscreen = win.get("fullscreen", 0)

    if fullscreen != 0:
        hyprctl_dispatch("fullscreen", "0")
        if not force_direct:
            return

    # Move active window to special:minimized
    hyprctl_dispatch("movetoworkspacesilent", f"special:minimized,address:{addr}")

    # Update stack state
    current_stack = load_state()
    new_stack = [w for w in current_stack if w.get("address") != addr]
    new_stack.append({
        "address": addr,
        "class": win.get("class", ""),
        "initialClass": win.get("initialClass", ""),
        "title": win.get("title", "")
    })
    save_state(new_stack)
    ensure_dock_running()

def maximize():
    if is_overview_active():
        return

    clients = hyprctl_json(["clients"]) or []
    min_clients = {c.get("address"): c for c in clients if c.get("workspace", {}).get("name", "").startswith("special:minimized")}

    active_ws = hyprctl_json(["activeworkspace"])
    active_ws_id = active_ws.get("id", 1) if active_ws else 1

    current_stack = load_state()
    target_addr = None

    # Pop most recent from stack that is currently in special:minimized
    while current_stack:
        item = current_stack.pop()
        addr = item.get("address")
        if addr in min_clients:
            target_addr = addr
            break

    # Fallback to any minimized window
    if not target_addr and min_clients:
        target_addr = next(iter(min_clients.keys()))

    if target_addr:
        hyprctl_dispatch("movetoworkspace", f"{active_ws_id},address:{target_addr}")
        hyprctl_dispatch("focuswindow", f"address:{target_addr}")
        save_state(current_stack)
        return

    # If no window is minimized, check if active window is floating and tile it
    cur_win = hyprctl_json(["activewindow"])
    if cur_win and cur_win.get("floating", False):
        hyprctl_dispatch("togglefloating")

def restore_addr(addr):
    if not addr:
        return
    active_ws = hyprctl_json(["activeworkspace"])
    active_ws_id = active_ws.get("id", 1) if active_ws else 1

    hyprctl_dispatch("movetoworkspace", f"{active_ws_id},address:{addr}")
    hyprctl_dispatch("focuswindow", f"address:{addr}")

    current_stack = load_state()
    new_stack = [w for w in current_stack if w.get("address") != addr]
    save_state(new_stack)

def reorder_workspaces(order_str):
    try:
        import re
        order = [int(x) for x in re.findall(r"\d+", order_str)]
        if not order:
            return

        active_ws = hyprctl_json(["activeworkspace"])
        old_active_id = active_ws.get("id", 1) if active_ws else 1
        new_active_id = old_active_id

        ws_mapping = {}
        for new_idx, old_id in enumerate(order, 1):
            ws_mapping[old_id] = new_idx
            if old_id == old_active_id:
                new_active_id = new_idx

        clients = hyprctl_json(["clients"]) or []
        for c in clients:
            ws_id = c.get("workspace", {}).get("id")
            addr = c.get("address")
            if ws_id in ws_mapping and ws_mapping[ws_id] != ws_id:
                temp_ws = 5000 + ws_id
                hyprctl_dispatch("movetoworkspacesilent", f"{temp_ws},address:{addr}")

        clients = hyprctl_json(["clients"]) or []
        for c in clients:
            ws_id = c.get("workspace", {}).get("id")
            addr = c.get("address")
            if ws_id and ws_id > 5000:
                orig_id = ws_id - 5000
                target_id = ws_mapping.get(orig_id)
                if target_id:
                    hyprctl_dispatch("movetoworkspacesilent", f"{target_id},address:{addr}")

        if new_active_id:
            hyprctl_dispatch("workspace", str(new_active_id))
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(0)

    action = sys.argv[1]
    if action == "minimize":
        force = len(sys.argv) > 2 and sys.argv[2] == "--force"
        minimize(force)
    elif action == "maximize":
        maximize()
    elif action == "restore" and len(sys.argv) > 2:
        restore_addr(sys.argv[2])
    elif action == "sync":
        sync_state()
    elif action == "reorder" and len(sys.argv) > 2:
        reorder_workspaces(sys.argv[2])
