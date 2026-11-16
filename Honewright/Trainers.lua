-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: weapon masters. Who teaches a weapon type for your faction,
-- what it costs, pinning them on your map, and remembering what a weapon
-- master really teaches and charges when you open their window (so
-- reputation discounts and any patch changes show up).
--
-- Honewright never buys training for you: it only reads the trainer window
-- you opened yourself.

local ADDON, ns = ...

---------------------------------------------------------------------------
-- What we know about a trainer
---------------------------------------------------------------------------

local function Seen(t) return ns.db and ns.db.trainersSeen[t.name] end

local function Teaches(t, key)
  local seen = Seen(t)
  if seen and seen.teaches then return seen.teaches[key] ~= nil end
  for _, k in ipairs(t.teaches) do if k == key then return true end end
  return false
end

-- Cost in copper and level needed. Second value says if it was seen at the trainer.
function ns.TrainingCost(t, w)
  local seen = Seen(t)
  local cost = seen and seen.cost and seen.cost[w.key]
  local level = seen and seen.level and seen.level[w.key]
  if cost then return cost, level or w.level, true end
  return w.cost, w.level, false
end

-- The city you're in right now (English name from the trainer list), if any.
local function CurrentCity()
  if not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = ok and ns.Num(mapID)
  if not mapID then return nil end
  for city, id in pairs(ns.db and ns.db.mapIDs or {}) do
    if id == mapID then return city end
  end
  return nil
end

-- Trainers of your faction who teach this weapon type; the city you're in first.
function ns.TrainersFor(w)
  local faction = ns.PlayerFaction()
  local here = CurrentCity()
  local list = {}
  for i, t in ipairs(ns.TRAINERS) do
    if (not faction or t.faction == faction) and Teaches(t, w.key) then
      list[#list + 1] = { t = t, order = (t.city == here and 0 or 1) * 100 + i }
    end
  end
  table.sort(list, function(a, b) return a.order < b.order end)
  local out = {}
  for _, e in ipairs(list) do out[#out + 1] = e.t end
  return out
end

-- "Woo Ping, Stormwind (Weller's Arsenal, Trade District) 63.8, 69.0: 10s"
function ns.TrainerLine(t, w)
  local cost, level, seen = ns.TrainingCost(t, w)
  local text = ("%s, %s (%s) %.1f, %.1f: %s"):format(t.name, t.city, t.area, t.x, t.y, ns.Money(cost))
  if not seen then text = text .. "*" end
  if level and level > ns.PlayerLevel() then text = text .. ns.Colored("ff4040", (" (level %d)"):format(level)) end
  return text
end
ns.COST_NOTE = "* before reputation discounts. Open a weapon master and Honewright remembers their real price."

---------------------------------------------------------------------------
-- Map pins
---------------------------------------------------------------------------

local function MapName(mapID)
  if not C_Map or not C_Map.GetMapInfo then return nil end
  local ok, info = pcall(C_Map.GetMapInfo, mapID)
  return ok and type(info) == "table" and ns.Str(info.name) or nil
end

-- The map ID for a city: the one seen while you were there, else the first
-- candidate whose name matches.
function ns.CityMapID(city)
  local known = ns.db and ns.db.mapIDs[city]
  if known then return known, true end
  local match = ns.CITY_NAME_MATCH[city] or city
  for _, id in ipairs(ns.CITY_MAP_CANDIDATES[city] or {}) do
    local name = MapName(id)
    if name and name:sub(1, #match) == match then return id, false end
  end
  -- other game languages: names won't match, so take the first that exists
  for _, id in ipairs(ns.CITY_MAP_CANDIDATES[city] or {}) do
    if MapName(id) then return id, false end
  end
  return nil, false
end

-- Remember the real map ID of a capital while you're standing in it.
function ns.LearnCityMap()
  if not ns.db or not C_Map or not C_Map.GetBestMapForUnit then return end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  mapID = ok and ns.Num(mapID)
  if not mapID then return end
  local name = MapName(mapID)
  local zone = GetRealZoneText and ns.Str(GetRealZoneText())
  for city, match in pairs(ns.CITY_NAME_MATCH) do
    if name and name:sub(1, #match) == match then ns.db.mapIDs[city] = mapID return city end
    -- other languages: the zone text of a trainer's city, learned when you met them
    for _, seen in pairs(ns.db.trainersSeen) do
      if seen.city == city and seen.zoneText and zone == seen.zoneText then
        ns.db.mapIDs[city] = mapID
        return city
      end
    end
  end
  return nil
end

function ns.PinTrainer(t)
  local mapID, sure = ns.CityMapID(t.city)
  local where = ("%s, %s (%s) %.1f, %.1f"):format(t.name, t.city, t.area, t.x, t.y)
  local pinned = false
  if mapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local canSet = not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(mapID)
    if canSet then
      local ok = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, t.x / 100, t.y / 100))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
          C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
      end)
      pinned = ok
    end
  end
  if pinned then
    ns.Print("Pinned on your map: " .. where .. ".")
    if not sure then
      ns.Print("If the pin is in the wrong spot, it fixes itself after you've been in " .. t.city .. " once.")
    end
  else
    ns.Print("Couldn't place a map pin here. " .. where .. ".")
  end
  return pinned
end

---------------------------------------------------------------------------
-- Reading a weapon master's window you opened
---------------------------------------------------------------------------

-- Proficiency name -> weapon key, in the game's language.
local function NameIndex()
  local index = {}
  for key, w in pairs(ns.WEAPONS) do
    if C_Spell and C_Spell.GetSpellName then
      local ok, n = pcall(C_Spell.GetSpellName, w.spell)
      n = ok and ns.Str(n)
      if n then index[n] = key end
    end
    index[ns.WeaponName(w)] = key
    index[w.name] = key
  end
  return index
end

-- Returns the trainer record it saved, or nil if this isn't a weapon master.
function ns.ReadTrainerWindow()
  if not GetNumTrainerServices or not GetTrainerServiceInfo then return nil end
  local npc = UnitName and ns.Str(UnitName("npc"))
  if not npc then return nil end
  local index = NameIndex()
  local rec = { teaches = {}, cost = {}, level = {}, status = {} }
  local found = 0
  local n = ns.Num(GetNumTrainerServices()) or 0
  for i = 1, n do
    local name, _, category = GetTrainerServiceInfo(i)
    name, category = ns.Str(name), ns.Str(category)
    if name == nil then break end
    local key = category ~= "header" and index[name]
    if key then
      found = found + 1
      rec.teaches[key] = true
      rec.status[key] = category
      if GetTrainerServiceCost then rec.cost[key] = ns.Num((GetTrainerServiceCost(i))) end
      if GetTrainerServiceLevelReq then rec.level[key] = ns.Num(GetTrainerServiceLevelReq(i)) end
    end
  end
  if found == 0 then return nil end
  -- which city this trainer is in, from Honewright's list (names are the same in every language)
  for _, t in ipairs(ns.TRAINERS) do
    if t.name == npc then rec.city = t.city end
  end
  rec.zoneText = GetRealZoneText and ns.Str(GetRealZoneText()) or nil
  rec.time = time and time() or nil
  -- the trainer's list can be filtered: keep what an earlier visit saw that's hidden now
  local old = ns.db.trainersSeen[npc]
  if old and old.teaches then
    for key in pairs(old.teaches) do
      if not rec.teaches[key] then
        rec.teaches[key] = true
        rec.cost[key] = old.cost and old.cost[key]
        rec.level[key] = old.level and old.level[key]
        rec.status[key] = old.status and old.status[key]
      end
    end
  end
  ns.db.trainersSeen[npc] = rec
  -- you're standing in this trainer's city: remember its map
  if rec.city and C_Map and C_Map.GetBestMapForUnit then
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and ns.Num(mapID)
    if mapID then ns.db.mapIDs[rec.city] = mapID end
  end
  return rec, npc
end

-- One chat line: what this weapon master can teach you that you don't know yet.
function ns.ReportTrainer(rec, npc)
  if not rec then return end
  local parts = {}
  for _, key in ipairs(ns.WEAPON_ORDER) do
    if rec.status[key] == "available" or (rec.status[key] == "unavailable" and ns.ClassCanLearn(ns.PlayerClass(), key)) then
      local w = ns.WEAPONS[key]
      if not ns.IsLearned(w) then
        local extra = ns.Money(rec.cost[key])
        local level = rec.level[key]
        if level and level > ns.PlayerLevel() then extra = extra .. ", level " .. level end
        parts[#parts + 1] = ("%s (%s)"):format(ns.WeaponName(w), extra)
      end
    end
  end
  if #parts > 0 then
    ns.Print(npc .. " can teach you: " .. table.concat(parts, ", ") .. ".")
  end
end

ns.Listen("LOADED", function()
  ns.On("TRAINER_SHOW", function()
    -- the list fills in a moment after the window opens
    local function Read() ns.ReportTrainer(ns.ReadTrainerWindow()) end
    if C_Timer then C_Timer.After(0.2, Read) else Read() end
  end)
  ns.On("PLAYER_ENTERING_WORLD", function() ns.LearnCityMap() end)
  ns.On("ZONE_CHANGED_NEW_AREA", function() ns.LearnCityMap() end)
end)
