import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

// Launcher button. Opens the native NexusDotShell application grid;
// right-click continues to toggle the compositor overview.
BasePill {
  id: root

  property var barWindow: null
  property var parentScreen: null

  onClicked: launcher.opened = !launcher.opened

  onRightClicked: {
    overviewProc.command = ["hyprctl", "dispatch", "overview:toggle"]
    overviewProc.running = true
  }

  LauncherOverlay {
    id: launcher
    barWindow: root.barWindow
  }

  content: Component {
    Item {
      implicitWidth: 30
      implicitHeight: 26

      Rectangle {
        id: nexusMark
        anchors.centerIn: parent
        width: 26
        height: 26
        radius: 9
        color: Theme.withAlpha(Theme.primaryContainer, 0.72)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.88)

        Rectangle {
          anchors.fill: parent
          anchors.margins: 2
          radius: 7
          color: "transparent"
          border.width: 1
          border.color: Theme.withAlpha(Theme.surfaceBright, 0.30)
        }

        Text {
          anchors.centerIn: parent
          text: "結"
          color: Theme.primary
          font.family: "Noto Sans CJK JP"
          font.pixelSize: 16
          font.weight: Font.DemiBold
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.rightMargin: 2
          anchors.topMargin: 2
          width: 5
          height: 5
          radius: 2.5
          color: Theme.tertiary
          border.width: 1
          border.color: Theme.primaryContainer
        }
      }
    }
  }

  property Process overviewProc: Process {
    id: overviewProc
    command: ["hyprctl", "dispatch", "overview:toggle"]
  }
}
