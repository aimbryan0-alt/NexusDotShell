import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Modules.Bar.Widgets
import qs.Services

// Battery pill. Renders percentage (and a charging indicator) from UPower,
// guarded so it renders nothing when no battery is present.
BasePill {
  id: root

  property var barWindow: null
  property var parentScreen: null
  property bool overviewOpen: false
  property int overviewX: 0
  property int overviewY: 0

  readonly property real level: UPower.displayDevice ? (UPower.displayDevice.percentage * 100) : -1
  readonly property bool hasBattery: level >= 0
  readonly property var batteryDevices: UPower.devices
    ? UPower.devices.values.filter(device => device && device.isLaptopBattery)
    : []
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
  // Access the singleton once per shell, regardless of the number of monitors.
  readonly property bool _batteryNotificationsActive: BatteryNotificationService.active

  function toggleOverview() {
    if (root.overviewOpen) {
      root.overviewOpen = false
      return
    }
    if (!root.barWindow)
      return
    const screenWidth = root.parentScreen ? root.parentScreen.width : root.barWindow.width
    const screenHeight = root.parentScreen ? root.parentScreen.height : root.barWindow.height
    const popupWidth = Math.min(520, screenWidth - 24)
    const popupHeight = Math.min(overviewPopup.implicitHeight, screenHeight - 24)
    const point = root.mapToItem(root.barWindow.contentItem, root.width / 2, 0)
    root.overviewX = Math.round(Math.max(8, Math.min(
      screenWidth - popupWidth - 8,
      point.x - popupWidth / 2
    )))
    const belowY = point.y + root.height + Theme.spaceXS
    root.overviewY = Math.round(Math.max(8, Math.min(
      screenHeight - popupHeight - 8,
      belowY + popupHeight <= screenHeight - 8 ? belowY : point.y - popupHeight - Theme.spaceXS
    )))
    root.overviewOpen = true
  }

  PopupWindow {
    id: overviewPopup
    anchor.window: root.barWindow
    anchor.rect.x: root.overviewX
    anchor.rect.y: root.overviewY
    visible: root.overviewOpen
    grabFocus: true
    color: "transparent"
    implicitWidth: Math.min(520, root.parentScreen ? root.parentScreen.width - 24 : 520)
    implicitHeight: Math.min(
      batteryOverview.implicitHeight,
      root.parentScreen ? root.parentScreen.height - 24 : 600
    )

    onVisibleChanged: {
      if (!visible)
        root.overviewOpen = false
    }

    BatteryOverview {
      id: batteryOverview
      width: overviewPopup.width
      height: overviewPopup.height
      batteryDevice: UPower.displayDevice
      batteryDevices: root.batteryDevices
      accessoryDevices: root.accessoryDevices
      active: root.overviewOpen
      onCloseRequested: root.overviewOpen = false
    }
  }

  content: Component {
    Row {
      visible: root.hasBattery || root.accessoryDevices.length > 0
      spacing: 4

      Row {
        visible: root.hasBattery
        spacing: 4

        DmsIcon {
          name: root.batteryIcon()
          size: root.iconSize(-4)
          color: root._charging ? Theme.primary : (root._low ? Theme.error : Theme.widgetIconColor)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: Math.round(root.level) + "%"
          color: root._low ? Theme.error : Theme.widgetTextColor
          font.family: Theme.monoFontFamily
          font.pixelSize: root.textSize()
        }
      }

      Repeater {
        model: root.accessoryDevices

        delegate: Row {
          required property var modelData
          spacing: 4

          DmsIcon {
            name: root.accessoryIcon(modelData)
            size: root.iconSize(-4)
            color: modelData.state === UPowerDeviceState.Charging
              ? Theme.primary
              : (root.accessoryLevel(modelData) <= 20 ? Theme.error : Theme.widgetIconColor)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.accessoryLevel(modelData) + "%"
            color: root.accessoryLevel(modelData) <= 20 ? Theme.error : Theme.widgetTextColor
            font.family: Theme.monoFontFamily
            font.pixelSize: root.textSize()
          }
        }
      }
    }
  }

  // Keep the charging glyph while AC power is connected, including when a
  // charge limit leaves the battery below 100% or UPower reports full.
  readonly property bool _charging: UPower.displayDevice ? !UPower.onBattery : false
  readonly property bool _actuallyCharging: UPower.displayDevice
    ? UPower.displayDevice.state === UPowerDeviceState.Charging
    : false
  readonly property bool _low: root.hasBattery && root.level <= 20

  function batteryIcon() {
    if (root._charging) {
      if (root.level >= 100) return "battery_charging_full"
      if (root.level >= 90) return "battery_charging_90"
      if (root.level >= 60) return "battery_charging_80"
      if (root.level >= 50) return "battery_charging_60"
      if (root.level >= 30) return "battery_charging_50"
      if (root.level >= 20) return "battery_charging_30"
      return "battery_charging_20"
    }

    if (root.level >= 95) return "battery_full"
    if (root.level >= 85) return "battery_6_bar"
    if (root.level >= 70) return "battery_5_bar"
    if (root.level >= 55) return "battery_4_bar"
    if (root.level >= 40) return "battery_3_bar"
    if (root.level >= 25) return "battery_2_bar"
    return "battery_1_bar"
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

  onClicked: root.toggleOverview()
}
