pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Singletons"
import Ryoku.Ui.Singletons

/**
 * macOS Mission Control Stage:
 * Displays all open windows dynamically arranged and scaled across the full screen
 * with live Screencopy previews, app titles, icons, space badges, Spaces top bar,
 * floating borderless "+" Add Space button, drag-and-drop window transfer, and organic layout.
 */
Item {
    id: root

    property real s: 1
    property string screenName: ""
    property bool active: false
    property bool dataReady: false
    property bool focusHere: false
    signal requestClose()

    // View All Spaces toggle (true = all running windows across all workspaces, false = specific space)
    property bool viewAllSpaces: true
    function setViewAllSpaces(all) {
        root.viewAllSpaces = all;
        root.selected = 0;
    }

    // Search query state
    property string searchQuery: ""
    function handleSearchInput(t) {
        root.searchQuery += t;
        root.selected = 0;
    }
    function handleBackspace() {
        if (root.searchQuery.length > 0) {
            root.searchQuery = root.searchQuery.slice(0, -1);
            root.selected = 0;
        }
    }
    function clearSearch() {
        root.searchQuery = "";
        root.selected = 0;
    }

    // Monitor geometry
    readonly property var mon: {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++) {
            if (ms[i] && ms[i].name === root.screenName)
                return ms[i];
        }
        return null;
    }
    readonly property var monObj: root.mon ? root.mon.lastIpcObject : null
    readonly property real monScale: (root.monObj && root.monObj.scale > 0) ? root.monObj.scale : 1
    readonly property real monLW: (root.monObj && root.monObj.width > 0) ? root.monObj.width / root.monScale : 1920
    readonly property real monLH: (root.monObj && root.monObj.height > 0) ? root.monObj.height / root.monScale : 1080
    readonly property real aspect: root.monLW > 0 ? root.monLW / root.monLH : (16 / 9)

    // Active workspace
    readonly property int activeWsId: {
        if (Hyprland.focusedWorkspace && typeof Hyprland.focusedWorkspace.id === "number")
            return Hyprland.focusedWorkspace.id;
        if (root.monObj && root.monObj.activeWorkspace && typeof root.monObj.activeWorkspace.id === "number")
            return root.monObj.activeWorkspace.id;
        if (root.mon && root.mon.activeWorkspace)
            return root.mon.activeWorkspace.id;
        return 1;
    }
    property int viewedWsId: 1

    // Explicit user created spaces tracking
    property var userCreatedSpaces: []

    // Workspace enumeration
    readonly property var allWsIds: {
        var out = [];
        var all = Hyprland.workspaces.values;
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (w && w.id > 0 && out.indexOf(w.id) === -1)
                out.push(w.id);
        }
        var raw = root.rawWindows;
        for (var j = 0; j < raw.length; j++) {
            var wid = raw[j].wsId;
            if (wid > 0 && out.indexOf(wid) === -1)
                out.push(wid);
        }
        for (var k = 0; k < root.userCreatedSpaces.length; k++) {
            var cid = root.userCreatedSpaces[k];
            if (cid > 0 && out.indexOf(cid) === -1)
                out.push(cid);
        }
        if (out.indexOf(root.activeWsId) === -1)
            out.push(root.activeWsId);
        if (out.length === 0)
            out.push(1);
        out.sort(function (a, b) { return a - b; });
        return out;
    }

    readonly property int maxOccWs: {
        var m = 0;
        for (var i = 0; i < root.allWsIds.length; i++)
            m = Math.max(m, root.allWsIds[i]);
        return Math.max(m, root.activeWsId);
    }
    readonly property int newWsId: root.maxOccWs + 1

    readonly property var deskList: {
        var out = [];
        for (var i = 0; i < root.allWsIds.length; i++)
            out.push(root.allWsIds[i]);
        return out;
    }

    function deskWinCount(wsId) {
        if (wsId <= 0) return 0;
        var count = 0;
        var raw = root.rawWindows;
        for (var i = 0; i < raw.length; i++) {
            if (raw[i].wsId === wsId)
                count++;
        }
        return count;
    }

    function switchToWs(wsId) {
        root.viewedWsId = wsId;
        root.selected = 0;
    }

    function createSpace() {
        var nextId = root.newWsId;
        var cur = root.userCreatedSpaces.slice();
        if (cur.indexOf(nextId) === -1) {
            cur.push(nextId);
            root.userCreatedSpaces = cur;
        }
        root.viewAllSpaces = false;
        root.viewedWsId = nextId;
        root.selected = 0;
        Hyprland.refreshWorkspaces();
    }

    function createDesktop() {
        root.createSpace();
    }

    function removeSpace(wsId) {
        if (root.deskList.length <= 1) return;

        // Collect all remaining workspaces
        var remaining = [];
        for (var i = 0; i < root.deskList.length; i++) {
            if (root.deskList[i] !== wsId)
                remaining.push(root.deskList[i]);
        }
        var targetWs = remaining[0];
        for (var j = 0; j < remaining.length; j++) {
            if (remaining[j] < wsId)
                targetWs = remaining[j];
        }

        // Move all windows on wsId to targetWs safely
        var raw = root.rawWindows;
        for (var k = 0; k < raw.length; k++) {
            if (raw[k].wsId === wsId && !raw[k].isMinimized) {
                root.moveWindow(raw[k].addr, targetWs);
            }
        }

        // Remove from userCreatedSpaces
        var cur = root.userCreatedSpaces.slice();
        var idx = cur.indexOf(wsId);
        if (idx !== -1) {
            cur.splice(idx, 1);
            root.userCreatedSpaces = cur;
        }

        if (root.viewedWsId === wsId) {
            root.viewedWsId = targetWs;
        }
        if (root.activeWsId === wsId) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = ' + targetWs + ' })');
        }

        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    // Window collection across all workspaces / filtered space (including minimized, electron, system, and fullscreen windows)
    readonly property var rawWindows: {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            var o = t && t.lastIpcObject;
            if (!t || !o)
                continue;
            if (o.address === "")
                continue;
            if (o.size && o.size[0] <= 10 && o.size[1] <= 10 && !o.hidden)
                continue;

            var wsName = (o.workspace && o.workspace.name) ? String(o.workspace.name) : "";
            var isMin = (wsName === "special:minimized");

            var clsStr = String(o.class || o.initialClass || t.appId || "").toLowerCase();
            // Filter out only lockscreen/logout/launcher overlays
            if (clsStr === "hyprlock" || clsStr === "wlogout" || clsStr === "rofi" || clsStr === "wofi" ||
                clsStr.indexOf("wlr-layer") >= 0 || clsStr === "quickshell")
                continue;

            var rawWsId = (o.workspace && typeof o.workspace.id === "number") ? o.workspace.id : ((t.workspace && typeof t.workspace.id === "number") ? t.workspace.id : 1);
            var parsedWs = parseInt(wsName, 10);
            var wsId = 1;
            if (isMin) {
                // Attach minimized windows to active space so they appear in current view & all spaces
                wsId = (root.activeWsId > 0) ? root.activeWsId : 1;
            } else if (rawWsId > 0) {
                wsId = rawWsId;
            } else if (!isNaN(parsedWs) && parsedWs > 0) {
                wsId = parsedWs;
            } else {
                wsId = (root.activeWsId > 0) ? root.activeWsId : 1;
            }

            var w = (o.size && o.size[0] > 0) ? o.size[0] : 1920;
            var h = (o.size && o.size[1] > 0) ? o.size[1] : 1080;
            var winAspect = (w > 0 && h > 0) ? (w / h) : root.aspect;
            winAspect = Math.max(0.35, Math.min(3.5, winAspect));

            var titleStr = String(o.title || o.initialTitle || t.title || clsStr || "Window");
            var isFs = (o.fullscreenClient !== 0 || o.fullscreen !== 0 || (t && t.fullscreen === true));

            out.push({
                addr: o.address,
                tl: t,
                cls: clsStr,
                title: titleStr,
                wsId: wsId,
                isMinimized: isMin,
                fullscreen: isFs,
                monitor: (o.monitor !== undefined ? o.monitor : 0),
                origW: w,
                origH: h,
                aspect: winAspect
            });
        }
        return out;
    }

    readonly property int totalWindowCount: root.rawWindows.length

    // Filtered window model (by desktop space)
    readonly property var windowModel: {
        var list = root.rawWindows;
        var out = [];
        for (var i = 0; i < list.length; i++) {
            var win = list[i];
            if (!root.viewAllSpaces && win.wsId !== root.viewedWsId)
                continue;
            out.push(win);
        }
        return out;
    }

    // Number of windows matching the active search query
    readonly property int matchCount: {
        var q = root.searchQuery.toLowerCase().trim();
        if (q.length === 0) return root.windowModel.length;
        var count = 0;
        for (var i = 0; i < root.windowModel.length; i++) {
            var w = root.windowModel[i];
            if ((w.title && w.title.toLowerCase().indexOf(q) !== -1) || (w.cls && w.cls.toLowerCase().indexOf(q) !== -1))
                count++;
        }
        return count;
    }

    readonly property int windowCount: root.windowModel.length

    // Layout seed refreshed on each launch for dynamic organic placement
    property int layoutSeed: 101

    // ---- Dynamic 2D Window Spread Layout Engine ------------------------------
    readonly property real topBarY: 24 * root.s
    readonly property real stageTop: topBarY + 38 * root.s + 18 * root.s
    readonly property real stageBottom: root.height - 110 * root.s
    readonly property real availW: Math.max(300, root.width - 2 * (56 * root.s))
    readonly property real availH: Math.max(200, root.stageBottom - root.stageTop)

    // Calculate dynamic layout: organic randomized non-overlapping scatter matching macOS Mission Control
    readonly property var dynamicLayout: {
        var N = root.windowCount;
        if (N === 0)
            return { items: [], totalW: root.availW, totalH: root.availH };

        var items = [];
        var list = root.windowModel;
        var headerH = 38 * root.s;
        var marginW = 8 * root.s;

        // Calculates card dimensions inside a max bounding box while keeping exact window aspect ratio
        function fitCard(winAspect, maxSlotW, maxSlotH, mult) {
            var m = mult || 1.0;
            var netSlotW = Math.max(60 * root.s, maxSlotW - marginW) * m;
            var netSlotH = Math.max(40 * root.s, maxSlotH - headerH) * m;
            var previewW = Math.min(netSlotW, netSlotH * winAspect);
            var previewH = previewW / winAspect;
            if (previewH > netSlotH) {
                previewH = netSlotH;
                previewW = previewH * winAspect;
            }
            return {
                w: Math.round(previewW + marginW),
                h: Math.round(previewH + headerH)
            };
        }

        // Seeded pseudorandom generator in range [0, 1)
        function pRand(idx, salt) {
            var s = (root.layoutSeed + 13) * 9301 + (idx + 1) * 49297 + (salt || 1) * 233280;
            var v = Math.sin(s) * 10000;
            return v - Math.floor(v);
        }

        // Collision separation pass: guarantees 100% NO OVERLAP between any cards
        function resolveCollisions(itemList, minSep) {
            var sep = minSep || (24 * root.s);
            for (var iter = 0; iter < 45; iter++) {
                var collisionFound = false;
                for (var i = 0; i < itemList.length; i++) {
                    for (var j = i + 1; j < itemList.length; j++) {
                        var a = itemList[i];
                        var b = itemList[j];

                        var overlapX = Math.min(a.x + a.w + sep, b.x + b.w + sep) - Math.max(a.x, b.x);
                        var overlapY = Math.min(a.y + a.h + sep, b.y + b.h + sep) - Math.max(a.y, b.y);

                        if (overlapX > 0 && overlapY > 0) {
                            collisionFound = true;
                            if (overlapX < overlapY) {
                                var pushX = (overlapX / 2) + 2 * root.s;
                                if (a.x + a.w / 2 < b.x + b.w / 2) {
                                    a.x -= pushX;
                                    b.x += pushX;
                                } else {
                                    a.x += pushX;
                                    b.x -= pushX;
                                }
                            } else {
                                var pushY = (overlapY / 2) + 2 * root.s;
                                if (a.y + a.h / 2 < b.y + b.h / 2) {
                                    a.y -= pushY;
                                    b.y += pushY;
                                } else {
                                    a.y += pushY;
                                    b.y += pushY;
                                }
                            }
                        }
                    }
                }
                // Clamp within stageArea bounds
                for (var k = 0; k < itemList.length; k++) {
                    var it = itemList[k];
                    it.x = Math.max(0, Math.min(root.availW - it.w, it.x));
                    it.y = Math.max(0, Math.min(root.availH - it.h, it.y));
                }
                if (!collisionFound) break;
            }
        }

        // Centers the entire cluster of windows inside the stageArea
        function centerGroup(itemList) {
            if (!itemList || itemList.length === 0) return;
            var minX = itemList[0].x;
            var maxX = itemList[0].x + itemList[0].w;
            var minY = itemList[0].y;
            var maxY = itemList[0].y + itemList[0].h;

            for (var i = 1; i < itemList.length; i++) {
                var it = itemList[i];
                if (it.x < minX) minX = it.x;
                if (it.x + it.w > maxX) maxX = it.x + it.w;
                if (it.y < minY) minY = it.y;
                if (it.y + it.h > maxY) maxY = it.y + it.h;
            }

            var groupW = maxX - minX;
            var groupH = maxY - minY;
            var shiftX = (root.availW - groupW) / 2 - minX;
            var shiftY = (root.availH - groupH) / 2 - minY;

            for (var j = 0; j < itemList.length; j++) {
                var it2 = itemList[j];
                it2.x = Math.max(0, Math.min(root.availW - it2.w, it2.x + shiftX));
                it2.y = Math.max(0, Math.min(root.availH - it2.h, it2.y + shiftY));
            }
        }

        // =====================================================================
        // CASE 1: SINGLE WINDOW
        // =====================================================================
        if (N === 1) {
            var maxSlotW = root.availW * 0.74;
            var maxSlotH = root.availH * 0.74;
            var c = fitCard(list[0].aspect, maxSlotW, maxSlotH, 1.0);
            var jx = (pRand(0, 1) - 0.5) * 24 * root.s;
            var jy = (pRand(0, 2) - 0.5) * 16 * root.s;
            var sx = (root.availW - c.w) / 2 + jx;
            var sy = (root.availH - c.h) / 2 + jy;
            items.push({ x: sx, y: sy, w: c.w, h: c.h });
            return { items: items, totalW: root.availW, totalH: root.availH };
        }

        // =====================================================================
        // CASE 2: TWO WINDOWS (Normal size, diagonal or organic random placement)
        // =====================================================================
        if (N === 2) {
            var slotW2 = root.availW * 0.48;
            var slotH2 = root.availH * 0.62;
            var c0 = fitCard(list[0].aspect, slotW2, slotH2, 0.98);
            var c1 = fitCard(list[1].aspect, slotW2, slotH2, 0.98);

            var diag = pRand(0, 7) > 0.35;
            var flip = pRand(0, 9) > 0.5;

            if (diag) {
                if (flip) {
                    items.push({
                        x: root.availW * 0.52 + (pRand(0, 11) - 0.5) * 60 * root.s,
                        y: root.availH * 0.08 + (pRand(0, 13) - 0.5) * 40 * root.s,
                        w: c0.w,
                        h: c0.h
                    });
                    items.push({
                        x: root.availW * 0.10 + (pRand(1, 11) - 0.5) * 60 * root.s,
                        y: root.availH * 0.40 + (pRand(1, 13) - 0.5) * 40 * root.s,
                        w: c1.w,
                        h: c1.h
                    });
                } else {
                    items.push({
                        x: root.availW * 0.10 + (pRand(0, 11) - 0.5) * 60 * root.s,
                        y: root.availH * 0.08 + (pRand(0, 13) - 0.5) * 40 * root.s,
                        w: c0.w,
                        h: c0.h
                    });
                    items.push({
                        x: root.availW * 0.52 + (pRand(1, 11) - 0.5) * 60 * root.s,
                        y: root.availH * 0.40 + (pRand(1, 13) - 0.5) * 40 * root.s,
                        w: c1.w,
                        h: c1.h
                    });
                }
            } else {
                items.push({
                    x: root.availW * 0.12 + (pRand(0, 15) - 0.5) * 50 * root.s,
                    y: root.availH * 0.28 + (pRand(0, 16) - 0.5) * 60 * root.s,
                    w: c0.w,
                    h: c0.h
                });
                items.push({
                    x: root.availW * 0.52 + (pRand(1, 15) - 0.5) * 50 * root.s,
                    y: root.availH * 0.24 + (pRand(1, 16) - 0.5) * 60 * root.s,
                    w: c1.w,
                    h: c1.h
                });
            }

            resolveCollisions(items, 36 * root.s);
            centerGroup(items);
            return { items: items, totalW: root.availW, totalH: root.availH };
        }

        // =====================================================================
        // CASE 3: THREE WINDOWS (Normal size, organic triangular/diagonal scatter)
        // =====================================================================
        if (N === 3) {
            var slotW3 = root.availW * 0.45;
            var slotH3 = root.availH * 0.48;

            var c0 = fitCard(list[0].aspect, slotW3, slotH3, 0.96 + pRand(0, 41) * 0.08);
            var c1 = fitCard(list[1].aspect, slotW3, slotH3, 0.96 + pRand(1, 41) * 0.08);
            var c2 = fitCard(list[2].aspect, slotW3, slotH3, 0.96 + pRand(2, 41) * 0.08);

            items.push({
                x: root.availW * 0.30 + (pRand(0, 21) - 0.5) * 90 * root.s,
                y: root.availH * 0.06 + (pRand(0, 23) - 0.5) * 40 * root.s,
                w: c0.w,
                h: c0.h
            });
            items.push({
                x: root.availW * 0.08 + (pRand(1, 21) - 0.5) * 70 * root.s,
                y: root.availH * 0.46 + (pRand(1, 23) - 0.5) * 40 * root.s,
                w: c1.w,
                h: c1.h
            });
            items.push({
                x: root.availW * 0.54 + (pRand(2, 21) - 0.5) * 70 * root.s,
                y: root.availH * 0.44 + (pRand(2, 23) - 0.5) * 40 * root.s,
                w: c2.w,
                h: c2.h
            });

            resolveCollisions(items, 32 * root.s);
            centerGroup(items);
            return { items: items, totalW: root.availW, totalH: root.availH };
        }

        // =====================================================================
        // CASE: FOUR OR MORE WINDOWS (macOS Mission Control Floating Mosaic)
        // Spreads windows across the canvas with organic spatial variety,
        // dynamic sizing based on column occupancy, zero overlap, and
        // comfortable balanced negative space matching the reference design.
        // =====================================================================
        var gap = Math.max(18 * root.s, (26 - Math.min(6, N)) * root.s);

        var numCols = (N <= 4) ? 2 : ((N <= 8) ? 3 : 4);
        var colW = root.availW / numCols;

        // Distribute N items across columns with balanced occupancy
        // (For 7 items: [3, 2, 2]; for 6 items: [2, 2, 2]; for 5 items: [2, 1, 2])
        var colCounts = [];
        for (var c = 0; c < numCols; c++) {
            colCounts.push(Math.floor(N / numCols));
        }
        var rem = N % numCols;
        if (rem === 1) {
            colCounts[0] += 1;
        } else if (rem === 2) {
            colCounts[0] += 1;
            colCounts[numCols - 1] += 1;
        }

        var itemIdx = 0;
        for (var col = 0; col < numCols; col++) {
            var countInCol = colCounts[col];
            if (countInCol <= 0) continue;

            // Dynamic slot height specifically tailored to this column occupancy
            var colSlotW = colW * 0.92;
            var colSlotH = (root.availH * 0.88 - (countInCol - 1) * gap) / countInCol;

            // Phase shift for this column creates staggered vertical mosaic
            var colPhaseY = ((col % 2 === 1) ? 0.08 : -0.02) * root.availH + (pRand(col, 29) - 0.5) * 20 * root.s;
            var colCenterX = (col + 0.5) * colW;
            var rowStepY = (root.availH * 0.86) / countInCol;

            for (var row = 0; row < countInCol; row++) {
                if (itemIdx >= N) break;

                // Fit card within this column budget: larger for 2-item columns, compact for 3-item columns
                var sizeJitter = 0.96 + (pRand(itemIdx, 41) - 0.5) * 0.08;
                var curCard = fitCard(list[itemIdx].aspect, colSlotW, colSlotH, sizeJitter);

                var jX = (pRand(itemIdx, 71) - 0.5) * (colW * 0.20);
                var jY = (pRand(itemIdx, 73) - 0.5) * (rowStepY * 0.16);

                var anchorX = colCenterX + jX;
                var anchorY = (row + 0.5) * rowStepY + colPhaseY + jY;

                var posX = anchorX - curCard.w / 2;
                var posY = anchorY - curCard.h / 2;

                items.push({
                    x: Math.max(8 * root.s, Math.min(root.availW - curCard.w - 8 * root.s, posX)),
                    y: Math.max(8 * root.s, Math.min(root.availH - curCard.h - 8 * root.s, posY)),
                    w: curCard.w,
                    h: curCard.h
                });

                itemIdx++;
            }
        }

        resolveCollisions(items, gap);
        centerGroup(items);
        return { items: items, totalW: root.availW, totalH: root.availH };
    }

    // Keyboard selection navigation
    property int selected: 0
    property bool seeded: false
    function trySeed() {
        if (root.seeded || !root.dataReady)
            return;
        root.viewedWsId = root.activeWsId;
        root.selected = 0;
        root.seeded = true;
    }

    // Dynamic Hyprland compositor active opacity query
    property real compositorActiveOpacity: 0.85
    Process {
        id: queryOpacityProc
        command: ["hyprctl", "getoption", "decoration:active_opacity", "-j"]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var obj = JSON.parse(line);
                    if (obj && typeof obj.float === "number" && obj.float > 0) {
                        root.compositorActiveOpacity = obj.float;
                    }
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: queryOpacityProc.running = true

    Process {
        id: markOverviewActiveProc
        command: ["touch", "/tmp/ryoku_overview_active"]
    }
    Process {
        id: markOverviewInactiveProc
        command: ["rm", "-f", "/tmp/ryoku_overview_active"]
    }
    Process {
        id: hideSpecialMinimizedProc
        command: ["/usr/bin/python3", "/home/kshitij/.config/hypr/scripts/hide-special-minimized.py"]
    }

    onDataReadyChanged: root.trySeed()
    onActiveWsIdChanged: root.trySeed()
    onActiveChanged: {
        if (root.active) {
            queryOpacityProc.running = true;
            markOverviewActiveProc.running = true;
            var foc = Hyprland.focusedToplevel;
            root.initFocusedAddr = (foc && foc.address) ? foc.address : "";
            root.layoutSeed = (root.layoutSeed + 1 + Math.floor(Math.random() * 9999)) % 100000;
            root.seeded = false;
            root.showClearConfirm = false;
            root.clearSearch();
            root.trySeed();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        } else {
            root.cancelDrag();
            root.clearSearch();
            markOverviewInactiveProc.running = true;
            hideSpecialMinimizedProc.running = true;
        }
    }

    function cycle(d) {
        var n = root.windowCount;
        if (n === 0) return;
        root.selected = ((root.selected + d) % n + n) % n;
    }

    function cycleVertical(d) {
        var n = root.windowCount;
        if (n === 0) return;
        var layout = root.dynamicLayout;
        if (!layout || !layout.items || layout.items.length !== n) {
            root.cycle(d);
            return;
        }

        var curBox = layout.items[root.selected];
        if (!curBox) {
            root.cycle(d);
            return;
        }

        var curCenterX = curBox.x + curBox.w / 2;
        var curCenterY = curBox.y + curBox.h / 2;

        var bestIdx = -1;
        var bestDist = 999999;

        for (var i = 0; i < n; i++) {
            if (i === root.selected) continue;
            var box = layout.items[i];
            var candCenterX = box.x + box.w / 2;
            var candCenterY = box.y + box.h / 2;
            var dy = candCenterY - curCenterY;

            if (d > 0 && dy > 15 * root.s) {
                var dist = dy + Math.abs(candCenterX - curCenterX) * 0.7;
                if (dist < bestDist) {
                    bestDist = dist;
                    bestIdx = i;
                }
            } else if (d < 0 && dy < -15 * root.s) {
                var distU = Math.abs(dy) + Math.abs(candCenterX - curCenterX) * 0.7;
                if (distU < bestDist) {
                    bestDist = distU;
                    bestIdx = i;
                }
            }
        }

        if (bestIdx >= 0) {
            root.selected = bestIdx;
        } else {
            root.cycle(d > 0 ? 1 : -1);
        }
    }

    function cycleDesktop(d) {
        var list = root.deskList;
        if (list.length === 0) return;
        var cur = list.indexOf(root.viewedWsId);
        if (cur < 0) cur = 0;
        var nx = ((cur + d) % list.length + list.length) % list.length;
        root.viewAllSpaces = false;
        root.switchToWs(list[nx]);
    }

    function switchToSpaceNumber(num) {
        if (num <= 0) return;
        if (root.deskList.indexOf(num) !== -1) {
            root.viewAllSpaces = false;
            root.switchToWs(num);
        } else if (num <= root.maxOccWs + 1) {
            root.createDesktop();
        }
    }

    function activateSelected() {
        if (root.selected < 0 || root.selected >= root.windowModel.length)
            return;
        var win = root.windowModel[root.selected];
        root.focusWindow(win.tl, win.addr, win.isMinimized, win.wsId);
    }

    // Hyprland Actions & Focus
    function normAddr(a) { return (a && a.indexOf("0x") === 0) ? a : "0x" + a; }
    property var pendingCommit: null
    Timer {
        id: commitTimer
        interval: 150
        repeat: false
        onTriggered: {
            var fn = root.pendingCommit;
            root.pendingCommit = null;
            if (fn) fn();
        }
    }
    function commitOnClose(fn) {
        hideSpecialMinimizedProc.running = true;
        markOverviewInactiveProc.running = true;
        root.pendingCommit = fn;
        root.requestClose();
        commitTimer.restart();
    }
    function switchWs(id) {
        root.commitOnClose(function () {
            Hyprland.dispatch('hl.dsp.focus({ workspace = ' + id + ' })');
        });
    }
    function focusWindow(tl, addr, isMin, wsId) {
        root.commitOnClose(function () {
            if (isMin) {
                Hyprland.dispatch('require("modules.minmax").restore("' + root.normAddr(addr) + '")');
            } else {
                if (typeof wsId === "number" && wsId > 0 && wsId !== root.activeWsId) {
                    Hyprland.dispatch('hl.dsp.focus({ workspace = ' + wsId + ' })');
                }
                if (addr) {
                    Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.normAddr(addr) + '" })');
                }
                if (tl && tl.wayland) {
                    tl.wayland.activate();
                }
            }
        });
    }
    function moveWindow(addr, wsId) {
        if (!addr || !wsId) return;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + wsId + ', window = "address:' + root.normAddr(addr) + '" })');
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }

    function moveToNewSpace(addr) {
        if (!addr) return;
        var target = root.newWsId;
        var cur = root.userCreatedSpaces.slice();
        if (cur.indexOf(target) === -1) {
            cur.push(target);
            root.userCreatedSpaces = cur;
        }
        root.moveWindow(addr, target);
        root.viewedWsId = target;
        root.setViewAllSpaces(false);
        root.dropConfirmed(target);
    }

    function deskWinIcons(wsId) {
        var res = [];
        for (var i = 0; i < root.rawWindows.length; i++) {
            var w = root.rawWindows[i];
            if (w.wsId === wsId && w.cls) {
                var e = DesktopEntries.heuristicLookup(w.cls);
                var p = (e && e.icon) ? Quickshell.iconPath(e.icon, true) : "";
                if (!p) p = Quickshell.iconPath(w.cls, true);
                if (p && res.indexOf(p) === -1)
                    res.push(p);
            }
        }
        return res;
    }

    function cancelDrag() {
        root.dragging = false;
        root.dragTargetWs = root.noWs;
        root.dragAddr = "";
        root.dragTl = null;
    }
    function closeWindow(tl, addr) {
        if (tl && tl.wayland)
            tl.wayland.close();
        else if (addr)
            Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + root.normAddr(addr) + '" })');
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }

    // Clear All state
    property bool showClearConfirm: false
    function clearAllWindows() {
        root.showClearConfirm = false;
        var wins = root.rawWindows;
        var batch = [];
        for (var i = 0; i < wins.length; i++) {
            var cls = wins[i].cls;
            if (cls.indexOf("quickshell") >= 0 || cls.indexOf("ryoku") >= 0 ||
                cls === "hyprlock" || cls === "wlogout" || cls === "rofi" ||
                cls.indexOf("wlr-layer") >= 0) continue;
            batch.push("dispatch closewindow address:" + root.normAddr(wins[i].addr));
        }
        if (batch.length > 0) {
            clearAllProc.command = ["hyprctl", "--batch", batch.join(" ; ")];
            clearAllProc.running = true;
        }
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }
    Process { id: clearAllProc }

    function reorderWorkspaces(orderList) {
        if (!orderList || orderList.length <= 1) return;
        var wins = root.rawWindows;
        var mapping = {};
        for (var i = 0; i < orderList.length; i++) {
            mapping[orderList[i]] = i + 1;
        }
        for (var w = 0; w < wins.length; w++) {
            var win = wins[w];
            var target = mapping[win.wsId];
            if (target && target !== win.wsId && !win.isMinimized) {
                Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + (5000 + win.wsId) + ', window = "address:' + root.normAddr(win.addr) + '" })');
            }
        }
        for (var w2 = 0; w2 < wins.length; w2++) {
            var win2 = wins[w2];
            var target2 = mapping[win2.wsId];
            if (target2 && target2 !== win2.wsId && !win2.isMinimized) {
                Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + target2 + ', window = "address:' + root.normAddr(win2.addr) + '" })');
            }
        }
        if (mapping[root.viewedWsId])
            root.viewedWsId = mapping[root.viewedWsId];
        if (mapping[root.activeWsId])
            Hyprland.dispatch('hl.dsp.focus({ workspace = ' + mapping[root.activeWsId] + ' })');
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    // Drag-and-drop hit testing for Spaces Bar & Add Space button
    readonly property int noWs: -999
    property bool dragging: false
    property string dragAddr: ""
    property int dragSrcWs: 1
    property int dragTargetWs: noWs
    property real dragX: 0
    property real dragY: 0
    property var dragTl: null

    function endDrag() {
        root.dragging = false;
        root.dragTargetWs = root.noWs;
        root.dragAddr = "";
        root.dragTl = null;
    }
    function updateDrag(rx, ry) {
        root.dragX = rx;
        root.dragY = ry;
        var d = root.deskAtRoot(rx, ry);
        root.dragTargetWs = d;
    }
    function commitDrop() {
        if (root.dragTargetWs !== root.noWs) {
            var target = root.dragTargetWs;
            if (target === root.newWsId) {
                var cur = root.userCreatedSpaces.slice();
                if (cur.indexOf(root.newWsId) === -1) {
                    cur.push(root.newWsId);
                    root.userCreatedSpaces = cur;
                }
            }
            root.moveWindow(root.dragAddr, target);
            root.dropConfirmed(target);
        }
    }
    function deskAtRoot(px, py) {
        // Hit test "+" Add Space button on top-right (expanded with magnetism)
        var abX = addSpaceBtn.x;
        var abY = addSpaceBtn.y;
        var abW = addSpaceBtn.width;
        var abH = addSpaceBtn.height;
        if (px >= abX - 30 * root.s && px <= abX + abW + 30 * root.s &&
            py >= abY - 30 * root.s && py <= abY + abH + 30 * root.s) {
            return root.newWsId;
        }

        // Hit test Spaces Bar with proximity magnetism
        var lx = px - spacesBarWrap.x;
        var ly = py - spacesBarWrap.y;
        if (ly < -26 * root.s || ly > spacesBarWrap.height + 26 * root.s || lx < -26 * root.s || lx > spacesBarWrap.width + 26 * root.s)
            return root.noWs;

        var allPillW = (root.dragging ? 150 : 140) * root.s;
        var gap = (root.dragging ? 16 : 12) * root.s;
        var cardW = (root.dragging ? 164 : 140) * root.s;
        var step = cardW + gap;
        var startOffset = allPillW + gap;

        // If hovering over ALL SPACES pill
        if (lx >= -10 * root.s && lx < allPillW + gap / 2) {
            return root.viewedWsId;
        }

        if (lx >= allPillW + gap / 2) {
            var relX = lx - startOffset;
            var idx = Math.floor(relX / step);
            if (idx < 0) idx = 0;
            if (idx >= root.deskList.length) idx = root.deskList.length - 1;
            return root.deskList[idx];
        }
        return root.viewedWsId;
    }

    // ---- Visual Components ---------------------------------------------------

    // Poster Title (top-left)
    Row {
        id: brandPoster
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 40 * root.s
        anchors.topMargin: 24 * root.s
        spacing: 10 * root.s
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        BrandMark {
            anchors.verticalCenter: parent.verticalCenter
            size: 22 * root.s
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * root.s
            Text {
                text: I18n.tr("MISSION CONTROL")
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.letterSpacing: 2 * root.s
                font.weight: Font.Bold
            }
            Text {
                text: root.viewAllSpaces ? I18n.tr("ALL RUNNING WINDOWS") : (I18n.tr("SPACE ") + root.viewedWsId)
                color: Theme.brand
                font.family: Theme.mono
                font.pixelSize: 8.5 * root.s
                font.letterSpacing: 1.2 * root.s
            }
        }
    }

    // Top Spaces Bar (macOS Spaces) - centered, floating without outer container
    Item {
        id: spacesBarWrap
        x: (root.width - spacesBar.implicitWidth) / 2
        y: root.active ? root.topBarY : (root.topBarY - 12 * root.s)
        opacity: root.active ? 1 : 0
        width: spacesBar.implicitWidth
        height: spacesBar.implicitHeight
        z: 30

        Behavior on y { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        SpacesBar {
            id: spacesBar
            s: root.s
            ov: root
        }
    }

    // "+" Add Space Button (Morphs into "+ New Space" pill when dragging)
    Item {
        id: addSpaceBtn
        anchors.right: parent.right
        anchors.rightMargin: 40 * root.s
        anchors.verticalCenter: spacesBarWrap.verticalCenter
        width: (root.dragging ? 154 : 58) * root.s
        height: (root.dragging ? 58 : 58) * root.s
        opacity: root.active ? 1 : 0
        z: 40

        Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        property bool hovered: addSpaceMa.containsMouse
        readonly property bool dropHot: !!root.dragging && root.dragTargetWs === root.newWsId

        scale: addSpaceMa.pressed ? 0.95 : ((addSpaceBtn.dropHot || addSpaceBtn.hovered) ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.fill: parent
            radius: 28 * root.s
            color: addSpaceBtn.dropHot ? Qt.rgba(226/255, 52/255, 42/255, 0.25)
                : (addSpaceBtn.hovered ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.10))
            border.width: addSpaceBtn.dropHot ? 2 : (addSpaceBtn.hovered ? 1 : 0)
            border.color: addSpaceBtn.dropHot ? Theme.brand : (addSpaceBtn.hovered ? Qt.rgba(1, 1, 1, 0.20) : "transparent")

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            // Inner highlight
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 2
                width: parent.width * 0.6
                height: 1
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            Row {
                anchors.centerIn: parent
                spacing: 6 * root.s

                Text {
                    text: "+"
                    color: (addSpaceBtn.hovered || addSpaceBtn.dropHot) ? Theme.brand : Qt.rgba(1, 1, 1, 0.80)
                    font.family: Theme.font
                    font.pixelSize: (root.dragging ? 22 : 32) * root.s
                    font.weight: Font.Light
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Text {
                    visible: root.dragging
                    text: I18n.tr("New Space")
                    color: addSpaceBtn.dropHot ? Theme.brand : "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }
            }
        }

        MouseArea {
            id: addSpaceMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.createSpace()
        }
    }

    // Search Query Toast / Pill (appears when typing)
    Rectangle {
        id: searchToast
        visible: root.searchQuery.trim().length > 0
        anchors.top: spacesBarWrap.bottom
        anchors.topMargin: 10 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        height: 30 * root.s
        width: searchRow.implicitWidth + 22 * root.s
        radius: 15 * root.s
        color: Qt.rgba(0, 0, 0, 0.45)
        border.width: 0
        border.color: "transparent"
        z: 35

        Row {
            id: searchRow
            anchors.centerIn: parent
            spacing: 7 * root.s

            Text {
                text: "⌕"
                color: Theme.brand
                font.pixelSize: 12 * root.s
                font.weight: Font.Bold
            }
            Text {
                text: root.searchQuery
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                text: "(" + root.matchCount + " " + I18n.tr("matching") + ")"
                color: Qt.rgba(255, 255, 255, 0.6)
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
            }
        }
    }

    // Empty State (No open windows)
    Item {
        anchors.fill: stageArea
        visible: opacity > 0
        opacity: root.windowCount === 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

        Column {
            anchors.centerIn: parent
            spacing: 10 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "□"
                color: Qt.rgba(255, 255, 255, 0.35)
                font.pixelSize: 44 * root.s
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("No Open Windows")
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: 14 * root.s
                font.weight: Font.DemiBold
            }
        }
    }

    // Main Window Spread Stage (Transparent background)
    Item {
        id: stageArea
        x: 56 * root.s
        y: root.stageTop
        width: root.availW
        height: root.availH

        Repeater {
            model: root.windowModel
            delegate: MissionCard {
                id: cardItem
                required property var modelData
                required property int index
                readonly property var box: (root.dynamicLayout && root.dynamicLayout.items && root.dynamicLayout.items[cardItem.index]) ? root.dynamicLayout.items[cardItem.index] : ({ x: 0, y: 0, w: 100, h: 100 })

                x: cardItem.box.x
                y: cardItem.box.y
                width: cardItem.box.w
                height: cardItem.box.h
                s: root.s
                ov: root
                idx: cardItem.index
                winData: cardItem.modelData
                selected: root.selected === cardItem.index

                Behavior on x { enabled: cardItem.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on y { enabled: cardItem.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on width { enabled: cardItem.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on height { enabled: cardItem.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
            }
        }
    }

    // ✕ CLOSE ALL — Glassmorphic Pill Button (above footer)
    Item {
        id: clearAllBtn
        visible: root.windowCount > 0 && !root.showClearConfirm
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 52 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: clearAllRow.implicitWidth + 48 * root.s
        height: 48 * root.s
        z: 25

        scale: clearAllMa.pressed ? 0.97 : (clearAllMa.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

        Rectangle {
            anchors.fill: parent
            radius: 24 * root.s
            color: clearAllMa.containsMouse
                ? Qt.rgba(0, 0, 0, 0.18)
                : Qt.rgba(0, 0, 0, 0.10)
            border.width: 0
            border.color: "transparent"

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            // Inner highlight
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 16 * root.s
                anchors.rightMargin: 16 * root.s
                height: 1
                radius: 1
                color: Qt.rgba(1, 1, 1, 0.05)
            }

            Row {
                id: clearAllRow
                anchors.centerIn: parent
                spacing: 10 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                    font.weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("CLOSE ALL")
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2 * root.s
                }
            }
        }

        MouseArea {
            id: clearAllMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showClearConfirm = true
        }
    }

    // Clear All Confirmation Dialog (Glassmorphic Panel)
    Rectangle {
        id: clearConfirmPanel
        visible: root.showClearConfirm
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 42 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        width: 360 * root.s
        height: 110 * root.s
        radius: 20 * root.s
        z: 25
        color: Qt.rgba(0, 0, 0, 0.65)
        border.width: 0
        border.color: "transparent"

        opacity: root.showClearConfirm ? 1 : 0
        scale: root.showClearConfirm ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        // Inner highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 1
            anchors.leftMargin: 16 * root.s
            anchors.rightMargin: 16 * root.s
            height: 1
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.05)
        }

        Column {
            anchors.centerIn: parent
            spacing: 16 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("Close all running applications?")
                color: Qt.rgba(1, 1, 1, 0.85)
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * root.s

                // CANCEL button
                Rectangle {
                    width: cancelText.implicitWidth + 32 * root.s
                    height: 36 * root.s
                    radius: 18 * root.s
                    color: cancelMa.containsMouse ? Qt.rgba(0, 0, 0, 0.20) : Qt.rgba(0, 0, 0, 0.10)
                    border.width: 0
                    border.color: "transparent"
                    scale: cancelMa.pressed ? 0.96 : 1.0

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Text {
                        id: cancelText
                        anchors.centerIn: parent
                        text: I18n.tr("CANCEL")
                        color: Qt.rgba(1, 1, 1, 0.70)
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.5
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showClearConfirm = false
                    }
                }

                // CLOSE ALL confirm button
                Rectangle {
                    width: confirmText.implicitWidth + 32 * root.s
                    height: 36 * root.s
                    radius: 18 * root.s
                    color: confirmMa.containsMouse ? Qt.rgba(0.7, 0.2, 0.2, 0.60) : Qt.rgba(0, 0, 0, 0.10)
                    border.width: 0
                    border.color: "transparent"
                    scale: confirmMa.pressed ? 0.96 : 1.0

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

                    Text {
                        id: confirmText
                        anchors.centerIn: parent
                        text: I18n.tr("CLOSE ALL")
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                    }

                    MouseArea {
                        id: confirmMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.clearAllWindows()
                    }
                }
            }
        }
    }

    // Bottom Navigation Help Footer
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20 * root.s
        text: I18n.tr("CLICK  FOCUS WINDOW      TAB / ARROWS  NAVIGATE      TYPE  FILTER      ✕  CLOSE      ESC  DISMISS")
        color: Qt.rgba(255, 255, 255, 0.45)
        font.family: Theme.mono
        font.pixelSize: 9.5 * root.s
        font.letterSpacing: 1.4 * root.s
    }

    // Mouse Wheel Navigation
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            if (e.angleDelta.y === 0) return;
            root.cycle(e.angleDelta.y < 0 ? 1 : -1);
        }
    }

    // Carried Window Ghost (while dragging window to Spaces Bar)
    Item {
        anchors.fill: parent
        z: 200

        Rectangle {
            id: dragGhost
            visible: root.dragging
            width: 170 * root.s
            height: Math.round(170 * root.s / root.aspect)
            x: root.dragX - width / 2
            y: root.dragY - height / 2
            radius: 10 * root.s
            color: "#1e1e24"
            border.width: 2
            border.color: Theme.brand
            antialiasing: true
            scale: root.dragging ? 1.05 : 0.9
            opacity: 0.9

            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeExpo } }

            ScreencopyView {
                anchors.fill: parent
                anchors.margins: 2
                captureSource: root.dragTl
                live: false
                visible: root.dragTl !== null
            }
        }
    }
}
