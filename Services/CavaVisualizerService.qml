pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var levels: [0.1, 0.1, 0.1, 0.1, 0.1]

    Process {
        id: cavaProcess

        command: [
            "cava",
            "-p",
            Quickshell.shellDir + "/Services/cava-visualizer.conf"
        ]

        running: true

        stdout: SplitParser {
            onRead: data => {
                const parts = String(data).trim().split(";")
                    .filter(value => value.trim() !== "")

                if (parts.length !== 5)
                    return

                const values = parts.map(value => Number(value))

                if (values.some(value => !Number.isFinite(value)))
                    return

                root.levels = values.map(value =>
                    Math.max(0, Math.min(1, value / 1000))
                )
            }
        }
    }
}
