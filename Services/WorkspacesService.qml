pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Compositor-agnostic workspace state.
//
// The bar binds to this one interface instead of reaching into any specific
// compositor. The current implementation shells out to hyprctl (Hyprland), the
// same approach the Omarchy shell relies on, and yields data through a small
// sink-shaped surface:
//   workspaceIds   - every workspace id present in the layout (sorted)
//   occupiedIds    - workspaces that currently have a window open
//   activeWorkspaceId(name) - active workspace id for a monitor, by name
//   activeWorkspaceName(name) - active workspace name for a monitor
//   switchTo(id)   - focus a workspace
//
// A Niri/I3/generic backend can later implement the same surface without the
// bar changing. When no workspaces are reported the bar simply renders empty.
QtObject {
  id: root

  property var workspaceIds: []
  property var occupiedIds: []

  // Active workspace id per monitor name, refreshed from hyprctl.
  property var activeByMonitor: ({})
  property var activeNameByMonitor: ({})
  readonly property string desktop: (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("DESKTOP_SESSION") || "").toLowerCase()
  readonly property string backend: desktop.indexOf("niri") !== -1 ? "niri"
    : (desktop.indexOf("hypr") !== -1 ? "hyprland"
    : (desktop.indexOf("mango") !== -1 ? "mango"
    : (desktop.indexOf("dwl") !== -1 ? "dwl"
    : (desktop.indexOf("labwc") !== -1 ? "labwc" : "hyprland"))))

  function activeWorkspaceId(monitorName) {
    var v = activeByMonitor[monitorName]
    return v === undefined ? 0 : v
  }

  function activeWorkspaceName(monitorName) {
    return String(activeNameByMonitor[monitorName] || "")
  }

  readonly property var specialWorkspaceNames: {
    if (root.backend !== "hyprland")
      return []
    const names = ["special"]
    for (const workspace of Hyprland.workspaces?.values || []) {
      const workspaceName = String(workspace.name || "")
      if (!workspaceName.startsWith("special:"))
        continue
      const name = workspaceName.slice("special:".length) || "special"
      if (names.indexOf(name) === -1)
        names.push(name)
    }
    return names
  }

  function hyprlandToplevelFor(window) {
    if (!window)
      return null
    for (const toplevel of Hyprland.toplevels?.values || []) {
      if (toplevel.wayland === window)
        return toplevel
    }
    return null
  }

  function windowScratchpadName(window) {
    const toplevel = root.hyprlandToplevelFor(window)
    const workspaceName = String(toplevel?.workspace?.name || "")
    if (workspaceName === "special")
      return "special"
    return workspaceName.startsWith("special:")
      ? workspaceName.slice("special:".length) || "special"
      : ""
  }

  function moveWindowToScratchpad(window, name) {
    const toplevel = root.hyprlandToplevelFor(window)
    if (root.backend !== "hyprland" || !toplevel?.address)
      return false
    const workspace = name === "special" ? "special" : "special:" + String(name)
    const address = String(toplevel.address)
    const selector = "address:" + (address.startsWith("0x") ? address : "0x" + address)
    Hyprland.dispatch(
      "hl.dsp.window.move({ workspace = " + root.luaString(workspace)
      + ", window = " + root.luaString(selector) + ", follow = false })"
    )
    return true
  }

  function moveWindowOutOfScratchpad(window) {
    const toplevel = root.hyprlandToplevelFor(window)
    if (root.backend !== "hyprland" || !toplevel?.address)
      return false
    const workspace = toplevel.monitor?.activeWorkspace
    const target = workspace?.name || workspace?.id || "+0"
    const address = String(toplevel.address)
    const selector = "address:" + (address.startsWith("0x") ? address : "0x" + address)
    Hyprland.dispatch(
      "hl.dsp.window.move({ workspace = " + root.luaValue(target)
      + ", window = " + root.luaString(selector) + ", follow = true })"
    )
    return true
  }

  function closeWindow(window) {
    if (!window || typeof window.close !== "function")
      return false
    window.close()
    return true
  }

  function luaString(value) {
    return "\"" + String(value).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""
  }

  function luaValue(value) {
    const text = String(value)
    return /^\d+$/.test(text) ? text : root.luaString(text)
  }

  // Refresh workspace state from Quickshell's native Hyprland model.
  // This is event-driven: no recurring hyprctl process is spawned.
  function refreshAll() {
    if (root.backend !== "hyprland") {
      workspaceIds = []
      occupiedIds = []
      activeByMonitor = ({})
      activeNameByMonitor = ({})
      return
    }

    Hyprland.refreshWorkspaces()
    Hyprland.refreshMonitors()
    Hyprland.refreshToplevels()
    refreshTimer.restart()
  }

  function syncFromHyprland() {
    if (root.backend !== "hyprland")
      return

    const ids = []
    const occupied = []
    const workspaces = Hyprland.workspaces?.values || []

    for (const workspace of workspaces) {
      const id = Number(workspace.id)
      if (!Number.isInteger(id) || id < 1)
        continue

      if (ids.indexOf(id) === -1)
        ids.push(id)

      const windows = workspace.toplevels?.values || []
      if (windows.length > 0)
        occupied.push(id)
    }

    ids.sort((a, b) => a - b)
    occupied.sort((a, b) => a - b)
    workspaceIds = ids
    occupiedIds = occupied

    const byMonitor = ({})
    const namesByMonitor = ({})
    const monitors = Hyprland.monitors?.values || []

    for (const monitor of monitors) {
      const name = String(monitor.name || "")
      const active = monitor.activeWorkspace
      if (!name)
        continue

      byMonitor[name] = active ? Number(active.id) : 0
      namesByMonitor[name] = active ? String(active.name || "") : ""
    }

    activeByMonitor = byMonitor
    activeNameByMonitor = namesByMonitor
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (!event || root.backend !== "hyprland")
        return

      const name = String(event.name || "")
      const workspaceEvents = [
        "workspace", "workspacev2",
        "createworkspace", "createworkspacev2",
        "destroyworkspace", "destroyworkspacev2",
        "moveworkspace", "moveworkspacev2",
        "renameworkspace", "focusedmon",
        "monitoradded", "monitorremoved",
        "configreloaded"
      ]
      const windowEvents = [
        "openwindow", "closewindow",
        "movewindow", "movewindowv2"
      ]

      if (workspaceEvents.indexOf(name) !== -1) {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshMonitors()
        Hyprland.refreshToplevels()
        refreshTimer.restart()
      } else if (windowEvents.indexOf(name) !== -1) {
        Hyprland.refreshToplevels()
        refreshTimer.restart()
      }
    }
  }

  Component.onCompleted: root.refreshAll()

  // Coalesce bursts of compositor events into one UI-state refresh.
  property Timer refreshTimer: Timer {
    id: refreshTimer
    interval: 60
    repeat: false
    onTriggered: root.syncFromHyprland()
  }
}
