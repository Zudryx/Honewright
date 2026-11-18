-- Copyright (C) 2026 Zudryx. Part of Honewright, licensed under the GNU GPL v3 only.
-- SPDX-License-Identifier: GPL-3.0-only

-- Honewright: the newest changelog sections, for the "what's new" window.
-- Made from CHANGELOG.md by tests/make_whats_new.py: edit the changelog,
-- then run that script. Don't edit this file by hand.

local ADDON, ns = ...

ns.WHATS_NEW = {
  { version = "0.1.2", lines = {
    "- **Map pins land on the right map from the start.** WoW Forever uses the Classic city maps, so Honewright now tries those first instead of waiting until you've been in the city.",
    "- **Diagnostics for bug reports.** Honewright now notes what the game let it read while you play (skill values in and out of combat, skill-up messages, trainer windows, how often the auto-attack signals arrive) and saves it, with your last few `/hone probe` results, in `WTF\\Account\\<account>\\SavedVariables\\Honewright.lua`. Sending that file is all a bug report needs. It's reset for each new version so it stays small, and it doesn't change how anything works.",
  } },
  { version = "0.1.1", lines = {
    "- **New logo**, in the same style as Zudryx's other addons: a sword inside a green progress ring. It's the icon in the addon list too.",
    "- Honewright's name in chat and its windows now uses the logo's green.",
    "- No other changes.",
  } },
  { version = "0.1.0", lines = {
    "- **First test version.**",
    "- **On-screen panel:** each equipped weapon type with your skill against max for your level, colored from green (maxed) to red (far behind), plus any bonus from gear. Drag it where you like; click it for the weapon list.",
    "- **Weapon tooltips:** your skill for that weapon type. For a type you haven't learned: which weapon master teaches it, where, and the cost (hold Shift for every trainer). For a type your class can't use, it says so.",
    "- **Under-trained warning:** equip a weapon whose skill is 25 or more below max (you can change the number) and you get a warning on screen and in chat.",
    "- **Skill-up alerts:** every point shows the new value on screen, with an extra alert when a weapon reaches max for your level. Sound and chat line are optional.",
    "- **Progress toward the next point:** an estimate. The game doesn't let addons count real swings, so Honewright times how long your auto-attack runs in combat, divides by your weapon speed, and learns from your own skill-ups how many swings a point takes. Before your first skill-up with a weapon it shows swings so far.",
    "- **Weapon list** (`/hone learn`): every weapon type your class can use in WoW Forever (including the ones Forever added, like One-Handed Axes for Rogues), your skill in the ones you know, and the weapon master, location and cost for the rest, with a button to pin them on your map.",
    "- **Real prices:** open a weapon master and Honewright remembers what they actually teach and charge, reputation discounts included.",
    "- `/hone probe` lists what the game lets Honewright read on your client, in and out of combat.",
    "- Honewright only shows information. It never attacks, equips or buys training for you.",
  } },
}
