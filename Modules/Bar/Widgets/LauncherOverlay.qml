import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Common

// Compact, keyboard-first application launcher built from the system's
// Freedesktop desktop entries. The GridView virtualizes delegates so large
// application lists do not create a permanent background workload.
PopupWindow {
  id: root

  property var barWindow: null
  property bool opened: false
  property var filteredApps: []

  visible: opened
  anchor.window: barWindow
  anchor.rect.x: Math.max(12, (barWindow ? (barWindow.width - implicitWidth) / 2 : 12))
  anchor.rect.y: barWindow ? barWindow.height + 8 : 12
  grabFocus: true
  color: "transparent"
  surfaceFormat.opaque: false
  implicitWidth: 760
  implicitHeight: 560

  function filterApps(query) {
    const needle = String(query || "").trim().toLowerCase()
    const entries = DesktopEntries.applications.values || []
    const matches = entries.filter(entry => {
      if (!needle)
        return true
      const searchable = [
        entry.name || "",
        entry.genericName || "",
        entry.comment || "",
        (entry.keywords || []).join(" ")
      ].join(" ").toLowerCase()
      return searchable.indexOf(needle) !== -1
    })
    matches.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")))
    root.filteredApps = matches
    grid.currentIndex = 0
  }

  function launchEntry(entry) {
    if (!entry)
      return
    entry.execute()
    root.opened = false
  }

  function togglePinnedApp(entry) {
    if (!entry || !entry.id) return
    const id = String(entry.id)
    const pinned = Array.isArray(SettingsData.dockPinnedApps) ? SettingsData.dockPinnedApps : []
    const next = pinned.indexOf(id) !== -1 ? pinned.filter(item => item !== id) : pinned.concat([id])
    SettingsData.set("dockPinnedApps", next)
  }

  function isPinned(entry) {
    return !!entry && !!entry.id && Array.isArray(SettingsData.dockPinnedApps)
      && SettingsData.dockPinnedApps.indexOf(String(entry.id)) !== -1
  }

  onVisibleChanged: {
    if (visible) {
      searchField.text = ""
      root.filterApps("")
      searchField.forceActiveFocus()
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 22
    color: Theme.withAlpha(Theme.surfaceContainer, 0.97)
    border.width: 1
    border.color: Theme.withAlpha(Theme.primary, 0.42)

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 3
      radius: 2
      color: Theme.primary
      opacity: 0.8
    }

    Column {
      anchors.fill: parent
      anchors.margins: 22
      spacing: 16

      Row {
        width: parent.width
        spacing: 12

        Rectangle {
          width: 42
          height: 42
          radius: 13
          color: Theme.withAlpha(Theme.primary, 0.14)
          Text {
            anchors.centerIn: parent
            text: "N"
            color: Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: 22
            font.bold: true
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Text {
            text: "NEXUS // APPLICATIONS"
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.bold: true
          }
          Text {
            text: root.filteredApps.length + " applications · right-click to pin/unpin"
            color: Theme.surfaceVariantText
            font.family: Theme.fontFamily
            font.pixelSize: 11
          }
        }

        Item { width: 1; height: 1; Layout.fillWidth: true }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "ESC  CLOSE"
          color: Theme.surfaceVariantText
          font.family: Theme.fontFamily
          font.pixelSize: 10
        }
      }

      TextField {
        id: searchField
        width: parent.width
        height: 48
        placeholderText: "Search applications..."
        selectByMouse: true
        color: Theme.surfaceText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        leftPadding: 16
        rightPadding: 16
        background: Rectangle {
          radius: 13
          color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.75)
          border.width: searchField.activeFocus ? 1 : 0
          border.color: Theme.primary
        }
        onTextChanged: root.filterApps(text)
        Keys.onEscapePressed: root.opened = false
        Keys.onReturnPressed: {
          if (root.filteredApps.length > 0)
            root.launchEntry(root.filteredApps[Math.max(0, grid.currentIndex)])
        }
        Keys.onDownPressed: grid.forceActiveFocus()
      }

      GridView {
        id: grid
        width: parent.width
        height: parent.height - 42 - 48 - 32
        cellWidth: 132
        cellHeight: 112
        clip: true
        focus: true
        model: root.filteredApps
        currentIndex: 0
        keyNavigationEnabled: true
        keyNavigationWraps: true
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
          required property var modelData
          required property int index
          width: grid.cellWidth
          height: grid.cellHeight

          Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            radius: 15
            color: appMouse.containsMouse || grid.currentIndex === index
              ? Theme.withAlpha(Theme.primary, 0.12)
              : Theme.withAlpha(Theme.surfaceContainerHigh, 0.42)
            border.width: grid.currentIndex === index ? 1 : 0
            border.color: Theme.withAlpha(Theme.primary, 0.55)

            Column {
              anchors.centerIn: parent
              spacing: 9

              IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 38
                height: 38
                source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                asynchronous: true
              }

              Text {
                width: 108
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.name || "Application"
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }
          }

          MouseArea {
            id: appMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: grid.currentIndex = index
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function(mouse) {
              if (mouse.button === Qt.RightButton) {
                root.togglePinnedApp(modelData)
                return
              }
              root.launchEntry(modelData)
            }
          }

          Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 11
            anchors.topMargin: 8
            text: root.isPinned(modelData) ? "★" : "+"
            color: root.isPinned(modelData) ? Theme.primary : Theme.surfaceVariantText
            font.pixelSize: 14
            font.bold: true
          }
        }

        Text {
          anchors.centerIn: parent
          visible: grid.count === 0
          text: "No applications found"
          color: Theme.surfaceVariantText
          font.family: Theme.fontFamily
          font.pixelSize: 13
        }

        Keys.onEscapePressed: root.opened = false
        Keys.onReturnPressed: {
          if (root.filteredApps.length > 0)
            root.launchEntry(root.filteredApps[Math.max(0, grid.currentIndex)])
        }
        Keys.onUpPressed: {
          if (grid.currentIndex === 0)
            searchField.forceActiveFocus()
        }
      }
    }
  }

  Component.onCompleted: root.filterApps("")
}
