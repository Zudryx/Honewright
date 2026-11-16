-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: reading your weapon skills and equipped weapons.
--
-- Skill values come from the game's skill list (C_SkillInfo on WoW Forever;
-- the older GetSkillLineInfo where that's missing). A skill-up is noticed
-- when a rank goes up between two reads. If the game hides the numbers
-- during a fight, Honewright reads them again as soon as the fight ends,
-- and the skill-up message in chat (when it isn't hidden) fills the gap.

local ADDON, ns = ...

local SLOT_MAIN, SLOT_OFF, SLOT_RANGED = 16, 17, 18
ns.WEAPON_SLOTS = { SLOT_MAIN, SLOT_OFF, SLOT_RANGED }
ns.SLOT_LABEL = { [SLOT_MAIN] = "Main hand", [SLOT_OFF] = "Off hand", [SLOT_RANGED] = "Ranged" }

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------

-- The weapon type's name in the game's language, e.g. "One-Handed Swords".
function ns.WeaponName(w)
  if not w then return "?" end
  if not w._name then
    local name
    if C_Item and C_Item.GetItemSubClassInfo then
      local ok, n = pcall(C_Item.GetItemSubClassInfo, 2, w.sub)
      if ok then name = ns.Str(n) end
    end
    if not name and GetItemSubClassInfo then
      local ok, n = pcall(GetItemSubClassInfo, 2, w.sub)
      if ok then name = ns.Str(n) end
    end
    w._name = name or w.name
  end
  return w._name
end

---------------------------------------------------------------------------
-- Reading one skill
---------------------------------------------------------------------------

local function FromAttributes(info)
  if type(info) ~= "table" then return nil end
  local rank, max = ns.Num(info.rank), ns.Num(info.maxRank)
  if ns.IsHidden(info.rank) or ns.IsHidden(info.maxRank) then return { hidden = true } end
  if not rank or not max then return nil end
  return { rank = rank, max = max, mod = ns.Num(info.modifier) or 0, name = ns.Str(info.name) }
end

-- Look through the whole skill list (for clients without the by-ID call).
-- Collapsed headers hide their skills, so this only finds what's expanded.
local function ScanList(skillID, wantName)
  if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
    local n = ns.Num(C_SkillInfo.GetNumSkillLines()) or 0
    for i = 1, n do
      local ok, info = pcall(C_SkillInfo.GetSkillLineInfo, i)
      if ok and type(info) == "table" and not info.isHeader then
        if ns.Num(info.skillID) == skillID or (wantName and ns.Str(info.name) == wantName) then
          return FromAttributes(info)
        end
      end
    end
    return nil
  end
  if GetNumSkillLines and GetSkillLineInfo then
    local n = ns.Num(GetNumSkillLines()) or 0
    for i = 1, n do
      local name, header, _, rank, _, mod, max = GetSkillLineInfo(i)
      if not header and wantName and ns.Str(name) == wantName then
        if ns.IsHidden(rank) or ns.IsHidden(max) then return { hidden = true } end
        return { rank = ns.Num(rank), max = ns.Num(max), mod = ns.Num(mod) or 0, name = name }
      end
    end
  end
  return nil
end

-- Returns { rank, max, mod, name } for a learned skill, { hidden = true }
-- when the game hides it right now, or nil when it isn't learned.
function ns.ReadSkill(skillID)
  if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
    local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, skillID)
    if ok then
      local s = FromAttributes(info)
      -- a learned skill is at least 1; some clients answer for unlearned ones with 0
      if s and (s.hidden or ((s.max or 0) > 0 and (s.rank or 0) > 0)) then return s end
    end
  end
  local w = ns.bySkill[skillID]
  local cached = ns.char and ns.char.skills[skillID]
  return ScanList(skillID, cached and cached.name or (w and ns.WeaponName(w)))
end

-- Do you know how to use this weapon type?
function ns.IsLearned(w)
  if not w then return false end
  if IsPlayerSpell then
    local ok, known = pcall(IsPlayerSpell, w.spell)
    if ok and known and not ns.IsHidden(known) then return true end
  end
  local s = ns.ReadSkill(w.skill)
  if s and s.hidden then
    local cached = ns.char and ns.char.skills[w.skill]
    return cached ~= nil
  end
  return s ~= nil and (s.max or 0) > 0
end

-- The latest known values for a skill: read now, or the last good read when
-- the game is hiding them. Second return is true when it's the saved copy.
function ns.GetSkill(skillID)
  local s = ns.ReadSkill(skillID)
  if s and not s.hidden then return s, false end
  local cached = ns.char and ns.char.skills[skillID]
  if cached then return cached, true end
  return nil, false
end

---------------------------------------------------------------------------
-- Equipped weapons
---------------------------------------------------------------------------

local function ItemWeapon(itemID)
  if not itemID then return nil end
  local classID, subclassID
  if C_Item and C_Item.GetItemInfoInstant then
    local ok, _, _, _, _, _, c, s = pcall(C_Item.GetItemInfoInstant, itemID)
    if ok then classID, subclassID = c, s end
  elseif GetItemInfoInstant then
    local ok, _, _, _, _, _, c, s = pcall(GetItemInfoInstant, itemID)
    if ok then classID, subclassID = c, s end
  end
  if ns.Num(classID) ~= 2 then return nil end
  return ns.bySubclass[ns.Num(subclassID)]
end
ns.ItemWeapon = ItemWeapon

-- { slot, itemID, w } for each equipped weapon, main hand first. Two slots
-- with the same weapon type are both listed (the panel merges them).
function ns.EquippedWeapons()
  local out = {}
  for _, slot in ipairs(ns.WEAPON_SLOTS) do
    local itemID = ns.Num(GetInventoryItemID("player", slot))
    local w = ItemWeapon(itemID)
    if w then out[#out + 1] = { slot = slot, itemID = itemID, w = w } end
  end
  return out
end

---------------------------------------------------------------------------
-- Keeping the saved copy current, and noticing skill-ups
---------------------------------------------------------------------------

ns.pendingRead = false   -- true while the game is hiding skills (re-read after the fight)

-- Read every weapon skill. Fires HW_SKILL_UP for each rank that went up
-- since the last read, and HW_SKILLS_UPDATED once at the end.
function ns.RefreshSkills(source)
  if not ns.char then return end
  local skills = ns.char.skills
  local hiddenAny = false
  for _, key in ipairs(ns.WEAPON_ORDER) do
    local w = ns.WEAPONS[key]
    local s = ns.ReadSkill(w.skill)
    if s and s.hidden then
      hiddenAny = true
    elseif s then
      local old = skills[w.skill]
      skills[w.skill] = { rank = s.rank, max = s.max, mod = s.mod, name = s.name or (old and old.name) }
      if old and old.rank and s.rank > old.rank then
        ns.Fire("SKILL_UP", w.skill, old.rank, s.rank, s.max, source or "read")
      elseif not old and ns.skillsReady then
        ns.Fire("SKILL_LEARNED", w.skill, s.rank, s.max)
      end
    elseif skills[w.skill] and not ns.IsLearned(w) then
      skills[w.skill] = nil   -- unlearned at a trainer
    end
  end
  ns.pendingRead = hiddenAny
  ns.skillsReady = true
  ns.Fire("SKILLS_UPDATED")
end

-- "Your skill in %s has increased to %d." -> a Lua pattern with captures.
local function SkillUpPattern()
  local fmt = ns.Str(ERR_SKILL_UP_SI) or "Your skill in %s has increased to %d."
  local p = fmt:gsub("([%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")
  p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. p .. "$"
end

-- Backup for when the game hides skill values in a fight but shows the chat
-- message: take the new rank from the message.
function ns.OnSkillMessage(text)
  text = ns.Str(text)
  if not text or not ns.char then return false end
  local name, rank = text:match(SkillUpPattern())
  rank = tonumber(rank)
  if not name or not rank then return false end
  for _, key in ipairs(ns.WEAPON_ORDER) do
    local w = ns.WEAPONS[key]
    local cached = ns.char.skills[w.skill]
    if cached and (cached.name == name or ns.WeaponName(w) == name) then
      if cached.rank and rank > cached.rank then
        local old = cached.rank
        cached.rank = rank
        ns.Fire("SKILL_UP", w.skill, old, rank, cached.max, "chat")
        ns.Fire("SKILLS_UPDATED")
      end
      return true
    end
  end
  return false
end

ns.Listen("LOADED", function()
  ns.On("PLAYER_LOGIN", function() ns.RefreshSkills("login") end)
  ns.On("SKILL_LINES_CHANGED", function() ns.RefreshSkills("event") end)
  ns.On("PLAYER_LEVEL_UP", function()
    -- max skill goes up a moment after the level; read again shortly
    if C_Timer then C_Timer.After(1, function() ns.RefreshSkills("level") end) end
  end)
  ns.On("LEARNED_SPELL_IN_TAB", function() ns.RefreshSkills("learned") end)
  ns.On("PLAYER_REGEN_ENABLED", function()
    if ns.pendingRead then ns.RefreshSkills("after combat") end
  end)
  ns.On("CHAT_MSG_SKILL", function(_, text)
    if not ns.OnSkillMessage(text) then ns.RefreshSkills("chat") end
  end)
end)
