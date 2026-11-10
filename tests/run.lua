-- No KOReader checkout or third-party test runner required.
local profile = arg[1] or "zero2"
assert(profile == "zero2" or profile == "micro", "Usage: luajit tests/run.lua [zero2|micro]")
local directory = "eightbitdo.koplugin/"
local setting = "eightbitdo_remotes"
-- Both remotes send C for D-pad up and J for B.
local up_code = 46
local back_code = 36
local original_letter = "C"
local translated = {}
package.loaded.gettext = function(text) translated[text] = true; return text end
local Config = dofile(directory .. "config.lua")
local broadcasts, hooks, queue, saved, executions = {}, {}, {}, {}, {}
local saves = 0
local function no() return false end
local Device = { hasKeys = no, hasDPad = no, input = { event_map = { [up_code] = original_letter, [116] = "Power" } } }
function Device.input:registerEventAdjustHook(hook) hooks[#hooks + 1] = hook end
local UIManager = {}
function UIManager:nextTick(callback) queue[#queue + 1] = callback end
function UIManager:broadcastEvent(event) broadcasts[#broadcasts + 1] = event end
function UIManager:show(widget) self.last_widget = widget end
local Widget = {}
function Widget:extend(definition)
    definition.__index = definition
    function definition:new(values)
        local instance = setmetatable(values, self)
        instance:init()
        return instance
    end
    return definition
end
package.loaded.device = Device
package.loaded["ui/uimanager"] = UIManager
package.loaded["ui/widget/container/inputcontainer"] = Widget
local Dispatcher = {}
function Dispatcher:init() end
function Dispatcher:menuTextFunc(actions)
    return actions.night_mode and "Toggle night mode" or "Custom actions"
end
function Dispatcher:addSubMenu(caller, menu, location, button)
    local start = #menu
    menu[start + 1] = { text = "General", callback = function()
        location[button] = location[button] or {}
        location[button].night_mode = true
        caller.updated = true
    end }
    menu[start + 2] = { text = "Nothing", callback = function()
        location[button] = {}
        caller.updated = true
    end }
    menu[start + 3] = { callback = function()
        location[button] = location[button] or {}
        location[button].increase_frontlight = 10
        caller.updated = true
    end }
    menu.max_per_page = start + 3
    menu[start + 4] = { text = "Show as QuickMenu" }
    menu[start + 5] = { text = "Execute one by one" }
    menu[start + 6] = { text = "Toggle night mode", callback = function()
        if location[button] and location[button].night_mode then
            location[button].night_mode = nil
        else
            location[button] = location[button] or {}
            location[button].night_mode = true
        end
        caller.updated = true
    end }
end
function Dispatcher:execute(actions, properties)
    executions[#executions + 1] = { actions = actions, properties = properties }
end
function Dispatcher.getActionArgs() return { 10, 20 }, "set_font" end
package.loaded.dispatcher = Dispatcher
package.loaded["ui/event"] = { new = function(_, name) return { name = name } end }
package.loaded["ui/widget/infomessage"] = { new = function(_, values) return values end }
G_reader_settings = {
    readSetting = function(_, key) return saved[key] end,
    saveSetting = function(_, key, value) saved[key] = value; saves = saves + 1 end,
}
local function equal(actual, expected, message)
    assert(actual == expected, (message or "Values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function drain()
    local pending = queue
    queue = {}
    for _, callback in ipairs(pending) do callback() end
end
-- event(code) is a tap: the press is reported, then a release follows.
-- Pass an explicit value (1 press, 0 release, 2 repeat) for a single event.
local function event(code, value, event_type)
    local ev = { type = event_type or 1, code = code, value = value or 1 }
    for _, hook in ipairs(hooks) do hook(Device.input, ev) end
    local key = Device.input.event_map[ev.code]
    if value == nil and ev.type == 1 then
        local release = { type = 1, code = code, value = 0 }
        for _, hook in ipairs(hooks) do hook(Device.input, release) end
    end
    return ev, key
end
local Zero2 = dofile(directory .. "main.lua")
local registered = 0
local ui = { menu = { registerToMainMenu = function() registered = registered + 1 end } }
local plugin = Zero2:new{ ui = ui }
plugin:selectRemote(profile)
Zero2:new{ ui = ui }
equal(#hooks, 1, "Reader/file manager share one hook")
equal(registered, 2)
drain()
equal(Device:hasKeys(), true)
equal(Device:hasDPad(), true)
equal(broadcasts[1].name, "PhysicalKeyboardConnected")
equal(#broadcasts, 1, "Later instances see the wrapped capabilities; no refresh")
-- KOReader's FileManager reinitializes on this broadcast, so reopening the
-- reader or file manager must not repeat it while capabilities are unchanged.
Zero2:new{ ui = ui }
drain()
equal(#broadcasts, 1, "Reopening does not rebuild the file manager")

local expected = { [46] = "Up", [32] = "Down", [18] = "Left", [33] = "Right",
    [37] = "LPgBack", [50] = "LPgFwd", [23] = "LPgBack", [34] = "Press", [35] = "Menu", [36] = "Back" }
if profile == "micro" then
    expected[38], expected[19] = "LPgBack", "LPgFwd"
    expected[49], expected[24] = "Back", "Menu"
end
for code, key in pairs(expected) do
    for _, value in ipairs({ 1, 0 }) do
        local ev, actual = event(code, value)
        equal(actual, key, "Mapping for " .. code)
        equal(ev.value, value, "Preserve press/release")
    end
    local _, actual = event(code, 2)
    equal(actual, nil, "Held buttons never repeat")
end
equal(Device.input.event_map[up_code], original_letter, "Original keyboard mapping intact")
equal(event(116).code, 116, "Power key untouched")
equal(event(up_code, 1, 3).code, up_code, "Absolute events untouched")
equal(event(999).code, 999, "Unknown keys untouched")

local menu = {}
plugin:addToMainMenu(menu)
local items = menu.eightbitdo.sub_item_table
equal(#items, 4, "Menu: enable, remote, assignments, help")
for _, item in ipairs(items) do
    assert(not (item.text or ""):find("repeat", 1, true), "No repeat setting in the menu")
end
items[4].callback()
assert(UIManager.last_widget.text:find("v0.7.3", 1, true), "Help identifies installed build")
assert(not UIManager.last_widget.text:find("repeat", 1, true), "Help does not mention repeat")
assert(not UIManager.last_widget.text:find("standalone", 1, true), "Help has no upgrade instructions")
assert(UIManager.last_widget.text:find("switch on the bottom to K", 1, true), "Help explains Micro keyboard mode")
assert(UIManager.last_widget.text:find("hold the right bumper (R) while turning it on", 1, true), "Help explains Zero 2 keyboard mode")
local assignments = items[3].sub_item_table_func()
local actions = assignments[1].sub_item_table_func()[1].sub_item_table_func() -- Native D-pad up choices.
actions[1].callback() -- Reassign to next page.
equal(select(2, event(up_code)), "LPgFwd")
equal(saved[setting].profiles[profile].mappings.up, "LPgFwd", "Save assignment immediately")
assert(assignments[1].text_func():find("Next page", 1, true))
actions[#Config.actions].callback() -- Ignore button, including releases and repeats.
for _, value in ipairs({ 0, 1, 2 }) do equal(select(2, event(up_code, value)), nil) end
event(up_code, 0) -- Release the held button.
assignments[#assignments].callback() -- Reset.
equal(select(2, event(up_code)), "Up")

-- Simulate External Keyboard replacing its event map and capabilities.
Device.input.event_map = { [up_code] = original_letter }
Device.hasKeys = no
Device.hasDPad = no
plugin:onPhysicalKeyboardDisconnected()
equal(Device:hasKeys(), true)
equal(select(2, event(up_code)), "Up", "Mapping survives a replacement event map")
items[1].callback() -- Disable.
equal(Device:hasKeys(), false, "Original capability restored logically")
equal(Device:hasDPad(), false)
equal(event(up_code).code, up_code, "Disabled mapping passes through")
equal(select(2, event(up_code)), original_letter)
items[1].callback()
equal(select(2, event(up_code)), "Up")
local refreshes = #broadcasts
drain()
equal(#broadcasts, refreshes + 2, "Enabling and disabling refresh changed capabilities")
equal(broadcasts[refreshes + 1].name, "PhysicalKeyboardDisconnected", "Disabling withdraws the keys")
equal(broadcasts[refreshes + 2].name, "PhysicalKeyboardConnected", "Enabling announces the keys")
items[1].callback() -- Disable again to check the plugin's own bindings survive.
plugin:onPhysicalKeyboardDisconnected()
assert(next(plugin.key_events), "Private bindings survive a disconnect while disabled")
items[1].callback()
drain()

-- Saved preferences survive a fresh plugin module load (process restart).
saved[setting].profiles[profile].mappings.b = "LPgFwd"
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
equal(select(2, event(back_code)), "LPgFwd")
drain()

-- A device that already reports keys and a D-pad needs no refresh at all.
local function yes() return true end
local refresh_count = #broadcasts
hooks = {}
Device.hasKeys, Device.hasDPad = yes, yes
local KeyDevice = dofile(directory .. "main.lua")
local key_device_plugin = KeyDevice:new{ ui = ui }
drain()
equal(#broadcasts, refresh_count, "Unchanged native capabilities skip the refresh")
key_device_plugin:setEnabled(false)
drain()
equal(#broadcasts, refresh_count, "Toggling cannot change a keyed device's capabilities")
key_device_plugin:setEnabled(true)
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
drain()
equal(#broadcasts, refresh_count + 1, "Restart on a touch-only device refreshes once")
for _, malformed in ipairs({ false, "bad", 42, { mappings = "bad" }, { mappings = { up = "Power" } } }) do
    equal(Config.normalizeProfile(malformed, profile).mappings.up, "Up", "Invalid settings fall back safely")
end
equal(Config.normalize({ enabled = false }).enabled, false)
if profile == "micro" then
    equal(#Config.buttons.micro, 15, "All emitting buttons included")
    local ev, key = event(31)
    equal(key, nil, "Capture ignored by default")
    local micro_menu = {}
    plugin:addToMainMenu(micro_menu)
    local capture = micro_menu.eightbitdo.sub_item_table[3].sub_item_table_func()[15].sub_item_table_func()[1].sub_item_table_func()
    capture[1].callback()
    equal(select(2, event(31)), "LPgFwd", "Capture can be assigned")
    equal(event(0).code, 0, "Star Null is not mapped to KEY_RESERVED")


end
-- Switching has immediate effect and preserves each profile's assignments.
local before = saved[setting].profiles[profile].mappings.b
local other = profile == "micro" and "zero2" or "micro"
local selector = plugin:getRemoteMenu()
selector[other == "micro" and 2 or 1].callback()
equal(select(2, event(46)), "Up", "Other remote's D-pad up")
equal(before, "LPgFwd", "This remote's B was reassigned earlier")
equal(select(2, event(36)), "Back", "Other remote uses its own B assignment")
equal(event(38).code == 38, other ~= "micro", "Micro-only keys pass through on Zero 2")
local other_menu = plugin:getAssignmentsMenu()
other_menu[1].sub_item_table_func()[1].sub_item_table_func()[1].callback()
equal(select(2, event(46)), "LPgFwd")
plugin:selectRemote(profile)
equal(select(2, event(36)), before, "Own B assignment restored")
equal(select(2, event(46)), saved[setting].profiles[profile].mappings.up, "Own D-pad up restored")
equal(saved[setting].profiles[profile].mappings.b, before)
-- A menu opened for the other profile continues to edit that profile.
other_menu[#other_menu].callback()
equal(saved[setting].profiles[profile].mappings.b, before)
plugin:selectRemote("invalid")
equal(saved[setting].remote, profile)
local wrapper = Device.hasKeys
for count = 1, 20 do plugin:onPhysicalKeyboardConnected() end
equal(Device.hasKeys, wrapper, "Connection notifications don't stack wrappers")
plugin:setEnabled(false)
equal(event(32).code, 32)
equal(event(46).code, 46)
equal(event(38).code, 38)
equal(Device:hasKeys(), false)

-- No saved settings gives the defaults; saved settings are loaded as saved.
local defaults = Config.load(nil)
equal(defaults.enabled, true)
equal(defaults.remote, "zero2")
equal(defaults.profiles.zero2.mappings.up, "Up")
local existing = Config.load({ enabled = false, remote = "micro", profiles = { micro = { mappings = { b = "Press" } } } })
equal(existing.enabled, false)
equal(existing.remote, "micro")
equal(existing.profiles.micro.mappings.b, "Press")
for _, malformed in ipairs({ false, "bad", 42, { profiles = "bad", remote = "unknown" } }) do
    local normalized = Config.normalize(malformed)
    equal(normalized.remote, "zero2")
    equal(normalized.profiles.micro.mappings.up, "Up")
end
print(profile .. " PASS: mapping, menus, persistence, no repeat, switching, lifecycle, migration")

-- Gesture actions travel as private keys through KOReader's normal input
-- pipeline, so the raw hook cannot run actions during suspend/input inhibition.
plugin:setEnabled(true)
plugin:selectRemote(profile)
local button_menu = plugin:getButtonMenu(profile, Config.buttons[profile][1])
local gesture_menu = button_menu
local native_menu = button_menu[1].sub_item_table_func()
equal(button_menu[1].text, "Native navigation keys")
equal(button_menu[2].text, "General", "Gesture categories visible directly under button")
equal(#gesture_menu, 7, "Full tap-corner picker retained, including execution and QuickMenu controls")
equal(gesture_menu.max_per_page, 4, "Dispatcher pagination retained")
equal(saved[setting].profiles[profile].actions.up, nil, "Opening picker keeps native assignment")
local save_count = saves
gesture_menu[2].callback()
assert(saves > save_count, "Dispatcher edits save immediately")
local assigned = saved[setting].profiles[profile].actions.up
local key = select(2, event(up_code))
equal(key, "EightBitDo_" .. profile .. "_up")
equal(#executions, 0, "Raw hook never executes actions")
local binding = plugin.key_events[key]
equal(binding[1][1], key, "InputContainer binding matches private key")
equal(binding.event, "EightBitDoAction")
plugin["on" .. binding.event](plugin, binding.args)
equal(#executions, 1)
equal(executions[1].actions, assigned, "Pass selected action to Dispatcher")
equal(assigned.increase_frontlight, nil, "Only selected action configured initially")
assert(plugin:getAssignmentsMenu()[1].text_func():find("Toggle night mode", 1, true))
equal(native_menu[1].checked_func(), false, "Custom assignment deselects native action")
equal(not button_menu[1].checked_func(), true)
local count = #executions
event(up_code, 0)
equal(#executions, count, "Release never executes an action")
equal(select(2, event(up_code, 2)), nil, "Custom action never repeats")
equal(#executions, count, "Held custom button runs its action once")
plugin:setEnabled(false)
plugin:onEightBitDoAction(binding.args)
equal(#executions, count, "Disabled plugin refuses stale event")
plugin:setEnabled(true)
plugin:selectRemote(other)
plugin:onEightBitDoAction(binding.args)
equal(#executions, count, "Inactive profile refuses stale event")
plugin:selectRemote(profile)
local normalized = Config.normalize(saved[setting])
equal(normalized.profiles[profile].actions.up.night_mode, true)
normalized.profiles[profile].actions.up.night_mode = false
equal(assigned.night_mode, true, "Action settings copied without aliasing")

gesture_menu[4].callback()
equal(saved[setting].profiles[profile].actions.up.increase_frontlight, 10, "Numeric argument retained")
equal(saved[setting].profiles[profile].actions.up.night_mode, true, "Additional action retained, like Tap corner")
gesture_menu[2].callback()
equal(saved[setting].profiles[profile].actions.up.increase_frontlight, 10, "Editing one action preserves other selections")

-- A fresh reader/file-manager module restores custom mappings and bindings.
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
equal(select(2, event(up_code)), key, "Custom action survives restart")
binding = plugin.key_events[key]
assigned = saved[setting].profiles[profile].actions.up
button_menu = plugin:getButtonMenu(profile, Config.buttons[profile][1])
gesture_menu = button_menu
native_menu = button_menu[1].sub_item_table_func()

-- Sequences advance without assuming the Gestures plugin is enabled.
-- Tap-corner action sequences remain available for remote buttons.
assigned.increase_frontlight = 10
assigned.settings = { order = { "night_mode", "increase_frontlight" } }
assigned.settings.execute_one_by_one = 1
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.night_mode, true)
equal(executions[#executions].actions.increase_frontlight, nil)
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.increase_frontlight, 10)
equal(assigned.settings.execute_one_by_one, 1)
assigned.settings.show_as_quickmenu = true
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions, assigned, "QuickMenu options forwarded intact")
assigned.settings.show_as_quickmenu = nil
assigned.settings.cycle = true
assigned.set_font = 10
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.set_font, 10)
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.set_font, 20)
-- KOReader 2026.07.1 predates Dispatcher.getActionArgs. Ordered actions
-- must still work if a saved assignment contains a newer cycle setting.
local get_action_args = Dispatcher.getActionArgs
Dispatcher.getActionArgs = nil
assigned.settings.execute_one_by_one = 1
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.night_mode, true)
-- A newer API that cannot name the cycling action must not index with nil.
Dispatcher.getActionArgs = function() return { 10, 20 }, nil end
assigned.settings.execute_one_by_one = 1
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.night_mode, true, "Unnamed cycle falls back to sequence")
Dispatcher.getActionArgs = function() return nil, "set_font" end
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions.increase_frontlight, 10, "Missing cycle order falls back")
-- Malformed saved order executes the assignment as a whole, without erroring.
Dispatcher.getActionArgs = get_action_args
assigned.settings.cycle = nil
local saved_order = assigned.settings.order
assigned.settings.order = "bad"
plugin:onEightBitDoAction(binding.args)
equal(executions[#executions].actions, assigned, "Malformed order is ignored")
assigned.settings.order = saved_order
gesture_menu[3].callback()
plugin:onEightBitDoAction(binding.args)
equal(next(executions[#executions].actions), nil, "Nothing consumes button with no actions")
native_menu[1].callback()
equal(saved[setting].profiles[profile].actions.up, nil)
equal(select(2, event(up_code)), "LPgFwd", "Native assignment replaces gesture actions")
gesture_menu[2].callback()
local reset = plugin:getAssignmentsMenu()
reset[#reset].callback()
equal(saved[setting].profiles[profile].actions.up, nil, "Reset clears custom actions")
equal(select(2, event(up_code)), "Up")
equal(Config.normalizeProfile({ actions = { up = "bad" } }, profile).actions.up, nil)
print(profile .. " PASS: full tap-corner picker, multiple actions, numeric args, private keys, sequences, reset")

-- Unchecking the last action returns the button to its native key; only an
-- explicit "Nothing" keeps a button that does nothing.
local unchecked_menu = plugin:getButtonMenu(profile, Config.buttons[profile][1])
local toggle, nothing = unchecked_menu[7], unchecked_menu[3]
equal(nothing.text, "Nothing")
toggle.callback()
equal(select(2, event(up_code)), "EightBitDo_" .. profile .. "_up")
toggle.callback()
equal(saved[setting].profiles[profile].actions.up, nil, "Unchecking the last action clears the assignment")
equal(select(2, event(up_code)), "Up", "Native key restored")
equal(unchecked_menu[1].checked_func(), true, "Native navigation keys checked again")
toggle.callback()
nothing.callback()
assert(saved[setting].profiles[profile].actions.up, "Explicit Nothing replacing actions is kept")
equal(next(saved[setting].profiles[profile].actions.up), nil)
equal(select(2, event(up_code)), "EightBitDo_" .. profile .. "_up", "Nothing consumes the button")
unchecked_menu[1].sub_item_table_func()[2].callback() -- Native "Previous page".
nothing.callback()
assert(saved[setting].profiles[profile].actions.up, "Explicit Nothing from a native key is kept")
toggle.callback()
toggle.callback()
equal(saved[setting].profiles[profile].actions.up, nil, "Leaving Nothing then unchecking returns to native")
equal(select(2, event(up_code)), "LPgBack")
local reopened = plugin:getButtonMenu(profile, Config.buttons[profile][1])
reopened[3].callback()
reopened = plugin:getButtonMenu(profile, Config.buttons[profile][1])
reopened[7].callback()
reopened[7].callback()
equal(saved[setting].profiles[profile].actions.up, nil, "Reopened menu tracks the last action too")
local cleanup = plugin:getAssignmentsMenu()
cleanup[#cleanup].callback()

-- Labels are marked for translation; product names are not.
for _, text in ipairs({ "D-pad up", "Left bumper", "Capture", "Minus (-)", "Next page", "Ignore button" }) do
    assert(translated[text], "Translatable label: " .. text)
end
equal(translated["8BitDo Zero 2"], nil, "Product names are not translated")
equal(translated["8BitDo Micro"], nil)

-- Android (including Nook) delivers Android keycodes (KEYCODE_A = 29) and
-- repeats a held key as further presses without a release.
local linux_letters = { C = 46, D = 32, E = 18, F = 33, G = 34, H = 35, I = 23, J = 36,
    K = 37, L = 38, M = 50, N = 49, O = 24, R = 19, S = 31 }
for letter, linux in pairs(linux_letters) do
    equal(Config.android_codes[linux], 29 + letter:byte() - ("A"):byte(), "Android code for " .. letter)
end
for _, id in ipairs(Config.order) do
    local seen = {}
    for _, button in ipairs(Config.buttons[id]) do
        local code = Config.deviceCode(button, true)
        assert(code, "Android code for " .. id .. " " .. button.id)
        assert(not seen[code], "Android codes unique within " .. id)
        seen[code] = true
        equal(Config.deviceCode(button, false), button.code, "Linux code unchanged")
    end
end
equal(Config.deviceCode(Config.buttons.zero2[1], true), 31, "Zero 2 D-pad up (C) is Android 31")
-- The Zero 2 sends the same letter as the Micro for every shared button.
local micro_codes = {}
for _, button in ipairs(Config.buttons.micro) do micro_codes[button.id] = button.code end
for _, button in ipairs(Config.buttons.zero2) do
    equal(button.code, micro_codes[button.id], "Zero 2 " .. button.id .. " matches Micro")
end
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Device.isAndroid = function() return true end
local AndroidRemotes = dofile(directory .. "main.lua")
local android_plugin = AndroidRemotes:new{ ui = ui }
android_plugin:selectRemote(profile)
drain()
for _, button in ipairs(Config.buttons[profile]) do
    local expected_key = button.default ~= "none" and button.default or nil
    equal(select(2, event(Config.deviceCode(button, true))), expected_key, "Android " .. button.id)
end
equal(event(50).code, 50, "Linux codes are not matched on Android")
local android_up = Config.deviceCode(Config.buttons[profile][1], true)
assert(android_plugin:getAssignmentsMenu()[1].text_func():find("(" .. android_up .. ")", 1, true),
    "Menu shows the code this device sends")
equal(select(2, event(android_up, 1)), "Up")
equal(select(2, event(android_up, 1)), nil, "Android repeat press dropped")
equal(select(2, event(android_up, 1)), nil)
equal(select(2, event(android_up, 0)), "Up", "Release still delivered")
equal(select(2, event(android_up, 1)), "Up", "Next press after release works")
android_plugin:setEnabled(false)
android_plugin:setEnabled(true)
equal(select(2, event(android_up, 1)), "Up", "Release missed while disabled does not swallow a press")
android_plugin:selectRemote(profile)
equal(select(2, event(android_up, 1)), "Up", "Switching remotes clears held buttons")
event(android_up, 0)
Device.isAndroid = nil
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
drain()

-- Settings schema: the stored shape is locked to Config.SCHEMA.
equal(Config.SCHEMA, 2)
equal(saved[setting].schema, Config.SCHEMA, "Saved settings carry the schema")
local function keys_of(value)
    local list = {}
    for name in pairs(value) do list[#list + 1] = name end
    table.sort(list)
    return table.concat(list, ",")
end
local locked = Config.normalize(nil)
equal(keys_of(locked), "enabled,profiles,remote,schema", "Top-level shape locked")
equal(keys_of(locked.profiles), "micro,zero2", "Profile set locked")
for _, id in ipairs(Config.order) do
    equal(keys_of(locked.profiles[id]), "actions,mappings", "Profile shape locked")
end
equal(keys_of(Config.normalize({ surprise = true })), "enabled,profiles,remote,schema", "Unknown fields dropped")
equal(#Config.migrations, Config.SCHEMA, "Every schema number has a migration")
-- Pre-schema (0.3.x) settings upgrade without loss or aliasing.
local pre_schema = { enabled = false, remote = "micro",
    profiles = { micro = { repeat_keys = true, mappings = { b = "Press" }, actions = { a = { night_mode = true } } } } }
local upgraded = Config.load(pre_schema)
equal(upgraded.schema, 2)
equal(upgraded.enabled, false)
equal(upgraded.remote, "micro")
equal(upgraded.profiles.micro.mappings.b, "Press")
equal(upgraded.profiles.micro.repeat_keys, nil, "Repeat preference dropped")
equal(upgraded.profiles.micro.actions.a.night_mode, true)
equal(pre_schema.schema, nil, "Migration does not modify the stored table")
equal(pre_schema.profiles.micro.repeat_keys, true, "Migration leaves the stored repeat flag alone")
-- Schema 1 (0.4.0) settings drop repeat_keys and keep everything else.
local schema1 = { schema = 1, enabled = true, remote = "zero2", profiles = {
    zero2 = { repeat_keys = true, mappings = { up = "Menu" }, actions = { b = { night_mode = true } } },
    micro = "bad" } }
local from1 = Config.load(schema1)
equal(from1.schema, 2)
equal(from1.profiles.zero2.repeat_keys, nil)
equal(from1.profiles.zero2.mappings.up, "Menu")
equal(from1.profiles.zero2.actions.b.night_mode, true)
equal(from1.profiles.micro.mappings.up, "Up", "Malformed profile falls back to defaults")
equal(schema1.profiles.zero2.repeat_keys, true, "Stored schema 1 table not modified")
upgraded.profiles.micro.actions.a.night_mode = false
equal(pre_schema.profiles.micro.actions.a.night_mode, true, "Migration copies actions")
for _, malformed in ipairs({ "1", -1, 0.5, true }) do
    equal(Config.schemaOf({ schema = malformed }), 0, "Malformed schema treated as pre-schema")
    equal(Config.load({ schema = malformed, remote = "micro" }).remote, "micro")
end
equal(Config.isNewer({ schema = Config.SCHEMA }), false)
equal(Config.isNewer({ schema = Config.SCHEMA + 1 }), true)

-- Settings from the old standalone plugins are no longer imported.
saved[setting] = nil
local standalone = { enabled = true, mappings = { b = "Press" } }
saved.eightbitdo_micro = standalone
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
drain()
equal(saved[setting].remote, "zero2", "Fresh install starts with defaults")
equal(saved[setting].profiles.micro.mappings.b, "Back", "Standalone assignments are not imported")
equal(saved.eightbitdo_micro, standalone, "Standalone settings are left alone")
equal(standalone.mappings.b, "Press")
saved.eightbitdo_micro = nil

-- A newer build's settings are used but never overwritten by this build.
local newer = { schema = Config.SCHEMA + 1, enabled = true, remote = profile, future = { kept = true },
    profiles = { [profile] = { mappings = { up = "LPgFwd" } } } }
saved[setting] = newer
hooks = {}
Device.hasKeys, Device.hasDPad = no, no
local save_total = saves
Zero2 = dofile(directory .. "main.lua")
plugin = Zero2:new{ ui = ui }
drain()
equal(select(2, event(up_code)), "LPgFwd", "Newer settings still applied")
plugin:selectRemote(other)
plugin:onFlushSettings()
local newer_menu = {}
plugin:addToMainMenu(newer_menu)
newer_menu.eightbitdo.sub_item_table[4].callback()
assert(UIManager.last_widget.text:find("newer version", 1, true), "Help explains read-only settings")
equal(saves, save_total, "Newer settings never saved over")
equal(saved[setting], newer)
equal(newer.remote, profile)
equal(newer.future.kept, true)
print(profile .. " PASS: Android keycodes, settings schema, migration, downgrade protection")
