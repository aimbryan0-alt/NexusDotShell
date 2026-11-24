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
  readonly property var dockWindows: {
    const windows = root.monitorWindows
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
  readonly property bool shouldShow: !SettingsData.dockAutoHide || root.pointerInside

  HoverHandler {
    onHoveredChanged: root.pointerInside = hovered
  }

  Rectangle {
    id: dockSurface
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.shouldShow ? 10 : -dockSurface.height - 8
    width: dockRow.implicitWidth + 28
    height: root.baseIconSize + 24
    radius: height / 2
    color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.94)
    border.width: 1
    border.color: Theme.withAlpha(Theme.primary, root.shouldShow ? 0.72 : 0.3)
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
      width: Math.min(parent.width - 48, Math.max(36, dockRow.implicitWidth * 0.42))
      height: 2
      radius: 1
      color: Theme.primary
      opacity: 0.75
    }

    Row {
      id: dockRow
      anchors.centerIn: parent
      spacing: 5

      Repeater {
        model: root.dockWindows

        delegate: Item {
          required property var modelData
          readonly property var appWindow: modelData
          readonly property real iconSize: root.baseIconSize

          width: iconMouse.containsMouse ? iconSize + 7 : iconSize
          height: iconSize + 7

          Behavior on width {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
          }

          Rectangle {
            anchors.fill: parent
            radius: 15
            color: iconMouse.containsMouse
              ? Theme.withAlpha(Theme.primary, 0.16)
              : "transparent"
            border.width: appWindow.activated ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary, 0.52)
          }

          IconImage {
            anchors.centerIn: parent
            width: iconSize - 8
            height: iconSize - 8
            source: Theme.getAppIcon(appWindow.appId)
            asynchronous: true
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: appWindow.activated ? 13 : 4
            height: 3
            radius: 2
            color: Theme.primary
            opacity: appWindow.activated ? 1 : 0.42
          }

          MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: appWindow.activate()
          }

          ToolTip.visible: iconMouse.containsMouse && !!appWindow.title
          ToolTip.text: appWindow.title || appWindow.appId || "Application"
          ToolTip.delay: 450
        }
      }

      Text {
        visible: root.dockWindows.length === 0
        text: "NEXUS  //  NO ACTIVE APPS"
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
    height: 5
    color: "transparent"
    visible: SettingsData.dockAutoHide

    HoverHandler {
      onHoveredChanged: root.triggerHovered = hovered
    }
  }
}
