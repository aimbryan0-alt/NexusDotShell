import QtQuick
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
        width: 26
        height: 26
        radius: 10
        clip: true
        color: Theme.withAlpha(Theme.primary, 0.12)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.38)
        anchors.verticalCenter: parent.verticalCenter

        Image {
          anchors.fill: parent
          source: root.currentImage
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          smooth: true
          mipmap: true
          visible: status === Image.Ready
        }

        DmsIcon {
          anchors.centerIn: parent
          name: "wallpaper"
          size: 15
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
