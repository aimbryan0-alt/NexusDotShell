import QtQuick
import Quickshell

Item {
  id: root

  Variants {
    model: Quickshell.screens

    delegate: Component {
      LyricsHud {
        required property var modelData
        targetScreen: modelData
      }
    }
  }
}
