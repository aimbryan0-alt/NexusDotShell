import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Bar.Widgets

// Compact network throughput pill using Linux interface byte counters.
BasePill {
  id: root

  property real downloadRate: 0
  property real uploadRate: 0
  property real previousRx: -1
  property real previousTx: -1
  property real previousSample: 0
  property string interfaceName: ""

  function updateSample(raw) {
    const fields = String(raw || "").trim().split("|")
    if (fields.length < 3)
      return
    const iface = fields[0]
    const rx = Number(fields[1])
    const tx = Number(fields[2])
    const now = Date.now() / 1000
    if (!iface || !Number.isFinite(rx) || !Number.isFinite(tx)) {
      root.interfaceName = ""
      root.downloadRate = 0
      root.uploadRate = 0
      return
    }
    if (iface === root.interfaceName && root.previousSample > 0) {
      const elapsed = now - root.previousSample
      if (elapsed > 0) {
        root.downloadRate = Math.max(0, (rx - root.previousRx) / elapsed)
        root.uploadRate = Math.max(0, (tx - root.previousTx) / elapsed)
      }
    } else {
      root.downloadRate = 0
      root.uploadRate = 0
    }
    root.interfaceName = iface
    root.previousRx = rx
    root.previousTx = tx
    root.previousSample = now
  }

  readonly property string connectionLabel: root.interfaceName
    ? (root.interfaceName.startsWith("wl") ? "WI-FI" : "LAN")
    : "OFFLINE"

  function formatRate(rate) {
    const value = Math.max(0, Number(rate) || 0)
    if (value >= 1048576)
      return (value / 1048576).toFixed(1) + " MB/s"
    if (value >= 1024)
      return (value / 1024).toFixed(0) + " KB/s"
    return Math.round(value) + " B/s"
  }

  Process {
    id: networkProbe
    command: [
      "bash", "-c",
      "iface=$(ip -o route show default 2>/dev/null | awk 'NR == 1 {print $5}'); " +
      "if [ -z \"$iface\" ]; then " +
        "for path in /sys/class/net/*; do candidate=$(basename \"$path\"); " +
        "[ \"$candidate\" = lo ] && continue; iface=$candidate; break; done; " +
      "fi; " +
      "if [ -n \"$iface\" ] && [ -r \"/sys/class/net/$iface/statistics/rx_bytes\" ]; then " +
        "printf '%s|%s|%s\\n' \"$iface\" " +
        "\"$(cat /sys/class/net/$iface/statistics/rx_bytes)\" " +
        "\"$(cat /sys/class/net/$iface/statistics/tx_bytes)\"; " +
      "fi"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateSample(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.interfaceName = ""
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!networkProbe.running)
        networkProbe.running = true
    }
  }

  content: Component {
    Row {
      spacing: 5
      anchors.verticalCenter: parent.verticalCenter

      DmsIcon {
        name: root.interfaceName && root.interfaceName.startsWith("wl")
          ? "wifi" : root.interfaceName ? "lan" : "wifi_off"
        size: root.iconSize(-3)
        color: root.interfaceName ? Theme.primary : Theme.widgetInactiveIconColor
        anchors.verticalCenter: parent.verticalCenter
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Row {
          spacing: 3
          DmsIcon {
            name: "south"
            size: 9
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.formatRate(root.downloadRate)
            color: Theme.widgetTextColor
            font.family: Theme.monoFontFamily
            font.pixelSize: Math.max(8, root.textSize() - 2)
          }
        }

        Row {
          spacing: 3
          DmsIcon {
            name: "north"
            size: 9
            color: Theme.secondary
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.formatRate(root.uploadRate)
            color: Theme.widgetInactiveIconColor
            font.family: Theme.monoFontFamily
            font.pixelSize: Math.max(8, root.textSize() - 2)
          }
        }
      }
    }
  }
}
