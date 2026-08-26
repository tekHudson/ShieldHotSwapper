--[[ ShieldWatch — options panel via the modern Settings API.

Settings: hover-only visibility toggle, lock toggle.
Display: rows / columns sliders sizing the icon grid.

No AceConfig/AceGUI; falls back to the legacy InterfaceOptions API on older
clients, same pattern as PallySquire/UI/Options.lua.
]]

local ADDON, ns = ...
local SW = ns.SW

local function makeCheck(parent, label, get, set, y)
	local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 24, y)
	cb.Text:SetText(label)
	cb:SetChecked(get())
	cb:SetScript("OnClick", function(self) set(self:GetChecked()) end)
	return cb
end

local function makeSlider(parent, name, label, lo, hi, get, set, y)
	local slider = CreateFrame("Slider", "ShieldWatch" .. name .. "Slider", parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", 26, y)
	slider:SetMinMaxValues(lo, hi)
	slider:SetValueStep(1)
	slider:SetObeyStepOnDrag(true)
	slider:SetValue(get())
	_G[slider:GetName() .. "Low"]:SetText(lo)
	_G[slider:GetName() .. "High"]:SetText(hi)
	_G[slider:GetName() .. "Text"]:SetText(label)
	slider:SetScript("OnValueChanged", function(self, value)
		value = math.floor(value + 0.5)
		set(value)
		_G[self:GetName() .. "Text"]:SetText(label .. " (" .. value .. ")")
		SW:RefreshLayout()
	end)
	return slider
end

function SW:CreateOptions()
	local panel = CreateFrame("Frame", "ShieldWatchOptionsPanel", UIParent)
	panel.name = "ShieldWatch"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("ShieldWatch")

	local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	sub:SetText("Shows every shield in your bags with live durability. Hold to drag the group.")

	local y = -58
	local function header(text)
		local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		h:SetPoint("TOPLEFT", 16, y)
		h:SetText(text)
		h:SetTextColor(1, 0.82, 0)
		local line = panel:CreateTexture(nil, "ARTWORK")
		line:SetSize(340, 1)
		line:SetPoint("TOPLEFT", 16, y - 16)
		line:SetColorTexture(1, 0.82, 0, 0.35)
		y = y - 28
	end

	------------------------------------------------------------------
	header("Settings")
	makeCheck(panel, "Only show shield icons on hover", function() return SW.opt.hoverOnly end,
		function(v) SW.opt.hoverOnly = v end, y)
	y = y - 26
	makeCheck(panel, "Lock frame position", function() return SW.opt.locked end,
		function(v) SW.opt.locked = v end, y)
	y = y - 34

	------------------------------------------------------------------
	header("Display")
	makeSlider(panel, "Rows", "Rows", 1, 6,
		function() return SW.opt.display.rows end,
		function(v) SW.opt.display.rows = v end, y)
	y = y - 48
	makeSlider(panel, "Columns", "Columns", 1, 10,
		function() return SW.opt.display.columns end,
		function(v) SW.opt.display.columns = v end, y)
	y = y - 48

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, "ShieldWatch")
		Settings.RegisterAddOnCategory(category)
		SW.optionsCategory = category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	SW.optionsPanel = panel
end

function SW:OpenOptions()
	if Settings and Settings.OpenToCategory and SW.optionsCategory then
		Settings.OpenToCategory(SW.optionsCategory:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(SW.optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(SW.optionsPanel)
	end
end
