# Honewright

**Your weapon skill at a glance, for WoW Forever.**

WoW Forever kept Classic's weapon skills. You have to learn a weapon type before you can use it, a new weapon type starts at skill 1, and until its skill catches up with your level you miss, and hit for less, far more often. The game doesn't explain any of that, so a new weapon can feel broken. Honewright puts the numbers where you'll see them and tells you what to do about them.

## Features

- **On-screen panel:** each equipped weapon type with your skill against max for your level, colored from green (maxed) to red (far behind), plus any bonus from gear.
- **Weapon tooltips:** your skill for that weapon type, or which weapon master teaches it, where, and what it costs. Weapon types your class can't use are called out.
- **Under-trained warning** when you equip a weapon whose skill is far below max (you pick how far).
- **Skill-up alerts** on screen for every point, and when a weapon reaches max for your level.
- **Progress toward the next point:** an estimate learned from your own skill-ups (addons can't count real swings in WoW Forever, so Honewright times your auto-attack in combat).
- **Weapon list** (`/hone learn`): every weapon type your class can use in Forever, including the new ones (One-Handed Axes for Rogues, Polearms for Druids, Two-Handed Axes and Maces for Shamans), with the trainer, location and cost, and a button to pin them on your map.
- **Real prices:** open a weapon master and Honewright remembers what they actually charge, reputation discounts included.

## Commands

`/hone learn`, `/hone panel on|off`, `/hone lock|unlock`, `/hone warn <points>|off`, `/hone alerts on|off`, `/hone tooltip on|off`, `/hone options`, `/hone probe`. `/hone help` lists them all.

## Fair play

Honewright only reads information and shows it to you. It never attacks, equips, swaps weapons, buys training or sends chat messages for you.

## Details

- Built for World of Warcraft: Forever (interface 16001).
- Free and open source under the GNU GPL v3: https://github.com/Zudryx/Honewright
- Found a bug or wrong trainer data? Please open an issue on GitHub.
