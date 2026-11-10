local Device = require("device")
local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local _ = require("gettext")

local directory = debug.getinfo(1, "S").source:match("^@(.*/)")
local Config = dofile(directory .. "config.lua")
local SETTING = "eightbitdo_remotes"
local EV_KEY = 1
local VERSION = "0.7.1"
-- KOReader on Android (including Nook) delivers Android keycodes.
local ANDROID = type(Device.isAndroid) == "function" and Device:isAndroid() and true or false
local state = { capabilities = {}, held = {} }
local by_code = {}
for profile_index, profile in ipairs(Config.order) do
    by_code[profile] = {}
    for index, button in ipairs(Config.buttons[profile]) do
        by_code[profile][Config.deviceCode(button, ANDROID)] = {
            button = button,
            virtual_code = 0x7000 + profile_index * 0x100 + index,
            key = "EightBitDo_" .. profile .. "_" .. button.id,
        }
    end
end

local Remotes = InputContainer:extend{
    name = "eightbitdo",
    is_doc_only = false,
}

local function enableCapabilities()
    for dummy, name in ipairs({ "hasKeys", "hasDPad" }) do
        if Device[name] ~= state.capabilities[name] then
            local original = Device[name]
            local wrapper = function(device)
                return state.settings.enabled or original(device)
            end
            state.capabilities[name] = wrapper
            Device[name] = wrapper
        end
    end
end

local function adjustEvent(input, ev)
    if not state.settings.enabled or ev.type ~= EV_KEY then return end
    local profile = state.settings.remote
    local mapping = by_code[profile][ev.code]
    if not mapping then return end
    local settings = state.settings.profiles[profile]
    local key = settings.mappings[mapping.button.id]
    if settings.actions[mapping.button.id] ~= nil then key = mapping.key end
    -- Held buttons never repeat: drop autorepeat events along with ignored
    -- buttons. Press and release still pass through. Linux marks repeats
    -- with value 2; Android sends them as further presses without a release.
    local repeated = ev.value == 2 or (ev.value == 1 and state.held[ev.code])
    if ev.value == 1 then
        state.held[ev.code] = true
    elseif ev.value == 0 then
        state.held[ev.code] = nil
    end
    if key == "none" or repeated then
        key = nil
    end
    -- External Keyboard may replace event_map, so refresh each private entry
    -- when needed. The original keyboard codes remain untouched.
    input.event_map[mapping.virtual_code] = key
    ev.code = mapping.virtual_code
end

-- Number of Dispatcher actions in an assignment (its "settings" entry holds
-- options, not an action). Returns 0 for no assignment.
local function countActions(actions)
    local count = 0
    if type(actions) == "table" then
        for name in pairs(actions) do
            if name ~= "settings" then count = count + 1 end
        end
    end
    return count
end

local function capabilities()
    return Device:hasKeys() and true or false, Device:hasDPad() and true or false
end

-- Widgets register key bindings from hasKeys/hasDPad when they initialize.
-- Re-announce a keyboard only when this plugin changed those answers:
-- KOReader 2026.07.1's FileManager answers PhysicalKeyboardConnected with a
-- full reinit, so an unconditional broadcast rebuilds it on every opening.
local function updateCapabilities(keys, dpad)
    enableCapabilities()
    local new_keys, new_dpad = capabilities()
    if new_keys ~= keys or new_dpad ~= dpad then
        -- Gaining keys asks widgets to register bindings; losing them lets
        -- widgets drop bindings the device can no longer reach. In 2026.07.1
        -- every reader and file-manager module that binds keys re-registers
        -- them on Connected, so a later re-enable restores them.
        local gained = (new_keys and not keys) or (new_dpad and not dpad)
        local name = gained and "PhysicalKeyboardConnected" or "PhysicalKeyboardDisconnected"
        UIManager:nextTick(function()
            UIManager:broadcastEvent(Event:new(name))
        end)
    end
end

function Remotes:init()
    -- One state and hook for all reader/file-manager instances.
    if not state.settings then
        local saved = G_reader_settings:readSetting(SETTING)
        state.read_only = Config.isNewer(saved)
        state.settings = Config.load(saved,
            G_reader_settings:readSetting("eightbitdo_zero2"),
            G_reader_settings:readSetting("eightbitdo_micro"))
        self:save()
    end
    if state.input ~= Device.input then
        Device.input:registerEventAdjustHook(adjustEvent)
        state.input = Device.input
    end
    -- The host's modules registered their keys before plugins were loaded.
    local keys, dpad = capabilities()
    Dispatcher:init()
    self.key_events = {}
    for profile, mappings in pairs(by_code) do
        for _, mapping in pairs(mappings) do
            self.key_events[mapping.key] = {
                { mapping.key }, event = "EightBitDoAction",
                args = { profile = profile, button = mapping.button.id },
            }
        end
    end
    self.ui.menu:registerToMainMenu(self)
    updateCapabilities(keys, dpad)
end

function Remotes:save()
    -- Never downgrade settings written by a newer build of this plugin.
    if state.read_only then return end
    G_reader_settings:saveSetting(SETTING, state.settings)
end

Remotes.onFlushSettings = Remotes.save

function Remotes:onEightBitDoAction(binding)
    if not state.settings.enabled or state.settings.remote ~= binding.profile then return end
    local actions = state.settings.profiles[binding.profile].actions[binding.button]
    if not actions then return end
    if self.ui.keyselection then self.ui.keyselection:stopHighlightIndicator(true) end
    local execution = actions
    local options = actions.settings
    if options and options.execute_one_by_one and not options.show_as_quickmenu then
        -- Dispatcher otherwise marks the Gestures/Profile plugin dirty when
        -- advancing a sequence. These assignments belong to this plugin, and
        -- must also work when Gestures is disabled.
        local order, action
        local cycle = options.cycle and Dispatcher.getActionArgs ~= nil
        if cycle then
            -- Newer than KOReader 2026.07.1; fall back to the ordered sequence
            -- if it cannot name the action whose argument should cycle.
            order, action = Dispatcher.getActionArgs(actions, true)
            if action == nil or type(order) ~= "table" then cycle = false end
        end
        if not cycle then
            order = options.order
        end
        if type(order) == "table" and #order > 0 then
            local index = options.execute_one_by_one
            if type(index) ~= "number" or index < 1 or index > #order then index = 1 end
            if cycle then
                actions[action] = order[index]
                execution = { [action] = order[index] }
            else
                execution = { [order[index]] = actions[order[index]] }
            end
            options.execute_one_by_one = index == #order and 1 or index + 1
        end
    end
    Dispatcher:execute(execution, { hotkeys = "eightbitdo_" .. binding.button })
    self:save()
    return true
end

function Remotes:setEnabled(enabled)
    local keys, dpad = capabilities()
    state.settings.enabled = enabled
    -- Releases are not tracked while disabled; start afresh.
    state.held = {}
    self:save()
    updateCapabilities(keys, dpad)
end

function Remotes:selectRemote(profile)
    if not Config.names[profile] then return end
    state.settings.remote = profile
    state.held = {}
    self:save()
end

function Remotes:onPhysicalKeyboardConnected()
    enableCapabilities()
end
-- Also overrides InputContainer's handler, which would clear this plugin's
-- private key bindings when the device reports no keys.
Remotes.onPhysicalKeyboardDisconnected = Remotes.onPhysicalKeyboardConnected

function Remotes:getRemoteMenu()
    local items = {}
    for dummy, id in ipairs(Config.order) do
        local profile = id
        items[#items + 1] = {
            text = Config.names[profile],
            checked_func = function() return state.settings.remote == profile end,
            callback = function() self:selectRemote(profile) end,
        }
    end
    return items
end

function Remotes:getActionLabel(key)
    for dummy, action in ipairs(Config.actions) do
        if action.key == key then return action.label end
    end
end

function Remotes:getNativeKeyMenu(profile, button)
    local items = {}
    for dummy, action in ipairs(Config.actions) do
        local key = action.key
        items[#items + 1] = {
            text = action.label,
            checked_func = function()
                local settings = state.settings.profiles[profile]
                return settings.actions[button.id] == nil and settings.mappings[button.id] == key
            end,
            callback = function()
                state.settings.profiles[profile].mappings[button.id] = key
                state.settings.profiles[profile].actions[button.id] = nil
                self:save()
            end,
        }
    end
    return items
end

function Remotes:getButtonMenu(profile, button)
    local menu = {
        {
            text = _("Native navigation keys"),
            checked_func = function()
                return state.settings.profiles[profile].actions[button.id] == nil
            end,
            sub_item_table_func = function() return self:getNativeKeyMenu(profile, button) end,
            separator = true,
        },
    }
    -- Put the same categories used by Tap corner directly in the assignment
    -- menu, instead of hiding them after a page of navigation key choices.
    local location = state.settings.profiles[profile].actions
    local last_count = countActions(location[button.id])
    local chose_nothing = false
    local caller = setmetatable({ profiles = {} }, {
        __newindex = function(_, key, value)
            if key ~= "updated" or not value then return end
            -- Dispatcher leaves an empty assignment when the last action is
            -- unchecked. Treat that as returning to the native key; only an
            -- explicit "Nothing" keeps a button that does nothing.
            local count = countActions(location[button.id])
            if count == 0 and last_count > 0 and not chose_nothing then
                location[button.id] = nil
            end
            last_count, chose_nothing = count, false
            self:save()
        end,
    })
    local start = #menu
    Dispatcher:addSubMenu(caller, menu, location, button.id)
    for index = start + 1, #menu do
        local item = menu[index]
        if item.text == _("Nothing") and type(item.callback) == "function" then
            local callback = item.callback
            item.callback = function(...)
                chose_nothing = true
                return callback(...)
            end
            break
        end
    end
    return menu
end

function Remotes:getAssignmentsMenu()
    -- Capture the profile whose menu was opened so callbacks cannot modify a
    -- different remote if the selection changes before they run.
    local profile = state.settings.remote
    local items = {}
    for dummy, definition in ipairs(Config.buttons[profile]) do
        local button = definition
        items[#items + 1] = {
            text_func = function()
                return string.format("%s (%d): %s", button.label, Config.deviceCode(button, ANDROID),
                    self:getButtonLabel(profile, button.id))
            end,
            sub_item_table_func = function() return self:getButtonMenu(profile, button) end,
        }
    end
    items[#items + 1] = {
        text = _("Reset this remote's button assignments"),
        callback = function()
            state.settings.profiles[profile].mappings = Config.normalizeProfile(nil, profile).mappings
            state.settings.profiles[profile].actions = {}
            self:save()
        end,
    }
    return items
end

function Remotes:getButtonLabel(profile, button)
    local settings = state.settings.profiles[profile]
    if settings.actions[button] ~= nil then
        return Dispatcher:menuTextFunc(settings.actions[button], true)
    end
    return self:getActionLabel(settings.mappings[button])
end

function Remotes:addToMainMenu(menu_items)
    menu_items.eightbitdo = {
        text = _("8BitDo remotes"),
        sub_item_table = {
            {
                text = _("Enable remote mappings"),
                checked_func = function() return state.settings.enabled end,
                callback = function() self:setEnabled(not state.settings.enabled) end,
            },
            {
                text_func = function() return _("Remote") .. ": " .. Config.names[state.settings.remote] end,
                sub_item_table_func = function() return self:getRemoteMenu() end,
            },
            {
                text = _("Button assignments"),
                sub_item_table_func = function() return self:getAssignmentsMenu() end,
            },
            {
                text = _("Help"),
                callback = function()
                    UIManager:show(InfoMessage:new{
                        text = "8BitDo remotes v" .. VERSION .. "\n\n"
                            .. (state.read_only and _("Settings were saved by a newer version of this plugin. Changes made with this version are not saved.") .. "\n\n" or "")
                            .. _("Select Zero 2 or Micro under Remote. Button assignments are saved separately for each remote. Switching applies immediately. Open a button to see the Gesture Manager action categories directly: General, Device, Screen and lights, File browser, Reader, and document-specific actions. Native navigation keys are in their own submenu. Multiple actions and QuickMenus are supported.\n\nPair the remote in HID keyboard mode using your device's Bluetooth settings. Micro: set the switch on the bottom to K, then turn it on. Zero 2: hold the right bumper (R) while turning it on. This plugin maps input already delivered to KOReader; it does not pair or open Bluetooth devices.\n\nDisable or remove the old standalone Zero 2 and Micro plugins, then restart KOReader. Their saved assignments are imported on first use.\n\nMappings also affect physical keyboards sending the same codes. Disable remote mappings when typing. Micro Star emits no key; Capture is configurable."),
                    })
                end,
            },
        },
    }
end

return Remotes
