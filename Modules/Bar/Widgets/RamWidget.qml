import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

// Memory usage pill. Reads the shared SystemStatsService so all stats share one
// poller. Left click cycles the display format (percent vs used/total label).
BasePill {
  id: root

  property var barWindow: null
  property var parentScreen: null

  property bool showLabel: false

  content: Component {
    Item {
      implicitWidth: collapsedRow.visible ? collapsedRow.implicitWidth : expandedColumn.implicitWidth
      implicitHeight: (collapsedRow.visible ? collapsedRow.implicitHeight : expandedColumn.implicitHeight) + 3

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(18, parent.implicitWidth - 8)
        height: 2
        radius: 1
        color: Theme.withAlpha(Theme.outline, 0.28)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(100, SystemStatsService.memoryUsage)) / 100
          height: parent.height
          radius: parent.radius
          color: root.usageColor()
          Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
          Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
        }
      }

      Row {
        id: collapsedRow
        visible: !root.showLabel
        spacing: 4
        anchors.centerIn: parent
        DmsIcon {
          name: "developer_board"
          size: root.iconSize()
          color: root.usageColor()
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: Math.round(SystemStatsService.memoryUsage) + "%"
          color: root.usageColor()
          font.family: Theme.monoFontFamily
          font.pixelSize: root.textSize()
          font.bold: true
        }
      }
      Column {
        id: expandedColumn
        visible: root.showLabel
        spacing: 0
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "MEM"
          color: Theme.primary
          font.family: Theme.monoFontFamily
          font.pixelSize: root.textSize()
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: SystemStatsService.memUsedText + "/" + SystemStatsService.memTotalText
          color: root.usageColor()
          font.family: Theme.monoFontFamily
          font.pixelSize: Math.round(root.textSize() * 0.7)
        }
      }
    }
  }

  function usageColor() {
    return SystemStatsService.memoryUsage > 90 ? Theme.error
      : (SystemStatsService.memoryUsage > 75 ? Theme.warning : Theme.widgetIconColor)
  }

  onClicked: root.showLabel = !root.showLabel
}
