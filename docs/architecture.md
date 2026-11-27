# Architecture

## Scene flow

`scenes/ui/title_screen.tscn` (main scene) → `scenes/ui/join_screen.tscn` (each device joins and
picks a side) → `scenes/game/game.tscn` (dungeon, split screen) → `scenes/game/final_battle.tscn`
(one shared arena) → back to the title. Scenes change with `get_tree().change_scene_to_file`.

## `GameState` autoload (`scripts/game/game_state.gd`)

Holds everything that has to survive a scene change:
- the phase (DUNGEON/FINAL_BATTLE)
- the 63s match timer, ticked by `game.gd._process`
- the 3s grace period (async, using signals)
- each player's `PlayerStats`, keyed by player index 1/2
- pauses left
- the opponent ticker signal
- the balance log counters (picks, rooms cleared, deaths), written once per finished match by
  `log_match_result()`. See [balance.md](balance.md).

`start_match()` resets all of it, so rematches start clean. When the timer expires, `game.gd`
captures stats from the live players, and `final_battle.gd` spawns fresh `Player` instances and
calls `PlayerStats.apply_to()` on them. `PlayerStats` currently carries fire rate and bullet modes,
but not which weapon the player has.

## Split screen and rooms

`game.tscn` has two `SubViewport`s, each holding a world (`player1_world.tscn` /
`player2_world.tscn`, script `world.gd`) with its own `Player` and `RoomManager`.

The two worlds share **one SceneTree**, so `get_nodes_in_group()` returns nodes from both. Filter
by world (`node.get_world_2d()`) or by owner (`enemy.target`). Physics queries are per World2D,
so they're already scoped to the right world.

`RoomManager` picks rooms from `normal_rooms`/`boss_rooms` (layouts in `scenes/rooms/layouts/`,
built on `room_base.tscn` with `PlayerSpawn` + `EnemySpawns/` children of type `EnemySpawn`),
counts enemies, and offers `Upgrade` pickups when a room is cleared. Every third room is a boss
room, and clearing it also offers a `BulletUpgrade`.

To add an upgrade, extend `Upgrade` and add its scene to `UPGRADE_SCENES` in `room_manager.gd`.
To add a bullet mode, add it to `BulletUpgrade.MODES` and implement it in `bow_weapon.gd` or
`player_bullet.gd`.

## Weapons

`scenes/weapons/` has `weapon.tscn` (base `Weapon`: `fire_rate`, `try_fire()`),
`bow_weapon.tscn` (the only weapon equipped, in `player._ready()`, and the only one with bullet
modes), `axe_weapon.tscn` (a melee swing) and `weapon_pickup.tscn`. Nothing places the axe or the
pickup yet. The `resources/*_data.tres` `WeaponData` files (bow, axe, sword) aren't referenced by
any code.

## Shields

`scripts/player/shield.gd` (`Shield`, a child of each player) is raised with the shield button and
faces the aim. **`Shield.try_block(bullet)` is the only code that decides a block** (#63): both
bullet scripts call it from `_on_area_entered` and free themselves when it returns true, so any new
shield behavior goes in there. It skips the owner's own shots. A hit within `PERFECT_HALF_WIDTH` of
the centre line, measured in shield-local space (`to_local()` undoes the shrink-with-health scale),
is a **perfect block** (#58): no cost, and a fresh `player_bullet` goes back along the aim, owned by
the blocker, with the original damage, no modes and `reflected = true`. A reflected bullet is always
a normal block, so a rally ends after one return. Feedback is a flash, `PerfectSound` (a plain
`AudioStreamPlayer`, because a 2D one would be silent in our SubViewports, which don't enable the 2D
audio listener) and a stripe drawn in `_draw()` (the sprite has `show_behind_parent`).

## Physics layers

Named in project.godot `[layer_names]` and mirrored as constants in `scripts/physics_layers.gd`.
Use those constants rather than raw numbers.
