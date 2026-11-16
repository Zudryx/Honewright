-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: settings page in Esc > Options > AddOns > Honewright.
--
-- Uses the game's Settings API and writes to the same table the /hone
-- commands use. If this client doesn't have the parts it needs, the page
-- lists the commands instead, so it never breaks the options window.

local ADDON, ns = ...

local Options = {}
ns.Options = Options
local category, registered

local function VarType(kind)
  local vt = Settings and Settings.VarType
  if kind == "boolean" then return vt and vt.Boolean or "boolean" end
  return vt and vt.Number or "number"
end

local function OnChange(setting, variable, key)
  local cb = function(_, value) ns.Fire("SETTING_CHANGED", key, value) end
  if setting and setting.SetValueChangedCallback then
    setting:SetValueChangedCallback(cb)
  elseif Settings.SetOnValueChangedCallback then
    Settings.SetOnValueChangedCallback(variable, cb)
  end
end

local function BuildVertical()
  local cat, layout = Settings.RegisterVerticalLayoutCategory("Honewright")
  local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  assert(cat and layout and CreateCheckbox and Settings.CreateSlider, "settings API incomplete")
  local tbl = ns.settings

  local function Header(text)
    if CreateSettingsListSectionHeaderInitializer then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  local function Check(key, label, tooltip)
    local variable = "Honewright_" .. key
    local s = Settings.RegisterAddOnSetting(cat, variable, key, tbl, VarType("boolean"), label, ns.DEFAULTS[key])
    CreateCheckbox(cat, s, tooltip)
    OnChange(s, variable, key)
  end

  local function Slider(key, label, tooltip, min, max, step, format)
    local variable = "Honewright_" .. key
    local s = Settings.RegisterAddOnSetting(cat, variable, key, tbl, VarType("number"), label, ns.DEFAULTS[key])
    local opts = Settings.CreateSliderOptions(min, max, step)
    if opts.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
      opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
    end
    Settings.CreateSlider(cat, s, opts, tooltip)
    OnChange(s, variable, key)
  end

  local function Button(label, text, tooltip, fn)
    if CreateSettingsButtonInitializer then
      layout:AddInitializer(CreateSettingsButtonInitializer(label, text, fn, tooltip, true))
    end
  end

  Header("On-screen panel")
  Check("panel", "Show the panel", "Your equipped weapons' skill against max for your level, with progress toward the next point.")
  Check("panelLocked", "Lock the panel", "Stops it moving when you drag it. Click still opens the weapon list.")
  Check("panelProgress", "Show progress toward the next point", "An estimate: the game doesn't let addons count real swings, so Honewright times your auto-attack in combat.")
  Check("panelHideMaxed", "Hide while every weapon is maxed", "Only while the panel is locked, so you can always find it to move it.")
  Button("Panel position", "Reset", "Move the panel back to its starting spot.", function() ns.ResetPanelPosition() end)

  Header("Warnings and alerts")
  Check("equipWarning", "Warn when I equip an under-trained weapon", "An on-screen warning and a chat line when you equip a weapon whose skill is far below max.")
  Slider("warnGap", "Warn when this far below max", "How many points below max counts as under-trained. Also colors the skill orange.",
    5, 100, 5, function(v) return ("%d points"):format(v) end)
  Check("skillUpAlert", "Alert on every skill-up", "Shows the new value on screen each time a weapon skill goes up.")
  Check("maxedAlert", "Alert when a weapon reaches max", "A separate alert when a weapon skill reaches max for your level.")
  Check("skillUpSound", "Play a sound with alerts", nil)
  Check("skillUpChat", "Also print skill-ups in chat", "The game prints its own line too; this adds the max next to it.")

  Header("Tooltips")
  Check("tooltip", "Weapon skill in weapon tooltips", "Your skill for that weapon type, or that you haven't learned it.")
  Check("tooltipTrainers", "Where to learn it, in tooltips", "For weapon types you haven't learned: which weapon master teaches it, where, and the cost.")

  Header("Weapon list")
  Button("Weapon types for your class", "Open", "Every weapon type your class can use, where to learn the ones you don't know, and a map pin.",
    function() ns.ToggleLearnWindow(true) end)

  Settings.RegisterAddOnCategory(cat)
  return cat
end

local function BuildCanvas()
  local f = CreateFrame("Frame")
  f.name = "Honewright"
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Honewright " .. ns.VERSION)
  local body = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  body:SetJustifyH("LEFT")
  body:SetText("This game version can't show Honewright's settings here. These commands do the same:\n\n"
    .. table.concat(ns.HELP_LINES or {}, "\n"))
  local cat = Settings.RegisterCanvasLayoutCategory(f, "Honewright")
  Settings.RegisterAddOnCategory(cat)
  return cat
end

function Options.Register()
  if registered or not Settings then return end
  registered = true
  local ok, cat = pcall(BuildVertical)
  if not ok then
    ns.Debug("settings page: " .. tostring(cat))
    ok, cat = pcall(BuildCanvas)
  end
  if ok then category = cat end
end

function Options.Open()
  if not category then
    ns.Print("The settings page isn't available in this game version. /hone help lists every command.")
    return
  end
  local id = category.GetID and category:GetID() or category
  if not pcall(Settings.OpenToCategory, id) then
    ns.Print("Find Honewright under Esc > Options > AddOns.")
  end
end

ns.Listen("LOADED", function() Options.Register() end)
