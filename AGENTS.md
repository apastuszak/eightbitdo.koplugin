# Repository guide

## Purpose and compatibility

This repository provides one KOReader plugin for the 8BitDo Zero 2 and Micro
in HID keyboard mode. The user runs KOReader **2026.07.1**. Check upstream APIs
against that release before depending on newer behavior; do not assume `master`
matches the installed reader. The matching upstream tag is `v2026.07.1`; inspect
it with a shallow clone outside the repository, for example
`git clone --depth 1 --branch v2026.07.1 https://github.com/koreader/koreader.git`.
Code that uses newer APIs must feature-test them and keep a working fallback for
2026.07.1 (for example, `Dispatcher.getActionArgs` and the `cycle` sequence
option do not exist in that release).

The requested assignment list is the full action picker available under
**Gesture Manager → Tap corner**. Use KOReader's Dispatcher to populate it,
including actions registered by other enabled plugins. Show its action categories
directly under each button. Keep basic navigation choices in **Native navigation
keys**. Do not replace this with a fixed shortlist or impose a one-action limit.
Multiple actions, numeric parameters, sequences, and QuickMenus are intentional.
Remote presses provide no touch position or swipe distance; describe those
limitations honestly instead of inventing gesture coordinates.

## Layout

- `eightbitdo.koplugin/main.lua`: event translation, key bindings, Dispatcher
  integration, menus, settings persistence, and lifecycle handling.
- `eightbitdo.koplugin/config.lua`: button definitions, Linux key codes,
  defaults, settings normalization, and schema migration.
- `eightbitdo.koplugin/_meta.lua`: plugin metadata and version.
- `README.md`: installation, mappings, limitations, and development instructions.
- `eightbitdo.koplugin/README.md`: packaged copy of the root README; keep them
  identical.
- `tests/run.lua`: standalone LuaJIT regression suite with KOReader service stubs.
- `dist/`: installable archives containing a single `eightbitdo.koplugin/` folder.
- `LICENSE`: GNU AGPL-3.0, matching KOReader. Keep the text verbatim.
- `eightbitdo.koplugin/LICENSE`: packaged copy of `LICENSE`; keep them identical.
- `CHANGELOG.md`: user-facing release notes in Keep a Changelog format.
- `scripts/build.sh`: runs every check and builds `dist/` archives; with
  `--check` it only verifies (used by CI).
- `.github/workflows/test.yml`: GitHub Actions running `scripts/build.sh --check`
  on every push and pull request.
- `AGENTS.md`: these repository instructions. `CLAUDE.md` only points here;
  edit this file rather than duplicating guidance there.
- `2-pocketbook-bt-keys.lua`: separate PocketBook key patch. It is not part of
  the combined plugin package; do not bundle or modify it without a task reason.

## Implementation rules

- Keep both remotes in the combined plugin. Their overlapping key codes require
  manual profile selection; do not infer a controller from the key code alone.
- Preserve per-profile mappings and gesture actions. Held-button repeat was
  removed in 0.5.0 by request; do not reintroduce it without a task reason.
  Reset only the profile whose assignment menu was opened. Menu callbacks must
  keep targeting that profile even if the active remote subsequently changes.
- The plugin and its standalone predecessors were never publicly released
  before 1.0. Settings from the standalone plugins (`eightbitdo_zero2`,
  `eightbitdo_micro`) are deliberately not imported; do not add import code or
  user-facing upgrade instructions for them or for pre-1.0 builds.
- Keep settings under `eightbitdo_remotes`. Schema migrations for earlier
  builds of this plugin stay (see below).
- The stored settings shape is locked by `Config.SCHEMA` (documented in
  `config.lua`). Any change to that shape must bump `Config.SCHEMA` and add a
  `Config.migrations[n]` step for the new number; never renumber or delete
  existing steps. Settings with a newer schema are used read-only and must never
  be saved over. Update the shape assertions in `tests/run.lua` with the bump.
- `Config.buttons` stores Linux `EV_KEY` codes, not USB HID usage IDs. On
  Android (`Device:isAndroid()`, which includes Nook), koreader-base delivers
  Android KeyEvent keycodes in `EV_KEY` events, so match buttons through
  `Config.deviceCode`. Micro Star emits no key in the supplied profile; do not
  map it to key code zero.
- Android reports a held key as repeated presses (value 1) without releases,
  never value 2. Treat a press of a button that is still down as a repeat, and
  clear held-button state whenever releases may have been missed (mappings
  toggled, remote switched).
- Translate through private virtual codes without overwriting the original
  keyboard mappings. Preserve unrelated keys, touch events, and power events.
- Route custom actions through KOReader's normal key handling and Dispatcher.
  Never execute actions directly in the raw event-adjust hook: that would bypass
  normal input inhibition and UI dispatch.
- Preserve press/release handling and always drop autorepeat (`value == 2`)
  events for translated buttons. Keep one shared input hook across reader and
  file-manager instances, and tolerate External Keyboard replacing its event map
  or device capability functions.
- Broadcast `PhysicalKeyboardConnected` only when the plugin actually changes
  the effective `Device:hasKeys()` or `Device:hasDPad()` result. In 2026.07.1,
  FileManager answers that event with a full `reinit` (settings flush and file
  list rebuild), so an unconditional broadcast redraws it on every opening. The
  test stubs cannot show that side effect; the suite counts broadcasts instead.
  Send `PhysicalKeyboardDisconnected` when the plugin removes keys (mappings
  turned off on a touch-only device) and keep overriding InputContainer's
  disconnect handler so the plugin's private bindings are not cleared.
- In the button picker, unchecking the last action returns the button to its
  native key; only Dispatcher's explicit **Nothing** keeps an empty assignment.
- Mark user-facing labels in `config.lua` with `_()` where they are defined;
  do not translate product names or wrap those labels again in `main.lua`.
- Bluetooth pairing and operating-system input delivery are outside the plugin.
- Use LuaJIT-compatible Lua, four-space indentation, and the existing gettext
  pattern for user-facing strings. Avoid adding dependencies for routine changes.

## Validation

For behavior changes, run both profiles from the repository root:

```sh
luajit tests/run.lua
luajit tests/run.lua micro
```

`scripts/build.sh --check` runs these plus the syntax, version, README and
archive checks below without writing anything; CI runs the same command.

Extend the regression suite when changing input routing, migration, persistence,
profile switching, or Dispatcher integration. The suite uses stubs: passing it
does not prove real-device Bluetooth delivery, UI rendering, or action execution.
Distinguish source/API inspection, automated tests, and hardware verification in
reports. Documentation-only edits do not require rerunning the suite.

Check Lua syntax when changing plugin sources, writing bytecode outside the repo:

```sh
luajit -b eightbitdo.koplugin/main.lua /tmp/eightbitdo-main.luac
luajit -b eightbitdo.koplugin/config.lua /tmp/eightbitdo-config.luac
luajit -b eightbitdo.koplugin/_meta.lua /tmp/eightbitdo-meta.luac
```

## Packaging and upgrades

After changes to packaged files, rebuild `dist/eightbitdo.koplugin.zip` from the
plugin folder. When producing a new release, also provide a versioned archive
using `eightbitdo-VERSION.koplugin.zip`. Keep the version consistent in
`main.lua`'s `VERSION` constant (shown in Help), `_meta.lua`, both READMEs, and
the Help assertion in `tests/run.lua`. Do not silently change an older versioned
release archive: a packaged-code change after a release needs a version bump and
a new versioned archive. Record user-visible changes under **Unreleased** in
`CHANGELOG.md` as they land, and move them under the new version and date when
releasing.

Build with `scripts/build.sh` from the repository root. It checks that the
version agrees across `_meta.lua`, `main.lua`, both READMEs, `tests/run.lua` and
a `CHANGELOG.md` section, runs the syntax checks and tests, then creates
`dist/eightbitdo-VERSION.koplugin.zip` if missing and refreshes
`dist/eightbitdo.koplugin.zip`. It leaves matching archives untouched and refuses
to rewrite an existing versioned archive that no longer matches the source:
bump the version instead. Do not bypass it with manual `zip` commands.

Verify archive integrity and that archived bytes match the current source.
Exclude tests, local bytecode, reference patches, and repository instructions.
The installation path must be `koreader/plugins/eightbitdo.koplugin/main.lua`,
without an extra nested plugin folder.

### KOReader App Store

The [App Store plugin](https://github.com/omer-faruq/appstore.koplugin) finds
this repository through the `koreader-plugin` GitHub topic (or a repository
name containing `.koplugin`); the repository must be public. Keep these
properties, which it relies on:

- The plugin stays in a `*.koplugin/` folder with `_meta.lua`, so the repository
  ZIP is detected via `*.koplugin/_meta.lua`. Only that folder is installed.
- `_meta.lua` keeps `version = "X.Y.Z"` as a plain string literal: update checks
  read it from the default branch with a pattern match, so push the version
  bump before publishing the release.
- Release tags are `vX.Y.Z`, published as non-prerelease. Tags containing
  `pre`, `rc`, `dev`, `test`, `alpha`, `beta` or `preview` are skipped.
- Attach `dist/eightbitdo.koplugin.zip` to each release under exactly that name:
  the asset name `*.koplugin.zip` becomes the installed folder name.

When the device still shows old menus, first check the build number under
**8BitDo remotes → Help**, installation nesting, and whether KOReader was fully
exited before overwriting the plugin. Do not assume the current archive is loaded.
Upgrades must preserve settings. If the old standalone Zero 2 or Micro
plugins are present on a test device, disable or remove them and restart
KOReader: their input hooks compete with this plugin.
