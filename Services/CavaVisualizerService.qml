pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var levels: [0.1, 0.1, 0.1, 0.1, 0.1]

    // Each PlayerWidget registers independently, supporting multiple bars.
    property var activeConsumers: []

    function setConsumerPlaying(consumer, playing) {
        if (!consumer)
            return

        const index = root.activeConsumers.indexOf(consumer)

        if (playing && index === -1) {
            root.activeConsumers = root.activeConsumers.concat([consumer])
        } else if (!playing && index !== -1) {
            const updated = root.activeConsumers.slice()
            updated.splice(index, 1)
            root.activeConsumers = updated
        }

        if (root.activeConsumers.length === 0)
            root.levels = [0.1, 0.1, 0.1, 0.1, 0.1]
    }

    Process {
        id: cavaProcess

        command: [
            "cava",
            "-p",
            Quickshell.shellDir + "/Services/cava-visualizer.conf"
        ]

        running: root.activeConsumers.length > 0

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
