# 8BitDo remotes for KOReader

One plugin for the **8BitDo Zero 2** and **8BitDo Micro** in HID keyboard mode. Choose the remote in the menu; its button assignments are saved separately and restored when switching back.

## Install

Current plugin build: **0.7.3**, shown in **8BitDo remotes → Help**. The versioned archive is `dist/eightbitdo-0.7.3.koplugin.zip`.

1. Exit KOReader.
2. Extract **`dist/eightbitdo.koplugin.zip`** into `koreader/plugins/`, or copy the `eightbitdo.koplugin` folder there. The resulting path must be `koreader/plugins/eightbitdo.koplugin/main.lua`.
3. Restart KOReader. If necessary, enable **8BitDo remotes** in Plugin management and restart again.
4. Pair your remote with your reader in HID keyboard mode, using the reader's Bluetooth settings. Both remotes must be in keyboard mode; in any other mode they send game-controller buttons that the plugin cannot use.
   - **8BitDo Micro:** set the small switch on the bottom of the remote to **K**, then turn it on.
   - **8BitDo Zero 2:** hold the right bumper (**R**) while turning the remote on.
5. Open **8BitDo remotes → Remote** and select **8BitDo Zero 2** or **8BitDo Micro**. Open **Button assignments** to customize its buttons.

Only the selected profile translates input. Switching applies immediately without restarting or erasing settings. Release held buttons before switching. Both remotes use overlapping codes, so selecting the remote is manual; the plugin cannot identify the controller from the code alone.

## Settings

The menu provides a global **Enable remote mappings** toggle, a **Remote** selector, and per-remote button assignments. Resetting assignments resets only the profile whose assignments menu you opened, preserving the other profile. New installations start enabled with Zero 2 selected.

Settings are saved under `eightbitdo_remotes` with a format version, so future releases can update them automatically. If you install an older release after a newer one has saved its settings, the older release uses what it understands but does not save over them; **Help** shows a notice, and changes made in the older release are not kept.

## Platforms and key codes

Tested on a PocketBook Era Lite with the Zero 2. On Linux-based readers (PocketBook, Kobo, Kindle and similar), KOReader receives Linux `EV_KEY` codes. On Android, including Nook readers, KOReader receives Android keycodes instead, which use different numbers for the same letters; the plugin detects Android and uses the Android column below. **Button assignments** shows the code your reader actually receives. Android sends a held button as repeated presses, and the plugin ignores those just as it ignores Linux key repeats.

## Zero 2 defaults

| Button | Linux EV_KEY code | Android keycode | KOReader key | Default behavior |
| --- | ---: | ---: | --- | --- |
| D-pad up | 46 | 31 | Up | Navigate up |
| D-pad down | 32 | 32 | Down | Navigate down |
| D-pad left | 18 | 33 | Left | Navigate left |
| D-pad right | 33 | 34 | Right | Navigate right |
| Left bumper | 37 | 39 | LPgBack | Previous page |
| Right bumper | 50 | 41 | LPgFwd | Next page |
| Y | 23 | 37 | LPgBack | Previous page |
| A | 34 | 35 | Press | Select |
| X | 35 | 36 | Menu | Open menu |
| B | 36 | 38 | Back | Back/close |

## Micro defaults

The screenshot's keyboard letters are translated into Linux `EV_KEY` codes, checked against `linux/input-event-codes.h`. These are Linux codes, not numeric USB HID usage IDs.

| Micro button | Screenshot key | Linux code | Android keycode | Default assignment |
| --- | --- | ---: | ---: | --- |
| D-pad up | C | 46 | 31 | Up |
| D-pad down | D | 32 | 32 | Down |
| D-pad left | E | 18 | 33 | Left |
| D-pad right | F | 33 | 34 | Right |
| L | K | 37 | 39 | Previous page |
| L2 | L | 38 | 40 | Previous page |
| R | M | 50 | 41 | Next page |
| R2 | R | 19 | 46 | Next page |
| Minus (−) | N | 49 | 42 | Back |
| Plus (+) | O | 24 | 43 | Menu |
| X | H | 35 | 36 | Menu |
| A | G | 34 | 35 | Select |
| Y | I | 23 | 37 | Previous page |
| B | J | 36 | 38 | Back |
| Capture (checkerboard) | S | 31 | 47 | Ignore button |
| Star | Null | — | — | No keyboard event to map |

Micro's Star button has no keyboard event in the supplied profile and is omitted from the menu. Capture defaults to Ignore button and can be reassigned. If you customized Micro's keyboard profile, restore the listed letters before using this mapping.

## Available assignments

Every emitting button can be assigned **Next page**, **Previous page**, **Up**, **Down**, **Left**, **Right**, **Select**, **Back**, **Menu**, or **Ignore button**. Native KOReader keys determine behavior on the active screen or dialog. Directions follow KOReader's normal rotation handling; bumpers provide dedicated page turns.

For the full action list offered under **Gesture Manager → Tap corner**, open **8BitDo remotes → Button assignments → [button]**. The action categories appear directly in the button menu: **General**, **Device**, **Screen and lights**, **File browser**, **Reader**, and document-specific categories. Basic keys are grouped under **Native navigation keys**. This uses KOReader's own Dispatcher picker, including actions registered by other enabled plugins. The complete action picker is available, including multiple actions, numeric parameters, action sequences and QuickMenus. There is no one-action restriction. Numeric settings such as brightness and font-size changes use the same parameter controls as gestures.

Selecting an action in this picker replaces that button's native key assignment. Merely opening the picker changes nothing. Choose **Nothing** inside the picker to consume the button without an action. Unchecking the last selected action instead returns the button to its native key assignment. Selecting any native assignment again clears the gesture actions. Existing assignments, including sequences and QuickMenus, survive upgrades and edits. Resetting a remote clears its gesture actions as well as resetting its native assignments.

Action availability follows your KOReader version, device capabilities, enabled plugins, and current document or file-browser context. A button supplies no touch position or swipe distance, so touch-location actions cannot reproduce a tap at a particular screen coordinate. Use explicit numeric amounts for incremental actions. Gesture-specific controls such as “Always active” govern touch recognition and do not apply to remote buttons.


Holding a button does not repeat it: each press acts once, including custom actions. Assignments and preferences are saved automatically with KOReader's global settings.

## Requirements and troubleshooting

Your operating system and KOReader's input integration must already deliver the remote's key events (Linux `EV_KEY` codes, or Android keycodes on Android). This plugin maps those events; it does not pair Bluetooth devices, enable Bluetooth, install drivers, or open `/dev/input/event*` devices. Android key codes and gamepad axis events are different formats.

Mappings are global and also affect physical keyboards sending the same codes. Disable **Enable remote mappings** when typing on a physical keyboard. Unrelated codes, touch input, and power buttons pass through unchanged.

If nothing works, verify keyboard mode, Bluetooth connection, and input delivery to KOReader. If up/down or X/B are reversed, check the selected remote. If the plugin menu is missing, check folder nesting, Plugin management, and KOReader's `crash.log`. **Help** shows the installed build, for example **v0.7.3**. Do not extract into another `eightbitdo.koplugin` folder.

To uninstall, exit KOReader, remove `plugins/eightbitdo.koplugin`, then restart. The saved settings are harmless; optionally remove `eightbitdo_remotes` from `settings.reader.lua` while KOReader is closed.

## Development and validation

Run both profiles through the regression suite:

```sh
luajit tests/run.lua
luajit tests/run.lua micro
```

Tests stub KOReader services and exercise mappings, press/release, repeat suppression, menus, settings persistence, profile switching, migration, event-map replacement, reader/file-manager lifecycle, the full tap-corner action picker, multiple action selections, custom action routing, returning to the native key when the last action is unchecked, keyboard connect/disconnect signals, translatable labels, numeric arguments, QuickMenus, action sequences, and reset. Actual Bluetooth delivery and reader/menu behavior still require hardware testing.

Check everything and build the installation archives in `dist/`:

```sh
scripts/build.sh          # checks, then builds
scripts/build.sh --check  # checks only; CI runs this on every push
```

The implementation follows KOReader's [input hook and key translation API](https://github.com/koreader/koreader/blob/v2026.07.1/frontend/device/input.lua) and [External Keyboard connection notifications](https://github.com/koreader/koreader/blob/v2026.07.1/plugins/externalkeyboard.koplugin/main.lua).

Gesture assignments follow KOReader's [Dispatcher action picker and execution API](https://github.com/koreader/koreader/blob/master/frontend/dispatcher.lua), with key bindings handled through [InputContainer](https://github.com/koreader/koreader/blob/master/frontend/ui/widget/container/inputcontainer.lua).
