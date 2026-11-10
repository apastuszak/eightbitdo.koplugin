# Changelog

All notable changes to the 8BitDo remotes KOReader plugin are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

## [0.7.1] - 2026-11-10

### Changed

- The README and **Help** explain how to put each remote in HID keyboard mode
  before pairing: the Micro's bottom switch set to **K**, and the Zero 2
  turned on while holding the right bumper.
## [0.7.0] - 2026-11-10

### Added

- Licensed under the GNU Affero General Public License v3.0 (`LICENSE`).
- This changelog.

### Fixed

- Remotes now work with KOReader on Android, including Nook readers. Android
  delivers Android keycodes rather than Linux codes, so most buttons were not
  recognized and some did the wrong thing. **Button assignments** now shows
  the code the reader actually receives.
- Holding a button on Android no longer repeats it. Android sends a held key
  as repeated presses without a release; these are now ignored like Linux
  key repeats.

## [0.6.0] - 2026-11-09

### Changed

- Unchecking the last action in a button's action picker now returns the
  button to its native key assignment. Only choosing **Nothing** keeps a
  button that does nothing.
- Turning remote mappings off on a touch-only device now tells KOReader the
  keys were disconnected, so screens drop bindings the device can no longer
  reach. Turning mappings on again restores them.

### Fixed

- Button and key labels are now marked for translation where they are
  defined. Product names stay untranslated.

## [0.5.0] - 2026-11-08

### Removed

- The **Allow held-button repeat** option. Holding a button now acts once,
  including for custom actions.

### Changed

- Settings schema 2: the saved repeat preference is dropped on upgrade. All
  button assignments are kept.

## [0.4.0] - 2026-11-08

### Added

- Saved settings carry a schema number (schema 1). Settings from earlier
  builds are upgraded automatically.
- Settings written by a newer build are used but never saved over, and
  **Help** explains that changes will not be kept.

## [0.3.1] - 2026-11-08

### Fixed

- The file browser no longer rebuilds itself twice every time it opens. The
  plugin now announces a keyboard only when it changes whether KOReader
  reports keys or a D-pad.
- Action sequences no longer crash if a newer KOReader's cycle API cannot
  name the action to cycle, or if a saved sequence order is malformed.

## [0.3.0] - 2026-11-08

### Added

- One plugin for the 8BitDo Zero 2 and Micro in HID keyboard mode, with a
  manual **Remote** selector and separate button assignments per remote.
- KOReader's full **Gesture Manager → Tap corner** action picker under each
  button, including actions from other plugins, multiple actions, numeric
  parameters, sequences and QuickMenus. Basic keys live under **Native
  navigation keys**.
- An **Allow held-button repeat** option per remote, off by default.
- Import of assignments from the standalone Zero 2 and Micro plugins, leaving
  their settings untouched.
- The build number in **8BitDo remotes → Help**.

[0.7.1]: dist/eightbitdo-0.7.1.koplugin.zip
[0.7.0]: dist/eightbitdo-0.7.0.koplugin.zip
[0.6.0]: dist/eightbitdo-0.6.0.koplugin.zip
[0.5.0]: dist/eightbitdo-0.5.0.koplugin.zip
[0.4.0]: dist/eightbitdo-0.4.0.koplugin.zip
[0.3.1]: dist/eightbitdo-0.3.1.koplugin.zip
[0.3.0]: dist/eightbitdo-0.3.0.koplugin.zip
