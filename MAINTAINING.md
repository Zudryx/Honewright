# Maintaining Honewright

## Ground rules

- **Honewright stays an assistant.** It only reads and shows information. Never add anything that attacks, equips or swaps weapons, buys training, sends chat messages or controls the game from outside (the updater only downloads files).
- **Don't name other addons** in the addon, its docs, the changelog, release notes or pull requests, and never suggest Honewright is one of them or works with them.
- **License headers.** Honewright is GPL-3.0 only. New Lua files start with the same two license lines as the others (`-- Copyright (C) 2026 Zudryx. ...` and `-- SPDX-License-Identifier: GPL-3.0-only`). Don't change `LICENSE`, which must stay the unmodified GPL text; the name and logo terms live in `NOTICE.md`.
- **The owner tests before anything reaches players.** Work goes on the `testing` branch. Each push there publishes a GitHub **pre-release** test build (`vX.Y.Z-test.N`): not on CurseForge, and the normal updater skips it ("Update Honewright (testing).bat" installs it). Merge `testing` into `main` only after the owner approves; that publishes the normal GitHub release, which the Windows updater installs. **Every approved change is released on GitHub this way.** A test build needs a version that isn't released yet: bump the version first.
- **CurseForge only when the owner says a batch of changes is finished.** A push to `main` never uploads to CurseForge. When the owner calls it done, run the Release workflow by hand on `main` with **CurseForge: upload**, which sends the current release.
- **Keep the CurseForge page in step.** `docs/curseforge-description.md` is the text for the CurseForge project page. When a release changes what Honewright does, update it too.

## Test

```
lua5.4 tests/syntax.lua Honewright
lua5.4 tests/smoke_test.lua Honewright
```

(or `python3 tests/runlua.py tests/<file>.lua Honewright`). Both must pass. The smoke test runs the whole addon against a simulated game API.

## Version, changelog

- Bump the version in **both** `Honewright/Honewright.toc` (`## Version:`) and `Honewright/Core.lua` (`ns.VERSION`). The syntax test checks they match.
- Add a `## x.y.z` section at the top of `CHANGELOG.md`, written for players: what changed in plain words. Then run `python3 tests/make_whats_new.py`, which copies the newest sections into `Honewright/WhatsNew.lua` for `/hone new`.

## Weapon data

`Honewright/Data.lua` holds the weapon types (item subclass, skill line ID, the proficiency spell that learns it), which classes can learn each one in WoW Forever, and the weapon masters (name, city, area, map coordinates, what they teach). Sources: Warcraft Tavern's WoW Forever weapon trainer guide (`warcrafttavern.com/forever/guides/weapon-trainers/`), checked November 2026. Write the data in our own format, never copy guide text.

When a patch changes trainers, costs or class weapons, update the tables and the matching checks in `tests/smoke_test.lua`. A player's own visit to a weapon master already overrides the table for them (`HonewrightDB.trainersSeen`), so a wrong entry only matters until they've been there.

City map IDs: Honewright learns each capital's real map ID when you're in it (or open a weapon master there). `CITY_MAP_CANDIDATES` is only the first guess before that. `/hone probe` shows the map you're on and what each city resolves to.

## What the game lets addons read

`/hone probe` lists it, in and out of combat: the skill API, whether skill values or skill-up chat lines are hidden, weapon speed, and how often the auto-attack events arrived. If a patch hides something new, that's the first place to look.

## When WoW Forever patches

If the game's interface version changes, update `## Interface:` in `Honewright/Honewright.toc` (`/dump select(4, GetBuildInfo())` in game). Then bump the version.

## CurseForge uploads

Nothing is uploaded automatically. When the owner says a batch of changes is finished, run the Release workflow by hand on `main` (Actions > Release > Run workflow) with **CurseForge: upload**: `.github/scripts/curseforge_upload.py` sends the current release's zip. It needs `## X-Curse-Project-ID: <id>` in `Honewright/Honewright.toc` (the project's number on CurseForge) and the `CF_API_KEY` repository secret. To check the token without uploading, choose **CurseForge: check**.
