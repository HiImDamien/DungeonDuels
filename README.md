# DungeonDuels

A two-player, split-screen dungeon crawler that ends in a duel. You and a friend each fight
through your own dungeon for 63 seconds, clearing rooms of bats and slimes and grabbing upgrades
as you go. When the timer runs out, you both drop into one arena with everything you collected,
and the last one standing wins.

**Play it in your browser: [hiimdamien.itch.io/dungeon-duels](https://hiimdamien.itch.io/dungeon-duels)**

<!-- TODO(#10): add a gameplay GIF here, e.g. docs/media/gameplay.gif -->

## How to play

1. Choose **Play** on the title screen.
2. On the join screen, each player presses a button on their device (the keyboard or a
   controller), picks a side and readies up. Left is Player 1, right is Player 2.
3. Clear rooms in your dungeon. Every cleared room offers an upgrade, and every third room is a
   boss whose defeat offers a bullet upgrade.
4. When the timer hits zero, the final battle starts. Your upgrades come with you.

**Solo play:** if you're alone, join with one device, ready up, then press A / Enter again. The
other player spawns but stands still, which is handy for trying the game out.

### Controls

Each player uses one device. Controllers use the same layout for both players.

| Action | Keyboard | Controller (Xbox / PlayStation) |
|---|---|---|
| Move | W A S D | Left stick |
| Aim | Arrow keys | Right stick |
| Shoot | Arrow keys (aiming fires) | RT / R2 |
| Shield | Space | LT / L2 |
| Pause | Esc / P | Start / Options |
| Menu confirm / back | Enter / Backspace | A / Cross, B / Circle |

The in-game **Controls** screen (title menu or pause menu) always shows the current bindings.

**Controllers in the browser:** browsers only report a controller after you press one of its
buttons, so press a button on the join screen. If it still doesn't show up, restart the browser
with the controller already connected.

## Run it locally

You need [Godot 4.7](https://godotengine.org/download/) (the standard build, not .NET).

1. Clone the repo and open `project.godot` in Godot.
2. Press **F5** (or the Play button) to run from the title screen.

To build the Web version the way CI does:

```bash
godot --headless --export-release "Web" build/web/index.html
```

### Smoke test

A headless end-to-end test drives the menus, the join screen, a dungeon run and the final battle.
Its exit code is the number of failed checks.

```bash
tests/run_smoke_test.sh
```

If `godot` isn't on your `PATH`:

```bash
GODOT=/path/to/Godot tests/run_smoke_test.sh
```

Every pull request and push to `main` runs the smoke test and a Web export on GitHub Actions.
Pushes to `main` then deploy to itch.io.

## Docs

| Doc | What's in it |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Scene flow, `GameState`, split screen, rooms and upgrades, weapons, physics layers |
| [docs/input.md](docs/input.md) | Player input, `PlayerDevices`, join screen, solo play |
| [docs/cpu-opponent.md](docs/cpu-opponent.md) | CPU opponent design |
| [docs/ui.md](docs/ui.md) | Menus, overlays and pausing |
| [docs/testing.md](docs/testing.md) | How the smoke test works |
| [docs/deployment.md](docs/deployment.md) | CI, itch.io deploy and local Web export |
| [docs/roadmap.md](docs/roadmap.md) | What's planned next |
| [docs/itch-page.md](docs/itch-page.md) | Text for the itch.io page |

## Credits

DungeonDuels started as a team project for CS 780 in spring 2026
([original repo](https://github.com/gt1074/DungeonDuels)). Credits below follow the git history.

| Who | Built |
|---|---|
| **Gavin Tucker** | The first playable demo (player, shield, bat, camera), controller support, the first two-view split screen, the bat's triple shot, the room manager and room layouts, and the upgrade system (attack rate, max shield, shield regen) |
| **Deven Deming** | The axe and bow weapons and the chest pickup, bullet upgrades after boss fights (combining modes, burst shot, tracking and cardinal shots), and room-clear and damage fixes |
| **Niall Gavin** | The title screen, the health pickup, the big slime boss and its slash attack, and the room banners |
| **Damien Fabiano** | Full two-player split screen, the HUD, shield health and break, aiming, the slime enemy, the match timer, grace period, final battle and ending, music, the controls screen, the pause menu, the join screen with solo play, the smoke test, the Web build and itch.io deploy, and the work since the class ended |

### Damien's part

After the semester I kept going on my own fork: refactored enemies, rooms and upgrades into
editor scenes and base classes, named the physics layers, added a headless smoke test and CI that
deploys to itch.io, added the Controls screen, the pause menu and the join screen (one device per
player, solo play), made the game work in the browser, and started a CPU opponent behind a
`PlayerInput` interface.

### Assets

All third-party assets are CC0 (public domain).

- **Brackeys' Platformer Bundle** (CC0), repackaged by Brackeys. Sprites by
  [analogStudios_](https://analogstudios.itch.io/) and
  [RottingPixels](https://rottingpixels.itch.io/), sounds by Asbjørn Thirslund, music by Sofia
  Thirslund, and the Pixel Operator font by Jayvee Enaguas (HarvettFox96). Full list in
  [assets/brackeys_platformer_assets/LICENSE & CREDITS.txt](assets/brackeys_platformer_assets/LICENSE%20%26%20CREDITS.txt).
- **"Mutant Club"** by HoliznaCC0 (CC0).
<!-- TODO(#9): credit assets/sprites/chest.png once its source and license are confirmed. -->
