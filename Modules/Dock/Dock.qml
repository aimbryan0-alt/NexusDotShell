import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Common

Item {
  id: root

  property var screen: null
  property bool dockHovered: false
  property bool triggerHovered: false

  readonly property real baseIconSize: Math.max(36, Math.min(
    64, Number(SettingsData.dockIconSize) || 45
  ))
  readonly property var monitorWindows: {
    const monitorName = root.screen ? root.screen.name : ""
    const windows = Hyprland.toplevels ? Hyprland.toplevels.values : []
    return windows.filter(window =>
      window && window.wayland && window.monitor
        && (!monitorName || window.monitor.name === monitorName)
    )
  }
  function appAliases(value) {
    const full = String(value || "").toLowerCase().replace(/\.desktop$/, "")
    const tail = full.split(".").pop()
    return full ? [full, tail] : []
  }
  function desktopEntryForAppId(appId) {
    const aliases = root.appAliases(appId)
    if (aliases.length === 0 || !DesktopEntries.applications)
      return null
    const entries = DesktopEntries.applications.values || []
    return entries.find(entry =>
      root.appAliases(entry.id).some(alias => aliases.indexOf(alias) !== -1)
    ) || null
  }
  function matchesPinnedWindow(entry, window) {
    if (!entry || !window)
      return false
    const pinnedAliases = root.appAliases(entry.id)
    const windowValues = [window.class, window.initialClass,
      window.wayland ? window.wayland.appId : ""]
    return windowValues.some(value =>
      root.appAliases(value).some(alias => pinnedAliases.indexOf(alias) !== -1)
    )
  }
  function runningWindowFor(entry) {
    return root.monitorWindows.find(window => root.matchesPinnedWindow(entry, window)) || null
  }
  readonly property var dockWindows: {
    const windows = root.monitorWindows.filter(window =>
      window && window.wayland
        && !root.pinnedEntries.some(entry => root.matchesPinnedWindow(entry, window))
    )
    if (!SettingsData.dockGroupByApp)
      return windows.map(window => window.wayland)
    const seen = []
    const grouped = []
    for (let i = 0; i < windows.length; i++) {
      const appId = String(windows[i].class || windows[i].initialClass
        || windows[i].wayland.appId || windows[i].wayland.title || "")
      if (seen.indexOf(appId) !== -1)
        continue
      seen.push(appId)
      grouped.push(windows[i].wayland)
    }
    return grouped
  }
  readonly property var pinnedEntries: {
    const ids = Array.isArray(SettingsData.dockPinnedApps) ? SettingsData.dockPinnedApps : []
    const entries = DesktopEntries.applications ? DesktopEntries.applications.values : []
    return ids.map(id => entries.find(entry => String(entry.id) === String(id))).filter(entry => !!entry)
  }
  readonly property bool shouldShow: !SettingsData.dockAutoHide
    || root.dockHovered || root.triggerHovered

  Rectangle {
    id: dockSurface
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.shouldShow ? 10 : -dockSurface.height - 8
    width: dockRow.implicitWidth + 32
    height: root.baseIconSize + 26
    radius: height / 2
    color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.88)
    border.width: 1
    border.color: Theme.withAlpha(Theme.primary, root.shouldShow ? 0.42 : 0.18)
    opacity: root.shouldShow ? 1 : 0
    visible: opacity > 0

    HoverHandler {
      onHoveredChanged: root.dockHovered = hovered
    }

    Behavior on anchors.bottomMargin {
      NumberAnimation {
        duration: 170
        easing.type: Easing.OutCubic
      }
    }
    Behavior on opacity {
      NumberAnimation { duration: 130 }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: Math.min(parent.width - 64, Math.max(28, dockRow.implicitWidth * 0.24))
      height: 1
      radius: 1
      color: Theme.primary
      opacity: 0.48
    }

    // Small HUD corner marks keep the dock visually aligned with the top bar.
    Rectangle {
      anchors.left: parent.left
      anchors.leftMargin: 11
      anchors.top: parent.top
      anchors.topMargin: 9
      width: 9
      height: 2
      color: Theme.primary
      opacity: 0.55
    }
    Rectangle {
      anchors.right: parent.right
      anchors.rightMargin: 11
      anchors.top: parent.top
      anchors.topMargin: 9
      width: 9
      height: 2
      color: Theme.primary
      opacity: 0.55
    }

    Row {
      id: dockRow
      anchors.centerIn: parent
      spacing: 6

      Repeater {
        model: root.pinnedEntries
        delegate: Item {
          required property var modelData
          readonly property var entry: modelData
          readonly property real iconSize: root.baseIconSize
          width: iconSize + 10
          height: iconSize + 10
          scale: favoriteMouse.containsMouse ? 1.055 : 1.0
          Behavior on scale {
            NumberAnimation { duration: 135; easing.type: Easing.OutCubic }
          }
          Rectangle {
            anchors.fill: parent
            radius: 14
            color: favoriteMouse.containsMouse
              ? Theme.withAlpha(Theme.primary, 0.16)
              : root.runningWindowFor(entry)
                ? Theme.withAlpha(Theme.primary, 0.09)
                : Theme.withAlpha(Theme.surfaceContainerHigh, 0.24)
            border.width: favoriteMouse.containsMouse ? 1 : root.runningWindowFor(entry) ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary,
              favoriteMouse.containsMouse ? 0.82 : 0.48)
            Behavior on color { ColorAnimation { duration: 145 } }
            Behavior on border.color { ColorAnimation { duration: 145 } }
          }
          IconImage {
            anchors.centerIn: parent
            width: iconSize - 10
            height: iconSize - 10
            source: entry.icon ? Quickshell.iconPath(entry.icon) : ""
            asynchronous: true
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: root.runningWindowFor(entry) ? 10 : 3
            height: 3
            radius: 2
            color: Theme.primary
            opacity: root.runningWindowFor(entry) ? 1 : 0.42
            Behavior on width { NumberAnimation { duration: 145 } }
            Behavior on opacity { NumberAnimation { duration: 145 } }
          }
          MouseArea {
            id: favoriteMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                const pinned = Array.isArray(SettingsData.dockPinnedApps) ? SettingsData.dockPinnedApps : []
                SettingsData.set("dockPinnedApps", pinned.filter(id => id !== String(entry.id)))
                return
              }
              const running = root.runningWindowFor(entry)
              if (running && running.wayland)
                running.wayland.activate()
              else
                entry.execute()
            }
          }
          ToolTip.visible: favoriteMouse.containsMouse
          ToolTip.text: entry.name || "Pinned application"
          ToolTip.delay: 450
        }
      }

      Rectangle {
        visible: root.pinnedEntries.length > 0 && root.dockWindows.length > 0
        width: 1
        height: root.baseIconSize * 0.58
        radius: 1
        color: Theme.withAlpha(Theme.primary, 0.36)
        anchors.verticalCenter: parent.verticalCenter
      }

      Repeater {
        model: root.dockWindows

        delegate: Item {
          required property var modelData
          readonly property var appWindow: modelData || null
          readonly property real iconSize: root.baseIconSize
          visible: !!appWindow

          width: iconSize + 10
          height: iconSize + 10
          scale: iconMouse.containsMouse ? 1.055 : 1.0
          Behavior on scale {
            NumberAnimation { duration: 135; easing.type: Easing.OutCubic }
          }

          Behavior on width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
          }

          Rectangle {
            anchors.fill: parent
            radius: 14
            color: iconMouse.containsMouse
              ? Theme.withAlpha(Theme.primary, 0.16)
              : appWindow && appWindow.activated
                ? Theme.withAlpha(Theme.primary, 0.09)
                : Theme.withAlpha(Theme.surfaceContainerHigh, 0.24)
            border.width: iconMouse.containsMouse || (appWindow && appWindow.activated) ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary,
              iconMouse.containsMouse ? 0.82 : 0.48)
            Behavior on color { ColorAnimation { duration: 145 } }
            Behavior on border.color { ColorAnimation { duration: 145 } }
          }

          IconImage {
            anchors.centerIn: parent
            width: iconSize - 10
            height: iconSize - 10
            source: appWindow ? Theme.getAppIcon(appWindow.appId || "") : ""
            asynchronous: true
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: appWindow && appWindow.activated ? 10 : 3
            height: 3
            radius: 2
            color: Theme.primary
            opacity: appWindow && appWindow.activated ? 1 : 0.42
            Behavior on width { NumberAnimation { duration: 145 } }
            Behavior on opacity { NumberAnimation { duration: 145 } }
          }

          MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            enabled: !!appWindow
            onClicked: function(mouse) {
              if (!appWindow)
                return
              if (mouse.button === Qt.RightButton) {
                const entry = root.desktopEntryForAppId(appWindow.appId)
                if (!entry)
                  return
                const pinned = Array.isArray(SettingsData.dockPinnedApps)
                  ? SettingsData.dockPinnedApps : []
                const entryId = String(entry.id)
                if (pinned.indexOf(entryId) === -1)
                  SettingsData.set("dockPinnedApps", pinned.concat([entryId]))
                return
              }
              appWindow.activate()
            }
          }

          ToolTip.visible: !!appWindow && iconMouse.containsMouse && !!(appWindow.title || appWindow.appId)
          ToolTip.text: appWindow
            ? (appWindow.title || appWindow.appId || "Application") + " · right-click to pin"
            : "Application"
          ToolTip.delay: 450
        }
      }

      Text {
        visible: root.pinnedEntries.length === 0 && root.dockWindows.length === 0
        text: "NEXUS  //  NO APPS PINNED OR RUNNING"
        color: Theme.surfaceVariantText
        font.family: Theme.monoFontFamily
        font.pixelSize: 10
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 8
    color: "transparent"
    visible: SettingsData.dockAutoHide

    HoverHandler {
      onHoveredChanged: root.triggerHovered = hovered
    }
  }
}
