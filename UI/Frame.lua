--[[ ShieldWatch — movable container frame + hover reveal.

Pure Lua (no XML). The container's own bounds ARE the hover/drag surface:
it stays EnableMouse(true) and sized to the full rows x columns grid at all
times, even while every icon inside it is hidden. That's what lets "only
expose shield icons on hover" work - there's always something under the
cursor to detect, whether or not anything is currently drawn.

Click-and-hold works from the background gap (this frame) or from any icon
button (UI/Buttons.lua delegates its drag scripts here), so the whole group
moves together no matter where you grab it.
]]

local ADDON, ns = ...
local SW = ns.SW

local ICON, PAD, MARGIN = ns.ICON, ns.PAD, ns.MARGIN

local function savePos(f)
	local point, _, relPoint, x, y = f:GetPoint()
	SW.opt.pos = { point = point, relPoint = relPoint, x = x, y = y }
end

function SW:CreateMainFrame()
	local f = CreateFrame("Frame", "ShieldWatchFrame", UIParent, "BackdropTemplate")
	f:SetSize(ICON + 2 * MARGIN, ICON + 2 * MARGIN)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})

	if SW.opt.pos then
		local p = SW.opt.pos
		f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
	else
		f:SetPoint("CENTER")
	end

	f:SetScript("OnDragStart", function(self)
		if not SW.opt.locked then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePos(self)
	end)

	SW.frame = f
end

----------------------------------------------------------------------
-- Hover reveal
----------------------------------------------------------------------
-- Checked on a light ticker rather than OnEnter/OnLeave: icon buttons are
-- separate mouse-enabled frames on top of this one, and Enter/Leave firing
-- order between a parent and its children is exactly the kind of thing that
-- causes visible flicker. IsMouseOver() is a plain rect test against this
-- frame's own bounds, so it doesn't care what's drawn on top of it.
function SW:InitHover()
	local revealed = nil -- last-applied backdrop state, so that alone can skip redundant SetBackdropColor calls

	-- Always re-syncs button visibility (cheap - a handful of icons, and
	-- RefreshLayout needs a freshly-laid-out button revealed immediately
	-- even when the overall show/hide state hasn't changed since last tick).
	function SW:ApplyReveal()
		local show = (not SW.opt.hoverOnly) or (not SW.opt.locked) or SW.frame:IsMouseOver()

		for _, btn in ipairs(SW.activeButtons or {}) do
			btn:SetShown(show)
		end

		if show == revealed then return end
		revealed = show

		if show then
			SW.frame:SetBackdropColor(0, 0, 0, 0.55)
			SW.frame:SetBackdropBorderColor(1, 1, 1, 0.5)
		elseif SW.opt.locked then
			SW.frame:SetBackdropColor(0, 0, 0, 0) -- fully invisible until hovered
			SW.frame:SetBackdropBorderColor(1, 1, 1, 0)
		else
			SW.frame:SetBackdropColor(0, 0, 0, 0.35) -- faint, so you can find it to unlock/drag
			SW.frame:SetBackdropBorderColor(1, 1, 1, 0.25)
		end
	end

	C_Timer.NewTicker(0.1, function()
		if SW.frame then SW:ApplyReveal() end
	end)
end

function SW:ResetPosition()
	SW.opt.pos = nil
	SW.frame:ClearAllPoints()
	SW.frame:SetPoint("CENTER")
end

function SW:InitUI()
	SW:CreateMainFrame()
	SW:CreateButtons()
	SW:InitHover()
	SW:CreateOptions()
	SW:RefreshLayout()
end
