# CLAUDE.md

DungeonDuels is a two-player local split-screen dungeon crawler that ends in a duel. It's built in
Godot 4.7 (standard GDScript build, not .NET; the `[dotnet]` section in project.godot is a
leftover), uses the Compatibility renderer, and ships as a Web export on itch.io.

## Always true

- **Web first.** Code must work in a browser. Check `OS.has_feature("web")` for platform-specific
  behavior. Don't assume gamepads exist at startup, because browsers only report one after a
  button is pressed.
- **project.godot** holds the Input Map, autoloads and layer names. An open Godot editor can
  overwrite outside edits, so check with the user before editing it.
- **`.uid` files** are tracked. Commit the `.uid` that the test runner's import step creates
  along with any new script.
- **Devices** are `"keyboard"` / `"joypad:<id>"` strings, never bare ids (the keyboard's id is 16
  in Godot 4.7).
- **Two worlds, one tree.** Split screen runs two worlds in one SceneTree, so filter group lookups
  by world.

## Commands

```bash
tests/run_smoke_test.sh                       # headless end-to-end smoke test; exit code = failed checks
GODOT=/path/to/Godot tests/run_smoke_test.sh  # if `godot` isn't on PATH
```

There's no linter or build step. For a new behavior, add `check(...)` calls to `tests/smoke_test.gd`.

## Read the doc for the area you're touching

| Doc | When |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Scene flow, `GameState`, split screen, rooms/upgrades, weapons, physics layers |
| [docs/input.md](docs/input.md) | Player input, `PlayerDevices`, join screen, solo play |
| [docs/cpu-opponent.md](docs/cpu-opponent.md) | CPU opponent design (`PlayerInput`, `CpuBrain`, profiles) |
| [docs/ui.md](docs/ui.md) | `MenuList` conventions, overlays, pausing |
| [docs/balance.md](docs/balance.md) | Balance log: record format, where the file is, `jq` summaries |
| [docs/testing.md](docs/testing.md) | Smoke test internals and the private fields it depends on |
| [docs/deployment.md](docs/deployment.md) | CI, itch.io deploy, local web export |
| [docs/roadmap.md](docs/roadmap.md) | Phases, milestone order, parked ideas |

Issues live on the fork: `gh ... -R HiImDamien/DungeonDuels`.
