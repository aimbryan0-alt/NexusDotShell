pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Common

// Native Desktop Notifications server. Registration is opt-in so an existing
// desktop notification daemon (for example KDE Plasma's) remains untouched.
QtObject {
  id: root

  readonly property bool enabled: SettingsData.notificationServerEnabled
  readonly property var notifications: serverLoader.item
    ? serverLoader.item.trackedNotifications.values
    : []
  readonly property int count: root.notifications.length

  signal notificationReceived(var notification)

  function dismiss(notification) {
    if (notification)
      notification.dismiss()
  }

  function dismissAll() {
    const current = root.notifications.slice()
    for (let i = 0; i < current.length; i++)
      current[i].dismiss()
  }

  Loader {
    id: serverLoader
    active: root.enabled

    sourceComponent: NotificationServer {
      keepOnReload: false
      actionsSupported: false
      persistenceSupported: false
      bodyMarkupSupported: false
      bodyHyperlinksSupported: false
      bodyImagesSupported: false
      imageSupported: false

      onNotification: notification => {
        // Track only while the user has explicitly enabled this server.
        notification.tracked = true
        root.notificationReceived(notification)
      }
    }
  }
}
