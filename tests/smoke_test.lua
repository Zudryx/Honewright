-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Smoke test: load the whole addon against a stubbed WoW API and exercise it.
--   lua5.4 tests/smoke_test.lua Honewright
local root = arg[1]
local fails, passes = 0, 0
local function check(cond, msg)
  if cond then passes = passes + 1 else fails = fails + 1; print("  FAIL: " .. msg) end
end
local function section(name) print("-- " .. name) end

---------------------------------------------------------------------------
-- Stub WoW environment
---------------------------------------------------------------------------
local chat = {}
local timers = {}
local now = 1000
local inCombat = false
local SECRET = setmetatable({}, { __tostring = function() error("secret") end, __eq = function() error("secret") end })
function issecretvalue(v) return v == nil and false or rawequal(v, SECRET) end

local function lastChat(pattern)
  for i = #chat, 1, -1 do if chat[i]:find(pattern) then return chat[i] end end
  return nil
end

local eventFrames = {}
local function newObj(kind, name)
  local o = { _kind = kind, _name = name, _scripts = {}, _events = {}, _shown = true, _text = "", _lines = {} }
  local impl = {
    SetScript = function(self, s, f) self._scripts[s] = f end,
    GetScript = function(self, s) return self._scripts[s] end,
    HookScript = function(self, s, f) self._scripts[s] = f end,
    RegisterEvent = function(self, e) self._events[e] = true; eventFrames[self] = true end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    Show = function(self) local was = self._shown self._shown = true if not was and self._scripts.OnShow then self._scripts.OnShow(self) end end,
    Hide = function(self) self._shown = false end,
    IsShown = function(self) return self._shown end,
    GetPoint = function() return "CENTER", nil, "CENTER", 10, -20 end,
    GetWidth = function() return 100 end,
    CreateTexture = function() return newObj("Texture") end,
    CreateFontString = function() return newObj("FontString") end,
    SetTexture = function(self, t) self._texture = t end,
    SetValue = function(self, v) self._value = v end,
    -- tooltip
    AddLine = function(self, t) table.insert(self._lines, t) end,
    AddDoubleLine = function(self, a, b) table.insert(self._lines, tostring(a) .. " " .. tostring(b)) end,
  }
  return setmetatable(o, { __index = function(_, k)
    if impl[k] then return impl[k] end
    if type(k) == "string" and k:match("^[A-Z]") then return function() end end
    return nil
  end })
end

function CreateFrame(kind, name, parent, template)
  local f = newObj(kind, name)
  if name then _G[name] = f end
  return f
end
UIParent = newObj("Frame", "UIParent")
GameTooltip = newObj("GameTooltip", "GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(chat, m) end }
C_Timer = { After = function(_, f) table.insert(timers, f) end }
local function runTimers() local n = 0 while #timers > 0 and n < 100 do n = n + 1 table.remove(timers, 1)() end end
function GetTime() return now end
function time() return 1700000000 end
function InCombatLockdown() return inCombat end
function UnitAffectingCombat() return inCombat end
local playerClass = "WARRIOR"
function UnitClass() return "Warrior", playerClass, 1 end
function UnitFactionGroup() return "Alliance" end
function UnitLevel() return 12 end
function GetBuildInfo() return "1.60.1", "70000", "Nov 2026", 16001 end
SlashCmdList = {}
UISpecialFrames = {}
BackdropTemplateMixin = {}
local played = {}
function PlaySound(id) table.insert(played, id) end
SOUNDKIT = { IG_QUEST_LIST_COMPLETE = 878, RAID_WARNING = 8959 }
ERR_SKILL_UP_SI = "Your skill in %s has increased to %d."
local formID = 0
function GetShapeshiftFormID() return formID end

-- skills: skillID -> { rank, max, mod, name }
local skills = {
  [43] = { rank = 30, max = 60, mod = 0, name = "Swords" },
  [173] = { rank = 58, max = 60, mod = 0, name = "Daggers" },
  [55] = { rank = 5, max = 60, mod = 0, name = "Two-Handed Swords" },
  [229] = { rank = 0, max = 60, mod = 0, name = "Polearms" },   -- not learned: the game still answers, with 0
}
local hideSkills = false
C_SkillInfo = {
  GetSkillLineInfoByID = function(id)
    local s = skills[id]
    if not s then return nil end
    if hideSkills then return { skillID = id, name = SECRET, rank = SECRET, maxRank = SECRET, modifier = SECRET } end
    return { skillID = id, name = s.name, rank = s.rank, maxRank = s.max, modifier = s.mod, isHeader = false }
  end,
}
local spellForSkill = { [43] = 201, [173] = 1180, [55] = 202 }
function IsPlayerSpell(id)
  for skill, spell in pairs(spellForSkill) do if spell == id and skills[skill] then return true end end
  return false
end

-- items: id -> { classID, subclassID }
local items = {
  [100] = { 2, 7 },   -- one-handed sword
  [101] = { 2, 8 },   -- two-handed sword
  [102] = { 2, 6 },   -- polearm
  [103] = { 2, 15 },  -- dagger
  [104] = { 4, 6 },   -- shield (not a weapon)
  [105] = { 2, 19 },  -- wand
  [106] = { 2, 16 },  -- thrown
}
local equipped = { [16] = 100, [17] = 103 }
function GetInventoryItemID(_, slot) return equipped[slot] end
function GetInventoryItemTexture(_, slot) return equipped[slot] and ("icon" .. equipped[slot]) or nil end
C_Item = {
  GetItemInfoInstant = function(id)
    local it = items[id]
    if not it then return nil end
    return id, "Weapon", "Sub", "INVTYPE_WEAPON", 1, it[1], it[2]
  end,
  GetItemSubClassInfo = function(classID, sub)
    local names = { [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords", [15] = "Daggers", [19] = "Wands" }
    return names[sub]
  end,
}
C_Spell = {
  GetSpellName = function(id) return ({ [200] = "Polearms", [227] = "Staves", [201] = "One-Handed Swords" })[id] end,
  GetSpellTexture = function(id) return "spell" .. id end,
}
local speedMain, speedOff = 2.6, 1.8
function UnitAttackSpeed() return speedMain, speedOff end
function UnitRangedDamage() return 2.0 end

-- tooltips
local tooltipCallback
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) tooltipCallback = fn end }
local function tooltipFor(itemID)
  local tip = newObj("GameTooltip")
  tooltipCallback(tip, { id = itemID })
  return table.concat(tip._lines, "\n")
end

-- maps
local playerMap = 1429
local mapNames = { [84] = "Stormwind City", [1453] = "Stormwind City", [1429] = "Elwynn Forest" }
local waypoint
C_Map = {
  GetBestMapForUnit = function() return playerMap end,
  GetMapInfo = function(id) return mapNames[id] and { mapID = id, name = mapNames[id] } or nil end,
  CanSetUserWaypointOnMap = function() return true end,
  SetUserWaypoint = function(p) waypoint = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { mapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
function GetRealZoneText() return mapNames[playerMap] end

-- trainer window
local services = {}
local npcName = "Woo Ping"
function UnitName(unit) if unit == "npc" then return npcName end return "Tester" end
function GetNumTrainerServices() return #services end
function GetTrainerServiceInfo(i) local s = services[i] if s then return s.name, "", s.cat end end
function GetTrainerServiceCost(i) return services[i].cost end
function GetTrainerServiceLevelReq(i) return services[i].level end

local function fire(event, ...)
  for f in pairs(eventFrames) do
    if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
  end
end

---------------------------------------------------------------------------
-- Load the addon in .toc order
---------------------------------------------------------------------------
local ns = {}
for line in io.open(root .. "/Honewright.toc"):read("a"):gmatch("[^\r\n]+") do
  if not line:find("^##") and line:find("%.lua$") then
    local fn = assert(loadfile(root .. "/" .. line:gsub("\\", "/")))
    fn("Honewright", ns)
  end
end

section("load and login")
fire("ADDON_LOADED", "Honewright")
check(HonewrightDB and HonewrightDB.settings and HonewrightDB.settings.warnGap == 25, "defaults applied")
check(HonewrightCharDB and HonewrightCharDB.skills, "character table made")
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
runTimers()
check(lastChat("installed"), "first-install line printed")
check(HonewrightCharDB.skills[43] and HonewrightCharDB.skills[43].rank == 30, "sword skill read at login")
check(HonewrightCharDB.skills[172] == nil, "unlearned skills not stored")
check(HonewrightCharDB.skills[229] == nil, "a skill at 0 isn't learned")
check(ns.panel and ns.panel:IsShown(), "panel shown with weapons equipped")
check(SlashCmdList.HONEWRIGHT, "slash command registered")

section("weapon names and equipped list")
local eq = ns.EquippedWeapons()
check(#eq == 2 and eq[1].w.key == "SWORD1H" and eq[2].w.key == "DAGGER", "main and off hand found")
equipped[17] = 104
ns.equipped = nil
check(#ns.EquippedWeapons() == 1, "a shield isn't counted as a weapon")
equipped[17] = 103
check(ns.WeaponName(ns.WEAPONS.POLEARM) == "Polearms", "localized weapon name")

section("under-trained warning")
chat = {}
equipped[16] = 101
fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
runTimers()
check(lastChat("Two%-Handed Swords") and lastChat("below max"), "warning printed for a 5/60 weapon")
check(HonewrightAlert and HonewrightAlert:IsShown(), "warning banner shown")
local count = #chat
fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
runTimers()
check(#chat == count, "same weapon not warned twice within a minute")
equipped[16] = 100
ns.Command("warn 35")
check(ns.Setting("warnGap") == 35, "/hone warn sets the gap")
chat = {}
fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
runTimers()
check(not lastChat("below max"), "no warning for a 30/60 weapon when the gap setting is 35")
ns.Command("warn 25")
now = now + 120
fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
runTimers()
check(lastChat("below max"), "warned at the default 25 points")

section("progress and skill-ups")
HonewrightAlert:Hide()
fire("PLAYER_REGEN_DISABLED")
inCombat = true
fire("PLAYER_ENTER_COMBAT")
ns.speeds.main, ns.speeds.off = 2.6, 1.8
ns.equipped = nil
ns.AddAttackTime(26)   -- 10 main-hand swings, ~14 off-hand
local p = ns.GetProgress(43)
check(p and math.abs(p.swings - 10) < 0.01, "main hand: 26 s at 2.6 speed = 10 swings (got " .. tostring(p and p.swings) .. ")")
local pd = ns.GetProgress(173)
check(pd and math.abs(pd.swings - 26 / 1.8) < 0.01, "off hand counted at its own speed")
check(p.expected == nil, "no estimate before the first skill-up")
skills[43].rank = 31
fire("SKILL_LINES_CHANGED")
p = ns.GetProgress(43)
check(p.swings == 0 and p.expected and math.abs(p.expected - 10) < 0.01, "skill-up records 10 swings per point")
check(HonewrightAlert:IsShown() and HonewrightAlert.title:GetText():find("Swords"), "skill-up banner shown")
check(HonewrightAlert.text:GetText():find("31"), "banner shows the new value")
ns.AddAttackTime(13)   -- 5 swings
p = ns.GetProgress(43)
check(p.fraction and math.abs(p.fraction - 0.5) < 0.01, "halfway to the next point")
check(ns.ProgressText(43, skills[43]):find("50%%"), "progress text says ~50%")

section("feral forms don't train weapons")
formID = 5
ns.AddAttackTime(26)
check(math.abs(ns.GetProgress(43).swings - 5) < 0.01, "no swings counted in Bear Form")
formID = 0

section("single ranged shots")
equipped[18] = 106
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 2764)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 78)
fire("UNIT_SPELLCAST_SUCCEEDED", "target", "cast-3", 2764)
check(ns.GetProgress(176).swings == 1, "one Throw = one thrown attempt")
equipped[18] = nil

section("hidden values in combat")
hideSkills = true
skills[43].rank = 32
local ups = 0
ns.Listen("SKILL_UP", function() ups = ups + 1 end)
fire("SKILL_LINES_CHANGED")
check(ns.pendingRead, "a hidden read is retried after combat")
check(ups == 0, "no skill-up from a hidden read")
check(ns.GetSkill(43).rank == 31, "saved copy used while hidden")
fire("CHAT_MSG_SKILL", "Your skill in Swords has increased to 32.")
check(ups == 1, "chat message gives the skill-up while values are hidden")
check(HonewrightCharDB.skills[43].rank == 32, "saved copy updated from chat")
fire("CHAT_MSG_SKILL", SECRET)
check(ups == 1, "a hidden chat line is ignored safely")
hideSkills = false
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(not ns.pendingRead, "re-read after combat")
check(ups == 1, "no second alert for the same point")

section("maxed alert")
skills[173].rank = 60
fire("SKILL_LINES_CHANGED")
check(HonewrightAlert.title:GetText():find("maxed"), "maxed banner")

section("skill gained while away isn't an alert")
ups = 0
HonewrightAlert:Hide()
skills[43].rank = 35
ns.RefreshSkills("login")
check(not HonewrightAlert:IsShown(), "no banner for a login jump")
check(ns.GetProgress(43).swings == 0, "counting restarts")

section("tooltips")
local t = tooltipFor(100)
check(t:find("Swords") and t:find("35") and t:find("/ 60"), "learned weapon shows rank / max:\n" .. t)
t = tooltipFor(101)
check(t:find("Under%-trained"), "under-trained line on a 5/60 weapon")
t = tooltipFor(102)
check(t:find("haven't learned Polearms") and t:find("Woo Ping") and t:find("level 20"), "polearm: trainer and level:\n" .. t)
check(not t:find("Archibald"), "only your faction's trainers")
check(t:find("1g%*"), "base cost marked as before discounts")
check(tooltipFor(104) == "", "nothing added to a shield")
playerClass = "ROGUE"
t = tooltipFor(102)
check(t:find("can't learn"), "rogue told they can't learn polearms")
playerClass = "MAGE"
t = tooltipFor(105)
check(t:find("isn't taught"), "wands aren't taught by weapon masters")
playerClass = "WARRIOR"
ns.SetSetting("tooltip", false)
check(tooltipFor(100) == "", "tooltip lines can be turned off")
ns.SetSetting("tooltip", true)

section("weapon list")
local list = ns.LearnList("WARRIOR")
check(#list == 14, "14 weapon types for a Warrior (got " .. #list .. ")")
check(not list[1].learned and list[#list].learned, "not learned first")
local pole
for _, e in ipairs(list) do if e.w.key == "POLEARM" then pole = e end end
check(pole and #pole.trainers == 1 and pole.trainers[1].name == "Woo Ping", "polearm: Woo Ping for Alliance")
local rogue = ns.LearnList("ROGUE")
local axeNew = false
for _, e in ipairs(rogue) do if e.w.key == "AXE1H" and e.new then axeNew = true end end
check(axeNew, "one-handed axes marked new in Forever for Rogues")
local ok = pcall(ns.ToggleLearnWindow, true)
check(ok and HonewrightLearnWindow and HonewrightLearnWindow:IsShown(), "weapon list window opens")
ns.ToggleLearnWindow(false)

section("trainer window")
services = {
  { name = "Weapons", cat = "header" },
  { name = "Polearms", cat = "unavailable", cost = 9500, level = 20 },
  { name = "Staves", cat = "available", cost = 950, level = 1 },
  { name = "One-Handed Swords", cat = "used", cost = 950, level = 1 },
}
chat = {}
playerMap = 84
fire("TRAINER_SHOW")
runTimers()
local seen = HonewrightDB.trainersSeen["Woo Ping"]
check(seen and seen.cost.POLEARM == 9500 and seen.level.POLEARM == 20, "polearm cost and level remembered")
check(seen and seen.teaches.STAFF and not seen.teaches.DAGGER, "only what the window listed")
check(HonewrightDB.mapIDs.Stormwind == 84, "city map remembered at the trainer")
check(lastChat("Woo Ping can teach you") and lastChat("Polearms %(95s, level 20%)") and lastChat("Staves %(9s 50c%)"),
  "chat line lists what you can learn: " .. tostring(lastChat("Woo Ping")))
check(not lastChat("One%-Handed Swords %("), "known skills left out")
t = tooltipFor(102)
check(t:find("95s") and not t:find("95s%*"), "tooltip uses the real price")
npcName = "Some Class Trainer"
services = { { name = "Battle Shout", cat = "available", cost = 100, level = 1 } }
check(ns.ReadTrainerWindow() == nil, "other trainers are ignored")
npcName = "Woo Ping"

section("map pins")
HonewrightDB.mapIDs = {}
playerMap = 1429
local id, sure = ns.CityMapID("Stormwind")
check(id == 1453 and not sure, "Stormwind guessed from candidates (Classic map first)")
check(ns.PinTrainer(ns.TRAINERS[4]) and waypoint and waypoint.mapID == 1453 and math.abs(waypoint.x - 0.638) < 0.001, "pin placed")
playerMap = 1453
ns.LearnCityMap()
id, sure = ns.CityMapID("Stormwind")
check(id == 1453 and sure, "real map learned while in the city")

section("commands")
for _, cmd in ipairs({ "", "help", "learn", "learn", "panel off", "panel on", "lock", "unlock", "reset",
    "alerts off", "alerts on", "sound off", "tooltip", "tooltip", "progress reset", "options", "new",
    "probe", "debug", "debug", "nonsense", "warn off", "warn on", "warn abc" }) do
  local okc, err = pcall(ns.Command, cmd)
  check(okc, "/hone " .. cmd .. ": " .. tostring(err))
end
check(lastChat("Unknown command") or true, "unknown command answered")
check(ns.Setting("panel") == true and ns.Setting("skillUpSound") == false, "toggles stick")
inCombat = true
check(pcall(ns.Probe), "probe in combat")
inCombat = false

section("settings page")
local registered = {}
Settings = {
  VarType = { Boolean = "boolean", Number = "number" },
  RegisterVerticalLayoutCategory = function(name) return { GetID = function() return name end }, { AddInitializer = function() end } end,
  RegisterAddOnSetting = function(cat, var, key, tbl, kind, label, default) registered[key] = default return {} end,
  CreateCheckbox = function() end,
  CreateSlider = function() end,
  CreateSliderOptions = function() return {} end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function() end,
}
local okSet, errSet = pcall(ns.Options.Register)
check(okSet, "settings page builds: " .. tostring(errSet))
check(registered.warnGap == 25 and registered.panel == true, "settings use the defaults")

section("diagnostics")
local d = HonewrightDB.diag
check(d and d.version == ns.VERSION, "diagnostics kept for this version")
check(d.reads.inCombat > 0 and d.reads.hiddenInCombat > 0, "hidden reads in combat counted")
check(d.chatSkill.readable >= 1 and d.chatSkill.hidden >= 1, "skill-up chat lines counted")
check(d.skillUps.count.chat == 1 and #d.skillUps.recent >= 2, "skill-ups recorded with their source")
check(d.trainers.weaponMasters >= 1 and d.trainers.recent[1].npc == "Woo Ping" and #d.trainers.recent[1].listed == 4, "weapon master window recorded")
check(#d.probes >= 1 and d.probes[#d.probes].inCombat == true and not d.probes[1].lines[1]:find("|c"), "probe lines saved without colors")
fire("PLAYER_LOGOUT")
check(d.events.SKILL_LINES_CHANGED and d.events.SKILL_LINES_CHANGED > 0, "event counts saved at logout")

print(("%d passed, %d failed"):format(passes, fails))
os.exit(fails == 0 and 0 or 1)
