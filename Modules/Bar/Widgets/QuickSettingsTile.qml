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
  color: Theme.withAlpha(
    active || tileMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh,
    active ? 0.24 : tileMouse.containsMouse ? 0.16 : 0.48
  )
  border.width: 1
  border.color: Theme.withAlpha(
    active || tileMouse.containsMouse ? Theme.primary : Theme.outlineVariant,
    active ? 0.72 : tileMouse.containsMouse ? 0.58 : 0.28
  )
  opacity: available ? 1 : 0.55

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 2
    radius: 1
    color: Theme.primary
    opacity: root.active ? 0.9 : tileMouse.containsMouse ? 0.5 : 0
  }

  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: 12
    width: 11
    height: 2
    radius: 1
    color: Theme.tertiary
    opacity: root.active ? 0.8 : tileMouse.containsMouse ? 0.55 : 0.22
  }

  Row {
    anchors.fill: parent
    anchors.margins: 10
    spacing: 9

    Rectangle {
      width: 30
      height: 30
      radius: 9
      anchors.verticalCenter: parent.verticalCenter
      color: Theme.withAlpha(root.active ? Theme.primary : Theme.surfaceContainerHighest, root.active ? 0.2 : 0.62)
      border.width: 1
      border.color: Theme.withAlpha(root.active ? Theme.primary : Theme.outlineVariant, root.active ? 0.42 : 0.24)

      DmsIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: 19
        color: root.active ? Theme.primary : Theme.widgetIconColor
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 40
      spacing: 3

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
    id: tileMouse
    anchors.fill: parent
    enabled: root.available
    hoverEnabled: true
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
