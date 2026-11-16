-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: the on-screen panel. One row per equipped weapon type: its
-- skill against max for your level, a bar, and the estimated progress
-- toward the next point. Drag to move (unless locked); click to open the
-- weapon list; hover for details.

local ADDON, ns = ...

local ROW_H, WIDTH, PAD = 30, 210, 6
local panel
local rows = {}

local function SavePosition(f)
  local point, _, relPoint, x, y = f:GetPoint(1)
  if point then ns.char.panelPos = { point = point, relPoint = relPoint, x = x, y = y } end
end

local function Row(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Frame", nil, panel)
  r:SetSize(WIDTH - PAD * 2, ROW_H)
  r:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -PAD - (i - 1) * ROW_H)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(22, 22)
  r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 1)
  r.name:SetJustifyH("LEFT")
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.value:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, 1)
  r.value:SetJustifyH("RIGHT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1)
  r.bar:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  r.bar:SetHeight(5)
  r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  r.bar:SetMinMaxValues(0, 1)
  r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
  r.bar.bg:SetAllPoints(r.bar)
  r.bar.bg:SetColorTexture(0, 0, 0, 0.6)
  r.next = r.bar:CreateTexture(nil, "OVERLAY")   -- thin marker: progress toward the next point
  r.next:SetHeight(2)
  r.next:SetPoint("BOTTOMLEFT", r.bar, "BOTTOMLEFT", 0, 0)
  r.next:SetColorTexture(1, 1, 1, 0.9)
  r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.sub:SetPoint("TOPRIGHT", r.value, "BOTTOMRIGHT", 0, -1)
  r.sub:SetJustifyH("RIGHT")
  rows[i] = r
  return r
end

local function HexToRGB(hex)
  return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- The weapon types to show: equipped, each type once.
local function Entries()
  local seen, out = {}, {}
  for _, e in ipairs(ns.EquippedWeapons()) do
    if not seen[e.w.skill] then
      seen[e.w.skill] = true
      out[#out + 1] = e
    end
  end
  return out
end

-- Text for progress toward the next point (always marked as an estimate).
function ns.ProgressText(skillID, s)
  if s and s.rank and s.max and s.rank >= s.max then return "maxed", nil end
  local prog = ns.GetProgress(skillID)
  if not prog then return "", nil end
  if prog.fraction then
    return ("~%d%% to next"):format(math.floor(prog.fraction * 100)), prog.fraction
  end
  if prog.swings >= 1 then
    return ("~%d swings"):format(math.floor(prog.swings + 0.5)), nil
  end
  return "", nil
end

function ns.UpdatePanel()
  if not panel then return end
  if not ns.Setting("panel") then panel:Hide() return end
  local entries = Entries()
  local allMaxed = #entries > 0
  local n = 0
  for _, e in ipairs(entries) do
    local s = ns.GetSkill(e.w.skill)
    n = n + 1
    local r = Row(n)
    local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", e.slot)
    r.icon:SetTexture((tex and not ns.IsHidden(tex)) and tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    r.name:SetText((s and s.name) or ns.WeaponName(e.w))
    if s and s.rank and s.max and s.max > 0 then
      local hex = ns.GapColor(s.rank, s.max)
      local bonus = (s.mod or 0) > 0 and ns.Colored("40ff40", " +" .. s.mod) or ""
      r.value:SetText(ns.Colored(hex, s.rank) .. " / " .. s.max .. bonus)
      r.bar:SetValue(s.rank / s.max)
      r.bar:SetStatusBarColor(HexToRGB(hex))
      if s.rank < s.max then allMaxed = false end
      local text, fraction = ns.ProgressText(e.w.skill, s)
      if ns.Setting("panelProgress") then
        r.sub:SetText(text)
        if fraction then
          r.next:SetWidth(math.max(1, r.bar:GetWidth() * fraction))
          r.next:Show()
        else
          r.next:Hide()
        end
      else
        r.sub:SetText("")
        r.next:Hide()
      end
    else
      allMaxed = false
      r.value:SetText(ns.Colored("ff4040", "not learned"))
      r.bar:SetValue(0)
      r.sub:SetText("")
      r.next:Hide()
    end
    r.skillID = e.w.skill
    r:Show()
  end
  for i = n + 1, #rows do rows[i]:Hide() end
  if n == 0 or (allMaxed and ns.Setting("panelHideMaxed") and ns.Setting("panelLocked")) then
    panel:Hide()
    return
  end
  panel:SetHeight(PAD * 2 + n * ROW_H)
  panel:Show()
end

---------------------------------------------------------------------------
-- Details on hover
---------------------------------------------------------------------------

function ns.AddSkillDetails(tooltip, skillID)
  local s, saved = ns.GetSkill(skillID)
  local w = ns.bySkill[skillID]
  tooltip:AddLine((s and s.name) or ns.WeaponName(w))
  if not s then
    tooltip:AddLine("Not learned.", 1, 0.3, 0.3)
    return
  end
  tooltip:AddDoubleLine("Skill", ("%d / %d"):format(s.rank, s.max), 1, 1, 1, 1, 1, 1)
  if (s.mod or 0) > 0 then tooltip:AddDoubleLine("Bonus from gear", "+" .. s.mod, 1, 1, 1, 0.25, 1, 0.25) end
  if saved then tooltip:AddLine("Last known values (the game is hiding them right now).", 0.6, 0.6, 0.6, true) end
  if s.rank >= s.max then
    tooltip:AddLine("Maxed for your level.", 0.25, 1, 0.25)
    return
  end
  local prog = ns.GetProgress(skillID)
  if prog then
    tooltip:AddDoubleLine("Swings since last point (est.)", math.floor(prog.swings + 0.5), 1, 1, 1, 1, 1, 1)
    if prog.expected then
      tooltip:AddDoubleLine("Swings per point lately (est.)", math.floor(prog.expected + 0.5), 1, 1, 1, 1, 1, 1)
    else
      tooltip:AddLine("Honewright learns how many swings a point takes from your next skill-up.", 0.6, 0.6, 0.6, true)
    end
  end
end

local function OnEnter(self)
  if not GameTooltip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.Colored(ns.ACCENT, "Honewright"))
  for _, r in ipairs(rows) do
    if r:IsShown() and r.skillID then
      GameTooltip:AddLine(" ")
      ns.AddSkillDetails(GameTooltip, r.skillID)
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Swings are estimated from how long your auto-attack runs in combat: the game doesn't let addons count real swings.", 0.6, 0.6, 0.6, true)
  GameTooltip:AddLine(ns.Setting("panelLocked") and "Click: weapons you could learn." or "Drag to move. Click: weapons you could learn.", 0.6, 0.8, 1, true)
  GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Building the panel
---------------------------------------------------------------------------

local function Build()
  local f = CreateFrame("Frame", "HonewrightPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(WIDTH, PAD * 2 + ROW_H)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  if f.SetBackdrop then
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0, 0, 0, 0.55)
    f:SetBackdropBorderColor(0.88, 0.66, 0.29, 0.6)
  end
  local pos = ns.char.panelPos
  if pos and pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 280, -160)
  end
  f:SetScript("OnDragStart", function(self)
    if not ns.Setting("panelLocked") and not ns.InCombat() then self:StartMoving() self.moving = true end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
    C_Timer.After(0, function() self.moving = nil end)
  end)
  f:SetScript("OnMouseUp", function(self, button)
    if self.moving then return end
    if button == "LeftButton" and ns.ToggleLearnWindow then ns.ToggleLearnWindow() end
  end)
  f:SetScript("OnEnter", OnEnter)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- progress moves during fights: refresh about once a second
  local since = 0
  f:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since >= 1 then since = 0 ns.UpdatePanel() end
  end)
  panel = f
  ns.panel = f
end

function ns.ResetPanelPosition()
  if not panel then return end
  ns.char.panelPos = nil
  panel:ClearAllPoints()
  panel:SetPoint("CENTER", UIParent, "CENTER", 280, -160)
end

ns.Listen("LOADED", function()
  ns.On("PLAYER_LOGIN", function() Build() ns.UpdatePanel() end)
  ns.On("PLAYER_EQUIPMENT_CHANGED", function() ns.equipped = nil ns.UpdatePanel() end)
end)
ns.Listen("SKILLS_UPDATED", function() ns.UpdatePanel() end)
ns.Listen("SETTING_CHANGED", function() ns.UpdatePanel() end)
