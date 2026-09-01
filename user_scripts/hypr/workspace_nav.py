#!/usr/bin/env python3
"""
workspace_nav.py - Bidirectional Dynamic Buffer Workspace Navigator for Hyprland 0.56+
- Base default: 3 workspaces [1, 2, 3].
- Lower-end expansion: If workspace 1 (or <=1) has windows, dynamically creates empty left buffer (0, -1, -2, etc.).
- Higher-end expansion: If workspace 3 (or >=3) has windows, dynamically creates empty right buffer (4, 5, 6, etc.).
- Linear (clamped) and Circular (loop) navigation modes.
- NEVER moves or shifts any client windows.
"""

import os
import sys
import glob
import json
import socket

def get_hypr_socket():
    runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        for d in glob.glob(f"{runtime}/hypr/*"):
            if os.path.exists(os.path.join(d, ".socket.sock")):
                sig = os.path.basename(d)
                break
    if sig:
        return f"{runtime}/hypr/{sig}/.socket.sock"
    return None

def hypr_ipc(cmd):
    sock_path = get_hypr_socket()
    if not sock_path or not os.path.exists(sock_path):
        return ""
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.2)
        s.connect(sock_path)
        s.sendall(cmd.encode("utf-8"))
        data = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
        s.close()
        return data.decode("utf-8", errors="ignore")
    except Exception:
        return ""

def parse_ws_num(name, ws_id):
    try:
        return int(name)
    except (ValueError, TypeError):
        if ws_id > 0:
            return ws_id
        return None

def get_dynamic_pool():
    raw_wss = hypr_ipc("j/workspaces")
    occupied = []
    if raw_wss:
        try:
            wss = json.loads(raw_wss)
            for w in wss:
                if w.get("windows", 0) > 0:
                    num = parse_ws_num(w.get("name"), w.get("id"))
                    if num is not None and -50 <= num <= 50:
                        occupied.append(num)
        except Exception:
            occupied = []

    min_occupied = min(occupied) if occupied else 2
    max_occupied = max(occupied) if occupied else 2

    # Left-end buffer: if <=1 is occupied, provision (min - 1)
    if any(w <= 1 for w in occupied):
        min_ws = min_occupied - 1
    else:
        min_ws = 1

    # Right-end buffer: if >=3 is occupied, provision (max + 1)
    if any(w >= 3 for w in occupied):
        max_ws = max_occupied + 1
    else:
        max_ws = 3

    min_ws = min(1, min_ws)
    max_ws = max(3, max_ws)

    return list(range(min_ws, max_ws + 1))

def navigate(mode):
    pool = get_dynamic_pool()

    raw_act = hypr_ipc("j/activeworkspace")
    current_num = 1
    if raw_act:
        try:
            act = json.loads(raw_act)
            current_num = parse_ws_num(act.get("name"), act.get("id"))
            if current_num is None:
                current_num = 1
        except Exception:
            current_num = 1

    if current_num not in pool:
        pool.append(current_num)
        pool.sort()

    try:
        idx = pool.index(current_num)
    except ValueError:
        idx = 0

    target_num = current_num

    if mode == "next_normal":
        if idx < len(pool) - 1:
            target_num = pool[idx + 1]
    elif mode == "prev_normal":
        if idx > 0:
            target_num = pool[idx - 1]
    elif mode == "next_loop":
        target_num = pool[(idx + 1) % len(pool)]
    elif mode == "prev_loop":
        target_num = pool[(idx - 1) % len(pool)]

    if target_num != current_num:
        target_str = str(target_num) if target_num > 0 else f"name:{target_num}"
        lua_cmd = f'eval hl.dispatch(hl.dsp.focus({{ workspace = "{target_str}" }}))\n'
        hypr_ipc(lua_cmd)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "next_normal"
    navigate(mode)
