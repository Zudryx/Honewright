-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: core (namespace, saved variables, events, shared helpers)
--
-- Honewright only reads and shows information. It never attacks, equips,
-- buys training or does anything else for you.

local ADDON, ns = ...

ns.VERSION = "0.1.2"
ns.ACCENT = "4ade80"   -- the logo's green progress ring
local PREFIX = "|cff" .. ns.ACCENT .. "Honewright|r: "

function ns.Print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

function ns.Debug(...)
  if HonewrightDB and HonewrightDB.debug then ns.Print("|cff888888[debug]|r", ...) end
end

---------------------------------------------------------------------------
-- Values the game may hide from addons
---------------------------------------------------------------------------

-- WoW Forever runs on the modern engine, which can hand addons "secret"
-- values during combat. They can be shown by the game's own UI but not read
-- or compared by addons. Anything that might be secret goes through here
-- first; a hidden value is treated as "not known right now".
function ns.IsHidden(v)
  if v == nil then return false end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, v)
    if ok and secret then return true end
  end
  local ok = pcall(function() local _ = (v == v) and tostring(v) end)
  return not ok
end

-- A plain number, or nil when it's missing or hidden.
function ns.Num(v)
  if v == nil or ns.IsHidden(v) then return nil end
  return tonumber(v)
end

-- A plain string, or nil when it's missing or hidden.
function ns.Str(v)
  if v == nil or ns.IsHidden(v) then return nil end
  if type(v) ~= "string" then return nil end
  return v
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

ns.DEFAULTS = {
  panel = true,            -- the on-screen panel
  panelLocked = false,
  panelHideMaxed = false,  -- hide the panel while every equipped weapon is maxed
  panelProgress = true,    -- show progress toward the next point on the panel
  tooltip = true,          -- lines in weapon tooltips
  tooltipTrainers = true,  -- where to learn weapons you don't know, in tooltips
  equipWarning = true,
  warnGap = 25,            -- warn when an equipped weapon's skill is this far below max
  skillUpAlert = true,     -- on-screen alert for every skill-up
  skillUpSound = true,
  skillUpChat = false,     -- a line in chat too (the game already prints its own)
  maxedAlert = true,       -- extra alert when a weapon reaches max for your level
}

local function ApplyDefaults(db, defaults)
  for k, v in pairs(defaults) do
    if db[k] == nil then db[k] = v end
  end
end

local function InitDB()
  HonewrightDB = HonewrightDB or {}
  local db = HonewrightDB
  db.settings = db.settings or {}
  ApplyDefaults(db.settings, ns.DEFAULTS)
  db.trainersSeen = db.trainersSeen or {}   -- what weapon masters really teach and charge, from their windows
  db.mapIDs = db.mapIDs or {}               -- city name -> map ID, learned when you're in the city

  HonewrightCharDB = HonewrightCharDB or {}
  local char = HonewrightCharDB
  char.skills = char.skills or {}           -- skillID -> { rank, max, mod } last read
  char.progress = char.progress or {}       -- skillID -> estimated swings since the last point + recent samples
  char.panelPos = char.panelPos
  ns.db, ns.char, ns.settings = db, char, db.settings
end

function ns.Setting(key)
  local s = ns.settings
  if s and s[key] ~= nil then return s[key] end
  return ns.DEFAULTS[key]
end

function ns.SetSetting(key, value)
  if ns.settings then ns.settings[key] = value end
  ns.Fire("SETTING_CHANGED", key, value)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

-- Game events go to every module that asked for them, each in its own pcall
-- so one module's error can't stop the others.
local handlers = {}
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    if not event:find("^HW_") then
      pcall(eventFrame.RegisterEvent, eventFrame, event)
    end
  end
  table.insert(handlers[event], fn)
end

local function Dispatch(event, ...)
  local list = handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, event, ...)
    if not ok then ns.Debug(event, err) end
  end
end

-- Honewright's own messages between modules (prefixed HW_ so they never
-- collide with game events).
function ns.Fire(message, ...)
  Dispatch("HW_" .. message, ...)
end

function ns.Listen(message, fn)
  ns.On("HW_" .. message, fn)
end

ns.eventCounts = {}   -- for /hone probe: which game events actually arrived
eventFrame:SetScript("OnEvent", function(_, event, ...)
  ns.eventCounts[event] = (ns.eventCounts[event] or 0) + 1
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    InitDB()
    Dispatch("HW_LOADED")
    return
  end
  Dispatch(event, ...)
end)
eventFrame:RegisterEvent("ADDON_LOADED")

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- 1050 copper -> "10s 50c" (no icons, so it reads fine in chat and tooltips)
function ns.Money(copper)
  copper = tonumber(copper)
  if not copper then return "?" end
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- Color for a skill by how far it is below max: green at max, then yellow,
-- orange, red. Returns a hex string like "40ff40".
function ns.GapColor(rank, max)
  if not rank or not max or max <= 0 then return "ffffff" end
  local gap = max - rank
  if gap <= 0 then return "40ff40" end
  if gap < 10 then return "c8ff40" end
  if gap < (ns.Setting("warnGap") or 25) then return "ffd040" end
  if gap < 60 then return "ff9030" end
  return "ff4040"
end

function ns.Colored(hex, text) return "|cff" .. hex .. tostring(text) .. "|r" end

function ns.PlayerClass()
  local _, token = UnitClass("player")
  return token
end

function ns.PlayerFaction()
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  return faction
end

function ns.PlayerLevel()
  return ns.Num(UnitLevel("player")) or 1
end

function ns.InCombat()
  local v = InCombatLockdown and InCombatLockdown()
  if ns.IsHidden(v) then return true end
  return v and true or false
end
