# Shared agent instructions for NexusDotShell

These instructions are self-contained and apply to every contributor and coding
agent working in this repository.

## Hyprland and live-session safety

- Prefer offline documentation and source inspection when investigating
  Hyprland's Lua API. Do not use deprecated dispatcher/config syntax from older
  Hyprland versions.
- Do not run state-changing live compositor actions, reloads, dispatches,
  runtime Lua evaluation, or tests that affect windows/focus without explicit
  user authorization.
- Avoid probing or enumerating C-backed objects against a live compositor;
  undocumented introspection can destabilize Hyprland. Use documented,
  read-only queries only when needed and when their syntax is known.
- A direct user request for a specific live query or probe authorizes only that
  scoped operation; do not extend it to unrelated probes.
- Preserve the bar's per-monitor fullscreen behavior: hide it for ordinary
  fullscreen windows. If a special workspace is visible over a fullscreen
  regular workspace on the same monitor, show the bar above the fullscreen
  content; hide it if a window on the special workspace is fullscreen.

## Theming and spacing

- Use `Common/Theme.qml` tokens for colors, typography, and design spacing.
  Do not introduce hard-coded colors or pixel gaps where a theme token applies.
- Use `Theme.cornerRadius` for rounded-rectangle surfaces,
  `Theme.hoverRadius` for compact hover highlights, and
  `Theme.pillRadius` for pill/circular icon targets. Avoid one-off numeric
  corner radii on interactive highlights.
- Use the same theme token for the same visual relationship throughout the
  shell. The standard gap between a bar and a popup, and between a popup and
  its directly nested popup, is `Theme.spaceXS` (4 px).
- Keep hover highlights and their hit areas inside the visible bounds of their
  owning pill or button. Do not use negative anchor margins to enlarge them;
  add internal padding within the control instead.
- Respect popup anchor coordinates: `anchor.rect` is relative to
  `anchor.window`. When a popup is anchored to another popup, calculate its
  position in that popup's local coordinates and include its height when
  placing it below.
- When matching gaps, compare visible edge-to-edge distance, including popup
  borders, margins, and implicit dimensions.
- Before changing spacing, inspect nearby widgets for the established token
  and anchoring pattern. Afterward, lint changed QML and review affected popup
  placements.

## Qt Quick Controls styling

Never ship an unstyled `ComboBox`, `Popup`, or other Qt Quick Control. Define
`contentItem`, `indicator`, `background`, `popup`, and `delegate`
explicitly where applicable, using `Common/Theme.qml` tokens only.

- In popup item delegates, keep label text color constant
  (`Theme.surfaceText`); convey selection/hover through the background pill.
- Popup `ListView` instances must set
  `highlightFollowsCurrentItem: false` when `currentIndex` is bound to the
  delegate highlight, to avoid unintended auto-scrolling.

## Project conventions

- Keep widgets declarative and put compositor/system integration and external
  process handling in `Services/`.
- Use `Common/Theme.qml` and the existing singleton architecture rather than
  introducing duplicate global state.
- Follow `.github/copilot-instructions.md` for architecture, build, validation,
  and QML conventions.
- Whenever a runtime/build dependency is added or changed, document in
  `README.md` whether it is required or optional, which feature uses it, and
  its fallback behavior.
- Preserve upstream attribution and the repository's GPL-3.0 license when
  modifying or redistributing derived code.

## Notes editor backend authority

- When the optional headless Neovim backend is available, it is the sole source
  of truth for Notes buffer text, active document, cursor/mode, selections,
  command-line state, and syntax highlights. `NotesService` data is a
  persistence mirror updated from accepted Neovim snapshots.
- Route editing keys and buffer-selection requests through the bridge. Only an
  explicit tab click or document lifecycle action may request a Neovim buffer
  selection.
- Do not overwrite an existing Neovim buffer with mirrored QML text when
  selecting it. Seed a buffer from persisted text only when creating/mapping a
  new document buffer. Save from a fresh backend snapshot.
- The Qt Quick text editor is an editable fallback only while Neovim is
  unavailable. While Neovim is active, render its snapshots read-only and do
  not maintain a second editable copy or text-rendering overlay.

## Validation

- Use `qmllint -I . <changed-files>` for focused QML validation.
- Run `./nob lint` for project-wide QML lint when the build driver is available.
- Run `bash -n <changed-scripts>` for shell-script syntax checks.
- Run `git diff --check` before committing.
