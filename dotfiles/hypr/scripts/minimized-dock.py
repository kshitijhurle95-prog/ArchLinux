#!/usr/bin/env python3
"""
Minimized Windows Dock for Hyprland
Renders pure 20px app icons floating at the bottom-left corner of the screen.
No background, no border, no container box, and 0px padding.
Clicking an icon maximizes that window to the current workspace without moving cursor.
Disappears automatically when no windows are minimized.
"""

import os
import sys
import fcntl
import json
import socket
import threading
import subprocess
import time
import glob
import gi

gi.require_version('Gtk', '3.0')
gi.require_version('GtkLayerShell', '0.1')
from gi.repository import Gtk, GtkLayerShell, Gdk, GLib, Gio

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
STATE_FILE = os.path.join(RUNTIME_DIR, "hypr_minimized.json")
LOCK_FILE = os.path.join(RUNTIME_DIR, "hypr_minimized_dock.lock")

class MinimizedDock:
    def __init__(self):
        self.icon_theme = Gtk.IconTheme.get_default()
        self.current_windows = []

        self.setup_css()
        self.setup_window()
        self.setup_monitor()
        self.setup_hypr_socket()

        # Initial read
        self.sync_and_refresh()

    def setup_css(self):
        self.css_provider = Gtk.CssProvider()
        css = b"""
        window, .dock-container, eventbox, image {
            background-color: transparent;
            background: transparent;
            background-image: none;
            border: none;
            border-width: 0px;
            border-radius: 0px;
            padding: 0px;
            margin: 0px;
            box-shadow: none;
            outline: none;
        }
        button.min-icon-btn {
            background-color: transparent;
            background: none;
            border: none;
            border-width: 0px;
            border-radius: 0px;
            padding: 0px;
            margin: 0px;
            box-shadow: none;
            outline: none;
            min-width: 20px;
            min-height: 20px;
            transition: opacity 120ms ease;
        }
        button.min-icon-btn:hover {
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
            opacity: 0.75;
        }
        button.min-icon-btn:active {
            background-color: transparent;
            background: none;
            border: none;
            box-shadow: none;
            opacity: 0.5;
        }
        """
        self.css_provider.load_from_data(css)
        screen = Gdk.Screen.get_default()
        if screen is not None:
            Gtk.StyleContext.add_provider_for_screen(
                screen,
                self.css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )

    def setup_window(self):
        self.window = Gtk.Window()
        screen = self.window.get_screen() or Gdk.Screen.get_default()
        if screen is not None:
            visual = screen.get_rgba_visual()
            if visual:
                self.window.set_visual(visual)
            Gtk.StyleContext.add_provider_for_screen(
                screen,
                self.css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
        self.window.set_app_paintable(True)

        GtkLayerShell.init_for_window(self.window)
        GtkLayerShell.set_namespace(self.window, "hypr-minimized-dock")
        GtkLayerShell.set_layer(self.window, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_anchor(self.window, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.LEFT, 3)
        GtkLayerShell.set_margin(self.window, GtkLayerShell.Edge.BOTTOM, 3)
        GtkLayerShell.set_keyboard_mode(self.window, GtkLayerShell.KeyboardMode.NONE)

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.box.get_style_context().add_class("dock-container")
        self.window.add(self.box)

    def resolve_icon(self, app_class, initial_class):
        icon_theme = Gtk.IconTheme.get_default() or self.icon_theme
        candidates = []
        for name in [app_class, initial_class]:
            if name:
                candidates.extend([
                    name,
                    name.lower(),
                    name.replace("org.gnome.", "").lower(),
                    name.replace("org.kde.", "").lower(),
                    name.split(".")[-1].lower(),
                    name.lower().replace("-browser", ""),
                    name.lower().replace("-stable", ""),
                ])

        app_lower = (app_class or initial_class or "").lower()
        if "ghostty" in app_lower:
            candidates.extend(["ghostty", "com.mitchellh.ghostty", "utilities-terminal", "terminal"])
        elif "term" in app_lower or "kitty" in app_lower or "alacritty" in app_lower or "foot" in app_lower:
            candidates.extend(["kitty", "foot", "alacritty", "utilities-terminal", "terminal"])
        elif "code" in app_lower:
            candidates.extend(["visual-studio-code", "code", "vscode", "com.visualstudio.code"])
        elif "chrome" in app_lower:
            candidates.extend(["google-chrome", "google-chrome-stable", "chromium"])
        elif "firefox" in app_lower or "zen" in app_lower or "librewolf" in app_lower:
            candidates.extend(["firefox", "zen-browser", "librewolf", "web-browser"])

        if icon_theme:
            for c in candidates:
                if icon_theme.has_icon(c):
                    return c
        return "application-x-executable"

    def restore_window(self, address):
        minmax_script = os.path.expanduser("~/.config/hypr/scripts/hypr-minmax.py")
        subprocess.Popen([sys.executable, minmax_script, "restore", str(address)],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        GLib.timeout_add(100, self.sync_and_refresh)

    def sync_and_refresh(self):
        minmax_script = os.path.expanduser("~/.config/hypr/scripts/hypr-minmax.py")
        try:
            subprocess.run([sys.executable, minmax_script, "sync"],
                           capture_output=True, timeout=1)
        except Exception:
            pass
        self.load_and_refresh()

    def load_and_refresh(self):
        windows = []
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r") as f:
                    windows = json.load(f)
            except Exception:
                windows = []

        self.update_ui(windows)

    def update_ui(self, windows):
        if windows == self.current_windows:
            return
        self.current_windows = list(windows)

        for child in self.box.get_children():
            self.box.remove(child)

        if not windows:
            self.window.hide()
            return

        for win in windows:
            addr = win.get("address")
            app_class = win.get("class", "")
            init_class = win.get("initialClass", "")
            title = win.get("title", "")

            icon_name = self.resolve_icon(app_class, init_class)
            image = Gtk.Image.new_from_icon_name(icon_name, Gtk.IconSize.LARGE_TOOLBAR)
            image.set_pixel_size(20)

            ebox = Gtk.EventBox()
            ebox.set_visible_window(False)
            ebox.set_above_child(True)
            if title:
                ebox.set_tooltip_text(f"{title} (Click to restore)")
            ebox.add(image)

            display = Gdk.Display.get_default()
            if display:
                cursor = Gdk.Cursor.new_from_name(display, "pointer")
                ebox.connect("realize", lambda w, c=cursor: w.get_window().set_cursor(c) if w.get_window() else None)

            # Click event to maximize
            ebox.connect("button-press-event", lambda w, e, a=addr: self.restore_window(a))
            self.box.pack_start(ebox, False, False, 0)

        self.window.show_all()

    def setup_monitor(self):
        if not os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "w") as f:
                    f.write("[]")
            except Exception:
                pass

        gfile = Gio.File.new_for_path(STATE_FILE)
        self.monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
        self.monitor.connect("changed", lambda m, f1, f2, e: GLib.idle_add(self.load_and_refresh))

        GLib.timeout_add(1000, self.periodic_check)

    def periodic_check(self):
        self.load_and_refresh()
        return True

    def _get_hypr_socket(self):
        his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if his:
            sock_path = f"{RUNTIME_DIR}/hypr/{his}/.socket2.sock"
            if os.path.exists(sock_path):
                return sock_path

        matches = glob.glob(f"{RUNTIME_DIR}/hypr/*/.socket2.sock")
        if matches:
            matches.sort(key=lambda p: os.path.getmtime(p), reverse=True)
            return matches[0]
        return None

    def setup_hypr_socket(self):
        thread = threading.Thread(target=self._socket_listener, daemon=True)
        thread.start()

    def _socket_listener(self):
        while True:
            sock_path = self._get_hypr_socket()
            if not sock_path or not os.path.exists(sock_path):
                time.sleep(1)
                continue

            try:
                client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                client.connect(sock_path)
                buffer = ""
                while True:
                    data = client.recv(1024).decode("utf-8", errors="ignore")
                    if not data:
                        break
                    buffer += data
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        if any(ev in line for ev in ("closewindow>>", "destroyworkspace>>", "movewindow>>", "openwindow>>")):
                            GLib.idle_add(self.sync_and_refresh)
            except Exception:
                pass
            time.sleep(1)

def main():
    # Acquire singleton lock
    try:
        lock_fd = open(LOCK_FILE, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (IOError, BlockingIOError):
        # Another instance is already running
        sys.exit(0)

    # Wait for graphical display connection if launched at login
    for _ in range(50):
        if Gdk.Display.get_default() is not None:
            break
        success, _ = Gtk.init_check(sys.argv)
        if success and Gdk.Display.get_default() is not None:
            break
        time.sleep(0.2)

    app = MinimizedDock()
    Gtk.main()

if __name__ == "__main__":
    main()
