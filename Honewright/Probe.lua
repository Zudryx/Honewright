-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: /hone probe
-- Reports what WoW Forever lets Honewright read on your client, so a test
-- run shows straight away if something is hidden. Run it once out of combat
-- and once while auto-attacking a mob.

local ADDON, ns = ...

local skillMsgs = { readable = 0, hidden = 0, last = nil }

local function Show(v)
  if ns.IsHidden(v) then return "|cffff5555HIDDEN|r" end
  if v == nil then return "nil" end
  return tostring(v)
end

local function Has(path)
  local t = _G
  for part in path:gmatch("[^%.]+") do
    if type(t) ~= "table" then return false end
    t = t[part]
  end
  return t ~= nil
end

local function YesNo(b) return b and "|cff40ff40yes|r" or "|cffff5555no|r" end

function ns.Probe()
  local lines = {}
  local function P(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    lines[#lines + 1] = table.concat(parts, " ")
    ns.Print(...)
  end
  local _, _, _, iface = GetBuildInfo()
  P(("probe, Honewright %s, interface %s, %s"):format(ns.VERSION, Show(iface),
    ns.InCombat() and "IN COMBAT" or "out of combat"))

  P("Game functions:")
  for _, api in ipairs({ "C_SkillInfo.GetSkillLineInfoByID", "C_SkillInfo.GetNumSkillLines", "GetSkillLineInfo",
      "IsPlayerSpell", "UnitAttackSpeed", "UnitRangedDamage", "GetNumTrainerServices", "GetTrainerServiceCost",
      "C_Map.SetUserWaypoint", "TooltipDataProcessor.AddTooltipPostCall", "issecretvalue" }) do
    P(("  %s: %s"):format(api, YesNo(Has(api))))
  end

  P("Weapon skills (straight from the game):")
  local any = false
  for _, key in ipairs(ns.WEAPON_ORDER) do
    local w = ns.WEAPONS[key]
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
      local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, w.skill)
      if ok and type(info) == "table" and (ns.IsHidden(info.maxRank) or (ns.Num(info.maxRank) or 0) > 0) then
        any = true
        P(("  %s [%d]: rank %s, max %s, bonus %s, name %s"):format(w.name, w.skill, Show(info.rank),
          Show(info.maxRank), Show(info.modifier), Show(info.name)))
      elseif not ok then
        P(("  %s: error %s"):format(w.name, tostring(info):sub(1, 60)))
      end
    end
  end
  if not any then
    local s = ns.ReadSkill(ns.WEAPONS.SWORD1H.skill)
    P("  nothing from the by-ID call" .. (s and " (the skill list fallback works)" or ""))
  end
  P(("  Re-read pending after combat: %s"):format(ns.pendingRead and "yes" or "no"))

  P("Equipped:")
  for _, e in ipairs(ns.EquippedWeapons()) do
    local s, saved = ns.GetSkill(e.w.skill)
    P(("  %s: %s, skill %s%s, learned %s"):format(ns.SLOT_LABEL[e.slot], ns.WeaponName(e.w),
      s and (s.rank .. "/" .. s.max) or "?", saved and " (saved copy)" or "", tostring(ns.IsLearned(e.w))))
  end

  P("Attack timing:")
  if UnitAttackSpeed then
    local main, off = UnitAttackSpeed("player")
    P(("  UnitAttackSpeed: %s, %s"):format(Show(main), Show(off)))
  end
  if UnitRangedDamage then P(("  UnitRangedDamage speed: %s"):format(Show((UnitRangedDamage("player"))))) end
  local melee, ranged, combat = ns.AttackState()
  P(("  Auto-attack on: %s, auto-repeat on: %s, in combat: %s"):format(tostring(melee), tostring(ranged), tostring(combat)))
  local counts = ns.eventCounts
  for _, ev in ipairs({ "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL",
      "STOP_AUTOREPEAT_SPELL", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRAINER_SHOW" }) do
    P(("  %s seen %d time(s)"):format(ev, counts[ev] or 0))
  end
  P(("  Skill-up chat lines: %d readable, %d hidden%s"):format(skillMsgs.readable, skillMsgs.hidden,
    skillMsgs.last and (", last: " .. skillMsgs.last) or ""))

  P("Maps:")
  if C_Map and C_Map.GetBestMapForUnit then
    local id = C_Map.GetBestMapForUnit("player")
    local info = id and not ns.IsHidden(id) and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
    P(("  You're on map %s (%s)"):format(Show(id), info and Show(info.name) or "?"))
  end
  for _, city in ipairs({ "Stormwind", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity" }) do
    local id, sure = ns.CityMapID(city)
    P(("  %s: map %s%s"):format(city, tostring(id), sure and " (seen there)" or " (guess)"))
  end
  local seen = 0
  for _ in pairs(ns.db.trainersSeen) do seen = seen + 1 end
  P(("  Weapon masters visited: %d"):format(seen))
  if ns.DiagProbe then ns.DiagProbe(lines) end
  ns.Print("Saved to SavedVariables\\Honewright.lua too (after you log out or /reload).")
end

ns.Listen("LOADED", function()
  ns.On("CHAT_MSG_SKILL", function(_, text)
    if ns.IsHidden(text) then skillMsgs.hidden = skillMsgs.hidden + 1
    else
      skillMsgs.readable = skillMsgs.readable + 1
      skillMsgs.last = tostring(text)
    end
  end)
end)
