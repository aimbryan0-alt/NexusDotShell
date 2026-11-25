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
      implicitWidth: 28
      implicitHeight: 22

      Rectangle {
        id: nexusMark
        anchors.centerIn: parent
        width: 22
        height: 22
        radius: 7
        color: Theme.withAlpha(Theme.primary, 0.13)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.72)

        Text {
          anchors.centerIn: parent
          text: "N"
          color: Theme.primary
          font.family: Theme.monoFontFamily
          font.pixelSize: 15
          font.weight: Font.Black
          font.letterSpacing: -1
        }

        Rectangle {
          anchors.right: parent.right
          anchors.top: parent.top
          width: 4
          height: 4
          radius: 1
          color: Theme.primary
        }
      }
    }
  }

  property Process overviewProc: Process {
    id: overviewProc
    command: ["hyprctl", "dispatch", "overview:toggle"]
  }
}
