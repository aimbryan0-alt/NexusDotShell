pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Centralized battery and accessory notifications.
// A single service instance prevents duplicate alerts across bar monitors.
QtObject {
  id: root

  readonly property real level: UPower.displayDevice
    ? UPower.displayDevice.percentage * 100
    : -1
  readonly property bool hasBattery: level >= 0
  readonly property bool charging: UPower.displayDevice ? !UPower.onBattery : false
  readonly property bool actuallyCharging: UPower.displayDevice
    ? UPower.displayDevice.state === UPowerDeviceState.Charging
    : false
  readonly property var accessoryDevices: {
    if (!UPower.devices)
      return []

    const accessoryTypes = [
      UPowerDeviceType.BluetoothGeneric,
      UPowerDeviceType.Headphones,
      UPowerDeviceType.Headset,
      UPowerDeviceType.Keyboard,
      UPowerDeviceType.Mouse,
      UPowerDeviceType.Speakers,
      UPowerDeviceType.Touchpad,
      UPowerDeviceType.GamingInput,
      UPowerDeviceType.Pen,
      UPowerDeviceType.Phone,
      UPowerDeviceType.Tablet,
      UPowerDeviceType.MediaPlayer,
      UPowerDeviceType.Wearable
    ]
    return UPower.devices.values.filter(device =>
      device && device.ready && !device.isLaptopBattery &&
      accessoryTypes.includes(device.type) && device.percentage >= 0)
  }
  readonly property bool active: root.hasBattery || root.accessoryDevices.length > 0

  property bool _notificationStateReady: false
  property bool _previousCharging: false
  property bool _lowNotified: false
  property bool _fullNotified: false
  property var _accessoryNotificationStates: ({})

  Timer {
    interval: 5000
    repeat: true
    running: root.active
    triggeredOnStart: true
    onTriggered: root.checkBatteryNotifications()
  }

  function sendNotification(summary, body, urgency) {
    sendDeviceNotification(summary, body, urgency, "battery")
  }

  function sendDeviceNotification(summary, body, urgency, icon) {
    Quickshell.execDetached([
      "notify-send",
      "-a", "MyQuickshell",
      "-u", urgency,
      "-i", icon,
      summary,
      body
    ])
  }

  function checkBatteryNotifications() {
    if (!root.hasBattery) {
      root.checkAccessoryNotifications()
      return
    }

    const isCharging = root.actuallyCharging
    // Establish a complete initial sample instead of notifying from transient
    // zero values while UPower is still initializing.
    if (!root._notificationStateReady) {
      root._previousCharging = isCharging
      root._notificationStateReady = true
      return
    }

    if (!isCharging && root.level <= 20) {
      if (!root._lowNotified) {
        root._lowNotified = true
        root.sendNotification("Low Battery", "Battery is at " + Math.round(root.level) + "%.", "critical")
      }
    } else if (root.level > 23 || isCharging) {
      root._lowNotified = false
    }

    if (root.charging && root.level >= 100) {
      if (!root._fullNotified) {
        root._fullNotified = true
        root.sendNotification("Battery Full", "Battery is fully charged.", "normal")
      }
    } else if (root._previousCharging && !isCharging && root.charging) {
      root.sendNotification("Charging Stopped", "The battery is no longer charging at " + Math.round(root.level) + "%.", "normal")
      root._fullNotified = false
    } else if (!isCharging || root.level < 97) {
      root._fullNotified = false
    }

    root._previousCharging = isCharging
    root.checkAccessoryNotifications()
  }

  function checkAccessoryNotifications() {
    const activePaths = {}

    for (const device of root.accessoryDevices) {
      const key = device.nativePath || device.model || String(device.type)
      const level = root.accessoryLevel(device)
      const isCharging = device.state === UPowerDeviceState.Charging
      const previous = root._accessoryNotificationStates[key] || {
        charging: isCharging,
        lowNotified: false,
        fullNotified: false
      }

      activePaths[key] = true

      if (!previous.charging && isCharging)
        previous.fullNotified = false

      if (!isCharging && level <= 20) {
        if (!previous.lowNotified) {
          previous.lowNotified = true
          root.sendDeviceNotification(
            "Low Battery",
            root.accessoryName(device) + " is at " + level + "%.",
            "critical",
            root.accessoryIcon(device)
          )
        }
      } else if (level > 23 || isCharging) {
        previous.lowNotified = false
      }

      if (isCharging && level >= 100) {
        if (!previous.fullNotified) {
          previous.fullNotified = true
          root.sendDeviceNotification(
            "Battery Full",
            root.accessoryName(device) + " is fully charged.",
            "normal",
            root.accessoryIcon(device)
          )
        }
      } else if (previous.charging && !isCharging) {
        root.sendDeviceNotification(
          "Charging Stopped",
          root.accessoryName(device) + " is no longer charging at " + level + "%.",
          "normal",
          root.accessoryIcon(device)
        )
        previous.fullNotified = false
      } else if (!isCharging || level < 97) {
        previous.fullNotified = false
      }

      previous.charging = isCharging
      root._accessoryNotificationStates[key] = previous
    }

    for (const key in root._accessoryNotificationStates) {
      if (!activePaths[key])
        delete root._accessoryNotificationStates[key]
    }
  }

  function accessoryName(device) {
    return device.model || UPowerDeviceType.toString(device.type)
  }

  function accessoryLevel(device) {
    return Math.round(device.percentage * 100)
  }

  function accessoryIcon(device) {
    if (device.state === UPowerDeviceState.Charging)
      return "battery_charging_full"

    switch (device.type) {
    case UPowerDeviceType.Keyboard:
      return "keyboard"
    case UPowerDeviceType.Mouse:
    case UPowerDeviceType.Touchpad:
      return "mouse"
    case UPowerDeviceType.Headset:
    case UPowerDeviceType.Headphones:
      return "headphones"
    case UPowerDeviceType.Speakers:
      return "speaker"
    case UPowerDeviceType.GamingInput:
      return "gamepad"
    case UPowerDeviceType.Pen:
      return "stylus"
    case UPowerDeviceType.Phone:
      return "smartphone"
    case UPowerDeviceType.Tablet:
      return "tablet"
    case UPowerDeviceType.MediaPlayer:
      return "media_output"
    case UPowerDeviceType.Wearable:
      return "watch"
    case UPowerDeviceType.BluetoothGeneric:
      return "bluetooth"
    default:
      return "battery_std"
    }
  }
}
