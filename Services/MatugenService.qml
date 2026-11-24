pragma Singleton

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/Settings/SettingsSpec.js" as Spec

// Runs the matugen CLI to generate the Material-3 colors JSON used by
// Theme.qml. Like DMS, colors are generated from a source color via
// `matugen color hex` (the simplest faithful path that reproduces the current
// DMS palette). Watches settings.json for matugenSourceColor / scheme / mode
// changes and re-runs on demand, debounced while a run is in flight.
Singleton {
  id: root

  readonly property string shellDir: Quickshell.shellDir
  readonly property string templatePath: localPath(shellDir) + "/assets/matugen/dank.json"
  readonly property string cacheDir: localPath(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation)) + "/MyQuickshell"
  readonly property string colorsPath: cacheDir + "/mql-colors.json"
  readonly property string configPath: cacheDir + "/matugen.toml"
  readonly property string settingsPath: localPath(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/myquickshell/settings.json"

  property bool _running: false
  property bool _pending: false
  property string _lastGeneratedSignature: ""
  property string _wallpaperImage: ""
  property string _wallpaperColor: ""

  function localPath(u) {
    return String(u).replace(/^file:\/\//, "")
  }

  // Merge settings.json with SPEC defaults so a fresh install (no settings.json
  // yet) still generates colors.
  function _params() {
    const spec = Spec.SPEC
    let obj = {}
    try {
      const txt = settingsFile.text()
      if (txt && txt.trim()) obj = JSON.parse(txt)
    } catch (e) { }
    return {
      sourceColor: root._wallpaperColor || obj.matugenSourceColor || spec.matugenSourceColor.def,
      sourceImage: root._wallpaperImage,
      scheme: obj.matugenScheme || spec.matugenScheme.def,
      mode: obj.matugenMode || spec.matugenMode.def
    }
  }

  function setWallpaperSource(source, type) {
    const value = String(source || "")
    let image = ""
    let color = ""
    if (type === "image" && value && !value.startsWith("http://") && !value.startsWith("https://")) {
      image = value.replace(/^file:\/\//, "")
    } else if (type === "color" && /^#?[0-9a-fA-F]{6}$/.test(value)) {
      color = value.replace(/^#/, "")
    }
    if (image === root._wallpaperImage && color === root._wallpaperColor)
      return
    root._wallpaperImage = image
    root._wallpaperColor = color
    root._lastGeneratedSignature = ""
    root.reschedule()
  }

  // Public entry point used by Theme/Settings to (re)generate colors. Sets up
  // the config file, then chains matugen through a single bash invocation so
  // there is no race between writing the TOML and matugen reading it.
  function reschedule() {
    const p = root._params()
    if (!p.sourceColor) return

    // settings.json also changes for unrelated state (for example media
    // playback position). Regenerate the palette only when Matugen inputs
    // actually change.
    const signature = JSON.stringify([p.sourceImage, p.sourceColor, p.scheme, p.mode])
    if (signature === root._lastGeneratedSignature) {
      root._pending = false
      return
    }
    if (root._running) {
      root._pending = true
      return
    }

    root._lastGeneratedSignature = signature
    root._running = true
    const toml =
      "[config]\n\n"
      + "[templates.dank]\n"
      + "input_path = \"" + root.templatePath + "\"\n"
      + "output_path = \"" + root.colorsPath + "\"\n\n"
      + "[templates.alacritty]\n"
      + "input_path = \"" + root.localPath(root.shellDir) + "/assets/matugen/alacritty.toml\"\n"
      + "output_path = \"~/.config/alacritty/themes/nexusdot-matugen.toml\"\n\n"
      + "[templates.hyprland]\n"
      + "input_path = \"" + root.localPath(root.shellDir) + "/assets/matugen/hyprland.conf\"\n"
      + "output_path = \"~/.config/hypr/nexusdot-matugen.conf\"\n"
      + "post_hook = \"hyprctl reload\"\n\n"
      + "[templates.gtk]\n"
      + "input_path = \"" + root.localPath(root.shellDir) + "/assets/matugen/gtk.css\"\n"
      + "output_path = \"~/.config/gtk-3.0/nexusdot-matugen.css\"\n\n"
      + "[templates.gtk4]\n"
      + "input_path = \"" + root.localPath(root.shellDir) + "/assets/matugen/gtk.css\"\n"
      + "output_path = \"~/.config/gtk-4.0/nexusdot-matugen.css\"\n"
    const script =
      "mkdir -p '" + root.cacheDir + "' \"$HOME/.config/alacritty/themes\" \"$HOME/.config/hypr\" \"$HOME/.config/gtk-3.0\" \"$HOME/.config/gtk-4.0\"\n"
      + "cat > '" + root.configPath + "' <<'DMS_MATGEN_EOF'\n"
      + toml
      + "DMS_MATGEN_EOF\n"
      + (p.sourceImage
        ? "matugen image '" + p.sourceImage.replace(/'/g, "'\\''") + "'"
        : "matugen color hex " + p.sourceColor)
      + " --config '" + root.configPath + "' --type " + p.scheme + " --mode " + p.mode
    matugenProc.command = ["bash", "-c", script]
    matugenProc.running = true
  }

  Process {
    id: matugenProc
    stdout: SplitParser {}
    onRunningChanged: {
      if (!matugenProc.running) {
        root._running = false
        if (root._pending) {
          root._pending = false
          root.reschedule()
        }
      }
    }
    onExited: function(status, exitStatus) {
      if (status !== 0)
        console.error("matugen failed with status " + status)
    }
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    onLoaded: root.reschedule()
  }

  // Startup: a Timer is the reliable trigger for singleton services (the same
  // pattern WorkspacesService uses); Component.onCompleted is unreliable with
  // pragma Singleton.
  Timer {
    interval: 300
    running: true
    triggeredOnStart: true
    repeat: false
    onTriggered: root.reschedule()
  }
}
