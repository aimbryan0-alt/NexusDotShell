.pragma library

.import "./SettingsSpec.js" as SpecModule
.import "./SpecUtil.js" as Util

var CONFIG_VERSION = 1;

function parse(root, jsonObj) {
    var SPEC = SpecModule.SPEC;

    // Reset every persisted key to its default when absent from the JSON
    // (including when there is no settings file yet).
    for (var k in SPEC) {
        if (SPEC[k].persist === false) continue;
        if (!jsonObj || !(k in jsonObj)) {
            root[k] = Util.cloneDef(SPEC[k].def);
        }
    }

    // Apply present values, running coerce when given.
    if (jsonObj) {
        for (var k in jsonObj) {
            if (!SPEC[k]) continue;
            var raw = jsonObj[k];
            var spec = SPEC[k];
            var coerce = spec.coerce;
            root[k] = coerce ? (coerce(raw) !== undefined ? coerce(raw) : root[k]) : raw;
        }
    }
}

function toJson(root) {
    var SPEC = SpecModule.SPEC;
    var out = {};
    for (var k in SPEC) {
        if (SPEC[k].persist === false) continue;
        var value = root[k];
        if (Util.isDefault(value, SPEC[k].def)) continue;
        out[k] = value;
    }
    out.configVersion = root.settingsConfigVersion || CONFIG_VERSION;
    return out;
}

function migrateToVersion(obj, targetVersion) {
    if (!obj) return null;
    var settings = JSON.parse(JSON.stringify(obj));
    var currentVersion = settings.configVersion || 0;
    if (currentVersion >= targetVersion) return null;
    if (currentVersion < 2) {
        var rightWidgets = settings.barRightWidgets;
        if (Array.isArray(rightWidgets) && !rightWidgets.some(function(widget) {
            return widget && widget.id === "cpuTemperature";
        })) {
            var migratedWidgets = rightWidgets.slice();
            var cpuIndex = migratedWidgets.findIndex(function(widget) {
                return widget && widget.id === "cpuUsage";
            });
            migratedWidgets.splice(cpuIndex >= 0 ? cpuIndex + 1 : migratedWidgets.length, 0, {
                id: "cpuTemperature",
                enabled: true
            });
            settings.barRightWidgets = migratedWidgets;
        }
    }
    if (currentVersion < 3) {
        var leftWidgets = settings.barLeftWidgets;
        if (Array.isArray(leftWidgets) && !leftWidgets.some(function(widget) {
            return widget && widget.id === "submap";
        })) {
            var migratedLeftWidgets = settings.barLeftWidgets.slice();
            var launcherIndex = migratedLeftWidgets.findIndex(function(widget) {
                return widget && widget.id === "launcherButton";
            });
            migratedLeftWidgets.splice(launcherIndex >= 0 ? launcherIndex + 1 : 0, 0, {
                id: "submap",
                enabled: true
            });
            settings.barLeftWidgets = migratedLeftWidgets;
        }
    }
    if (currentVersion < 4) {
        var centerWidgets = settings.barCenterWidgets;
        if (Array.isArray(centerWidgets) && !centerWidgets.some(function(widget) {
            return widget && widget.id === "player";
        })) {
            var migratedCenterWidgets = centerWidgets.slice();
            var clockIndex = migratedCenterWidgets.findIndex(function(widget) {
                return widget && widget.id === "clock";
            });
            migratedCenterWidgets.splice(clockIndex >= 0 ? clockIndex : migratedCenterWidgets.length, 0, {
                id: "player",
                enabled: true
            });
            settings.barCenterWidgets = migratedCenterWidgets;
        }
    }
    if (currentVersion < 6 && settings.calendarBirthYear === 0)
        settings.calendarBirthYear = -1;
    if (currentVersion < 7 && Array.isArray(settings.barRightWidgets) &&
        !settings.barRightWidgets.some(function(widget) {
            return widget && widget.id === "notepadButton";
        })) {
        var rightWidgetsWithNotepad = settings.barRightWidgets.slice();
        var settingsButtonIndex = rightWidgetsWithNotepad.findIndex(function(widget) {
            return widget && widget.id === "controlCenterButton";
        });
        rightWidgetsWithNotepad.splice(settingsButtonIndex >= 0 ? settingsButtonIndex : rightWidgetsWithNotepad.length, 0, {
            id: "notepadButton",
            enabled: true
        });
        settings.barRightWidgets = rightWidgetsWithNotepad;
    }
    if (currentVersion < 10 && Array.isArray(settings.barRightWidgets) &&
        !settings.barRightWidgets.some(function(widget) {
            return widget && widget.id === "networkMonitor";
        })) {
        var rightWidgetsWithNetwork = settings.barRightWidgets.slice();
        var trayIndex = rightWidgetsWithNetwork.findIndex(function(widget) {
            return widget && widget.id === "systemTray";
        });
        rightWidgetsWithNetwork.splice(trayIndex >= 0 ? trayIndex + 1 : rightWidgetsWithNetwork.length, 0, {
            id: "networkMonitor",
            enabled: true
        });
        settings.barRightWidgets = rightWidgetsWithNetwork;
    }
    if (currentVersion < 11 && Array.isArray(settings.barRightWidgets)) {
        var restoredRightWidgets = settings.barRightWidgets.slice();
        var sceneIndex = restoredRightWidgets.findIndex(function(widget) {
            return widget && widget.id === "wallpaperCarousel";
        });
        if (sceneIndex < 0) {
            var trayPosition = restoredRightWidgets.findIndex(function(widget) {
                return widget && widget.id === "systemTray";
            });
            restoredRightWidgets.splice(trayPosition >= 0 ? trayPosition : restoredRightWidgets.length, 0, {
                id: "wallpaperCarousel",
                enabled: true
            });
        }
        ["notepadButton", "controlCenterButton"].forEach(function(id) {
            var index = restoredRightWidgets.findIndex(function(widget) {
                return widget && widget.id === id;
            });
            if (index >= 0) {
                var item = restoredRightWidgets.splice(index, 1)[0];
                restoredRightWidgets.unshift(item);
            } else {
                restoredRightWidgets.unshift({ id: id, enabled: true });
            }
        });
        settings.barRightWidgets = restoredRightWidgets;
    }
    if (currentVersion < 12) {
        var centerWidgetsV12 = Array.isArray(settings.barCenterWidgets)
            ? settings.barCenterWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barCenterWidgets"].def);
        var rightWidgetsV12 = Array.isArray(settings.barRightWidgets)
            ? settings.barRightWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barRightWidgets"].def);
        var leftWidgetsV12 = Array.isArray(settings.barLeftWidgets)
            ? settings.barLeftWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barLeftWidgets"].def);

        // Keep Nexus Center alone in the true center; preserve other center
        // widgets by moving them into the right-side group.
        centerWidgetsV12.forEach(function(widget) {
            if (!widget || widget.id === "controlCenterButton") return;
            if (!rightWidgetsV12.some(function(existing) {
                return existing && existing.id === widget.id;
            }))
                rightWidgetsV12.push(widget);
        });

        leftWidgetsV12 = leftWidgetsV12.filter(function(widget) {
            return !widget || widget.id !== "controlCenterButton";
        });
        rightWidgetsV12 = rightWidgetsV12.filter(function(widget) {
            return !widget || widget.id !== "controlCenterButton";
        });

        settings.barLeftWidgets = leftWidgetsV12;
        settings.barCenterWidgets = [{ id: "controlCenterButton", enabled: true }];
        settings.barRightWidgets = rightWidgetsV12;
    }
    if (currentVersion < 13) {
        // Reorder the right lane for the intended visual sequence.
        // Row.layoutDirection is RightToLeft, so the array is stored in reverse.
        var orderedIds = [
            "player", "clock", "wallpaperCarousel", "notificationButton",
            "notepadButton", "battery", "diskUsage", "memUsage",
            "cpuTemperature", "cpuUsage", "networkMonitor", "systemTray"
        ];
        var sourceWidgets = Array.isArray(settings.barRightWidgets)
            ? settings.barRightWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barRightWidgets"].def);
        var orderedWidgets = [];
        orderedIds.forEach(function(id) {
            var index = sourceWidgets.findIndex(function(widget) {
                return widget && widget.id === id;
            });
            if (index >= 0)
                orderedWidgets.push(sourceWidgets.splice(index, 1)[0]);
            else
                orderedWidgets.push({ id: id, enabled: true });
        });
        // Keep any future/third-party widgets rather than silently deleting them.
        settings.barRightWidgets = orderedWidgets.concat(sourceWidgets);
    }
    if (currentVersion < 14) {
        // Restore natural left-to-right ordering for the original adaptive
        // lanes. The player is routed to its dedicated far-right Row.
        var orderedRightIds = [
            "systemTray", "networkMonitor", "cpuUsage", "cpuTemperature",
            "memUsage", "diskUsage", "battery", "notepadButton",
            "notificationButton", "wallpaperCarousel", "clock", "player"
        ];
        var existingRight = Array.isArray(settings.barRightWidgets)
            ? settings.barRightWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barRightWidgets"].def);
        var orderedRight = [];
        orderedRightIds.forEach(function(id) {
            var index = existingRight.findIndex(function(widget) {
                return widget && widget.id === id;
            });
            if (index >= 0)
                orderedRight.push(existingRight.splice(index, 1)[0]);
            else
                orderedRight.push({ id: id, enabled: true });
        });
        settings.barRightWidgets = orderedRight.concat(existingRight);
    }
    if (currentVersion < 15) {
        // Put media directly after the focused-window widget on the left.
        var leftForMedia = Array.isArray(settings.barLeftWidgets)
            ? settings.barLeftWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barLeftWidgets"].def);
        var rightWithoutMedia = Array.isArray(settings.barRightWidgets)
            ? settings.barRightWidgets.slice()
            : Util.cloneDef(SpecModule.SPEC["barRightWidgets"].def);
        var mediaEntry = null;
        [leftForMedia, rightWithoutMedia].forEach(function(list) {
            var index = list.findIndex(function(widget) {
                return widget && widget.id === "player";
            });
            if (index >= 0) {
                var found = list.splice(index, 1)[0];
                if (!mediaEntry) mediaEntry = found;
            }
        });
        if (!mediaEntry) mediaEntry = { id: "player", enabled: true };
        var focusedIndex = leftForMedia.findIndex(function(widget) {
            return widget && widget.id === "focusedWindow";
        });
        leftForMedia.splice(focusedIndex >= 0 ? focusedIndex + 1 : leftForMedia.length, 0, mediaEntry);
        settings.barLeftWidgets = leftForMedia;
        settings.barRightWidgets = rightWithoutMedia;
    }
    settings.configVersion = targetVersion;
    return settings;
}
