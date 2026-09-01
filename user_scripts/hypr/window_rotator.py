#!/usr/bin/env python3
"""
window_rotator.py - Deterministic Clockwise & Anti-Clockwise Geometric Window Rotator
Cycles tiled window positions in the current workspace with smooth resizing animations.
"""

import os
import sys
import glob
import math
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

def rotate_windows(direction="clockwise"):
    raw_act = hypr_ipc("j/activeworkspace")
    if not raw_act:
        return
    try:
        active_ws = json.loads(raw_act).get("id", 1)
    except Exception:
        return

    raw_clients = hypr_ipc("j/clients")
    if not raw_clients:
        return
    try:
        clients = json.loads(raw_clients)
        ws_clients = [c for c in clients if c.get("workspace", {}).get("id") == active_ws and not c.get("floating", False)]
    except Exception:
        return

    # If only 1 window or none, do nothing
    if len(ws_clients) <= 1:
        return

    # For 2 windows: simple swap
    if len(ws_clients) == 2:
        w0 = ws_clients[0]["address"]
        w1 = ws_clients[1]["address"]
        lua = (f'eval hl.dispatch(hl.dsp.focus({{ window = "address:{w0}" }})); '
               f'hl.dispatch(hl.dsp.window.swap({{ other = "address:{w1}" }}))\n')
        hypr_ipc(lua)
        return

    # For 3+ windows: Geometric Clockwise Sort
    # Compute center of all windows
    avg_cx = sum(c["at"][0] + c["size"][0] / 2.0 for c in ws_clients) / len(ws_clients)
    avg_cy = sum(c["at"][1] + c["size"][1] / 2.0 for c in ws_clients) / len(ws_clients)

    def get_angle(c):
        cx = c["at"][0] + c["size"][0] / 2.0
        cy = c["at"][1] + c["size"][1] / 2.0
        return math.atan2(cy - avg_cy, cx - avg_cx)

    # Sort in clockwise order around center
    sorted_clients = sorted(ws_clients, key=get_angle)
    addresses = [c["address"] for c in sorted_clients]
    n = len(addresses)

    lua_ops = []
    if direction == "clockwise":
        # Clockwise permutation (A0 -> A1 -> A2 ... -> AN-1 -> A0)
        # Swapping (A0, A1), (A0, A2), ..., (A0, AN-1) achieves exact clockwise rotation
        a0 = addresses[0]
        for i in range(1, n):
            ai = addresses[i]
            lua_ops.append(f'hl.dispatch(hl.dsp.focus({{ window = "address:{a0}" }}))')
            lua_ops.append(f'hl.dispatch(hl.dsp.window.swap({{ other = "address:{ai}" }}))')
    else:
        # Anti-Clockwise permutation (A0 -> AN-1 -> ... -> A1 -> A0)
        # Swapping (A0, AN-1), (A0, AN-2), ..., (A0, A1) achieves exact anti-clockwise rotation
        a0 = addresses[0]
        for i in range(n - 1, 0, -1):
            ai = addresses[i]
            lua_ops.append(f'hl.dispatch(hl.dsp.focus({{ window = "address:{a0}" }}))')
            lua_ops.append(f'hl.dispatch(hl.dsp.window.swap({{ other = "address:{ai}" }}))')

    if lua_ops:
        lua_cmd = "eval " + "; ".join(lua_ops) + "\n"
        hypr_ipc(lua_cmd)

if __name__ == "__main__":
    direction = "clockwise"
    if len(sys.argv) > 1 and sys.argv[1].lower() in ("anticlockwise", "counterclockwise", "prev", "left"):
        direction = "anticlockwise"
    rotate_windows(direction)
