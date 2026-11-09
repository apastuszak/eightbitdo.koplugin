local Device = require("device")
local UIManager = require("ui/uimanager")
local Notification = require("ui/widget/notification")
local logger = require("logger")

local map = Device.input and Device.input.event_map
if not map then
    logger.warn("bt-keys patch: no event_map on Device.input, skipping")
    return
end

-- page turning
map[33] = "RPgBack"
map[18] = "RPgFwd"

-- brightness (swap these two if they feel backwards)
map[37] = "BrightUp"
map[50] = "BrightDown"

local STEP = 2  -- adjust to taste, in frontlight levels

local function adjust(delta)
    if not Device:hasFrontlight() then return end
    local powerd = Device:getPowerDevice()
    local new = math.max(powerd.fl_min, math.min(powerd.fl_max, powerd:frontlightIntensity() + delta))
    powerd:setIntensity(new)
    UIManager:show(Notification:new{ text = "Brightness: " .. new, timeout = 1 })
end

local orig_sendEvent = UIManager.sendEvent
function UIManager:sendEvent(event)
    if event and (event.handler == "onKeyPress" or event.handler == "onKeyRepeat") then
        local key = event.args and event.args[1]
        local name = key and key.key
        if name == "BrightUp" then adjust(STEP) return true end
        if name == "BrightDown" then adjust(-STEP) return true end
    end
    return orig_sendEvent(self, event)
end

logger.info("bt-keys patch: remote keys mapped")