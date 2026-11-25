import QtQuick
import qs.Common
import qs.Services

// DMS BasePill replica (simplified). The shared wrapper for bar widgets: a
// rounded pill whose background is widgetBaseBackgroundColor blended by the
// widgetTransparency, tinted with primary on hover, with click / right-click /
// wheel signals and DMS-style barIconSize/barTextSize helpers. Vertical
// orientation is supported though the current bar is horizontal.
Item {
  id: root

  property QtObject screen: null
  property real widgetThickness: Theme.widgetThickness
  property real barThickness: Theme.barThickness
  property real barSpacing: 0
  property bool vertical: false
  property color backgroundTint: "transparent"
  property alias content: contentLoader.sourceComponent

  signal clicked
  signal rightClicked(real rootX, real rootY)
  signal wheel(var wheelEvent)

  readonly property real dpr: root.screen ? Theme.screenScaleOf(root.screen) : 1
  readonly property real horizontalPadding: Theme.snap(Math.max(4, widgetThickness * 0.14), dpr)
  readonly property bool isMouseHovered: mouseArea.containsMouse

  readonly property real visualWidth: vertical
    ? widgetThickness
    : (contentLoader.item ? contentLoader.item.implicitWidth + horizontalPadding * 2 : 20)
  readonly property real visualHeight: vertical
    ? (contentLoader.item ? contentLoader.item.implicitHeight + horizontalPadding * 2 : 20)
    : widgetThickness

  width: vertical ? barThickness : visualWidth
  height: vertical ? visualHeight : barThickness

  // Convenience size helpers for widgets that render their own text/icons.
  function iconSize(offset, maximize, scale) {
    return Theme.barIconSize(root.barThickness, offset, maximize, scale)
  }
  function textSize(maximize) {
    return Theme.barTextSize(root.barThickness, undefined, maximize)
  }

  Item {
    id: visualContent
    width: root.visualWidth
    height: root.visualHeight
    anchors.centerIn: parent

    Rectangle {
      id: background
      anchors.fill: parent
      radius: Math.min(height / 2, Theme.cornerRadius + 4)
      color: {
        const raw = typeof SettingsData !== "undefined" ? SettingsData.barWidgetTransparency : 0.65
        const isHovered = root.isMouseHovered
        const transparency = isHovered ? Math.max(0.3, raw) : raw
        const base = isHovered ? Theme.widgetBaseHoverColor : Theme.widgetBaseBackgroundColor
        const tintAmount = root.backgroundTint.a
        const tintedBase = tintAmount > 0
          ? Theme.blend(base, root.backgroundTint, tintAmount)
          : base
        return Theme.withAlpha(tintedBase, transparency)
      }
      border.width: 1
      border.color: Theme.withAlpha(
        root.isMouseHovered ? Theme.primary : Theme.outlineVariant,
        root.isMouseHovered ? 0.48 : 0.16
      )

      Behavior on color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
      Behavior on border.color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
    }

    // Quiet macOS-like glass pill; the Nexus accent appears on interaction.
    Rectangle {
      anchors.top: background.top
      anchors.horizontalCenter: background.horizontalCenter
      width: Math.max(0, background.width - 20)
      height: 1
      radius: 1
      color: Theme.primary
      opacity: root.isMouseHovered ? 0.68 : 0.05
    }

    Rectangle {
      anchors.top: background.top
      anchors.right: background.right
      anchors.rightMargin: 12
      width: 7
      height: 2
      radius: 1
      color: Theme.tertiary
      opacity: root.isMouseHovered ? 0.82 : 0
    }

    // A second, restrained accent anchors the pill without adding polling.
    Rectangle {
      anchors.bottom: background.bottom
      anchors.horizontalCenter: background.horizontalCenter
      width: Math.min(background.width - 24, Math.max(18, background.width * 0.24))
      height: 1
      radius: 1
      color: Theme.primary
      opacity: root.isMouseHovered ? 0.58 : 0.06
      Behavior on opacity {
        NumberAnimation { duration: 140 }
      }
    }

    Loader {
      id: contentLoader
      anchors.centerIn: parent
    }
  }

  MouseArea {
    id: mouseArea
    z: -1
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        const pos = mouseArea.mapToItem(root, mouse.x, mouse.y)
        root.rightClicked(pos.x, pos.y)
      } else {
        root.clicked()
      }
    }
    onWheel: function(wheelEvent) {
      wheelEvent.accepted = false
      root.wheel(wheelEvent)
    }
  }
}
