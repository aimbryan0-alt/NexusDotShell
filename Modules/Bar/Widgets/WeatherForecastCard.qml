import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Bar.Widgets

Rectangle {
  id: root
  radius: Theme.cornerRadius

  property var date: null
  property bool daily: true
  property var forecastData: null
  property bool dense: false

  readonly property bool isCurrent: {
    if (!date) return false
    if (daily) {
      return WeatherService.calendarDayDifference(new Date(), date) === 0
    } else {
      return WeatherService.calendarHourDifference(new Date(), date) === 0
    }
  }

  readonly property string dateText: {
    if (daily) return root.forecastData?.day ?? "--"
    return root.forecastData?.time ?? "--"
  }

  readonly property string minMaxTempText: {
    if (!root.forecastData) return "--/--"
    const mn = WeatherService.formatTemp(root.forecastData.tempMin)
    const mx = WeatherService.formatTemp(root.forecastData.tempMax)
    return mn + "/" + mx
  }

  readonly property string tempText: {
    if (!root.forecastData) return "--"
    return WeatherService.formatTemp(root.forecastData.temp)
  }

  readonly property string feelsLikeText: {
    if (!root.forecastData) return "--"
    return WeatherService.formatTemp(root.forecastData.feelsLike)
  }

  readonly property string humidityText: (root.forecastData?.humidity ?? "--") + "%"
  readonly property string windText: WeatherService.formatSpeed(root.forecastData?.wind)
  readonly property string pressureText: WeatherService.formatPressure(root.forecastData?.pressure)
  readonly property string precipitationText: (root.forecastData?.precipitationProbability ?? 0) + "%"

  readonly property var values: daily ? [] : [
    { label: qsTr("Umidade"), text: root.humidityText, icon: "humidity_low" },
    { label: qsTr("Vento"), text: root.windText, icon: "air" },
    { label: qsTr("Pressão"), text: root.pressureText, icon: "speed" },
    { label: qsTr("Chuva"), text: qsTr("%1 · %2").arg(root.precipitationText).arg(WeatherService.formatRain(root.forecastData?.precipitationMm)), icon: "rainy" }
  ]

  color: isCurrent ? Theme.withAlpha(Theme.primary, 0.11) : Theme.nestedSurface
  border.color: isCurrent ? Theme.withAlpha(Theme.primary, 0.38) : Theme.withAlpha(Theme.outline, 0.10)
  border.width: 1

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 2
    radius: 1
    color: isCurrent ? Theme.primary : Theme.withAlpha(Theme.primary, 0.16)
  }

  Column {
    anchors.centerIn: parent
    spacing: Theme.spaceS

    Text {
      text: root.forecastData != null ? root.dateText : "--"
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeSmall
      color: root.isCurrent ? Theme.primary : (root.forecastData ? Theme.surfaceText : Theme.outline)
      font.weight: root.isCurrent ? Font.Medium : Font.Normal
      anchors.horizontalCenter: parent.horizontalCenter
    }

    DmsIcon {
      name: root.forecastData ? WeatherService.weatherIcon(root.forecastData.wCode || 0, root.forecastData.isDay ?? true) : "cloud"
      size: 22
      color: root.isCurrent ? Theme.primary : Theme.withAlpha(Theme.primary, 0.72)
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.forecastData != null
    }

    Text {
      text: root.daily ? root.minMaxTempText : root.tempText
      font.family: Theme.monoFontFamily
      font.pixelSize: Theme.fontSizeSmall + 1
      color: root.isCurrent ? Theme.primary : Theme.surfaceText
      font.weight: Font.DemiBold
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.forecastData != null
    }

    Row {
      spacing: Theme.spacingXXS
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.forecastData != null && (root.daily || root.dense)
      DmsIcon {
        name: "rainy"
        size: 11
        color: Theme.withAlpha(Theme.primary, 0.82)
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: qsTr("%1 · %2").arg(root.precipitationText).arg(WeatherService.formatRain(root.forecastData.precipitationMm))
        font.family: Theme.monoFontFamily
        font.pixelSize: Theme.fontSizeSmall - 3
        color: Theme.withAlpha(Theme.surfaceText, 0.68)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Text {
      text: qsTr("Sensação %1").arg(root.feelsLikeText)
      font.family: Theme.monoFontFamily
      font.pixelSize: Theme.fontSizeSmall - 2
      color: root.isCurrent ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.7)
      anchors.horizontalCenter: parent.horizontalCenter
      visible: !root.daily && !root.dense
    }

    Column {
      id: detailsColumn
      spacing: Theme.spacingXXS
      visible: !root.dense && !root.daily

      Repeater {
        model: root.values
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Theme.spacingXXS

          DmsIcon {
            name: modelData.icon
            size: 10
            color: Theme.withAlpha(Theme.surfaceText, 0.6)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: modelData.text
            font.family: Theme.monoFontFamily
            font.pixelSize: Theme.fontSizeSmall - 3
            color: Theme.withAlpha(Theme.surfaceText, 0.6)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
