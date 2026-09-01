#!/usr/bin/env python3
"""
gesture_daemon.py - Bidirectional Dynamic Buffer 4-Finger Gesture Daemon for Hyprland 0.56+
- Reads raw kernel multi-touch events directly from touchpad device via evdev.
- Normal Swipe: Linear navigation across dynamic buffer pool (clamped at boundaries).
- Shift + Swipe: Circular loop navigation across dynamic buffer pool.
- NEVER moves or shifts any client windows.
Direct UNIX socket IPC (1ms latency) with zero process overhead.
"""

import os
import sys
import glob
import time
import socket
import select
import json
import evdev
from evdev import ecodes

class BidirectionalGestureDaemon:
    def __init__(self):
        self.sock_path = None
        self.dev = None
        self.keyboards = []
        self.init_hypr_socket()
        self.init_touchpad()
        self.init_keyboards()

    def init_hypr_socket(self):
        runtime = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not sig:
            dirs = glob.glob(f"{runtime}/hypr/*")
            for d in dirs:
                if os.path.exists(os.path.join(d, ".socket.sock")):
                    sig = os.path.basename(d)
                    break
        if sig:
            self.sock_path = f"{runtime}/hypr/{sig}/.socket.sock"
        else:
            self.sock_path = None

    def init_keyboards(self):
        self.keyboards = []
        for path in evdev.list_devices():
            try:
                d = evdev.InputDevice(path)
                caps = d.capabilities()
                if ecodes.EV_KEY in caps:
                    keys = caps[ecodes.EV_KEY]
                    if ecodes.KEY_LEFTSHIFT in keys or ecodes.KEY_RIGHTSHIFT in keys:
                        self.keyboards.append(d)
            except Exception:
                continue

    def is_shift_pressed(self):
        for kbd in self.keyboards:
            try:
                active = kbd.active_keys()
                if ecodes.KEY_LEFTSHIFT in active or ecodes.KEY_RIGHTSHIFT in active:
                    return True
            except Exception:
                continue
        return False

    def hypr_ipc(self, cmd):
        if not self.sock_path or not os.path.exists(self.sock_path):
            self.init_hypr_socket()
            if not self.sock_path or not os.path.exists(self.sock_path):
                return ""

        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.settimeout(0.15)
            s.connect(self.sock_path)
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

    def parse_ws_num(self, name, ws_id):
        try:
            return int(name)
        except (ValueError, TypeError):
            if ws_id > 0:
                return ws_id
            return None

    def get_dynamic_pool(self):
        raw_wss = self.hypr_ipc("j/workspaces")
        occupied = []
        if raw_wss:
            try:
                wss = json.loads(raw_wss)
                for w in wss:
                    if w.get("windows", 0) > 0:
                        num = self.parse_ws_num(w.get("name"), w.get("id"))
                        if num is not None and -50 <= num <= 50:
                            occupied.append(num)
            except Exception:
                occupied = []

        min_occupied = min(occupied) if occupied else 2
        max_occupied = max(occupied) if occupied else 2

        # Left-end buffer
        if any(w <= 1 for w in occupied):
            min_ws = min_occupied - 1
        else:
            min_ws = 1

        # Right-end buffer
        if any(w >= 3 for w in occupied):
            max_ws = max_occupied + 1
        else:
            max_ws = 3

        min_ws = min(1, min_ws)
        max_ws = max(3, max_ws)

        return list(range(min_ws, max_ws + 1))

    def get_target_workspace(self, direction, is_loop):
        pool = self.get_dynamic_pool()

        raw_act = self.hypr_ipc("j/activeworkspace")
        current_num = 1
        if raw_act:
            try:
                act = json.loads(raw_act)
                current_num = self.parse_ws_num(act.get("name"), act.get("id"))
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

        if is_loop:
            # Shift + Swipe (Circular Loop)
            if direction == "left":
                target_num = pool[(idx - 1) % len(pool)]
            else:
                target_num = pool[(idx + 1) % len(pool)]
        else:
            # Normal Swipe (Linear Clamped)
            if direction == "left":
                if idx > 0:
                    target_num = pool[idx - 1]
            else:
                if idx < len(pool) - 1:
                    target_num = pool[idx + 1]

        return target_num

    def switch_workspace(self, direction):
        is_loop = self.is_shift_pressed()
        target_num = self.get_target_workspace(direction, is_loop)
        if target_num is not None:
            target_str = str(target_num) if target_num > 0 else f"name:{target_num}"
            lua_cmd = f'eval hl.dispatch(hl.dsp.focus({{ workspace = "{target_str}" }}))\n'
            self.hypr_ipc(lua_cmd)

    def init_touchpad(self):
        for path in evdev.list_devices():
            try:
                d = evdev.InputDevice(path)
                if "touchpad" in d.name.lower():
                    caps = d.capabilities()
                    if ecodes.EV_KEY in caps and ecodes.BTN_TOOL_QUADTAP in caps[ecodes.EV_KEY]:
                        self.dev = d
                        return
            except Exception:
                continue

        for path in evdev.list_devices():
            try:
                d = evdev.InputDevice(path)
                caps = d.capabilities()
                if ecodes.EV_ABS in caps:
                    flat_abs = [c[0] if isinstance(c, tuple) else c for c in caps[ecodes.EV_ABS]]
                    if ecodes.ABS_MT_SLOT in flat_abs:
                        self.dev = d
                        return
            except Exception:
                continue

    def run(self):
        if not self.dev:
            print("No suitable touchpad device found.", file=sys.stderr)
            sys.exit(1)

        print(f"Bidirectional Buffer Gesture Daemon Active on {self.dev.name} ({self.dev.path})", flush=True)

        quad_active = False
        active_slots = {}
        slots_x = {}
        slots_y = {}
        current_slot = 0

        start_x = None
        start_y = None
        triggered = False
        SWIPE_DIST = 140

        while True:
            r, _, _ = select.select([self.dev], [], [], 2.0)
            if not r:
                continue

            for event in self.dev.read():
                if event.type == ecodes.EV_KEY:
                    if event.code == ecodes.BTN_TOOL_QUADTAP:
                        quad_active = (event.value == 1)
                        if not quad_active:
                            start_x = None
                            start_y = None
                            triggered = False
                    elif event.code == ecodes.BTN_TOUCH and event.value == 0:
                        quad_active = False
                        active_slots.clear()
                        slots_x.clear()
                        slots_y.clear()
                        start_x = None
                        start_y = None
                        triggered = False

                elif event.type == ecodes.EV_ABS:
                    if event.code == ecodes.ABS_MT_SLOT:
                        current_slot = event.value
                    elif event.code == ecodes.ABS_MT_TRACKING_ID:
                        if event.value == -1:
                            active_slots.pop(current_slot, None)
                            slots_x.pop(current_slot, None)
                            slots_y.pop(current_slot, None)
                            if len(active_slots) < 4:
                                quad_active = False
                                start_x = None
                                start_y = None
                                triggered = False
                        else:
                            active_slots[current_slot] = True
                    elif event.code == ecodes.ABS_MT_POSITION_X:
                        slots_x[current_slot] = event.value
                    elif event.code == ecodes.ABS_MT_POSITION_Y:
                        slots_y[current_slot] = event.value

                elif event.type == ecodes.EV_SYN and event.code == ecodes.SYN_REPORT:
                    is_four_fingers = quad_active or (len(active_slots) >= 4)

                    if is_four_fingers and len(slots_x) >= 2:
                        avg_x = sum(slots_x.values()) / len(slots_x)
                        avg_y = sum(slots_y.values()) / len(slots_y) if slots_y else 0

                        if start_x is None:
                            start_x = avg_x
                            start_y = avg_y
                            triggered = False
                        else:
                            dx = avg_x - start_x
                            dy = avg_y - start_y if start_y is not None else 0

                            if not triggered and abs(dx) > SWIPE_DIST and abs(dx) > abs(dy) * 1.2:
                                if dx > SWIPE_DIST:
                                    self.switch_workspace("left")
                                    triggered = True
                                elif dx < -SWIPE_DIST:
                                    self.switch_workspace("right")
                                    triggered = True

if __name__ == "__main__":
    daemon = BidirectionalGestureDaemon()
    daemon.run()
