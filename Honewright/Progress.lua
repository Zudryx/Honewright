-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: estimated progress toward your next weapon skill point.
--
-- WoW Forever keeps the combat log closed to addons, so real swings can't be
-- counted. What can be seen: when your auto-attack (or Auto Shot / Shoot) is
-- switched on, whether you're in combat, and your weapon speed. Honewright
-- adds up the time both are true, divides by the weapon's speed for an
-- ESTIMATED number of swings, and learns from your own skill-ups how many
-- swings a point has been taking. Everything here is an estimate and is
-- labeled that way wherever it's shown.

local ADDON, ns = ...

local MAX_SAMPLES = 8
local DEFAULT_SPEED = 2.0

local meleeOn, rangedOn, inCombat = false, false, false
local speeds = { main = nil, off = nil, ranged = nil }   -- last readable weapon speeds

local function P(skillID)
  local all = ns.char and ns.char.progress
  if not all then return nil end
  local p = all[skillID]
  if not p then
    p = { swings = 0, samples = {} }
    all[skillID] = p
  end
  return p
end
ns.ProgressRecord = P

---------------------------------------------------------------------------
-- Weapon speeds (read whenever the game shows them; kept for when it doesn't)
---------------------------------------------------------------------------

function ns.UpdateSpeeds()
  if UnitAttackSpeed then
    local ok, main, off = pcall(UnitAttackSpeed, "player")
    if ok then
      local m, o = ns.Num(main), ns.Num(off)
      if m and m > 0 then speeds.main = m end
      if o and o > 0 then speeds.off = o elseif m and not ns.IsHidden(off) then speeds.off = nil end
    end
  end
  if UnitRangedDamage then
    local ok, speed = pcall(UnitRangedDamage, "player")
    local s = ok and ns.Num(speed)
    if s and s > 0 then speeds.ranged = s end
  end
end
ns.speeds = speeds

-- Bear and Cat Form fight without your weapon, so they don't train it.
local FERAL_FORMS = { [1] = true, [5] = true, [8] = true }
local function InFeralForm()
  if not GetShapeshiftFormID then return false end
  local ok, id = pcall(GetShapeshiftFormID)
  return ok and FERAL_FORMS[ns.Num(id) or -1] or false
end

---------------------------------------------------------------------------
-- Adding up estimated swings
---------------------------------------------------------------------------

-- Credit "elapsed" seconds of auto-attack to the weapons that were swinging.
function ns.AddAttackTime(elapsed)
  if not ns.char or elapsed <= 0 then return end
  if InFeralForm() then return end
  ns.equipped = ns.equipped or ns.EquippedWeapons()
  for _, e in ipairs(ns.equipped) do
    local speed
    if meleeOn and not e.w.ranged and e.slot == 16 then speed = speeds.main or DEFAULT_SPEED
    elseif meleeOn and not e.w.ranged and e.slot == 17 then speed = speeds.off or DEFAULT_SPEED
    elseif rangedOn and e.slot == 18 then speed = speeds.ranged or DEFAULT_SPEED
    end
    if speed then
      local p = P(e.w.skill)
      if p then p.swings = p.swings + elapsed / speed end
    end
  end
end

-- Single ranged shots: Throw, Shoot Bow, Shoot Gun, Shoot Crossbow.
local SINGLE_SHOTS = { [2764] = true, [2480] = true, [7918] = true, [7919] = true }
function ns.OnRangedCast(spellID)
  if not spellID or not SINGLE_SHOTS[spellID] then return end
  local itemID = ns.Num(GetInventoryItemID("player", 18))
  local w = ns.ItemWeapon(itemID)
  local p = w and P(w.skill)
  if p then p.swings = p.swings + 1 end
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
  if (meleeOn or rangedOn) and inCombat then ns.AddAttackTime(elapsed) end
end)

---------------------------------------------------------------------------
-- Learning from skill-ups
---------------------------------------------------------------------------

function ns.RecordSkillUp(skillID, oldRank, newRank, max, source)
  local p = P(skillID)
  if not p then return end
  local points = (newRank or 0) - (oldRank or 0)
  -- gained while Honewright wasn't watching (another session, a level-up read):
  -- nothing to learn from, just start counting again
  if source == "login" or points <= 0 or points > 3 then p.swings = 0 return end
  local perPoint = p.swings / points
  if perPoint >= 1 then
    table.insert(p.samples, { swings = perPoint, gap = (max or 0) - oldRank })
    while #p.samples > MAX_SAMPLES do table.remove(p.samples, 1) end
  end
  p.swings = 0
  p.lastUp = time and time() or nil
end

-- What Honewright can say about the next point:
-- { swings = estimated swings since the last point,
--   expected = typical swings per point lately (nil until it has seen one),
--   fraction = swings / expected (capped below 1), samples = how many points it learned from }
function ns.GetProgress(skillID)
  local p = P(skillID)
  if not p then return nil end
  local s = ns.GetSkill(skillID)
  local gap = s and s.max and s.rank and (s.max - s.rank) or nil
  local pool = {}
  if gap then
    for _, sample in ipairs(p.samples) do
      if math.abs((sample.gap or 0) - gap) <= 15 then pool[#pool + 1] = sample end
    end
  end
  if #pool < 2 then pool = p.samples end
  local recent, total = {}, 0
  for i = #pool, math.max(1, #pool - 4), -1 do recent[#recent + 1] = pool[i] end
  for _, sample in ipairs(recent) do total = total + sample.swings end
  local expected = #recent > 0 and (total / #recent) or nil
  local fraction = expected and math.min(0.99, p.swings / expected) or nil
  return { swings = p.swings, expected = expected, fraction = fraction, samples = #p.samples, gap = gap }
end

function ns.ResetProgress(skillID)
  if not ns.char then return end
  if skillID then ns.char.progress[skillID] = nil else ns.char.progress = {} end
end

ns.Listen("SKILL_UP", function(_, skillID, oldRank, newRank, max, source)
  ns.RecordSkillUp(skillID, oldRank, newRank, max, source)
end)

ns.Listen("LOADED", function()
  local function SyncCombat()
    inCombat = UnitAffectingCombat and UnitAffectingCombat("player") and true or false
    if ns.IsHidden(inCombat) then inCombat = true end
  end
  ns.On("PLAYER_LOGIN", function() SyncCombat() ns.UpdateSpeeds() end)
  ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true ns.UpdateSpeeds() end)
  ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false meleeOn = false rangedOn = false ns.UpdateSpeeds() end)
  -- auto-attack switched on / off
  ns.On("PLAYER_ENTER_COMBAT", function() meleeOn = true end)
  ns.On("PLAYER_LEAVE_COMBAT", function() meleeOn = false end)
  -- Auto Shot, Shoot (wands) and throwing repeat by themselves while on
  ns.On("START_AUTOREPEAT_SPELL", function() rangedOn = true end)
  ns.On("STOP_AUTOREPEAT_SPELL", function() rangedOn = false end)
  -- Throw and the non-Hunter Shoot Bow / Gun / Crossbow are one shot per cast, not auto-repeat
  ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit ~= "player" then return end
    ns.OnRangedCast(ns.Num(spellID))
  end)
  ns.On("PLAYER_EQUIPMENT_CHANGED", function() ns.equipped = nil ns.UpdateSpeeds() end)
  ns.On("UNIT_ATTACK_SPEED", function(_, unit) if unit == "player" then ns.UpdateSpeeds() end end)
end)

-- for /hone probe
function ns.AttackState() return meleeOn, rangedOn, inCombat end
