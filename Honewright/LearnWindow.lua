-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: the weapon list (/hone learn, or click the panel). Every
-- weapon type your class can use: your skill in the ones you know, and for
-- the rest, which weapon master teaches it, where, and what it costs, with a
-- button to pin them on your map.

local ADDON, ns = ...

local ROW_H, WIDTH = 34, 560
local win
local rows = {}

local CLASS_NAMES = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

-- One entry per weapon type for your class, for the window and the tests.
-- { w, learned, skill (table or nil), trainers (list), new (added in Forever) }
function ns.LearnList(classToken)
  classToken = classToken or ns.PlayerClass()
  local out = {}
  for _, key in ipairs(ns.CLASS_WEAPONS[classToken] or {}) do
    local w = ns.WEAPONS[key]
    local learned = ns.IsLearned(w)
    out[#out + 1] = {
      order = #out,
      w = w,
      learned = learned,
      skill = learned and ns.GetSkill(w.skill) or nil,
      trainers = learned and {} or ns.TrainersFor(w),
      new = ns.NEW_IN_FOREVER[classToken] and ns.NEW_IN_FOREVER[classToken][key] or false,
    }
  end
  -- not learned first (that's what the window is for), otherwise the usual order
  table.sort(out, function(a, b)
    if a.learned ~= b.learned then return not a.learned end
    return a.order < b.order
  end)
  return out
end

local function SpellIcon(w)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, w.spell)
    if ok and tex and not ns.IsHidden(tex) then return tex end
  end
  return "Interface\\Icons\\INV_Sword_04"
end

local function Row(i)
  if rows[i] then return rows[i] end
  local r = CreateFrame("Frame", nil, win.content)
  r:SetSize(WIDTH - 40, ROW_H)
  r:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(24, 24)
  r.icon:SetPoint("LEFT", r, "LEFT", 0, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
  r.name:SetJustifyH("LEFT")
  r.detail = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.detail:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
  r.detail:SetPoint("RIGHT", r, "RIGHT", -70, 0)
  r.detail:SetJustifyH("LEFT")
  r.detail:SetWordWrap(false)
  r.pin = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.pin:SetSize(60, 20)
  r.pin:SetPoint("RIGHT", r, "RIGHT", 0, 0)
  r.pin:SetText("Pin")
  r.pin:SetScript("OnClick", function(self) if self.trainer then ns.PinTrainer(self.trainer) end end)
  r.pin:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.trainer then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Put a pin on your map at " .. self.trainer.name .. ".")
    GameTooltip:Show()
  end)
  r.pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    if not GameTooltip or not self.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local e = self.entry
    if e.learned then
      ns.AddSkillDetails(GameTooltip, e.w.skill)
    else
      GameTooltip:AddLine(ns.WeaponName(e.w))
      if #e.trainers == 0 then GameTooltip:AddLine("No weapon master teaches this for your faction.", 1, 0.3, 0.3, true) end
      for _, t in ipairs(e.trainers) do GameTooltip:AddLine(ns.TrainerLine(t, e.w), 1, 1, 1, true) end
      GameTooltip:AddLine(ns.COST_NOTE, 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  rows[i] = r
  return r
end

function ns.UpdateLearnWindow()
  if not win or not win:IsShown() then return end
  local class = ns.PlayerClass()
  local list = ns.LearnList(class)
  win.heading:SetText(("Weapon types a %s can use"):format(CLASS_NAMES[class] or "character"))
  for i, e in ipairs(list) do
    local r = Row(i)
    r.entry = e
    r.icon:SetTexture(SpellIcon(e.w))
    r.icon:SetDesaturated(not e.learned)
    local name = ns.WeaponName(e.w)
    if e.new then name = name .. ns.Colored("40c0ff", "  new in Forever") end
    r.name:SetText(name)
    r.pin.trainer = nil
    r.pin:Hide()
    if e.learned then
      local s = e.skill
      if s and s.rank and s.max then
        local text = ("Skill %s / %d"):format(ns.Colored(ns.GapColor(s.rank, s.max), s.rank), s.max)
        local prog = ns.ProgressText(e.w.skill, s)
        if prog ~= "" then text = text .. "   " .. prog end
        r.detail:SetText(text)
      else
        r.detail:SetText("Learned")
      end
    elseif e.w.noTrainer then
      r.detail:SetText(ns.Colored("999999", "Not taught by weapon masters."))
    elseif #e.trainers == 0 then
      r.detail:SetText(ns.Colored("999999", "No weapon master for your faction teaches this."))
    else
      local t = e.trainers[1]
      local text = ns.TrainerLine(t, e.w)
      if #e.trainers > 1 then text = text .. ns.Colored("999999", ("  (+%d more, hover)"):format(#e.trainers - 1)) end
      r.detail:SetText(ns.Colored("ff6060", "Not learned. ") .. text)
      r.pin.trainer = t
      r.pin:Show()
    end
    r:Show()
  end
  for i = #list + 1, #rows do rows[i]:Hide() end
  win:SetHeight(110 + #list * ROW_H)
end

local function Build()
  local ok, f = pcall(CreateFrame, "Frame", "HonewrightLearnWindow", UIParent, "BasicFrameTemplateWithInset")
  if not ok or not f then
    f = CreateFrame("Frame", "HonewrightLearnWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
      f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
  end
  f:SetSize(WIDTH, 400)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", f, "TOP", 0, -6)
  f.title:SetText("|TInterface\\AddOns\\Honewright\\Media\\Icon:14:14|t " .. ns.Colored(ns.ACCENT, "Honewright") .. ": weapon skills")
  f.heading = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -34)
  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -62)
  f.content:SetSize(WIDTH - 40, 10)
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  f.note:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 14)
  f.note:SetPoint("RIGHT", f, "RIGHT", -20, 0)
  f.note:SetJustifyH("LEFT")
  f.note:SetText(ns.COST_NOTE .. " Progress is estimated from your auto-attack time.")
  f:SetScript("OnShow", function() ns.UpdateLearnWindow() end)
  f:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "HonewrightLearnWindow") end   -- Esc closes it
  win = f
  ns.learnWindow = f
end

function ns.ToggleLearnWindow(show)
  if not win then Build() end
  if show == nil then show = not win:IsShown() end
  if show then win:Show() ns.UpdateLearnWindow() else win:Hide() end
end

ns.Listen("SKILLS_UPDATED", function() ns.UpdateLearnWindow() end)
ns.Listen("LOADED", function()
  ns.On("TRAINER_CLOSED", function() ns.UpdateLearnWindow() end)
end)
