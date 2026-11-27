import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modules.Bar.Widgets

// Nexus Material HUD — three independent floating lanes.
Item {
  id: root

  property QtObject screen: null
  property QtObject barWindow: null

  readonly property int spacing: Math.max(6,
    typeof SettingsData !== "undefined" ? SettingsData.barSpacing : 6)
  readonly property int innerPadding: Math.max(8,
    typeof SettingsData !== "undefined" ? SettingsData.barInnerPadding : 10)
  readonly property int laneGap: Math.max(14, root.spacing + 8)
  readonly property bool backgroundEnabled:
    typeof SettingsData !== "undefined" && SettingsData.barTransparency !== 0

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
    const lists = [
      SettingsData.barLeftWidgets,
      SettingsData.barCenterWidgets,
      SettingsData.barRightWidgets
    ]
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
    if (!list)
      return

    const groupCpuMemory =
      root.hasEnabledWidget("cpuUsage") && root.hasEnabledWidget("memUsage")

    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (!entry || entry.enabled !== true)
        continue

      // Omitir o título da janela ativa da barra.
      if (entry.id === "focusedWindow")
        continue
      if (groupCpuMemory && entry.id === "memUsage")
        continue

      var comp = root.registryFor(entry.id)
      if (comp && comp.status === Component.Error)
        console.error("MQBAR component error for", entry.id, ":", comp.errorString())
      if (comp === null)
        continue

      var initProps = {
        "screen": root.screen,
        "parentScreen": root.screen,
        "barWindow": root.barWindow
      }

      if (groupCpuMemory && entry.id === "cpuUsage")
        initProps["groupedMemory"] = true

      var obj = comp.createObject(hostRow, initProps)
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
      if (child === titleWidget)
        break
      if (!child.visible)
        continue
      if (count > 0)
        usedWidth += root.spacing
      usedWidth += child.width
      count++
    }

    if (count > 0)
      usedWidth += root.spacing

    return Math.max(0, Math.min(190,
      centerRow.x - root.laneGap - leftRow.x - usedWidth))
  }

  Component.onCompleted: root.rebuild()

  Connections {
    target: SettingsData
    function onSettingsApplied() {
      root.rebuild()
    }
  }

  // LEFT LANE — launcher, workspaces and contextual widgets.
  Rectangle {
    id: leftSurface
    x: leftRow.x - 7
    anchors.verticalCenter: parent.verticalCenter
    width: leftRow.width + 14
    height: Math.min(root.height - 4, Theme.widgetThickness + 6)
    radius: 22
    visible: leftRow.children.length > 0
    color: Theme.withAlpha(Theme.nestedSurface,
      root.backgroundEnabled ? 0.68 : 0.54)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.30)

    Rectangle {
      anchors.left: parent.left
      anchors.leftMargin: 7
      anchors.verticalCenter: parent.verticalCenter
      width: 2
      height: 13
      radius: 1
      color: Theme.primary
      opacity: 0.8
    }
  }

  // CENTER LANE — the visual anchor of the HUD.
  Rectangle {
    id: centerSurface
    x: centerRow.x - 8
    anchors.verticalCenter: parent.verticalCenter
    width: centerRow.width + 16
    height: Math.min(root.height - 4, Theme.widgetThickness + 6)
    radius: 22
    visible: centerRow.visible && centerRow.children.length > 0
    color: Theme.withAlpha(Theme.nestedSurface,
      root.backgroundEnabled ? 0.72 : 0.58)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.38)

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: Math.min(42, parent.width * 0.3)
      height: 2
      radius: 1
      color: Theme.primary
      opacity: 0.9
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: 18
      height: 2
      radius: 1
      color: Theme.outlineVariant
      opacity: 0.35
    }
  }

  // RIGHT LANE — system status and controls.
  Rectangle {
    id: rightSurface
    x: rightRow.x - 7
    anchors.verticalCenter: parent.verticalCenter
    width: rightRow.width + 14
    height: Math.min(root.height - 4, Theme.widgetThickness + 6)
    radius: 22
    visible: rightRow.children.length > 0
    color: Theme.withAlpha(Theme.nestedSurface,
      root.backgroundEnabled ? 0.68 : 0.54)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outlineVariant, 0.30)

    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 7
      anchors.verticalCenter: parent.verticalCenter
      width: 2
      height: 13
      radius: 1
      color: Theme.tertiary
      opacity: 0.8
    }
  }

  Row {
    id: leftRow
    x: root.innerPadding
    width: implicitWidth
    height: implicitHeight
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
  }

  Row {
    id: centerRow
    width: implicitWidth
    height: implicitHeight
    x: Math.max(
      leftRow.x + leftRow.width + root.laneGap,
      Math.min(
        (root.width - width) / 2,
        rightRow.x - root.laneGap - width
      )
    )
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.spacing
    visible: x + width <= rightRow.x - root.laneGap
  }

  Row {
    id: rightRow
    anchors.right: parent.right
    anchors.rightMargin: root.innerPadding
    anchors.verticalCenter: parent.verticalCenter
    width: implicitWidth
    height: implicitHeight
    spacing: root.spacing
  }
}
