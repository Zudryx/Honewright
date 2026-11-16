-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: lines in weapon tooltips. Your skill against max for weapons
-- you know; where to learn the ones you don't; a note when your class
-- can't use the type at all.

local ADDON, ns = ...

local function Line(tooltip, text, r, g, b, wrap)
  tooltip:AddLine(text, r or 1, g or 1, b or 1, wrap)
end

local TAG = "|cff" .. ns.ACCENT .. "Honewright:|r "

-- Adds Honewright's lines for a weapon item to a tooltip. Returns true when
-- it added something (used by the tests).
function ns.AddWeaponLines(tooltip, itemID)
  if not ns.Setting("tooltip") or not tooltip or not itemID then return false end
  local w = ns.ItemWeapon(itemID)
  if not w then return false end
  local class = ns.PlayerClass()
  local name = ns.WeaponName(w)

  if ns.IsLearned(w) then
    local s, saved = ns.GetSkill(w.skill)
    if s and s.rank and s.max then
      local hex = ns.GapColor(s.rank, s.max)
      local text = ("%s%s %s / %d"):format(TAG, (s.name or name), ns.Colored(hex, s.rank), s.max)
      if (s.mod or 0) > 0 then text = text .. ns.Colored("40ff40", " (+" .. s.mod .. " from gear)") end
      if saved then text = text .. ns.Colored("999999", " (last known)") end
      Line(tooltip, text)
      if s.max - s.rank >= (ns.Setting("warnGap") or 25) then
        Line(tooltip, "Under-trained: you'll miss a lot more with this until the skill catches up.", 1, 0.56, 0.19, true)
      end
    else
      Line(tooltip, TAG .. name .. ": learned")
    end
    return true
  end

  local canLearn = ns.ClassCanLearn(class, w.key)
  if canLearn == false then
    Line(tooltip, TAG .. "your class can't learn " .. name .. ".", 1, 0.25, 0.25, true)
    return true
  end
  if w.noTrainer then
    Line(tooltip, TAG .. name .. " isn't taught by weapon masters.", 1, 0.82, 0, true)
    return true
  end
  Line(tooltip, TAG .. ns.Colored("ff4040", "you haven't learned " .. name .. ".") .. " Weapon masters teach it:", 1, 1, 1, true)
  if not ns.Setting("tooltipTrainers") then return true end
  local list = ns.TrainersFor(w)
  local showAll = IsShiftKeyDown and IsShiftKeyDown()
  local shown = 0
  for _, t in ipairs(list) do
    if not showAll and shown >= 2 then
      Line(tooltip, ("  Hold Shift for %d more."):format(#list - shown), 0.6, 0.6, 0.6)
      break
    end
    shown = shown + 1
    Line(tooltip, "  " .. ns.TrainerLine(t, w), 0.9, 0.9, 0.9, true)
  end
  if #list == 0 then
    Line(tooltip, "  None known for your faction.", 0.6, 0.6, 0.6)
  end
  return true
end

local function ItemIDFromTooltip(tooltip, data)
  local id = data and ns.Num(data.id)
  if id then return id end
  if tooltip and tooltip.GetItem then
    local ok, _, link = pcall(tooltip.GetItem, tooltip)
    link = ok and ns.Str(link)
    if link then return tonumber(link:match("item:(%d+)")) end
  end
  return nil
end

ns.Listen("LOADED", function()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      if not tooltip or not tooltip.AddLine then return end
      local ok, err = pcall(ns.AddWeaponLines, tooltip, ItemIDFromTooltip(tooltip, data))
      if not ok then ns.Debug("tooltip", err) end
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
      pcall(ns.AddWeaponLines, tooltip, ItemIDFromTooltip(tooltip))
    end)
  end
end)
