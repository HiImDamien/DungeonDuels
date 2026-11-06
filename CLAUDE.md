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

**Scene flow:** `scenes/ui/title_screen.tscn` (main scene) → `scenes/game/game.tscn` (dungeon, split screen) → `scenes/game/final_battle.tscn` (one shared arena) → back to the title. Scenes change with `get_tree().change_scene_to_file`.

**`GameState` autoload** (`scripts/game/game_state.gd`) holds everything that has to survive a scene change: the phase (DUNGEON/FINAL_BATTLE), the 63s match timer (ticked by `game.gd._process`), the 3s grace period (async, using signals), each player's `PlayerStats` (keyed by player index 1/2), pauses left, and the opponent ticker signal. `start_match()` resets all of it, so rematches start clean. When the timer expires, `game.gd` captures stats from the live players, and `final_battle.gd` spawns fresh `Player` instances and calls `PlayerStats.apply_to()` on them.

**Split screen:** `game.tscn` has two `SubViewport`s, each holding a world (`player1_world.tscn` / `player2_world.tscn`, script `world.gd`) with its own `Player` and `RoomManager`. `RoomManager` picks rooms from `normal_rooms`/`boss_rooms` (layouts in `scenes/rooms/layouts/`, built on `room_base.tscn` with `PlayerSpawn` + `EnemySpawns/` children of type `EnemySpawn`), counts enemies, and offers `Upgrade` pickups when a room is cleared. Every third room is a boss room, and clearing it also offers a `BulletUpgrade`.

**Player input:** `player.gd` reads input actions with the prefix `""` for P1 and `"p2_"` for P2 (e.g. `p2_move_left`). The Input Map currently binds keyboard plus joypad device 0 to P1 actions and joypad device 1 to `p2_` actions. `pause` is bound for any device. Menus don't use actions. `MenuList` (`scripts/ui/menu_list.gd`) reads raw events, and `MenuList.player_for_event()` maps an event to a player (key → P1, joypad → device+1). `PauseMenu`, `ControlsScreen` and `MenuList.controlling_player` all depend on that mapping. Keyboard events and the first joypad both report device 0, so tell devices apart by event class plus device id.

**UI conventions:** Menus are `MenuList` containers of `Button`s, with built-in focus turned off (`FOCUS_NONE`) and navigation handled in `_unhandled_input`. Mark input as handled *before* doing anything that might change the scene; otherwise `get_viewport()` will be null afterwards. Hidden buttons are skipped by `get_buttons()`. Overlays such as `ControlsScreen`, `CountdownOverlay` and the win screen in `final_battle.gd` are built in code rather than in `.tscn` files. `InputLabels` creates the Controls screen text from the live Input Map, so rebinding updates it automatically.

**Pausing:** `PauseMenu` (CanvasLayer, `PROCESS_MODE_ALWAYS`) sets `get_tree().paused`. Only the player who paused can resume. Resuming counts down 3-2-1 first, and each player gets `GameState.PAUSES_PER_PLAYER` pauses per match. Async waits that should stop during a pause use `create_timer(t, false)` (process_always = false).

**Physics layers:** named in project.godot `[layer_names]` and mirrored as constants in `scripts/physics_layers.gd`.

## Smoke test notes

`smoke_test.gd` runs `PROCESS_MODE_ALWAYS` and plays a real match by injecting input with `Input.parse_input_event` through its `press(button, device)` and `press_key(key)` helpers. It reaches into private fields (`_root`, `_messages`, `_offered_upgrades`, `_input_prefix`), so renaming those breaks it. For a new behavior, add `check(...)` calls in the matching section rather than writing a separate test.
