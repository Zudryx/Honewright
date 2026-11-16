-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: /hone commands, the addon-list button, and the first-login line.

local ADDON, ns = ...

ns.HELP_LINES = {
  "/hone learn  - weapon types for your class and where to learn them",
  "/hone panel on | off  - the on-screen panel",
  "/hone lock | unlock  - stop or allow dragging the panel",
  "/hone reset  - move the panel back to its starting spot",
  "/hone warn <points 1-100> | off  - warn when an equipped weapon is this far below max (now %s)",
  "/hone alerts on | off  - skill-up alerts on screen",
  "/hone sound on | off  - sound with alerts",
  "/hone tooltip on | off  - lines in weapon tooltips",
  "/hone progress reset  - forget what Honewright learned about swings per point",
  "/hone options  - the settings page",
  "/hone new  - what's new in this version",
  "/hone probe  - what the game lets Honewright read (for bug reports)",
}

local function Help()
  ns.Print(("version %s. Commands:"):format(ns.VERSION))
  for _, line in ipairs(ns.HELP_LINES) do
    local warn = ns.Setting("equipWarning") and tostring(ns.Setting("warnGap")) or "off"
    DEFAULT_CHAT_FRAME:AddMessage("  " .. line:format(warn))
  end
end

local function OnOff(arg, key, label)
  if arg == "on" or arg == "off" then
    ns.SetSetting(key, arg == "on")
  else
    ns.SetSetting(key, not ns.Setting(key))
  end
  ns.Print(label .. ": " .. (ns.Setting(key) and "on" or "off") .. ".")
end

function ns.ShowWhatsNew()
  local first = ns.WHATS_NEW and ns.WHATS_NEW[1]
  if not first then return end
  ns.Print("what's new in " .. first.version .. ":")
  for _, line in ipairs(first.lines) do
    line = line:gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1")
    DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
  end
end

function ns.Command(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "help" then Help()
  elseif cmd == "learn" or cmd == "list" or cmd == "weapons" then ns.ToggleLearnWindow()
  elseif cmd == "panel" then OnOff(arg, "panel", "Panel")
  elseif cmd == "lock" then ns.SetSetting("panelLocked", true) ns.Print("Panel locked.")
  elseif cmd == "unlock" then ns.SetSetting("panelLocked", false) ns.Print("Panel unlocked: drag it where you like.")
  elseif cmd == "reset" then ns.ResetPanelPosition() ns.Print("Panel moved back to its starting spot.")
  elseif cmd == "warn" then
    local n = tonumber(arg)
    if arg == "off" then ns.SetSetting("equipWarning", false) ns.Print("Under-trained weapon warning: off.")
    elseif arg == "on" then ns.SetSetting("equipWarning", true) ns.Print("Under-trained weapon warning: on.")
    elseif n and n >= 1 and n <= 100 then
      ns.SetSetting("warnGap", math.floor(n))
      ns.SetSetting("equipWarning", true)
      ns.Print(("Warning when an equipped weapon is %d or more below max."):format(math.floor(n)))
    else
      ns.Print("Use /hone warn <points> (like /hone warn 25), or /hone warn off.")
    end
  elseif cmd == "alerts" then OnOff(arg, "skillUpAlert", "Skill-up alerts")
  elseif cmd == "sound" then OnOff(arg, "skillUpSound", "Alert sound")
  elseif cmd == "tooltip" or cmd == "tooltips" then OnOff(arg, "tooltip", "Tooltip lines")
  elseif cmd == "progress" and arg == "reset" then
    ns.ResetProgress()
    ns.Print("Forgot the swings-per-point estimates. They come back after your next skill-ups.")
    ns.UpdatePanel()
  elseif cmd == "options" or cmd == "config" or cmd == "settings" then ns.Options.Open()
  elseif cmd == "new" then ns.ShowWhatsNew()
  elseif cmd == "probe" then ns.Probe()
  elseif cmd == "debug" then
    ns.db.debug = not ns.db.debug
    ns.Print("Debug messages: " .. (ns.db.debug and "on" or "off") .. ".")
  else
    ns.Print("Unknown command. /hone help lists them.")
  end
end

SLASH_HONEWRIGHT1 = "/honewright"
SLASH_HONEWRIGHT2 = "/hone"
SlashCmdList["HONEWRIGHT"] = function(msg) ns.Command(msg) end

-- The addon-list button (the compartment by the minimap)
function Honewright_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then ns.Options.Open() else ns.ToggleLearnWindow() end
end

function Honewright_OnAddonCompartmentEnter(_, menuButton)
  if not GameTooltip then return end
  GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
  GameTooltip:AddLine(ns.Colored(ns.ACCENT, "Honewright"))
  GameTooltip:AddLine("Click: weapon types and trainers", 1, 1, 1)
  GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
  GameTooltip:Show()
end

function Honewright_OnAddonCompartmentLeave()
  if GameTooltip then GameTooltip:Hide() end
end

ns.Listen("LOADED", function()
  ns.On("PLAYER_LOGIN", function()
    local last = ns.db.lastVersion
    ns.db.lastVersion = ns.VERSION
    if not last then
      ns.Print(("%s installed. The panel shows your weapon skills; /hone learn lists weapon types you could learn; /hone help for the rest."):format(ns.VERSION))
    elseif last ~= ns.VERSION then
      ns.Print(("updated to %s. /hone new shows what changed."):format(ns.VERSION))
    end
  end)
end)
