-- Linux EV_KEY codes. Zero 2 codes supplied by the user; Micro letters
-- transcribed from the supplied screenshot and translated via Linux headers.
-- Android uses different numbers; see Config.deviceCode below.
local _ = require("gettext")

local Config = {}
Config.order = { "zero2", "micro" }
-- Product names are not translated.
Config.names = { zero2 = "8BitDo Zero 2", micro = "8BitDo Micro" }
Config.buttons = {
    zero2 = {
    { id = "up",    label = _("D-pad up"),     code = 32, default = "Up" },
    { id = "down",  label = _("D-pad down"),   code = 46, default = "Down" },
    { id = "left",  label = _("D-pad left"),   code = 18, default = "Left" },
    { id = "right", label = _("D-pad right"),  code = 33, default = "Right" },
    { id = "l",     label = _("Left bumper"),  code = 37, default = "LPgBack" },
    { id = "r",     label = _("Right bumper"), code = 50, default = "LPgFwd" },
    { id = "y",     label = _("Y"),            code = 23, default = "LPgBack" },
    { id = "a",     label = _("A"),            code = 34, default = "Press" },
    { id = "x",     label = _("X"),            code = 36, default = "Menu" },
    { id = "b",     label = _("B"),            code = 35, default = "Back" },
},
    micro = {
    { id = "up",      label = _("D-pad up"),       code = 46, default = "Up" }, -- C
    { id = "down",    label = _("D-pad down"),     code = 32, default = "Down" }, -- D
    { id = "left",    label = _("D-pad left"),     code = 18, default = "Left" }, -- E
    { id = "right",   label = _("D-pad right"),    code = 33, default = "Right" }, -- F
    { id = "l",       label = _("Left bumper (L)"), code = 37, default = "LPgBack" }, -- K
    { id = "r",       label = _("Right bumper (R)"),code = 50, default = "LPgFwd" }, -- M
    { id = "y",       label = _("Y"),              code = 23, default = "LPgBack" }, -- I
    { id = "a",       label = _("A"),              code = 34, default = "Press" }, -- G
    { id = "x",       label = _("X"),              code = 35, default = "Menu" }, -- H
    { id = "b",       label = _("B"),              code = 36, default = "Back" }, -- J
    { id = "l2",      label = _("L2"),             code = 38, default = "LPgBack" }, -- L
    { id = "r2",      label = _("R2"),             code = 19, default = "LPgFwd" }, -- R
    { id = "minus",   label = _("Minus (-)"),      code = 49, default = "Back" }, -- N
    { id = "plus",    label = _("Plus (+)"),       code = 24, default = "Menu" }, -- O
    { id = "capture", label = _("Capture"),        code = 31, default = "none" }, -- S
    -- Star is Null in the supplied screenshot: no keyboard event to map.
},
}

Config.actions = {
    { key = "LPgFwd",  label = _("Next page") },
    { key = "LPgBack", label = _("Previous page") },
    { key = "Up",      label = _("Up") },
    { key = "Down",    label = _("Down") },
    { key = "Left",    label = _("Left") },
    { key = "Right",   label = _("Right") },
    { key = "Press",   label = _("Select") },
    { key = "Back",    label = _("Back") },
    { key = "Menu",    label = _("Menu") },
    { key = "none",    label = _("Ignore button") },
}

-- Button codes above are Linux EV_KEY codes. On Android, KOReader receives
-- Android KeyEvent keycodes instead (KEYCODE_A = 29 through KEYCODE_Z = 54),
-- so each letter's Linux code is translated before matching.
local LINUX_LETTER_CODES = {
    A = 30, B = 48, C = 46, D = 32, E = 18, F = 33, G = 34, H = 35, I = 23,
    J = 36, K = 37, L = 38, M = 50, N = 49, O = 24, P = 25, Q = 16, R = 19,
    S = 31, T = 20, U = 22, V = 47, W = 17, X = 45, Y = 21, Z = 44,
}
Config.android_codes = {}
for letter, linux_code in pairs(LINUX_LETTER_CODES) do
    Config.android_codes[linux_code] = 29 + letter:byte() - ("A"):byte()
end

-- The code KOReader delivers for a button on this platform.
function Config.deviceCode(button, android)
    if android then return Config.android_codes[button.code] end
    return button.code
end

local function asTable(value)
    return type(value) == "table" and value or {}
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function Config.normalizeProfile(saved, profile)
    saved = asTable(saved)
    local result = { mappings = {}, actions = {} }
    local valid = {}
    for _, action in ipairs(Config.actions) do valid[action.key] = true end
    local mappings = asTable(saved.mappings)
    for _, button in ipairs(Config.buttons[profile]) do
        local key = mappings[button.id]
        result.mappings[button.id] = valid[key] and key or button.default
        local actions = asTable(saved.actions)[button.id]
        -- Dispatcher action names are extensible (including other plugins).
        -- Preserve their values, order, numeric arguments and QuickMenu options.
        if type(actions) == "table" then result.actions[button.id] = copy(actions) end
    end
    return result
end

-- Stored settings format (G_reader_settings key "eightbitdo_remotes"):
--   schema   integer, Config.SCHEMA when written by this build
--   enabled  boolean
--   remote   "zero2" | "micro"
--   profiles.<remote>.mappings.<button id>  Config.actions key
--   profiles.<remote>.actions.<button id>   Dispatcher action table (optional)
-- Changing this shape requires bumping Config.SCHEMA and adding a migration
-- for the new number. Never renumber or remove existing migrations.
Config.SCHEMA = 2
Config.migrations = {
    -- Builds before 0.4.0 stored no schema field but already used the
    -- schema 1 shape (this shape plus profiles.<remote>.repeat_keys).
    [1] = function(saved) return saved end,
    -- 0.5.0 removed held-button repeat; held buttons never repeat.
    [2] = function(saved)
        for _, profile in pairs(asTable(saved.profiles)) do
            if type(profile) == "table" then profile.repeat_keys = nil end
        end
        return saved
    end,
}

-- Returns the stored schema number; missing or malformed values count as 0
-- (written before schemas existed).
function Config.schemaOf(saved)
    local schema = type(saved) == "table" and saved.schema
    if type(schema) ~= "number" or schema < 0 or schema ~= math.floor(schema) then
        return 0
    end
    return schema
end

-- Settings from a newer build may hold data this build does not understand,
-- so they are used read-only rather than downgraded on save.
function Config.isNewer(saved)
    return Config.schemaOf(saved) > Config.SCHEMA
end

function Config.migrate(saved)
    saved = copy(asTable(saved))
    for schema = Config.schemaOf(saved) + 1, Config.SCHEMA do
        saved = Config.migrations[schema](saved)
    end
    return saved
end

function Config.normalize(saved)
    saved = asTable(saved)
    local profiles = asTable(saved.profiles)
    local result = {
        schema = Config.SCHEMA,
        enabled = saved.enabled ~= false,
        remote = Config.names[saved.remote] and saved.remote or "zero2",
        profiles = {},
    }
    for _, profile in ipairs(Config.order) do
        result.profiles[profile] = Config.normalizeProfile(profiles[profile], profile)
    end
    return result
end

function Config.load(saved, old_zero2, old_micro)
    -- A combined settings table always wins over legacy settings, even when
    -- disabled. Migration copies data and leaves legacy settings untouched.
    if type(saved) == "table" then
        if Config.isNewer(saved) then return Config.normalize(saved) end
        return Config.normalize(Config.migrate(saved))
    end
    local zero2, micro = asTable(old_zero2), asTable(old_micro)
    local zero_enabled = type(old_zero2) == "table" and zero2.enabled ~= false
    local micro_enabled = type(old_micro) == "table" and micro.enabled ~= false
    return Config.normalize{
        enabled = (type(old_zero2) ~= "table" and type(old_micro) ~= "table")
            or zero_enabled or micro_enabled,
        remote = micro_enabled and not zero_enabled and "micro" or "zero2",
        profiles = { zero2 = zero2, micro = micro },
    }
end

return Config
