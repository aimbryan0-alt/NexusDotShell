import QtQuick
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

BasePill {
  id: root

  property QtObject barWindow: null
  property QtObject parentScreen: null
  property bool showLabel: false

  content: Component {
    Item {
      implicitWidth: compactRow.visible ? compactRow.implicitWidth : expandedColumn.implicitWidth
      implicitHeight: (compactRow.visible ? compactRow.implicitHeight : expandedColumn.implicitHeight) + 3

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(18, parent.implicitWidth - 8)
        height: 2
        radius: 1
        color: Theme.withAlpha(Theme.outline, 0.28)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(100, SystemStatsService.cpuTemperature)) / 100
          height: parent.height
          radius: parent.radius
          color: root.temperatureColor()
          Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
          Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
          }
        }
      }

      // Thermal thresholds mirror the widget's warning and critical colors.
      Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        anchors.left: parent.left
        anchors.leftMargin: Math.max(9, (parent.implicitWidth - (parent.implicitWidth - 8)) / 2)
        width: Math.max(18, parent.implicitWidth - 8)
        height: 2
        spacing: 0
        z: 1

        Item {
          width: parent.width * 0.69
          height: 2
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 4
            radius: 1
            color: Theme.warning
            opacity: 0.72
          }
        }

        Item {
          width: parent.width * 0.16
          height: 2
          Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 4
            radius: 1
            color: Theme.error
            opacity: 0.78
          }
        }
      }

      Row {
        id: compactRow
        visible: !root.showLabel
        spacing: 4
        anchors.centerIn: parent

        DmsIcon {
          name: "device_thermostat"
          size: root.iconSize()
          color: root.temperatureColor()
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.temperatureText()
          color: root.temperatureColor()
          font.family: Theme.monoFontFamily
          font.pixelSize: root.textSize()
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      Column {
        id: expandedColumn
        visible: root.showLabel
        spacing: 0
        anchors.centerIn: parent

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "TEMP"
          color: Theme.primary
          font.family: Theme.monoFontFamily
          font.pixelSize: root.textSize()
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.temperatureText()
          color: root.temperatureColor()
          font.family: Theme.monoFontFamily
          font.pixelSize: Math.round(root.textSize() * 0.7)
        }
      }
    }
  }

  function temperatureText() {
    return SystemStatsService.cpuTemperature > 0
      ? Math.round(SystemStatsService.cpuTemperature) + "°C"
      : "--°C"
  }

  function temperatureColor() {
    return SystemStatsService.cpuTemperature > 85 ? Theme.error
      : (SystemStatsService.cpuTemperature > 69 ? Theme.warning : Theme.widgetIconColor)
  }

  onClicked: root.showLabel = !root.showLabel
}
