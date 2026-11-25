import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Bar.Widgets

// Compact world-clock HUD. It only refreshes while the popup is visible.
PopupWindow {
  id: root

  property var barWindow: null
  property real anchorX: 0
  property real anchorY: 0
  property int refreshKey: 0

  readonly property var cities: [
    { "name": "São Paulo", "country": "BRASIL", "timeZone": "America/Sao_Paulo", "accent": Theme.primary },
    { "name": "Nova York", "country": "ESTADOS UNIDOS", "timeZone": "America/New_York", "accent": Theme.secondary },
    { "name": "Londres", "country": "REINO UNIDO", "timeZone": "Europe/London", "accent": Theme.tertiary },
    { "name": "Tóquio", "country": "JAPÃO", "timeZone": "Asia/Tokyo", "accent": Theme.primary }
  ]

  anchor.window: root.barWindow
  anchor.rect.x: Math.max(8, Math.min(
    (root.barWindow ? root.barWindow.width : Screen.width) - implicitWidth - 8,
    root.anchorX - implicitWidth / 2
  ))
  anchor.rect.y: root.anchorY + Theme.spaceXS
  visible: false
  grabFocus: true
  color: "transparent"
  surfaceFormat.opaque: false
  implicitWidth: Math.min(460, Math.max(340, Screen.width - 24))
  implicitHeight: 242

  function toggle(ax, ay) {
    anchorX = ax
    anchorY = ay
    visible = !visible
    if (visible)
      refreshKey++
  }

  function formatTime(timeZone) {
    const refresh = root.refreshKey
    try {
      return new Intl.DateTimeFormat("pt-BR", {
        timeZone: timeZone,
        hour: "2-digit",
        minute: "2-digit",
        hour12: false
      }).format(new Date())
    } catch (error) {
      console.warn("WorldClockOverlay: falha ao formatar horário para", timeZone, error)
      return "--:--"
    }
  }

  function formatDate(timeZone) {
    const refresh = root.refreshKey
    try {
      return new Intl.DateTimeFormat("pt-BR", {
        timeZone: timeZone,
        weekday: "short",
        day: "2-digit",
        month: "short"
      }).format(new Date())
    } catch (error) {
      console.warn("WorldClockOverlay: falha ao formatar data para", timeZone, error)
      return ""
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    onTriggered: root.refreshKey++
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.cornerRadius + 4
    color: Theme.withAlpha(
      Theme.widgetBaseBackgroundColor,
      typeof SettingsData !== "undefined" ? SettingsData.popupTransparency : 0.65
    )
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.34)

    Column {
      anchors.fill: parent
      anchors.margins: Theme.spaceL
      spacing: Theme.spaceS

      Row {
        width: parent.width
        height: 30
        spacing: Theme.spaceS

        DmsIcon {
          anchors.verticalCenter: parent.verticalCenter
          name: "public"
          size: 19
          color: Theme.primary
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Text {
            text: qsTr("WORLD CLOCK")
            color: Theme.widgetTextColor
            font.family: Theme.monoFontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
          }

          Text {
            text: qsTr("HORÁRIOS AO REDOR DO MUNDO")
            color: Theme.widgetInactiveIconColor
            font.family: Theme.monoFontFamily
            font.pixelSize: 8
          }
        }

        Item { width: Math.max(0, parent.width - 210); height: 1 }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "LIVE"
          color: Theme.tertiary
          font.family: Theme.monoFontFamily
          font.pixelSize: 9
          font.weight: Font.DemiBold
        }
      }

      Grid {
        width: parent.width
        columns: 2
        columnSpacing: Theme.spaceS
        rowSpacing: Theme.spaceS

        Repeater {
          model: root.cities

          delegate: Rectangle {
            required property var modelData
            width: (parent.width - parent.columnSpacing) / 2
            height: 76
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.72)
            border.width: 1
            border.color: Theme.withAlpha(modelData.accent, 0.16)

            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 2
              radius: 1
              color: modelData.accent
              opacity: 0.8
            }

            Column {
              anchors.fill: parent
              anchors.leftMargin: Theme.spaceM
              anchors.rightMargin: Theme.spaceS
              anchors.topMargin: Theme.spaceS
              anchors.bottomMargin: Theme.spaceS
              spacing: 1

              Row {
                width: parent.width
                spacing: 5

                Text {
                  width: parent.width - 72
                  text: modelData.name
                  color: Theme.widgetTextColor
                  font.pixelSize: 11
                  font.weight: Font.Medium
                  elide: Text.ElideRight
                }

                Text {
                  width: 67
                  text: modelData.country
                  color: Theme.widgetInactiveIconColor
                  font.family: Theme.monoFontFamily
                  font.pixelSize: 7
                  horizontalAlignment: Text.AlignRight
                  elide: Text.ElideRight
                }
              }

              Text {
                text: root.formatTime(modelData.timeZone)
                color: modelData.accent
                font.family: Theme.monoFontFamily
                font.pixelSize: 23
                font.weight: Font.DemiBold
              }

              Text {
                text: root.formatDate(modelData.timeZone)
                color: Theme.widgetInactiveIconColor
                font.pixelSize: 9
              }
            }
          }
        }
      }

      Text {
        width: parent.width
        text: qsTr("Atualização automática a cada 30 segundos enquanto aberto")
        color: Theme.withAlpha(Theme.widgetInactiveIconColor, 0.72)
        font.pixelSize: 9
        horizontalAlignment: Text.AlignRight
      }
    }
  }
}
