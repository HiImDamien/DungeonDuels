# CPU opponent design

Status: design agreed Nov 18 2026. #31 (PlayerInput), #32 (duel), #33 (dungeon) and #34 (difficulty)
are built; next #48 (navigation, once rooms have walls).
Decision: the CPU drives a normal `Player` through a **controller abstraction**. It does not
fake input through the InputMap.

## Why not fake input?

`Input.action_press("p2_move_left")` would need no changes to `player.gd`, but:
- Input state is global. Pause menus, `MenuList` and the smoke test's `Input.parse_input_event`
  all read and write the same state, so a CPU pressing actions would interfere with them.
- Analog aim has to be split into four action strengths and put back together, which loses precision.
- `PlayerDevices.assign()` erases and rebinds the `p2_` actions at runtime. A CPU pushing those
  same actions would depend on that never changing.
- You can't test a brain on its own. A controller object can be unit-checked: "given this state,
  the brain wants to move left and shield".

## Shape

```
Player (player.gd)
 ├─ input: PlayerInput            ← the only thing player.gd reads controls from
 │    ├─ DeviceInput(prefix)      ← today's behavior: Input.get_vector(prefix + "move_left", …)
 │    └─ CpuInput                 ← plain fields that a brain writes each tick
 └─ CpuBrain (Node, only on CPU players)
      ├─ profile: CpuProfile      ← Easy / Medium / Hard .tres
      ├─ perception               ← reads this player's world: enemies, bullets, upgrades, opponent
      └─ behaviors                ← dungeon (fight / collect / dodge) and duel (strafe / shoot / shield / dodge)
```

### `PlayerInput` (`scripts/player/input/player_input.gd`, `class_name PlayerInput`, extends RefCounted)

```gdscript
func get_move() -> Vector2      # already deadzoned, length ≤ 1
func get_aim() -> Vector2       # raw; player.gd still applies the 0.2 threshold and keeps last_aim
func is_shooting() -> bool
func is_shielding() -> bool
```

- `DeviceInput.new(prefix)` contains exactly the `Input.get_vector` / `is_action_pressed` calls
  that `player.gd` makes today. `player._input_prefix` stays, because the smoke test reads it.
- `CpuInput` has `var move`, `var aim`, `var shoot`, `var shield`, and the getters return them.
- `player.gd` creates `DeviceInput` in `_ready()` unless something has already set `input`.
  The flip-h `facing` value comes from `get_move().x` instead of a separate `get_axis` call.
- Grace stun, the shield break and cooldown rules, and "can't shoot while shielding" stay in
  `player.gd`. The CPU gets the same restrictions as a human because it goes through the same code.

### Choosing the CPU

- `PlayerDevices.CPU := "cpu"` is a third device kind next to `"keyboard"` / `"joypad:<id>"`.
- In solo play the join screen passes `"cpu"` for the empty side. `"cpu"` behaves like `""` in `assign()` (actions erased, nothing bound),
  so no keyboard or controller can steer the CPU player.
- `player_for_event()` never returns the CPU's index, because no event's `device_of()` is
  `"cpu"`. That means the CPU can't pause and humans can't unpause for it, without any extra code.
- `PlayerDevices.cpu_difficulty` (`"easy"|"medium"|"hard"`) is set on the join screen and lives
  in the autoload, so it survives the scene change.
- Spawners attach the brain: `world.gd._ready()` (dungeon) and `final_battle.gd._spawn_player()`
  call `CpuBrain.attach_if_cpu(p)`. That checks `PlayerDevices.devices[p.player_index] == CPU`,
  sets `p.input = CpuInput.new()` and adds a `CpuBrain` child. The final battle spawns fresh
  players, so it attaches a fresh brain.

### `CpuBrain` (`scripts/player/cpu/cpu_brain.gd`, extends Node)

- Runs in `_physics_process`. It's a child of the player, so it stops on its own when the tree
  is paused or the player is freed.
- It **re-decides** every `profile.decision_interval` seconds and **steers** every frame toward
  the last decision. That keeps it cheap on web and gives it human-like hesitation.
- It does nothing while `player.is_dead` or `player.stunned` is true, so it waits out the grace
  countdown instead of getting a head start, and while it has no living opponent.
- `reaction_time` means a bullet must have been on screen that long before the CPU notices it.
  It then checks whether the bullet's path passes within `dodge_radius` in the next 0.6 s
  (`THREAT_LOOKAHEAD`). Each bullet gets one `dodge_skill` roll (react at all?) and one
  `shield_skill` roll (shield or sidestep). A sidestep is held for 0.25 s (`DODGE_COMMIT`).
- Threats are checked every frame (a handful of bullets, so it's cheap). Strafe direction, aim
  error and which enemy to fight wait for the next decision.
- **Human-looking movement** (#33 playtest: the first version snapped back and forth and reacted
  on the first frame). Its move direction turns at most `turn_rate` rad/s, so reversals are
  arcs. A new room's enemies, or upgrades appearing, start a `notice_time` (±25%) hesitation.
- **Aim** runs from the `AimPivot` (where the bow fires, 8 px above the feet) to the target's
  `CollisionShape2D`, not origin to origin: slimes' hitboxes sit lower than players', so
  origin-to-origin shots flew over them.
- It uses its own `RandomNumberGenerator`. `seed` is exported so the smoke test is deterministic.

### Perception: stay inside your own world

Split screen has **two worlds in one SceneTree**, so group lookups return nodes from both.
- Enemies: `get_nodes_in_group("enemy")` filtered by `enemy.target == player`. `enemy.gd`
  already sets `target`.
- Bullets: add `enemy_bullet` and `player_bullet` groups, filtered by
  `node.get_world_2d() == player.get_world_2d()`. In the duel, only bullets whose
  `shooter != player` count as threats.
- Upgrades: `get_nodes_in_group("upgrade")` (a new group added in `Upgrade._ready`), filtered by world.
- Opponent in the final battle: the other node in group `player` in the same world.
- Walls: a `PhysicsRayQueryParameters2D` on `player.get_world_2d().direct_space_state` against
  `PhysicsLayers.WALLS`. Physics queries are per World2D, so they're scoped to the right world
  automatically.

### Behaviors

All behaviors write a desired `move`/`aim`/`shoot`/`shield`. Dodge can override movement.
The brain tells the two phases apart by what it sees: an opponent in its own world means the
final battle, otherwise it's in the dungeon. The same brain follows the player from room to room,
because `RoomManager` re-parents the player rather than respawning it.

| Situation | Behavior |
|---|---|
| A bullet will pass within `dodge_radius` in the next `reaction_time` seconds | **Dodge**: move perpendicular to the bullet's path, away from walls. If the bullet would actually hit (within `SHIELD_HIT_RADIUS` of its body), `shield_skill` passes and the shield isn't broken, **shield** toward it instead (then no shooting). Near misses are always sidestepped, so the shield isn't worn down. |
| Dungeon, enemies alive | **Fight**: aim at the nearest enemy chasing it (lead and `aim_error` as in the duel), kite at `preferred_range` with the duel's strafe, shoot. |
| Dungeon, room cleared, upgrades offered | **Collect**: score the offered upgrades with `upgrade_weights` (missing ids weigh 1, plus a little random jitter; a `BulletUpgrade` always wins) and walk straight to the best one, without wall sliding. |
| Final battle | **Duel**: strafe around the opponent at `preferred_range`, lead the shot (`lead_accuracy` × predicted position), shoot, react to bullets as above. |

Pathing: rooms are open today, so steering is direct seek plus a wall-avoidance raycast.
Rooms with walls and hazards (milestone 5) add a `NavigationAgent2D` path. That's its own issue,
and it slots into the steering step without changing the rest.

### `CpuProfile` (`scripts/player/cpu/cpu_profile.gd`, Resource) plus `resources/cpu/{easy,medium,hard}.tres`

| Field | Easy | Medium | Hard |
|---|---|---|---|
| `decision_interval` (s) | 0.6 | 0.25 | 0.12 |
| `reaction_time` (s) | 0.5 | 0.3 | 0.1 |
| `aim_error_deg` | 6 | 12 | 2 |
| `aim_track_rate` (rad/s, 0 = instant) | 2 | 0 | 0 |
| `lead_accuracy` (0–1) | 0.0 | 0.5 | 1.0 |
| `shield_skill` (chance to shield a hit) | 0.1 | 0.4 | 0.95 |
| `dodge_radius` (px) | 8 | 14 | 24 |
| `dodge_skill` (chance to react to a bullet) | 0.4 | 0.75 | 1.0 |
| `turn_rate` (rad/s, 0 = instant) | 4 | 7 | 0 |
| `notice_time` (s) | 1.5 | 0.8 | 0 |
| `plant_chance` / `plant_time` (s) | 0.5 / 0.8 | 0.15 / 0.6 | 0 |
| `rest_chance` (hold fire for a decision) | 0.35 | 0 | 0 |
| `preferred_range` (px) | 90 | 80 | 100 |
| `upgrade_weights` | none (random) | none (random) | `attack_rate` 3, `health_max` 2.5, `shield_max` 1.5, `shield_regen` 1.5, `speed_boost` 1 |

Tuned in #34. Difficulty only changes these numbers. Easy never gets different code paths, and
Hard never gets extra stats. A bullet upgrade beats every stat upgrade at every level. Hard keeps
#33's first, instant reflexes (`turn_rate` 0, `notice_time` 0), which a playtest found too sharp
for Medium. The #34 playtest found Easy's big random aim error read as "always misses to one
side" and its constant motion as busy rather than easy, so Easy now plays *slower*: its aim swings
onto you (it hits a target standing still, lags a moving one), it stops to shoot, and it fires in
bursts.

The solo player picks the difficulty on the join screen (`PlayerDevices.cpu_difficulty`, Medium
by default). CPU vs CPU runs set `PlayerDevices.cpu_difficulty_override` per side instead; see
[balance.md](balance.md#cpu-vs-cpu).

## Testing

- Smoke test: a solo section where P2 is `"cpu"`. Check that P2 has a `CpuBrain`, that it moves
  and fires within a few seconds of grace ending, and that it clears at least one dungeon room.
  Hard CPU against an idle P1 in the final battle must produce a winner within N seconds.
- **CPU vs CPU** (`tests/cpu_vs_cpu.gd`, debug only): plays full matches headless and logs
  them with each side's difficulty to `user://balance_log_cpu.jsonl`, so upgrades and difficulties
  can be compared over many matches without a second human. Command in
  [balance.md](balance.md#cpu-vs-cpu).

## Out of scope for now

Machine learning, difficulty that adapts during a match, CPU teammates, and online play.
