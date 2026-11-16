# Contributing to Honewright

Thanks for helping! You don't need to write code to help.

## Report a bug or wrong data

Open an [issue](https://github.com/Zudryx/Honewright/issues/new/choose). The most useful things to include:

- Your class, level and faction, and your Honewright version (shown in the addon list and by `/hone help`).
- What happened, and what you expected.
- The text of any Lua error. Type `/console scriptErrors 1` in game to make WoW show them.
- The output of `/hone probe` (run it once out of combat and once while auto-attacking a mob; screenshots are fine).

For a wrong trainer, cost or class weapon: say what the game shows (a screenshot of the weapon master's window is perfect).

## Send a change (pull request)

### Ground rules

- **Honewright stays an assistant.** It only reads and shows information. Nothing may attack, equip, buy training, send chat messages or control the game for the player.
- **Write data and notes in your own words**, and link your sources in the pull request.
- **Don't name other addons** anywhere in the addon, its docs, the changelog or pull requests, and don't suggest Honewright is one of them or works with them.

### Where things are

| Path | What it is |
|---|---|
| `Honewright/Data.lua` | Weapon types, which classes can learn them, weapon masters. |
| `Honewright/Skills.lua` | Reading skills and equipped weapons; noticing skill-ups. |
| `Honewright/Progress.lua` | The swings estimate. |
| `Honewright/Alerts.lua` | Skill-up alerts and the under-trained warning. |
| `Honewright/Display.lua` | The on-screen panel. |
| `Honewright/Tooltip.lua` | Lines in weapon tooltips. |
| `Honewright/Trainers.lua` / `LearnWindow.lua` | Weapon masters, map pins and the weapon list. |
| `Honewright/Options.lua` | The settings page in Esc > Options > AddOns. |
| `MAINTAINING.md` | Releases and data updates. |
| `updater/` | The Windows updater. |

### Run the tests

You need Lua 5.4 (on Windows, WSL works; on Linux, `sudo apt install lua5.4`). From the repository folder:

```
lua5.4 tests/syntax.lua Honewright
lua5.4 tests/smoke_test.lua Honewright
```

Both must pass.

### Versions and releases

- Raise the version in **both** `Honewright/Honewright.toc` and `Honewright/Core.lua` (the tests check they match), add a short, plain-words entry at the top of `CHANGELOG.md`, and run `python3 tests/make_whats_new.py`.
- Open pull requests against the `testing` branch. Merged changes become a test build (a GitHub pre-release) for the owner to try in game; once approved, `testing` goes into `main` and the release is published.

### License of your contribution

Honewright is licensed under the GNU GPL v3 only (see [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md)). By sending a pull request, you agree that your contribution is released under the same license.
