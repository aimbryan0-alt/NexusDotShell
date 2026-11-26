import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Common
import qs.Modules.Bar
import qs.Modules.Dock
import qs.Services

// The top bar. Instantiates one PanelWindow layer surface per screen via
// Variants over Quickshell.screens. Clicking empty bar space toggles its
// background; right-clicking opens per-bar display options.
Item {
  id: root

  readonly property int barTransparency: typeof SettingsData !== "undefined" ? (SettingsData.barTransparency || 0) : 0

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "activespecial")
        Hyprland.refreshMonitors()
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData
        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DockPanel {
        required property var modelData
        targetScreen: modelData
      }
    }
  }

  component DockPanel: PanelWindow {
    id: dockWindow

    property var targetScreen: null

    Connections {
      target: Hyprland

      function onRawEvent(event) {
        if (event.name === "fullscreen"
            || event.name === "workspace"
            || event.name === "activespecial"
            || event.name === "activespecialv2") {
          Hyprland.refreshWorkspaces()
          Hyprland.refreshMonitors()
        }
      }
    }

    readonly property var hyprlandMonitor: Hyprland.monitorFor(dockWindow.screen)
    readonly property var specialWorkspace: dockWindow.hyprlandMonitor?.lastIpcObject?.specialWorkspace
    readonly property var specialWorkspaceState: {
      const monitor = dockWindow.hyprlandMonitor
      const special = dockWindow.specialWorkspace
      if (!monitor || !special || special.id === 0)
        return null
      return (Hyprland.workspaces?.values || []).find(workspace =>
        workspace.name === special.name
          && workspace.monitor?.name === monitor.name) || null
    }
    readonly property bool specialWorkspaceFullscreen:
      !!dockWindow.specialWorkspaceState?.hasFullscreen
    readonly property bool regularWorkspaceFullscreen:
      !!dockWindow.hyprlandMonitor?.activeWorkspace?.hasFullscreen

    screen: targetScreen
    anchors {
      bottom: true
      left: true
      right: true
    }
    visible: typeof SettingsData !== "undefined" && SettingsData.showDock
      && !dockWindow.specialWorkspaceFullscreen
      && !dockWindow.regularWorkspaceFullscreen
    implicitHeight: dockContent.shouldShow ? 88 : 8
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "nexusdot-dock"
    WlrLayershell.layer: WlrLayer.Overlay

    Dock {
      id: dockContent
      anchors.fill: parent
      screen: dockWindow.screen
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    property real contextMenuX: 0

    Connections {
      target: Hyprland

      function onRawEvent(event) {
        if (event.name === "fullscreen"
            || event.name === "workspace"
            || event.name === "activespecial"
            || event.name === "activespecialv2") {
          Hyprland.refreshWorkspaces()
          Hyprland.refreshMonitors()
        }
      }
    }
    readonly property bool backgroundEnabled: root.barTransparency !== 0
    readonly property var hyprlandMonitor: Hyprland.monitorFor(barWindow.screen)
    readonly property var specialWorkspace: barWindow.hyprlandMonitor?.lastIpcObject?.specialWorkspace
    readonly property var specialWorkspaceState: {
      const monitor = barWindow.hyprlandMonitor
      const special = barWindow.specialWorkspace
      if (!monitor || !special || special.id === 0)
        return null
      return (Hyprland.workspaces?.values || []).find(workspace =>
        workspace.name === special.name
          && workspace.monitor?.name === monitor.name) || null
    }
    readonly property bool specialWorkspaceFullscreen: {
      const workspace = barWindow.specialWorkspaceState
      return !!workspace?.hasFullscreen
    }
    readonly property bool specialWorkspaceOverFullscreen: {
      const special = barWindow.specialWorkspace
      const monitor = barWindow.hyprlandMonitor
      if (!monitor || !special || special.id === 0
          || !special.name.startsWith("special:"))
        return false
      return !!monitor.activeWorkspace?.hasFullscreen
        && !barWindow.specialWorkspaceFullscreen
    }
    readonly property bool regularWorkspaceFullscreen:
      !!barWindow.hyprlandMonitor?.activeWorkspace?.hasFullscreen

    anchors {
      top: true
      left: true
      right: true
    }

    visible: !barWindow.specialWorkspaceFullscreen
      && !barWindow.regularWorkspaceFullscreen
    implicitHeight: Theme.barHeight + Theme.space2() * 2
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.namespace: "mybar"
    WlrLayershell.layer: barWindow.specialWorkspaceOverFullscreen
      ? WlrLayer.Overlay : WlrLayer.Top

    BackgroundEffect.blurRegion: SettingsData.barBlurEnabled ? barBlurRegion : null

    Region {
      id: barBlurRegion
      x: 0
      y: 0
      width: barWindow.width
      height: barWindow.height
    }

    // Rounded HUD chassis keeps the original bar layout while giving it
    // a compact cyberpunk frame. All accents are static to avoid extra work.
    Rectangle {
      id: hudFrame
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      anchors.topMargin: 2
      anchors.bottomMargin: 2
      radius: 13
      color: Theme.withAlpha(
        Theme.surfaceContainerLowest,
        barWindow.backgroundEnabled ? 0.94 : 0.24
      )
      border.width: 1
      border.color: Theme.withAlpha(Theme.primary, barWindow.backgroundEnabled ? 0.48 : 0.24)

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 17
        anchors.top: parent.top
        width: 62
        height: 2
        radius: 1
        color: Theme.primary
        opacity: 0.9
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.bottom: parent.bottom
        width: 38
        height: 2
        radius: 1
        color: Theme.tertiary
        opacity: 0.78
      }

      Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 9
        radius: 1
        color: Theme.primary
        opacity: 0.8
      }

      Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 9
        radius: 1
        color: Theme.tertiary
        opacity: 0.8
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          barWindow.contextMenuX = mouse.x
          barContextMenu.visible = true
        } else {
          SettingsData.set("barTransparency", barWindow.backgroundEnabled ? 0 : 1)
        }
      }
    }

    PopupWindow {
      id: barContextMenu
      anchor.window: barWindow
      anchor.rect.x: Math.max(Theme.spaceS, Math.min(
        barWindow.width - implicitWidth - Theme.spaceS,
        barWindow.contextMenuX - implicitWidth / 2
      ))
      anchor.rect.y: barWindow.height + Theme.spaceXS
      visible: false
      grabFocus: true
      color: "transparent"
      surfaceFormat.opaque: false
      implicitWidth: 216
      implicitHeight: contextMenuContent.implicitHeight + Theme.spaceS * 2

      Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.6)

        Column {
          id: contextMenuContent
          anchors.fill: parent
          anchors.margins: Theme.spaceS
          spacing: Theme.spaceXS

          Repeater {
            model: [
              { label: "Bar background", enabled: barWindow.backgroundEnabled, setting: "background" },
              { label: "Blur behind bar and overlays", enabled: SettingsData.barBlurEnabled, setting: "blur" }
            ]

            delegate: Item {
              required property var modelData
              width: contextMenuContent.width
              height: Theme.spaceXL + Theme.spaceS

              Rectangle {
                anchors.fill: parent
                radius: Theme.hoverRadius
                color: optionMouse.containsMouse
                  ? Theme.withAlpha(Theme.primary, 0.12)
                  : "transparent"
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.enabled ? "On" : "Off"
                color: modelData.enabled ? Theme.primary : Theme.widgetInactiveIconColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }

              MouseArea {
                id: optionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.setting === "background")
                    SettingsData.set("barTransparency", barWindow.backgroundEnabled ? 0 : 1)
                  else
                    SettingsData.set("barBlurEnabled", !SettingsData.barBlurEnabled)
                }
              }
            }
          }

        }
      }
    }

    PopupWindow {
      id: nativeBuildPrompt
      anchor.window: barWindow
      anchor.rect.x: Math.max(Theme.spaceS, Math.min(
        barWindow.width - implicitWidth - Theme.spaceS,
        (barWindow.width - implicitWidth) / 2
      ))
      anchor.rect.y: barWindow.height + Theme.spaceXS
      visible: barWindow.visible
        && barWindow.screen === Quickshell.screens[0]
        && NativeBuildService.promptVisible
      grabFocus: true
      color: "transparent"
      surfaceFormat.opaque: false
      implicitWidth: 380
      implicitHeight: nativeBuildContent.implicitHeight + Theme.spaceM * 2

      Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.withAlpha(Theme.outlineVariant, 0.6)

        Column {
          id: nativeBuildContent
          anchors.fill: parent
          anchors.margins: Theme.spaceM
          spacing: Theme.spaceS

          Text {
            width: parent.width
            text: "Build native collectors?"
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
          }

          Text {
            width: parent.width
            text: NativeBuildService.buildError
              || "Build the optimized CPU, memory, and GPU collectors now? The shell remains usable with fallback collectors if you skip."
            color: Theme.surfaceText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
          }

          Row {
            anchors.right: parent.right
            spacing: Theme.spaceS
            height: Theme.spaceXL + Theme.spaceS

            Rectangle {
              width: buildButtonLabel.implicitWidth + Theme.spaceM * 2
              height: parent.height
              radius: Theme.cornerRadius
              color: Theme.primary
              opacity: NativeBuildService.buildRunning ? 0.5 : 1

              Text {
                id: buildButtonLabel
                anchors.centerIn: parent
                text: NativeBuildService.buildRunning ? "Building..."
                  : (NativeBuildService.buildError ? "Retry" : "Build")
                color: Theme.primaryText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }

              MouseArea {
                anchors.fill: parent
                enabled: !NativeBuildService.buildRunning
                cursorShape: Qt.PointingHandCursor
                onClicked: NativeBuildService.buildHelpers()
              }
            }

            Rectangle {
              width: dismissButtonLabel.implicitWidth + Theme.spaceM * 2
              height: parent.height
              radius: Theme.cornerRadius
              color: Theme.surfaceContainerHigh
              opacity: NativeBuildService.buildRunning ? 0.5 : 1

              Text {
                id: dismissButtonLabel
                anchors.centerIn: parent
                text: "Not now"
                color: Theme.surfaceText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
              }

              MouseArea {
                anchors.fill: parent
                enabled: !NativeBuildService.buildRunning
                cursorShape: Qt.PointingHandCursor
                onClicked: NativeBuildService.dismissPrompt()
              }
            }
          }
        }
      }
    }

    BarBody {
      anchors.fill: parent
      anchors.topMargin: Theme.spaceXXS
      anchors.bottomMargin: Theme.spaceXXS
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      screen: barWindow.screen
      barWindow: barWindow
    }
  }
}
