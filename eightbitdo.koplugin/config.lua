-- Linux EV_KEY codes. Zero 2 codes supplied by the user; Micro letters
-- transcribed from the supplied screenshot and translated via Linux headers.
local Config = {}
Config.order = { "zero2", "micro" }
Config.names = { zero2 = "8BitDo Zero 2", micro = "8BitDo Micro" }
Config.buttons = {
    zero2 = {
    { id = "up",    label = "D-pad up",     code = 32, default = "Up" },
    { id = "down",  label = "D-pad down",   code = 46, default = "Down" },
    { id = "left",  label = "D-pad left",   code = 18, default = "Left" },
    { id = "right", label = "D-pad right",  code = 33, default = "Right" },
    { id = "l",     label = "Left bumper",  code = 37, default = "LPgBack" },
    { id = "r",     label = "Right bumper", code = 50, default = "LPgFwd" },
    { id = "y",     label = "Y",            code = 23, default = "LPgBack" },
    { id = "a",     label = "A",            code = 34, default = "Press" },
    { id = "x",     label = "X",            code = 36, default = "Menu" },
    { id = "b",     label = "B",            code = 35, default = "Back" },
},
    micro = {
    { id = "up",      label = "D-pad up",       code = 46, default = "Up" }, -- C
    { id = "down",    label = "D-pad down",     code = 32, default = "Down" }, -- D
    { id = "left",    label = "D-pad left",     code = 18, default = "Left" }, -- E
    { id = "right",   label = "D-pad right",    code = 33, default = "Right" }, -- F
    { id = "l",       label = "Left bumper (L)", code = 37, default = "LPgBack" }, -- K
    { id = "r",       label = "Right bumper (R)",code = 50, default = "LPgFwd" }, -- M
    { id = "y",       label = "Y",              code = 23, default = "LPgBack" }, -- I
    { id = "a",       label = "A",              code = 34, default = "Press" }, -- G
    { id = "x",       label = "X",              code = 35, default = "Menu" }, -- H
    { id = "b",       label = "B",              code = 36, default = "Back" }, -- J
    { id = "l2",      label = "L2",             code = 38, default = "LPgBack" }, -- L
    { id = "r2",      label = "R2",             code = 19, default = "LPgFwd" }, -- R
    { id = "minus",   label = "Minus (-)",      code = 49, default = "Back" }, -- N
    { id = "plus",    label = "Plus (+)",       code = 24, default = "Menu" }, -- O
    { id = "capture", label = "Capture",        code = 31, default = "none" }, -- S
    -- Star is Null in the supplied screenshot: no keyboard event to map.
},
}

Config.actions = {
    { key = "LPgFwd",  label = "Next page" },
    { key = "LPgBack", label = "Previous page" },
    { key = "Up",      label = "Up" },
    { key = "Down",    label = "Down" },
    { key = "Left",    label = "Left" },
    { key = "Right",   label = "Right" },
    { key = "Press",   label = "Select" },
    { key = "Back",    label = "Back" },
    { key = "Menu",    label = "Menu" },
    { key = "none",    label = "Ignore button" },
}


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
    local result = { repeat_keys = saved.repeat_keys == true, mappings = {}, actions = {} }
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
--   profiles.<remote>.repeat_keys  boolean
--   profiles.<remote>.mappings.<button id>  Config.actions key
--   profiles.<remote>.actions.<button id>   Dispatcher action table (optional)
-- Changing this shape requires bumping Config.SCHEMA and adding a migration
-- for the new number. Never renumber or remove existing migrations.
Config.SCHEMA = 1
Config.migrations = {
    -- Builds before 0.4.0 stored no schema field but already used this shape.
    [1] = function(saved) return saved end,
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
