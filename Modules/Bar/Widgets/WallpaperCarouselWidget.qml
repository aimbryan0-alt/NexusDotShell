import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

// Tiny local wallpaper carousel. It only rotates through the already-scanned
// wallpaper library; it does not download images or change the desktop.
BasePill {
  id: root

  property int imageIndex: 0

  readonly property var images: WallpaperService.items || []
  readonly property string currentImage: root.images.length > 0
    ? String(root.images[root.imageIndex % root.images.length])
    : ""

  function nextImage() {
    if (root.images.length > 1)
      root.imageIndex = (root.imageIndex + 1) % root.images.length
    else if (root.images.length === 1)
      root.imageIndex = 0
    else
      WallpaperService.openOverview(root.screen)
  }

  onClicked: root.nextImage()

  onImagesChanged: {
    if (root.imageIndex >= root.images.length)
      root.imageIndex = 0
  }

  Timer {
    interval: 18000
    repeat: true
    running: root.visible && root.images.length > 1
    onTriggered: root.nextImage()
  }

  content: Component {
    Row {
      spacing: 0
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        width: 34
        height: 34
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.withAlpha(Theme.primary, 0.10)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.28)
      }

      Rectangle {
        width: 28
        height: 28
        radius: width / 2
        clip: true
        color: Theme.withAlpha(Theme.primary, 0.12)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.38)
        anchors.verticalCenter: parent.verticalCenter

        OpacityMask {
          anchors.fill: parent
          visible: root.currentImage !== ""
          cached: true

          source: Image {
            anchors.fill: parent
            source: root.currentImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
          }

          maskSource: Rectangle {
            width: 28
            height: 28
            radius: 14
            color: "white"
          }
        }

        DmsIcon {
          anchors.centerIn: parent
          name: "wallpaper"
          size: 16
          color: Theme.primary
          visible: root.currentImage === ""
        }

        Rectangle {
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          width: 5
          height: 5
          radius: 3
          color: Theme.primary
          border.width: 1
          border.color: Theme.surface
        }
      }


    }
  }
}
