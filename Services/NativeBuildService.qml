pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  readonly property string shellDir: Quickshell.shellDir
  readonly property string systemStatsCPath:
    shellDir + "/tools/system-stats/build/system-stats-c"
  readonly property string gpuCPath:
    shellDir + "/tools/gpu-probe/build/gpu-fdinfo-c"

  property bool promptVisible: false
  property bool buildRunning: false
  property string buildError: ""
  property bool _checkStarted: false

  function checkForMissingHelpers() {
    if (root._checkStarted)
      return
    root._checkStarted = true
    helperCheck.running = true
  }

  function dismissPrompt() {
    if (!root.buildRunning)
      root.promptVisible = false
  }

  function buildHelpers() {
    if (root.buildRunning)
      return
    root.buildError = ""
    root.buildRunning = true
    buildProcess.running = true
  }

  Process {
    id: helperCheck
    command: [
      "bash", "-c",
      "[ -x \"$1\" ] && [ -x \"$2\" ]",
      "myquickshell-check", root.systemStatsCPath, root.gpuCPath
    ]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.promptVisible = true
        if (exitCode > 1)
          console.warn("NativeBuildService: unable to check native collectors, exit code", exitCode)
      }
    }
  }

  Process {
    id: buildProcess
    command: [
      "bash", "-c",
      "{ cd \"$1\" && cc -o nob nob.c && ./nob build; } 2>&1",
      "myquickshell-build", root.shellDir
    ]
    stdout: StdioCollector {
      id: buildOutput
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.buildRunning = false
      if (exitCode === 0) {
        root.promptVisible = false
        root.buildError = ""
      } else {
        root.buildError = "Build failed (exit code " + exitCode
          + "). The shell will continue using its fallback collectors."
        console.warn("NativeBuildService:", root.buildError, buildOutput.text)
      }
    }
  }
}
