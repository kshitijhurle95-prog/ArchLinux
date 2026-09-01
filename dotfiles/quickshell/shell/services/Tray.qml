pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// QML view of the unified system tray & running applications.
// Merges background StatusNotifierItem tray services with all active Hyprland
// toplevel windows (Terminal, File Manager, Settings, Browser, Editor, etc.)
// so that the tray displays all running apps and only currently running apps.
Singleton {
    id: root

    property var sniItems: []
    property var items: []
    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function _updateUnifiedItems() {
        const result = [];
        const appMap = {};
        const sniUsed = {};

        // 1. Process active Hyprland windows
        const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (let i = 0; i < tls.length; i++) {
            const t = tls[i];
            const o = t && t.lastIpcObject;
            if (!o || !o.address)
                continue;

            const wsName = o.workspace ? String(o.workspace.name || "") : "";
            if (wsName.indexOf("special:sharebar") === 0)
                continue;

            const cls = String(o.class || o.initialClass || "").trim();
            const title = String(o.title || "").trim();

            // Filter out internal background surfaces
            if (cls === "" && title === "")
                continue;
            if (cls === "minmax-dock" || cls === "quickshell-popup-dismiss" || cls === "ryoku-shell")
                continue;

            const lowerCls = cls.toLowerCase();
            let appKey = lowerCls || "window";

            // Match against any registered SNI service
            let matchedSni = null;
            for (let s = 0; s < root.sniItems.length; s++) {
                const sni = root.sniItems[s];
                if (!sni)
                    continue;
                const sniId = String(sni.id || "").toLowerCase();
                const sniTitle = String(sni.title || "").toLowerCase();
                if (sniId.indexOf(lowerCls) >= 0 || lowerCls.indexOf(sniId) >= 0 ||
                    (sniTitle && (sniTitle.indexOf(lowerCls) >= 0 || lowerCls.indexOf(sniTitle) >= 0))) {
                    matchedSni = sni;
                    sniUsed[sni.service] = true;
                    appKey = "sni:" + sni.service;
                    break;
                }
            }

            if (appMap[appKey]) {
                appMap[appKey].windowAddresses.push(o.address);
                continue;
            }

            let desktop = null;
            if (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup) {
                desktop = DesktopEntries.heuristicLookup(cls);
                if (!desktop && (cls === "org.quickshell" || title === "Ryoku Settings"))
                    desktop = DesktopEntries.heuristicLookup("ryoku-settings");
            }

            let appName = "";
            if (cls === "org.quickshell" || lowerCls.indexOf("quickshell") >= 0 || title.indexOf("Settings") >= 0) {
                appName = "Settings";
            } else if (desktop && desktop.name) {
                appName = desktop.name;
            } else if (matchedSni && matchedSni.title) {
                appName = matchedSni.title;
            } else if (matchedSni && matchedSni.tooltip && matchedSni.tooltip.title) {
                appName = matchedSni.tooltip.title;
            } else if (lowerCls === "kitty" || lowerCls === "ghostty" || lowerCls === "alacritty" || lowerCls === "foot") {
                appName = "Terminal";
            } else if (lowerCls.indexOf("nautilus") >= 0 || lowerCls.indexOf("thunar") >= 0 || lowerCls.indexOf("dolphin") >= 0) {
                appName = "Files";
            } else if (lowerCls.indexOf("chrome") >= 0) {
                appName = "Google Chrome";
            } else if (lowerCls.indexOf("antigravity") >= 0) {
                appName = "Antigravity";
            } else {
                appName = title || cls || "App";
            }

            let iconPath = "";
            let iconName = "";

            if (matchedSni && matchedSni.iconPath) {
                iconPath = matchedSni.iconPath;
            } else if (matchedSni && matchedSni.iconName) {
                iconName = matchedSni.iconName;
                iconPath = Quickshell.iconPath(iconName, true);
            } else if (desktop && desktop.icon) {
                iconName = desktop.icon;
                iconPath = Quickshell.iconPath(desktop.icon, true);
            }

            if (!iconPath) {
                if (cls === "org.quickshell" || title.indexOf("Ryoku Settings") >= 0) {
                    iconPath = Quickshell.iconPath("ryoku-settings", true) || Quickshell.iconPath("preferences-system", true) || Quickshell.iconPath("preferences-desktop", true);
                } else if (lowerCls === "kitty") {
                    iconPath = Quickshell.iconPath("kitty", true) || Quickshell.iconPath("utilities-terminal", true);
                } else if (lowerCls.indexOf("nautilus") >= 0) {
                    iconPath = Quickshell.iconPath("org.gnome.Nautilus", true) || Quickshell.iconPath("system-file-manager", true);
                } else if (lowerCls.indexOf("chrome") >= 0) {
                    iconPath = Quickshell.iconPath("google-chrome", true);
                } else if (lowerCls) {
                    iconPath = Quickshell.iconPath(lowerCls, true) || Quickshell.iconPath("application-x-executable", true);
                }
            }

            if (!iconPath)
                iconPath = Quickshell.iconPath("application-x-executable", true);

            const itemObj = {
                service: matchedSni ? matchedSni.service : ("window:" + o.address),
                id: cls || "window",
                title: appName,
                status: matchedSni ? matchedSni.status : "Active",
                category: "ApplicationStatus",
                iconName: iconName || (matchedSni ? matchedSni.iconName : lowerCls),
                iconPath: iconPath,
                tooltip: {
                    title: appName,
                    description: (title && title !== appName) ? title : (desktop && desktop.genericName ? desktop.genericName : "")
                },
                itemIsMenu: matchedSni ? matchedSni.itemIsMenu : false,
                menu: matchedSni ? matchedSni.menu : null,
                isWindow: true,
                windowAddress: o.address,
                windowAddresses: [o.address],
                pid: o.pid || 0,
                workspace: wsName
            };

            appMap[appKey] = itemObj;
            result.push(itemObj);
        }

        // 2. Add remaining background SNI services (not attached to an open window)
        for (let s = 0; s < root.sniItems.length; s++) {
            const sni = root.sniItems[s];
            if (!sni || !sni.service)
                continue;
            if (sniUsed[sni.service])
                continue;

            let iconPath = sni.iconPath || "";
            if (!iconPath && sni.iconName)
                iconPath = Quickshell.iconPath(sni.iconName, true);
            if (!iconPath)
                iconPath = Quickshell.iconPath("application-x-executable", true);

            const cleanSni = Object.assign({}, sni, {
                iconPath: iconPath,
                title: sni.title || (sni.tooltip ? sni.tooltip.title : "") || sni.id || "App"
            });

            result.push(cleanSni);
        }

        root.items = result;
    }

    Timer {
        id: updateDebounce
        interval: 40
        repeat: false
        onTriggered: root._updateUnifiedItems()
    }

    function queueUpdate() {
        updateDebounce.restart();
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { root.queueUpdate(); }
    }

    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() { root.queueUpdate(); }
            function onTitleChanged() { root.queueUpdate(); }
            function onWorkspaceChanged() { root.queueUpdate(); }
        }
    }

    function apply(line) {
        try {
            const frame = JSON.parse(line);
            root.sniItems = Array.isArray(frame.items) ? frame.items : [];
            root.queueUpdate();
        } catch (e) {
            // Keep last set on malformed frame
        }
    }

    // Click intents. Left click activates/focuses the app window or SNI service.
    function activate(service, x, y) {
        if (!service)
            return;
        if (service.indexOf("window:") === 0) {
            const addr = service.substring(7);
            Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })');
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr]);
            return;
        }
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].service === service && root.items[i].windowAddress) {
                Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.items[i].windowAddress + '" })');
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + root.items[i].windowAddress]);
                break;
            }
        }
        root.send("tray.activate", { service: service, x: x, y: y });
    }

    function contextMenu(service, x, y) {
        if (!service)
            return;
        if (service.indexOf("window:") === 0) {
            const addr = service.substring(7);
            Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })');
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr]);
            return;
        }
        root.send("tray.contextMenu", { service: service, x: x, y: y });
    }

    function scroll(service, delta, orientation) { root.send("tray.scroll", { service: service, delta: delta, orientation: orientation }); }
    function aboutToShow(service) { root.send("tray.aboutToShow", { service: service }); }
    function menuEvent(service, id) { root.send("tray.menuEvent", { service: service, item: id }); }

    function send(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe tray\n");
                flush();
            } else {
                root.sniItems = [];
                root.queueUpdate();
                retry.restart();
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }

    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""

        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }

        onConnectionStateChanged: if (connected) flushQueued()
    }

    Component.onCompleted: {
        root._updateUnifiedItems();
        if (Hyprland.refreshToplevels)
            Hyprland.refreshToplevels();
    }
}
