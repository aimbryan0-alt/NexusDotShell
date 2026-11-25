import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.Bar.Widgets

// The bar's visual body: a transparent canvas laying out bar widgets into
// left / center / right groups, driven by the SettingsData widget lists.
// Widgets that have no component yet are skipped. Each widget id maps to an
// inline Component over the registered widget type. The bar surface wraps this
// and supplies the screen.
Item {
  id: root

  property QtObject screen: null
  property QtObject barWindow: null

  // Keep groups readable even when older settings contain zero/negative spacing.
  readonly property int spacing: Math.max(2,
    typeof SettingsData !== "undefined" ? SettingsData.barSpacing : 3)
  readonly property int innerPadding: Math.max(6,
    typeof SettingsData !== "undefined" ? SettingsData.barInnerPadding : 6)
  // Keep side groups close to Nexus Center without touching its centered position.
  readonly property int centerGap: Math.max(root.spacing, Theme.barThickness)

  Component { id: launcherButtonComp; LauncherButton {} }
  Component { id: submapComp; SubmapWidget {} }
  Component { id: workspaceSwitcherComp; WorkspacesWidget {} }
  Component { id: runningAppsComp; RunningAppsWidget {} }
  Component { id: focusedWindowComp; FocusedWindowWidget {} }
  Component { id: playerComp; PlayerWidget {} }
  Component { id: clockComp; ClockWidget {} }
  Component { id: systemTrayComp; SystemTrayWidget {} }
  Component { id: cpuUsageComp; CpuWidget {} }
  Component { id: cpuTemperatureComp; TemperatureWidget {} }
  Component { id: memUsageComp; RamWidget {} }
  Component { id: diskUsageComp; DiskWidget {} }
  Component { id: batteryComp; BatteryWidget {} }
  Component { id: settingsComp; SettingsWidget {} }
  Component { id: notepadComp; NotesWidget {} }
  Component { id: notificationComp; NotificationWidget {} }
  Component { id: wallpaperCarouselComp; WallpaperCarouselWidget {} }
  Component { id: networkComp; NetworkWidget {} }

  function registryFor(id) {
    switch (id) {
    case "launcherButton": return launcherButtonComp
    case "submap": return submapComp
    case "workspaceSwitcher": return workspaceSwitcherComp
    case "runningApps": return runningAppsComp
    case "focusedWindow": return focusedWindowComp
    case "player": return playerComp
    case "clock": return clockComp
    case "systemTray": return systemTrayComp
    case "cpuUsage": return cpuUsageComp
    case "cpuTemperature": return cpuTemperatureComp
    case "memUsage": return memUsageComp
    case "diskUsage": return diskUsageComp
    case "battery": return batteryComp
    case "controlCenterButton": return settingsComp
    case "notepadButton": return notepadComp
    case "notificationButton": return notificationComp
    case "wallpaperCarousel": return wallpaperCarouselComp
    case "networkMonitor": return networkComp
    default: return null
    }
  }

  function hasEnabledWidget(id) {
    const lists = [SettingsData.barLeftWidgets, SettingsData.barCenterWidgets, SettingsData.barRightWidgets]
    for (let listIndex = 0; listIndex < lists.length; listIndex++) {
      const list = lists[listIndex] || []
      for (let widgetIndex = 0; widgetIndex < list.length; widgetIndex++) {
        const entry = list[widgetIndex]
        if (entry && entry.id === id && entry.enabled === true)
          return true
      }
    }
    return false
  }

  property var _created: []

  function fillRow(list, hostRow) {
    if (!list) return
    const groupCpuMemory = root.hasEnabledWidget("cpuUsage") && root.hasEnabledWidget("memUsage")
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (!entry || entry.enabled !== true) continue
      if (groupCpuMemory && entry.id === "memUsage") continue
      var comp = root.registryFor(entry.id)
      if (comp && comp.status === Component.Error) {
        console.error("MQBAR component error for", entry.id, ":", comp.errorString())
      }
      if (comp === null) { console.info("MQBAR skip (no comp):", entry.id); continue }
      var targetRow = hostRow
      var initProps = {
        "screen": root.screen,
        "parentScreen": root.screen,
        "barWindow": root.barWindow
      }
      if (groupCpuMemory && entry.id === "cpuUsage")
        initProps["groupedMemory"] = true
      var obj = comp.createObject(targetRow, initProps)
      if (obj) {
        if (entry.id === "focusedWindow") {
          const titleWidget = obj
          obj.maxWidth = Qt.binding(function() {
            return root.titleSpaceFor(titleWidget)
          })
        }
        root._created.push(obj)
      } else {
        console.error("MQBAR failed to create obj for:", entry.id)
      }
    }
  }

  function rebuild() {
    for (var i = 0; i < root._created.length; i++) {
      root._created[i].destroy()
    }
    root._created = []
    root.fillRow(SettingsData.barLeftWidgets, leftRow)
    root.fillRow(SettingsData.barCenterWidgets, centerRow)
    root.fillRow(SettingsData.barRightWidgets, rightRow)
  }

  function titleSpaceFor(titleWidget) {
    var usedWidth = 0
    var precedingWidgets = 0
    for (var i = 0; i < leftRow.children.length; i++) {
      var child = leftRow.children[i]
      if (child === titleWidget)
        break
      if (!child.visible)
        continue
      if (precedingWidgets > 0)
        usedWidth += root.spacing
      usedWidth += child.width
      precedingWidgets++
    }
    if (precedingWidgets > 0)
      usedWidth += root.spacing
    return Math.max(0, centerRow.x - root.centerGap - leftRow.x - usedWidth)
  }

  Component.onCompleted: {
    root.rebuild()
  }

  Connections {
    target: SettingsData
    function onSettingsApplied() {
      root.rebuild()
    }
  }

  Row {
    id: leftRow
    x: Math.max(root.innerPadding,
      centerRow.x - root.centerGap - implicitWidth)
    width: Math.max(0, Math.min(implicitWidth,
      centerRow.x - root.centerGap - x))
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
    clip: true
  }

  // Nexus Center remains mathematically centered and independent of side groups.
  Row {
    id: centerRow
    width: implicitWidth
    x: Math.round((root.width - width) / 2)
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
    clip: true
    visible: width > 0
  }

  // The right group hugs the right edge when it fits. On narrow displays it
  // uses only the space left after Nexus Center instead of drifting off-screen.
  Row {
    id: rightRow
    x: Math.max(
      centerRow.x + centerRow.width + root.centerGap,
      root.width - implicitWidth - root.innerPadding
    )
    width: Math.max(0, root.width - x - root.innerPadding)
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
    clip: true
  }
}
