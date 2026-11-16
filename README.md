<p align="center"><img src="media/logo.png" alt="Honewright logo" width="128"></p>

# Honewright

**Your weapon skill at a glance, for World of Warcraft: Forever.**

WoW Forever kept Classic's weapon skills. You have to learn a weapon type before you can use it, a new weapon type starts at skill 1, and until its skill catches up with your level you miss, and hit for less, far more often. The game doesn't explain any of that, so a new weapon can feel broken. Honewright puts the numbers where you'll see them and tells you what to do about them.

## What it does

- **On-screen panel.** Each equipped weapon type with your skill against max for your level, colored from green (maxed) to red (far behind), plus any bonus from gear. Drag it where you like; click it for the weapon list; hover for details.
- **Weapon tooltips.** Your skill for that weapon type. For a type you haven't learned: which weapon master teaches it, where, and what it costs (hold Shift for every trainer). For a type your class can't use, it says so.
- **Under-trained warning.** Equip a weapon whose skill is 25 or more points below max (you pick the number) and you get a warning on screen and in chat.
- **Skill-up alerts.** Every point shows the new value on screen, with a separate alert when a weapon reaches max for your level. Sound and a chat line are optional.
- **Progress toward the next point** (an estimate, see below).
- **Weapon list** (`/hone learn`). Every weapon type your class can use in WoW Forever, including the ones Forever added (One-Handed Axes for Rogues, Polearms for Druids, Two-Handed Axes and Maces from a trainer for Shamans). Your skill in the ones you know; the weapon master, location, level and cost for the rest, with a button to pin them on your map.
- **Real prices.** Weapon skills cost 10 silver (Polearms 1 gold, from level 20) before reputation discounts. Open a weapon master and Honewright remembers what they really teach and charge.

## How the progress estimate works

WoW Forever keeps the combat log closed to addons, so no addon can count your real swings. What Honewright *can* see is when your auto-attack (or Auto Shot / Shoot) is switched on, whether you're in combat, your weapon speed, and casts of Throw and Shoot. It adds up the time you spend auto-attacking in combat, divides by your weapon speed for an estimated number of swings, and learns from your own skill-ups how many of those a point has been taking. Before your first skill-up with a weapon it shows the swings so far; after that, a percentage toward the next point.

It's labeled as an estimate everywhere because it is one: time spent out of range or stunned still counts, and special attacks don't add extra swings. Because the estimate learns from your own skill-ups in the same units, those errors mostly cancel out. `/hone progress reset` forgets what it learned.

## Commands

| Command | What it does |
|---|---|
| `/hone learn` | Weapon types for your class and where to learn them |
| `/hone panel on` / `off` | The on-screen panel |
| `/hone lock` / `unlock` | Stop or allow dragging the panel |
| `/hone reset` | Move the panel back to its starting spot |
| `/hone warn <points>` / `off` | Warn when an equipped weapon is this far below max (25 by default) |
| `/hone alerts on` / `off` | Skill-up alerts on screen |
| `/hone sound on` / `off` | Sound with alerts |
| `/hone tooltip on` / `off` | Lines in weapon tooltips |
| `/hone progress reset` | Forget the swings-per-point estimates |
| `/hone options` | The settings page (also in Esc > Options > AddOns) |
| `/hone new` | What's new in this version |
| `/hone probe` | What the game lets Honewright read (for bug reports) |

`/honewright` works too. The addon-list button by the minimap opens the weapon list (right-click: settings).

## Fair play

Honewright is an assistant: it only reads information and shows it to you. It never attacks, equips, swaps weapons, buys training or does anything else for you, and it doesn't send chat messages. Everything in it works within what WoW Forever allows addons to do.

## Install

Honewright is still in testing. Test builds are on the [Releases](https://github.com/Zudryx/Honewright/releases) page as GitHub pre-releases.

- **By hand:** download `Honewright-x.y.z.zip`, and copy the `Honewright` folder inside it to `World of Warcraft\_forever_\Interface\AddOns`. Then `/reload` (or restart the game).
- **Windows updater:** unzip `HonewrightUpdater.zip` anywhere and double-click `Update Honewright.bat` for releases, or `Update Honewright (testing).bat` for the newest test build. It finds your AddOns folder, backs up your current copy and installs the new one. Your settings are kept by WoW in `WTF`, so updating never touches them.

## Where the data comes from

The weapon masters, what they teach, the costs and which classes can learn which weapon types come from Warcraft Tavern's WoW Forever guides, checked November 2026 (see `Honewright/Data.lua`). What a weapon master's own window shows always wins over that list. If something is wrong, please open an issue.

## License

Honewright is free software, licensed under the GNU General Public License v3 only. Copyright (C) 2026 Zudryx. The name and logo have their own terms: see [NOTICE.md](NOTICE.md).

Honewright is a fan-made project and isn't made, endorsed or supported by Blizzard Entertainment.
