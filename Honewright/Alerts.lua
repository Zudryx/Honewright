-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: on-screen alerts. A skill-up, a weapon reaching max for your
-- level, and a warning when you equip a weapon whose skill is far below max.

local ADDON, ns = ...

---------------------------------------------------------------------------
-- The alert banner
---------------------------------------------------------------------------

local banner
local SHOW_FOR = 3.5

local function Banner()
  if banner then return banner end
  local f = CreateFrame("Frame", "HonewrightAlert", UIParent)
  f:SetSize(460, 64)
  f:SetPoint("TOP", UIParent, "TOP", 0, -170)
  f:SetFrameStrata("HIGH")
  f:EnableMouse(false)
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(36, 36)
  f.icon:SetPoint("LEFT", f, "LEFT", 0, 0)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
  f.title:SetJustifyH("LEFT")
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.text:SetWidth(410)
  f.text:SetJustifyH("LEFT")
  f:Hide()
  f.shownAt = 0
  f:SetScript("OnUpdate", function(self)
    local age = GetTime() - self.shownAt
    if age > SHOW_FOR + 1 then self:Hide()
    elseif age > SHOW_FOR then self:SetAlpha(1 - (age - SHOW_FOR)) end
  end)
  banner = f
  return f
end

-- title / text may hold color codes. icon is a texture path or file ID.
function ns.ShowAlert(title, text, icon)
  local f = Banner()
  f.title:SetText(title or "")
  f.text:SetText(text or "")
  f.icon:SetTexture(icon or "Interface\\AddOns\\Honewright\\Media\\Icon")
  f:SetAlpha(1)
  f.shownAt = GetTime()
  f:Show()
end

local function Sound(kind)
  if not ns.Setting("skillUpSound") or not PlaySound then return end
  local kit = SOUNDKIT or {}
  local id = (kind == "warn" and (kit.RAID_WARNING or 8959))
    or (kind == "max" and (kit.UI_QUEST_ROLLING_FORWARD_01 or kit.IG_QUEST_LIST_COMPLETE or 878))
    or (kit.IG_QUEST_LIST_COMPLETE or 878)
  pcall(PlaySound, id, "Master")
end

local function WeaponIcon(skillID)
  for _, e in ipairs(ns.EquippedWeapons()) do
    if e.w.skill == skillID then
      local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", e.slot)
      if tex and not ns.IsHidden(tex) then return tex end
    end
  end
  local w = ns.bySkill[skillID]
  if w and C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, w.spell)
    if ok and tex and not ns.IsHidden(tex) then return tex end
  end
  return nil
end

---------------------------------------------------------------------------
-- Skill-ups
---------------------------------------------------------------------------

local function SkillLabel(skillID)
  local w = ns.bySkill[skillID]
  local s = ns.char and ns.char.skills[skillID]
  return (s and s.name) or (w and ns.WeaponName(w)) or "Weapon skill"
end

function ns.OnSkillUp(skillID, oldRank, newRank, max, source)
  if source == "login" then return end
  local name = SkillLabel(skillID)
  local color = ns.GapColor(newRank, max)
  local maxed = max and newRank >= max
  if maxed and ns.Setting("maxedAlert") then
    ns.ShowAlert(ns.Colored("40ff40", name .. " maxed"),
      ("%d / %d: as good as it gets at your level. It goes up again when you level."):format(newRank, max),
      WeaponIcon(skillID))
    Sound("max")
  elseif ns.Setting("skillUpAlert") then
    local gained = newRank - (oldRank or newRank)
    local line = ("%s / %d   (+%d)"):format(ns.Colored(color, newRank), max or 0, math.max(1, gained))
    local prog = ns.GetProgress(skillID)
    if prog and prog.expected then
      line = line .. ("   about %d swings a point lately"):format(math.floor(prog.expected + 0.5))
    end
    ns.ShowAlert(name, line, WeaponIcon(skillID))
    Sound("up")
  end
  if ns.Setting("skillUpChat") then
    ns.Print(("%s %s / %d"):format(name, ns.Colored(color, newRank), max or 0))
  end
end

ns.Listen("SKILL_UP", function(_, ...) ns.OnSkillUp(...) end)

ns.Listen("SKILL_LEARNED", function(_, skillID, rank, max)
  local name = SkillLabel(skillID)
  ns.ShowAlert(name .. " learned",
    ("%d / %d. It starts low: fight with it to raise it, ideally on easy mobs first."):format(rank or 1, max or 0),
    WeaponIcon(skillID))
  Sound("up")
end)

---------------------------------------------------------------------------
-- Equipping an under-trained weapon
---------------------------------------------------------------------------

local lastWarned = {}   -- skillID -> time, so swapping back and forth doesn't spam
local WARN_EVERY = 60

-- Returns the warning text for a weapon type, or nil when its skill is fine.
function ns.EquipWarningText(w)
  local s = ns.GetSkill(w.skill)
  if not s or not s.rank or not s.max then return nil end
  local gap = s.max - s.rank
  if gap < (ns.Setting("warnGap") or 25) then return nil end
  return ("%s / %d: %d below max. Until it catches up you'll miss, and hit for less, a lot more often against enemies your level. Fighting with it is how it goes up.")
    :format(ns.Colored(ns.GapColor(s.rank, s.max), s.rank), s.max, gap), s, gap
end

function ns.CheckEquippedWarning(slot)
  if not ns.Setting("equipWarning") or not ns.skillsReady then return end
  local itemID = ns.Num(GetInventoryItemID("player", slot))
  local w = ns.ItemWeapon(itemID)
  if not w then return end
  local text = ns.EquipWarningText(w)
  if not text then return end
  local now = GetTime()
  if lastWarned[w.skill] and now - lastWarned[w.skill] < WARN_EVERY then return end
  lastWarned[w.skill] = now
  local name = SkillLabel(w.skill)
  local tex = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
  ns.ShowAlert(ns.Colored("ff9030", name .. " is under-trained"), text, (tex and not ns.IsHidden(tex)) and tex or nil)
  ns.Print(ns.Colored("ff9030", name .. ":") .. " " .. text)
  Sound("warn")
end

ns.Listen("LOADED", function()
  ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot, isEmpty)
    if slot ~= 16 and slot ~= 17 and slot ~= 18 then return end
    if isEmpty then return end
    -- let the game finish the swap (and update the skill list) first
    if C_Timer then C_Timer.After(0.3, function() ns.CheckEquippedWarning(slot) end)
    else ns.CheckEquippedWarning(slot) end
  end)
end)
