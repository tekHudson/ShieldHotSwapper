--[[ ShieldWatch — bootstrap, shared namespace, defaults, event dispatch.

Shows every shield sitting in your bags as a small icon grid, with live
durability so spare/resistance shields don't quietly go unrepaired. Classic
Era / Season of Discovery only. Pure Lua, no XML, no Ace3.
]]

local ADDON, ns = ...

-- The public object. Modules hang methods off this; the event frame below
-- dispatches WoW events to same-named methods (e.g. SW:BAG_UPDATE_DELAYED).
local SW = {}
_G.ShieldWatch = SW
ns.SW = SW
ns.ADDON = ADDON

----------------------------------------------------------------------
-- Environment / constants
----------------------------------------------------------------------
SW.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "0.0"

-- Shared icon-grid geometry (UI/Frame.lua and UI/Buttons.lua both need these
-- to agree on frame sizing vs. button placement).
ns.ICON = 36
ns.PAD = 4
ns.MARGIN = 6

----------------------------------------------------------------------
-- Saved variables + defaults merge
----------------------------------------------------------------------
local DEFAULTS = {
	locked = false,    -- when locked, the group only reveals on hover (see UI/Frame.lua)
	hoverOnly = true,  -- "only expose shield icons on hover"
	pos = nil,
	display = { rows = 1, columns = 6 },
}

local function mergeDefaults(db, defaults)
	for k, v in pairs(defaults) do
		if db[k] == nil then
			db[k] = (type(v) == "table") and {} or v
		end
		if type(v) == "table" then
			mergeDefaults(db[k], v)
		end
	end
	return db
end

----------------------------------------------------------------------
-- Output helper
----------------------------------------------------------------------
local PREFIX = "|cffff9832ShieldWatch:|r "
function SW:Print(...)
	print(PREFIX .. strjoin(" ", tostringall(...)))
end

----------------------------------------------------------------------
-- Event dispatch: SW:RegisterEvent("X") -> calls SW:X(event, ...)
----------------------------------------------------------------------
local frame = CreateFrame("Frame", "ShieldWatchEventFrame")
ns.eventFrame = frame
local registered = {}

function SW:RegisterEvent(event)
	if not registered[event] then
		registered[event] = true
		frame:RegisterEvent(event)
	end
end

function SW:UnregisterEvent(event)
	if registered[event] then
		registered[event] = nil
		frame:UnregisterEvent(event)
	end
end

frame:SetScript("OnEvent", function(_, event, ...)
	local handler = SW[event]
	if handler then
		handler(SW, event, ...)
	end
end)

----------------------------------------------------------------------
-- Bootstrap lifecycle
----------------------------------------------------------------------
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

function SW:ADDON_LOADED(_, name)
	if name ~= ADDON then return end
	SW:UnregisterEvent("ADDON_LOADED")
	ShieldWatchDB = ShieldWatchDB or {}
	SW.opt = mergeDefaults(ShieldWatchDB, DEFAULTS)
end

function SW:PLAYER_LOGIN()
	SW:InitScan()   -- Core/Scan.lua: builds SW.shields, wires rescan events
	SW:InitUI()     -- UI/Frame.lua + UI/Buttons.lua + UI/Options.lua

	SW:SetupSlash()
	SW:Print("v" .. SW.version .. " loaded. /sw for options.")
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
function SW:SetupSlash()
	SLASH_SHIELDWATCH1 = "/shieldwatch"
	SLASH_SHIELDWATCH2 = "/sw"
	_G.SlashCmdList["SHIELDWATCH"] = function(msg)
		msg = (msg or ""):lower():trim()
		if msg == "reset" then
			SW:ResetPosition()
			SW:Print("Position reset.")
		elseif msg == "lock" then
			SW.opt.locked = true
			SW:Print("Locked.")
		elseif msg == "unlock" then
			SW.opt.locked = false
			SW:Print("Unlocked.")
		else
			SW:OpenOptions()
		end
	end
end
