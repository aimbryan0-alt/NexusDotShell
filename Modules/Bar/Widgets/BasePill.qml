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
  property real widgetThickness: Theme.widgetThickness * 0.90
  property real barThickness: Theme.barThickness * 0.91
  property real barSpacing: 0
  property bool vertical: false
  property color backgroundTint: "transparent"
  property alias content: contentLoader.sourceComponent

  signal clicked
  signal rightClicked(real rootX, real rootY)
  signal wheel(var wheelEvent)

  readonly property real dpr: root.screen ? Theme.screenScaleOf(root.screen) : 1
  readonly property real horizontalPadding: Theme.snap(Math.max(4, widgetThickness * 0.13), dpr)
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
      radius: height / 2
      color: {
        const raw = typeof SettingsData !== "undefined"
          ? SettingsData.barWidgetTransparency : 0.65
        const transparency = Math.max(0.52, Math.min(0.76, raw))
        const base = root.isMouseHovered
          ? Theme.blend(Theme.widgetBaseBackgroundColor, Theme.primary, 0.18)
          : Theme.blend(Theme.nestedSurface, Theme.surfaceBright, 0.06)
        const tintAmount = root.backgroundTint.a
        const tintedBase = tintAmount > 0
          ? Theme.blend(base, root.backgroundTint, tintAmount)
          : base
        return Theme.withAlpha(tintedBase, transparency)
      }
      border.width: 1
      border.color: Theme.withAlpha(
        root.isMouseHovered ? Theme.primary : Theme.outlineVariant,
        root.isMouseHovered ? 0.72 : 0.30
      )

      Behavior on color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
      Behavior on border.color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
    }

    // Soft glass reflection: a subtle highlight across the upper surface.
    Rectangle {
      anchors.fill: background
      radius: background.radius
      gradient: Gradient {
        GradientStop {
          position: 0.0
          color: Theme.withAlpha(Theme.surfaceBright, 0.16)
        }
        GradientStop {
          position: 0.48
          color: Theme.withAlpha(Theme.surfaceBright, 0.035)
        }
        GradientStop {
          position: 1.0
          color: "transparent"
        }
      }
    }

    // Material HUD status accent: compact, restrained and interaction-aware.
    Rectangle {
      anchors.left: background.left
      anchors.leftMargin: 7
      anchors.verticalCenter: background.verticalCenter
      width: 3
      height: root.isMouseHovered ? 18 : 10
      radius: 2
      color: Theme.primary
      opacity: root.isMouseHovered ? 0.78 : 0.24

      Behavior on height {
        NumberAnimation {
          duration: 150
          easing.type: Easing.OutCubic
        }
      }
      Behavior on opacity {
        NumberAnimation { duration: 150 }
      }
      Behavior on color {
        ColorAnimation { duration: 150 }
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
