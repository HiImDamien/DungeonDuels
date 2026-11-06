# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

DungeonDuels is a two-player local split-screen dungeon crawler in Godot 4.7 (standard GDScript build, not .NET; the `[dotnet]` section in project.godot is a leftover). It targets the Compatibility renderer and has a Web export, so code must work in a browser: check `OS.has_feature("web")` for platform-specific behavior, and don't assume gamepads are connected at startup (browsers usually only report a gamepad after a button on it is pressed).

## Commands

```bash
tests/run_smoke_test.sh                     # headless end-to-end smoke test; exit code = failed checks
GODOT=/path/to/Godot tests/run_smoke_test.sh  # if `godot` isn't on PATH
```

- The runner first does `godot --headless --editor --quit` to import, so new `class_name` scripts get registered, and then runs `res://tests/smoke_test.tscn`.
- A run fails if the summary line isn't `N checks, 0 failed`, if any `SCRIPT ERROR` is logged, or if it hangs longer than 180s.
- There is one test (`tests/smoke_test.gd`) and no way to run part of it. To try a section, open `smoke_test.tscn` in the editor and run the current scene (F6, or ⌘R on macOS), or temporarily cut down `_run()`.
- There is no linter or build step.
- Godot generates a `.uid` file next to each script on import, and these are tracked in git. Commit the `.uid` that the runner's import step creates along with any new script.

## Editing project.godot

The Input Map, autoloads and layer names live in `project.godot`. If the Godot editor is open, it can overwrite changes made to this file from outside the editor, so check with the user before editing it. Input actions are serialized as `Object(InputEventKey, ...)` blobs where `"device"` matters: `-1` means any device.

## Architecture

**Scene flow:** `scenes/ui/title_screen.tscn` (main scene) → `scenes/ui/join_screen.tscn` (each device joins and picks a side) → `scenes/game/game.tscn` (dungeon, split screen) → `scenes/game/final_battle.tscn` (one shared arena) → back to the title. Scenes change with `get_tree().change_scene_to_file`.

**`GameState` autoload** (`scripts/game/game_state.gd`) holds everything that has to survive a scene change: the phase (DUNGEON/FINAL_BATTLE), the 63s match timer (ticked by `game.gd._process`), the 3s grace period (async, using signals), each player's `PlayerStats` (keyed by player index 1/2), pauses left, and the opponent ticker signal. `start_match()` resets all of it, so rematches start clean. When the timer expires, `game.gd` captures stats from the live players, and `final_battle.gd` spawns fresh `Player` instances and calls `PlayerStats.apply_to()` on them.

**Split screen:** `game.tscn` has two `SubViewport`s, each holding a world (`player1_world.tscn` / `player2_world.tscn`, script `world.gd`) with its own `Player` and `RoomManager`. `RoomManager` picks rooms from `normal_rooms`/`boss_rooms` (layouts in `scenes/rooms/layouts/`, built on `room_base.tscn` with `PlayerSpawn` + `EnemySpawns/` children of type `EnemySpawn`), counts enemies, and offers `Upgrade` pickups when a room is cleared. Every third room is a boss room, and clearing it also offers a `BulletUpgrade`.

**Player input:** `player.gd` reads input actions with the prefix `""` for P1 and `"p2_"` for P2 (e.g. `p2_move_left`). Each player has exactly one device (the keyboard or one controller), chosen on the join screen. The left side is P1 and the right side is P2.
- The `PlayerDevices` autoload (`scripts/game/player_devices.gd`) stores the choice as `"keyboard"` / `"joypad:<id>"`, built from the event class plus its device id.
- `assign()` rewrites both players' actions in the InputMap at runtime (in memory only), using P1's saved bindings in project.godot as templates. In project.godot, P1 actions hold the keyboard and controller templates. The `p2_` actions there are only defaults for when no join has happened, e.g. running `game.tscn` straight from the editor.
- `pause` stays bound to any device. `PlayerDevices.player_for_event()` (wrapped by `MenuList.player_for_event()`) decides who pressed something, and devices that haven't joined map to 0. `PauseMenu`, `ControlsScreen` and `MenuList.controlling_player` all depend on it.
- In Godot 4.7, keyboard events use `InputEvent.DEVICE_ID_KEYBOARD` (16). Saved `"device":0` key bindings are converted to 16 on load, and joypads start at 0. Never identify a device by id alone.
- The join screen is event-driven and never lists connected joypads at startup, because browsers only report a gamepad after one of its buttons is pressed.

**UI conventions:** Menus are `MenuList` containers of `Button`s, with built-in focus turned off (`FOCUS_NONE`) and navigation handled in `_unhandled_input`. Mark input as handled *before* doing anything that might change the scene; otherwise `get_viewport()` will be null afterwards. Hidden buttons are skipped by `get_buttons()`. Overlays such as `ControlsScreen`, `CountdownOverlay` and the win screen in `final_battle.gd` are built in code rather than in `.tscn` files. `InputLabels` creates the Controls screen text from the saved bindings (`PlayerDevices.template_events()`), so editing the Input Map updates it automatically, and the text doesn't change with who picked which side.

**Pausing:** `PauseMenu` (CanvasLayer, `PROCESS_MODE_ALWAYS`) sets `get_tree().paused`. Only the player who paused can resume. Resuming counts down 3-2-1 first, and each player gets `GameState.PAUSES_PER_PLAYER` pauses per match. Async waits that should stop during a pause use `create_timer(t, false)` (process_always = false).

**Physics layers:** named in project.godot `[layer_names]` and mirrored as constants in `scripts/physics_layers.gd`.

## Smoke test notes

`smoke_test.gd` runs `PROCESS_MODE_ALWAYS` and plays a real match by injecting input with `Input.parse_input_event` through its `press(button, device)`, `press_key(key)` and `join_side(device, side)` helpers. The first match joins the keyboard as P1 and controller 2 (device 1) as P2. The rematch joins controllers 1 and 2. It reaches into private fields (`_root`, `_messages`, `_offered_upgrades`, `_input_prefix`), so renaming those breaks it. For a new behavior, add `check(...)` calls in the matching section rather than writing a separate test.
