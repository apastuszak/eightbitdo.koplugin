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
  defaults, settings normalization, and legacy migration.
- `eightbitdo.koplugin/_meta.lua`: plugin metadata and version.
- `README.md`: installation, mappings, limitations, and development instructions.
- `eightbitdo.koplugin/README.md`: packaged copy of the root README; keep them
  identical.
- `tests/run.lua`: standalone LuaJIT regression suite with KOReader service stubs.
- `dist/`: installable archives containing a single `eightbitdo.koplugin/` folder.
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
- Keep settings under `eightbitdo_remotes`. Preserve migration from
  `eightbitdo_zero2` and `eightbitdo_micro`, without modifying or aliasing the
  legacy settings. Existing combined settings take precedence.
- The stored settings shape is locked by `Config.SCHEMA` (documented in
  `config.lua`). Any change to that shape must bump `Config.SCHEMA` and add a
  `Config.migrations[n]` step for the new number; never renumber or delete
  existing steps. Settings with a newer schema are used read-only and must never
  be saved over. Update the shape assertions in `tests/run.lua` with the bump.
- Interpret codes as Linux `EV_KEY` codes, not USB HID usage IDs. Micro Star
  emits no key in the supplied profile; do not map it to key code zero.
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
a new versioned archive.

From the repository root:

```sh
rm -f dist/eightbitdo.koplugin.zip
zip -qX -r dist/eightbitdo.koplugin.zip eightbitdo.koplugin -x '*.luac' -x '*/.*'
cp dist/eightbitdo.koplugin.zip dist/eightbitdo-VERSION.koplugin.zip
```

Verify archive integrity and that archived bytes match the current source.
Exclude tests, local bytecode, reference patches, and repository instructions.
The installation path must be `koreader/plugins/eightbitdo.koplugin/main.lua`,
without an extra nested plugin folder.

When the device still shows old menus, first check the build number under
**8BitDo remotes → Help**, installation nesting, and whether KOReader was fully
exited before overwriting the plugin. Do not assume the current archive is loaded.
Upgrades must preserve settings. The standalone Zero 2 and Micro plugins must
be disabled or removed and KOReader restarted to avoid competing hooks.
