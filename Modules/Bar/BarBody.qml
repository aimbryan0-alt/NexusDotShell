import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.Bar.Widgets

// Preserve the original Nexus bar architecture: left lane, adaptive center,
// right lane, and a dedicated music slot at the far right. This avoids
// squeezing the complete system HUD into a single clipped Row.
Item {
  id: root

  property QtObject screen: null
  property QtObject barWindow: null

  readonly property int spacing: Math.max(3,
    typeof SettingsData !== "undefined" ? SettingsData.barSpacing : 3)
  readonly property int innerPadding: Math.max(8,
    typeof SettingsData !== "undefined" ? SettingsData.barInnerPadding : 8)
  readonly property int laneGap: Math.max(8, root.spacing + 5)

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
      if (comp && comp.status === Component.Error)
        console.error("MQBAR component error for", entry.id, ":", comp.errorString())
      if (comp === null) {
        console.info("MQBAR skip (no comp):", entry.id)
        continue
      }
      // The music widget has its own terminal slot, matching the original bar.
      var targetRow = entry.id === "player" ? playerRow : hostRow
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
    for (var i = 0; i < root._created.length; i++)
      root._created[i].destroy()
    root._created = []
    root.fillRow(SettingsData.barLeftWidgets, leftRow)
    root.fillRow(SettingsData.barCenterWidgets, centerRow)
    root.fillRow(SettingsData.barRightWidgets, rightRow)
  }

  function titleSpaceFor(titleWidget) {
    var usedWidth = 0
    var count = 0
    for (var i = 0; i < leftRow.children.length; i++) {
      var child = leftRow.children[i]
      if (child === titleWidget) break
      if (!child.visible) continue
      if (count > 0) usedWidth += root.spacing
      usedWidth += child.width
      count++
    }
    if (count > 0) usedWidth += root.spacing
    return Math.max(0, Math.min(190,
      centerRow.x - root.laneGap - leftRow.x - usedWidth))
  }

  Component.onCompleted: root.rebuild()

  Connections {
    target: SettingsData
    function onSettingsApplied() { root.rebuild() }
  }

  Row {
    id: leftRow
    x: root.innerPadding
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
  }

  // The center remains visually centered when space permits, but yields a
  // little to the side lanes instead of covering or clipping their widgets.
  Row {
    id: centerRow
    x: Math.max(leftRow.x + leftRow.width + root.laneGap,
      Math.min((root.width - width) / 2,
        rightRow.x - root.laneGap - width))
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
    visible: x + width <= rightRow.x - root.laneGap
  }

  Row {
    id: rightRow
    anchors.right: playerRow.left
    anchors.rightMargin: root.laneGap
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
  }

  Row {
    id: playerRow
    anchors.right: parent.right
    anchors.rightMargin: root.innerPadding
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
  }
}
