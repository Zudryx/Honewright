-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: diagnostics saved to HonewrightDB.diag (in the account's
-- SavedVariables\Honewright.lua). They record what WoW Forever let
-- Honewright read while you played, so a bug report can be the file itself.
-- Nothing here changes how Honewright works, and it's reset for each new
-- version so it stays small. /hone probe results are saved here too.

local ADDON, ns = ...

local MAX_SKILLUPS, MAX_TRAINERS, MAX_PROBES = 20, 4, 4

function ns.Diag()
  local db = ns.db
  if not db then return nil end
  local d = db.diag
  if not d or d.version ~= ns.VERSION then
    local _, build, _, iface = GetBuildInfo()
    d = {
      version = ns.VERSION, client = tostring(build) .. " / " .. tostring(iface),
      reads = { outOfCombat = 0, inCombat = 0, hiddenOutOfCombat = 0, hiddenInCombat = 0 },
      skillUps = { count = {}, recent = {} },
      chatSkill = { readable = 0, hidden = 0 },
      attackSpeed = { readableInCombat = 0, hiddenInCombat = 0 },
      trainers = { opened = 0, weaponMasters = 0, recent = {} },
      events = {},
      probes = {},
    }
    db.diag = d
  end
  return d
end

local function Push(list, item, max)
  list[#list + 1] = item
  while #list > max do table.remove(list, 1) end
end

local function Stamp() return date and date("%Y-%m-%d %H:%M:%S") or "?" end

-- every time Honewright reads the skill list
function ns.DiagRead(hidden)
  local d = ns.Diag()
  if not d then return end
  local r = d.reads
  if ns.InCombat() then
    r.inCombat = r.inCombat + 1
    if hidden then r.hiddenInCombat = r.hiddenInCombat + 1 end
  else
    r.outOfCombat = r.outOfCombat + 1
    if hidden then r.hiddenOutOfCombat = r.hiddenOutOfCombat + 1 end
  end
end

-- every trainer window you open
function ns.DiagTrainer(npc, services, matched, raw)
  local d = ns.Diag()
  if not d then return end
  if matched > 0 then d.trainers.weaponMasters = d.trainers.weaponMasters + 1 end
  local known = false
  for _, t in ipairs(ns.TRAINERS) do if t.name == npc then known = true end end
  -- keep the full list only for weapon masters (by name or by what they teach)
  if known or matched > 0 then
    Push(d.trainers.recent, { npc = npc, at = Stamp(), services = services, matched = matched, listed = raw }, MAX_TRAINERS)
  end
end

-- /hone probe: keep its lines (without colors)
function ns.DiagProbe(lines)
  local d = ns.Diag()
  if not d then return end
  local clean = {}
  for _, l in ipairs(lines) do
    clean[#clean + 1] = (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end
  Push(d.probes, { at = Stamp(), inCombat = ns.InCombat(), lines = clean }, MAX_PROBES)
end

local WATCH = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
  "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "TRAINER_SHOW", "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_SUCCEEDED" }

ns.Listen("SKILL_UP", function(_, skillID, oldRank, newRank, max, source)
  local d = ns.Diag()
  if not d then return end
  d.skillUps.count[source or "?"] = (d.skillUps.count[source or "?"] or 0) + 1
  local p = ns.char and ns.char.progress[skillID]
  local last = p and p.samples[#p.samples]
  Push(d.skillUps.recent, {
    skill = skillID, from = oldRank, to = newRank, max = max, source = source, at = Stamp(),
    inCombat = ns.InCombat(), swingsForPoint = last and math.floor(last.swings + 0.5) or nil,
  }, MAX_SKILLUPS)
end)

ns.Listen("LOADED", function()
  ns.Diag()
  ns.On("TRAINER_SHOW", function()
    local d = ns.Diag()
    if d then d.trainers.opened = d.trainers.opened + 1 end
  end)
  ns.On("CHAT_MSG_SKILL", function(_, text)
    local d = ns.Diag()
    if not d then return end
    if ns.IsHidden(text) then d.chatSkill.hidden = d.chatSkill.hidden + 1
    else
      d.chatSkill.readable = d.chatSkill.readable + 1
      d.chatSkill.last = tostring(text)
    end
  end)
  -- is the weapon speed readable once a fight has started?
  ns.On("PLAYER_REGEN_DISABLED", function()
    if not C_Timer or not UnitAttackSpeed then return end
    C_Timer.After(2, function()
      local d = ns.Diag()
      if not d or not ns.InCombat() then return end
      local ok, main = pcall(UnitAttackSpeed, "player")
      if ok and not ns.IsHidden(main) then d.attackSpeed.readableInCombat = d.attackSpeed.readableInCombat + 1
      else d.attackSpeed.hiddenInCombat = d.attackSpeed.hiddenInCombat + 1 end
    end)
  end)
  -- how often the events Honewright relies on arrived (added up over the version)
  ns.On("PLAYER_LOGOUT", function()
    local d = ns.Diag()
    if not d then return end
    for _, ev in ipairs(WATCH) do
      d.events[ev] = (d.events[ev] or 0) + (ns.eventCounts[ev] or 0)
    end
  end)
end)
