-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: the newest changelog sections, for the "what's new" window.
-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,
-- then run that script. Don't edit this file by hand.

local ADDON, ns = ...

ns.WHATS_NEW = {
  { version = "0.1.3", lines = {
    "- **Weapon masters tell you what they can teach again.** WoW Forever lists a trainer's skills a little differently from other game versions, so Honewright couldn't tell which ones you can learn and stayed quiet. Now, when you open a weapon master, chat lists what they can teach you that you don't know yet, with the real price (reputation discounts included).",
    "- The diagnostics now count every trainer window you open, and save everything the game says about each weapon master's skills.",
  } },
  { version = "0.1.2", lines = {
    "- **Map pins land on the right map from the start.** WoW Forever uses the Classic city maps, so Honewright now tries those first instead of waiting until you've been in the city.",
    "- **Diagnostics for bug reports.** Honewright now notes what the game let it read while you play (skill values in and out of combat, skill-up messages, trainer windows, how often the auto-attack signals arrive) and saves it, with your last few `/hone probe` results, in `WTF\\Account\\<account>\\SavedVariables\\Honewright.lua`. Sending that file is all a bug report needs. It's reset for each new version so it stays small, and it doesn't change how anything works.",
  } },
  { version = "0.1.1", lines = {
    "- **New logo**, in the same style as Zudryx's other addons: a sword inside a green progress ring. It's the icon in the addon list too.",
    "- Honewright's name in chat and its windows now uses the logo's green.",
    "- No other changes.",
  } },
}
