import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

// Compact notification entry point, event-driven toast, and retained center.
BasePill {
  id: root

  property var barWindow: null
  property var parentScreen: null
  property bool centerOpen: false
  property var toastNotification: null

  readonly property var notificationItems: NotificationService.notifications
    ? NotificationService.notifications.slice().reverse()
    : []

  function positionPopups() {
    if (!root.barWindow)
      return
    const screenWidth = root.parentScreen ? root.parentScreen.width : root.barWindow.width
    const popupWidth = centerPopup.implicitWidth
    centerPopup.anchor.rect.x = Math.max(8, screenWidth - popupWidth - 12)
    centerPopup.anchor.rect.y = root.barWindow.height + Theme.spaceS
    toastPopup.anchor.rect.x = Math.max(8, screenWidth - toastPopup.implicitWidth - 12)
    toastPopup.anchor.rect.y = root.barWindow.height + Theme.spaceS
  }

  function toggleCenter() {
    if (!root.barWindow)
      return
    root.positionPopups()
    root.centerOpen = !root.centerOpen
    if (root.centerOpen) {
      toastTimer.stop()
      toastPopup.visible = false
    }
  }

  onClicked: root.toggleCenter()

  Connections {
    target: NotificationService
    function onNotificationReceived(notification) {
      root.toastNotification = notification
      if (!root.centerOpen && root.barWindow && root.parentScreen === Quickshell.screens[0]) {
        root.positionPopups()
        toastPopup.visible = true
        toastTimer.restart()
      }
    }
  }

  content: Component {
    Item {
      implicitWidth: 26
      implicitHeight: 24

      DmsIcon {
        anchors.centerIn: parent
        name: NotificationService.count > 0 ? "notifications_active" : "notifications"
        size: root.iconSize(-3)
        color: NotificationService.count > 0 ? Theme.primary : Theme.widgetIconColor
        filled: NotificationService.count > 0
      }

      Rectangle {
        visible: NotificationService.count > 0
        anchors.right: parent.right
        anchors.top: parent.top
        width: Math.max(10, countLabel.implicitWidth + 5)
        height: 10
        radius: 5
        color: Theme.primary

        Text {
          id: countLabel
          anchors.centerIn: parent
          text: NotificationService.count > 99 ? "99+" : String(NotificationService.count)
          color: Theme.surface
          font.family: Theme.monoFontFamily
          font.pixelSize: 7
          font.bold: true
        }
      }

      Rectangle {
        visible: !NotificationService.enabled
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 5
        height: 5
        radius: 3
        color: Theme.tertiary
      }
    }
  }

  PopupWindow {
    id: centerPopup
    anchor.window: root.barWindow
    visible: root.centerOpen
    grabFocus: true
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: 360
    implicitHeight: Math.min(500, Math.max(260,
      root.parentScreen ? root.parentScreen.height - (root.barWindow ? root.barWindow.height : Theme.barHeight) - 24 : 460))

    onVisibleChanged: {
      if (!visible)
        root.centerOpen = false
    }

    Rectangle {
      anchors.fill: parent
      radius: 16
      color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.97)
      border.width: 1
      border.color: Theme.withAlpha(Theme.primary, 0.48)

      Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Row {
          width: parent.width
          height: 28
          spacing: 8

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 18
            radius: 1
            color: Theme.primary
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 58
            text: "NEXUS // NOTIFICATIONS"
            color: Theme.primary
            font.family: Theme.monoFontFamily
            font.pixelSize: 12
            font.bold: true
          }

          Text {
            width: 42
            anchors.verticalCenter: parent.verticalCenter
            text: NotificationService.count.toString().padStart(2, "0")
            color: Theme.widgetTextColor
            font.family: Theme.monoFontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Theme.withAlpha(Theme.primary, 0.22)
        }

        Column {
          visible: !NotificationService.enabled
          width: parent.width
          height: parent.height - 50
          spacing: 12

          Item { width: 1; height: 24 }

          DmsIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "notifications_paused"
            size: 34
            color: Theme.widgetInactiveIconColor
          }

          Text {
            width: parent.width
            text: "NATIVE SERVER DISABLED"
            color: Theme.widgetTextColor
            font.family: Theme.monoFontFamily
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            width: parent.width
            text: "Enable the NexusDotShell notification server to receive desktop notifications here. Your current desktop notification service stays untouched until you enable it."
            color: Theme.widgetInactiveIconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
          }

          Rectangle {
            width: parent.width
            height: 38
            radius: 8
            color: Theme.withAlpha(Theme.primary, 0.16)
            border.width: 1
            border.color: Theme.withAlpha(Theme.primary, 0.55)

            Text {
              anchors.centerIn: parent
              text: "ENABLE NEXUS NOTIFICATIONS"
              color: Theme.primary
              font.family: Theme.monoFontFamily
              font.pixelSize: 10
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: SettingsData.set("notificationServerEnabled", true)
            }
          }
        }

        Column {
          visible: NotificationService.enabled
          width: parent.width
          height: parent.height - 50
          spacing: 8

          Row {
            width: parent.width
            height: 26

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 68
              text: NotificationService.count === 0 ? "INBOX // EMPTY" : "INBOX // LIVE"
              color: Theme.widgetInactiveIconColor
              font.family: Theme.monoFontFamily
              font.pixelSize: 9
            }

            Text {
              width: 60
              anchors.verticalCenter: parent.verticalCenter
              visible: NotificationService.count > 0
              text: "CLEAR ALL"
              color: Theme.primary
              font.family: Theme.monoFontFamily
              font.pixelSize: 9
              horizontalAlignment: Text.AlignRight

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.dismissAll()
              }
            }
          }

          Text {
            visible: NotificationService.count === 0
            width: parent.width
            height: 100
            text: "No notifications yet. Incoming alerts will appear here."
            color: Theme.widgetInactiveIconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          ListView {
            id: notificationList
            visible: NotificationService.count > 0
            width: parent.width
            height: parent.height - 28
            clip: true
            spacing: 7
            model: root.notificationItems
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
              required property var modelData
              width: notificationList.width
              height: notificationCard.implicitHeight + 18
              radius: 9
              color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.72)
              border.width: 1
              border.color: Theme.withAlpha(Theme.outlineVariant, 0.28)

              Column {
                id: notificationCard
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9
                spacing: 4

                Row {
                  width: parent.width
                  spacing: 6

                  Text {
                    width: parent.width - 58
                    text: modelData.appName || modelData.desktopEntry || "SYSTEM"
                    color: Theme.primary
                    font.family: Theme.monoFontFamily
                    font.pixelSize: 9
                    elide: Text.ElideRight
                  }

                  Text {
                    text: "DISMISS"
                    color: Theme.widgetInactiveIconColor
                    font.family: Theme.monoFontFamily
                    font.pixelSize: 8

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: NotificationService.dismiss(modelData)
                    }
                  }
                }

                Text {
                  width: parent.width
                  text: modelData.summary || "Notification"
                  color: Theme.widgetTextColor
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeSmall
                  font.bold: true
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                }

                Text {
                  visible: !!modelData.body
                  width: parent.width
                  text: modelData.body || ""
                  color: Theme.widgetInactiveIconColor
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeSmall - 1
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                }
              }
            }
          }
        }
      }
    }
  }

  PopupWindow {
    id: toastPopup
    anchor.window: root.barWindow
    visible: false
    color: "transparent"
    surfaceFormat.opaque: false
    implicitWidth: Math.min(340, root.parentScreen ? root.parentScreen.width - 24 : 340)
    implicitHeight: toastContent.implicitHeight + 22

    Rectangle {
      anchors.fill: parent
      radius: 13
      color: Theme.withAlpha(Theme.surfaceContainerLowest, 0.97)
      border.width: 1
      border.color: Theme.withAlpha(Theme.primary, 0.58)

      Column {
        id: toastContent
        anchors.fill: parent
        anchors.margins: 11
        spacing: 4

        Text {
          width: parent.width
          text: root.toastNotification
            ? (root.toastNotification.appName || root.toastNotification.desktopEntry || "SYSTEM")
            : "NEXUS // SYSTEM"
          color: Theme.primary
          font.family: Theme.monoFontFamily
          font.pixelSize: 9
        }

        Text {
          width: parent.width
          text: root.toastNotification ? (root.toastNotification.summary || "Notification") : ""
          color: Theme.widgetTextColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall
          font.bold: true
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
        }

        Text {
          visible: !!root.toastNotification && !!root.toastNotification.body
          width: parent.width
          text: root.toastNotification ? root.toastNotification.body : ""
          color: Theme.widgetInactiveIconColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeSmall - 1
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          toastPopup.visible = false
          root.toggleCenter()
        }
      }
    }
  }

  Timer {
    id: toastTimer
    interval: 4500
    repeat: false
    onTriggered: toastPopup.visible = false
  }
}
