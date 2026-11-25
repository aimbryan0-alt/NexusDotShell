import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.Common
import qs.Services

PanelWindow {
  id: root

  property var targetScreen: null
  readonly property var player: LyricsService.player
  readonly property string trackTitle: player ? String(player.trackTitle || "Faixa desconhecida") : ""
  readonly property string trackArtist: player ? String(player.trackArtist || "Artista desconhecido") : ""
  readonly property string artworkUrl: {
    if (!player)
      return ""
    if (player.trackArtUrl)
      return String(player.trackArtUrl)
    const metadata = player.metadata
    return metadata && metadata["mpris:artUrl"] ? String(metadata["mpris:artUrl"]) : ""
  }
  readonly property string currentLyric: {
    if (LyricsService.synced && LyricsService.lines.length > 0) {
      const index = LyricsService.activeIndex >= 0
        ? LyricsService.activeIndex : 0
      return LyricsService.lines[index] ? LyricsService.lines[index].x : ""
    }
    return LyricsService.plainLines.length > 0
      ? String(LyricsService.plainLines[0]) : ""
  }
  readonly property string nextLyric: {
    if (LyricsService.synced) {
      const index = LyricsService.activeIndex >= 0
        ? LyricsService.activeIndex + 1 : 1
      return LyricsService.lines[index] ? LyricsService.lines[index].x : ""
    }
    return LyricsService.plainLines.length > 1
      ? String(LyricsService.plainLines[1]) : ""
  }

  screen: root.targetScreen
  visible: SettingsData.lyricsHudEnabled && !!root.player && root.trackTitle !== ""
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "nexus-live-lyrics"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Item {
    id: hud
    width: 520
    height: 190

    x: SettingsData.lyricsHudPosition === "right-center"
      || SettingsData.lyricsHudPosition === "bottom-right"
      ? parent.width - width - 30 : 30
    y: SettingsData.lyricsHudPosition === "right-center"
      || SettingsData.lyricsHudPosition === "left-center"
      ? (parent.height - height) / 2
      : SettingsData.lyricsHudPosition === "top-left"
        ? 30 : parent.height - height - 30

    Rectangle {
      anchors.fill: parent
      radius: 18
      color: Qt.rgba(7 / 255, 12 / 255, 20 / 255, 0.88)
      border.width: 1
      border.color: Theme.withAlpha(Theme.primary, 0.58)
    }

    Rectangle {
      width: 3
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.margins: 18
      radius: 2
      color: Theme.primary
      opacity: 0.9
    }

    Row {
      anchors.fill: parent
      anchors.margins: 20
      spacing: 18

      ClippingRectangle {
        width: 136
        height: 136
        radius: 16
        color: Theme.surfaceContainerHigh

        Image {
          id: coverImage
          anchors.fill: parent
          source: root.artworkUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          mipmap: true
          smooth: true
          visible: status === Image.Ready
        }

        Text {
          anchors.centerIn: parent
          text: "♫"
          color: Theme.primary
          font.pixelSize: 30
          visible: coverImage.status !== Image.Ready
        }
      }

      Column {
        width: parent.width - 136 - parent.spacing
        spacing: 5

        Row {
          width: parent.width
          height: 17
          spacing: 8

          Text {
            width: parent.width - positionButton.width - closeButton.width - 20
            text: "NEXUS // LIVE LYRICS"
            color: Theme.primary
            font.family: Theme.monoFontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
            elide: Text.ElideRight
          }

          Text {
            id: positionButton
            text: "⌖"
            color: Theme.surfaceVariantText
            font.pixelSize: 16
            MouseArea {
              anchors.fill: parent
              anchors.margins: -5
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const positions = ["right-center", "left-center", "bottom-right", "bottom-left"]
                const index = positions.indexOf(SettingsData.lyricsHudPosition)
                SettingsData.set("lyricsHudPosition", positions[(index + 1) % positions.length])
              }
            }
          }

          Text {
            id: closeButton
            text: "×"
            color: Theme.surfaceVariantText
            font.pixelSize: 18
            MouseArea {
              anchors.fill: parent
              anchors.margins: -5
              cursorShape: Qt.PointingHandCursor
              onClicked: SettingsData.set("lyricsHudEnabled", false)
            }
          }
        }

        Text {
          width: parent.width
          text: root.trackTitle
          color: Theme.surfaceText
          font.family: Theme.fontFamily
          font.pixelSize: 13
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: root.trackArtist
          color: Theme.surfaceVariantText
          font.family: Theme.fontFamily
          font.pixelSize: 10
          elide: Text.ElideRight
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Theme.withAlpha(Theme.primary, 0.22)
        }

        Text {
          width: parent.width
          height: 30
          text: LyricsService.state === "ready"
            ? (root.currentLyric || "Aguardando a próxima linha…")
            : LyricsService.state === "loading"
              ? "Buscando letras…"
              : LyricsService.state === "instrumental"
                ? "Faixa instrumental"
                : "Letras ainda não disponíveis"
          color: Theme.surfaceText
          font.family: "serif"
          font.italic: true
          font.pixelSize: 18
          font.weight: Font.DemiBold
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 2
        }

        Text {
          width: parent.width
          height: 24
          visible: root.nextLyric !== ""
          text: root.nextLyric
          color: Theme.withAlpha(Theme.surfaceVariantText, 0.76)
          font.family: "serif"
          font.italic: true
          font.pixelSize: 13
          wrapMode: Text.WordWrap
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          width: parent.width
          text: LyricsService.synced ? "●  SYNCED LYRICS" : "●  PLAIN LYRICS"
          color: Theme.withAlpha(Theme.primary, 0.9)
          font.family: Theme.monoFontFamily
          font.pixelSize: 8
          font.letterSpacing: 0.7
          visible: LyricsService.state === "ready"
        }
      }
    }
  }

  property bool _lyricsViewRegistered: false

  function syncLyricsViewRegistration() {
    if (root.visible && !root._lyricsViewRegistered) {
      root._lyricsViewRegistered = true
      LyricsService.addLyricsViewRef()
    } else if (!root.visible && root._lyricsViewRegistered) {
      root._lyricsViewRegistered = false
      LyricsService.removeLyricsViewRef()
    }
  }

  onVisibleChanged: root.syncLyricsViewRegistration()
  Component.onCompleted: root.syncLyricsViewRegistration()
  Component.onDestruction: {
    if (root._lyricsViewRegistered)
      LyricsService.removeLyricsViewRef()
  }
}
