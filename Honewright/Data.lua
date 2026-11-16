-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: weapon types, which classes can learn them, and the weapon
-- masters who teach them in WoW Forever.
--
-- Sources (checked November 2026): Warcraft Tavern's WoW Forever weapon
-- trainer guide (warcrafttavern.com/forever/guides/weapon-trainers/) and
-- Forever's class changes (Rogues can learn One-Handed Axes, Druids
-- Polearms, Shamans Two-Handed Axes and Maces from a trainer).
-- When you open a weapon master in game, Honewright records what they
-- really teach and charge (Trainers.lua), and that wins over this table.

local ADDON, ns = ...

-- key = { item subclass (Enum.ItemWeaponSubclass), skill line ID,
--         proficiency spell ID, English name, level needed, cost in copper }
-- The English name is only a fallback: the game's own (translated) name is
-- used whenever it can be read.
local W = {
  AXE1H    = { sub = 0,  skill = 44,  spell = 196,   name = "One-Handed Axes" },
  AXE2H    = { sub = 1,  skill = 172, spell = 197,   name = "Two-Handed Axes" },
  BOW      = { sub = 2,  skill = 45,  spell = 264,   name = "Bows", ranged = true },
  GUN      = { sub = 3,  skill = 46,  spell = 266,   name = "Guns", ranged = true },
  MACE1H   = { sub = 4,  skill = 54,  spell = 198,   name = "One-Handed Maces" },
  MACE2H   = { sub = 5,  skill = 160, spell = 199,   name = "Two-Handed Maces" },
  POLEARM  = { sub = 6,  skill = 229, spell = 200,   name = "Polearms", level = 20, cost = 10000 },
  SWORD1H  = { sub = 7,  skill = 43,  spell = 201,   name = "One-Handed Swords" },
  SWORD2H  = { sub = 8,  skill = 55,  spell = 202,   name = "Two-Handed Swords" },
  STAFF    = { sub = 10, skill = 136, spell = 227,   name = "Staves" },
  FIST     = { sub = 13, skill = 473, spell = 15590, name = "Fist Weapons" },
  DAGGER   = { sub = 15, skill = 173, spell = 1180,  name = "Daggers" },
  THROWN   = { sub = 16, skill = 176, spell = 2567,  name = "Thrown", ranged = true },
  CROSSBOW = { sub = 18, skill = 226, spell = 5011,  name = "Crossbows", ranged = true },
  WAND     = { sub = 19, skill = 228, spell = 5009,  name = "Wands", ranged = true, noTrainer = true },
}
ns.WEAPONS = W
ns.WEAPON_ORDER = { "SWORD1H", "SWORD2H", "AXE1H", "AXE2H", "MACE1H", "MACE2H", "DAGGER", "FIST",
  "POLEARM", "STAFF", "BOW", "CROSSBOW", "GUN", "THROWN", "WAND" }

ns.DEFAULT_COST = 1000   -- 10 silver
ns.DEFAULT_LEVEL = 1
ns.UNARMED_SKILL = 162

ns.bySubclass, ns.bySkill, ns.bySpell = {}, {}, {}
for key, w in pairs(W) do
  w.key = key
  w.level = w.level or ns.DEFAULT_LEVEL
  w.cost = w.cost or ns.DEFAULT_COST
  ns.bySubclass[w.sub] = w
  ns.bySkill[w.skill] = w
  ns.bySpell[w.spell] = w
end

-- Weapon types each class can learn in WoW Forever. "new" marks the ones
-- Forever added (not possible in Classic).
ns.CLASS_WEAPONS = {
  WARRIOR = { "SWORD1H", "SWORD2H", "AXE1H", "AXE2H", "MACE1H", "MACE2H", "DAGGER", "FIST",
              "POLEARM", "STAFF", "BOW", "CROSSBOW", "GUN", "THROWN" },
  PALADIN = { "SWORD1H", "SWORD2H", "AXE1H", "AXE2H", "MACE1H", "MACE2H", "POLEARM" },
  HUNTER  = { "SWORD1H", "SWORD2H", "AXE1H", "AXE2H", "DAGGER", "FIST", "POLEARM", "STAFF",
              "BOW", "CROSSBOW", "GUN", "THROWN" },
  ROGUE   = { "SWORD1H", "AXE1H", "MACE1H", "DAGGER", "FIST", "BOW", "CROSSBOW", "GUN", "THROWN" },
  PRIEST  = { "MACE1H", "DAGGER", "STAFF", "WAND" },
  SHAMAN  = { "AXE1H", "AXE2H", "MACE1H", "MACE2H", "DAGGER", "FIST", "STAFF" },
  MAGE    = { "SWORD1H", "DAGGER", "STAFF", "WAND" },
  WARLOCK = { "SWORD1H", "DAGGER", "STAFF", "WAND" },
  DRUID   = { "MACE1H", "MACE2H", "DAGGER", "FIST", "STAFF", "POLEARM" },
}
ns.NEW_IN_FOREVER = {
  ROGUE = { AXE1H = true },
  DRUID = { POLEARM = true },
  SHAMAN = { AXE2H = true, MACE2H = true },
}

function ns.ClassCanLearn(classToken, key)
  local list = ns.CLASS_WEAPONS[classToken or ""]
  if not list then return nil end   -- unknown class: don't guess
  for _, k in ipairs(list) do if k == key then return true end end
  return false
end

-- Weapon masters. Coordinates are on each city's own map.
ns.TRAINERS = {
  { name = "Ilyenia Moonfire", faction = "Alliance", city = "Darnassus", area = "Warrior's Terrace",
    x = 57.6, y = 46.7, teaches = { "BOW", "DAGGER", "FIST", "STAFF", "THROWN" } },
  { name = "Buliwyf Stonehand", faction = "Alliance", city = "Ironforge", area = "Timberline Arms, Military Ward",
    x = 62.2, y = 89.6, teaches = { "FIST", "GUN", "AXE1H", "MACE1H", "AXE2H", "MACE2H" } },
  { name = "Bixi Wobblebonk", faction = "Alliance", city = "Ironforge", area = "Timberline Arms, Military Ward",
    x = 62.2, y = 89.6, teaches = { "CROSSBOW", "DAGGER", "THROWN" } },
  { name = "Woo Ping", faction = "Alliance", city = "Stormwind", area = "Weller's Arsenal, Trade District",
    x = 63.8, y = 69.0, teaches = { "CROSSBOW", "DAGGER", "SWORD1H", "POLEARM", "STAFF", "SWORD2H" } },
  { name = "Sayoc", faction = "Horde", city = "Orgrimmar", area = "Arms of Legend, Valley of Honor",
    x = 81.5, y = 19.6, teaches = { "BOW", "DAGGER", "FIST", "AXE1H", "STAFF", "THROWN", "AXE2H" } },
  { name = "Hanashi", faction = "Horde", city = "Orgrimmar", area = "Arms of Legend, Valley of Honor",
    x = 81.5, y = 19.6, teaches = { "BOW", "AXE1H", "STAFF", "THROWN", "AXE2H" } },
  { name = "Ansekhwa", faction = "Horde", city = "Thunder Bluff", area = "Thunder Bluff Weapons, Lower Rise",
    x = 40.9, y = 62.7, teaches = { "GUN", "MACE1H", "STAFF", "MACE2H" } },
  { name = "Archibald", faction = "Horde", city = "Undercity", area = "The War Quarter",
    x = 57.3, y = 32.8, teaches = { "CROSSBOW", "DAGGER", "SWORD1H", "POLEARM", "SWORD2H" } },
}

-- Map IDs to try for each city before Honewright has seen the real one
-- (it learns the right ID the first time you're in the city). The first ID
-- that exists and has the city's name wins.
ns.CITY_MAP_CANDIDATES = {
  ["Stormwind"] = { 84, 1453 },
  ["Ironforge"] = { 87, 1455 },
  ["Darnassus"] = { 89, 1457 },
  ["Orgrimmar"] = { 85, 1454 },
  ["Thunder Bluff"] = { 88, 1456 },
  ["Undercity"] = { 90, 1458 },
}
ns.CITY_NAME_MATCH = {   -- how the city's map name starts (English); "Stormwind City" etc.
  ["Stormwind"] = "Stormwind", ["Ironforge"] = "Ironforge", ["Darnassus"] = "Darnassus",
  ["Orgrimmar"] = "Orgrimmar", ["Thunder Bluff"] = "Thunder Bluff", ["Undercity"] = "Undercity",
}
