import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Modules.Bar.Widgets

Rectangle {
  id: root

  property string iconName: ""
  property string title: ""
  property string subtitle: ""
  property bool sensitiveSubtitle: false
  property bool active: false
  property bool available: true

  signal clicked
  signal rightClicked

  radius: Theme.cornerRadius
  color: Theme.withAlpha(active ? Theme.primary : Theme.surfaceContainerHigh, active ? 0.24 : 0.48)
  border.width: 1
  border.color: Theme.withAlpha(active ? Theme.primary : Theme.outlineVariant, active ? 0.62 : 0.28)
  opacity: available ? 1 : 0.55

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 2
    radius: 1
    color: Theme.primary
    opacity: root.active ? 0.9 : 0
  }

  Row {
    anchors.fill: parent
    anchors.margins: 9
    spacing: 8

    DmsIcon {
      anchors.verticalCenter: parent.verticalCenter
      name: root.iconName
      size: 24
      color: root.active ? Theme.primary : Theme.widgetIconColor
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 34
      spacing: 2

      Text {
        width: parent.width
        text: root.title
        color: Theme.widgetTextColor
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Item {
        id: subtitleContainer
        width: parent.width
        height: subtitleText.implicitHeight

        Text {
          id: subtitleText
          anchors.fill: parent
          text: root.subtitle
          color: Theme.widgetInactiveIconColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall - 2
          elide: Text.ElideRight
          layer.enabled: root.sensitiveSubtitle && !subtitleHover.containsMouse
          layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
          }
        }

        MouseArea {
          id: subtitleHover
          anchors.fill: parent
          visible: root.sensitiveSubtitle
          acceptedButtons: Qt.NoButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.available
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton)
        root.rightClicked()
      else
        root.clicked()
    }
  }
}
