# Balance log

Every finished match appends one JSON line to `user://balance_log.jsonl`, so upgrades can be
compared with data instead of gut feel (#35, and CPU-vs-CPU runs in #34). The line is also
`print()`ed.

Only a match that ends with a winner is logged. Quitting from the pause menu writes nothing, so
the log never has half records.

## Record

```json
{"time":"2026-11-18T18:22:02Z","version":"dev","duration_s":26.8,"winner":1,
 "p1":{"device":"keyboard","picks":["health_max","shield_regen","cardinal"],"rooms_cleared":3,"kills":14,"deaths":1},
 "p2":{"device":"joypad","picks":["shield_regen"],"rooms_cleared":1,"kills":6,"deaths":1}}
```

| Field | Meaning |
|---|---|
| `time` | UTC time the match ended |
| `version` | Project Settings > Application > Config > Version, or `dev` while it's blank |
| `duration_s` | Seconds played, dungeon + final battle. Pauses don't count. |
| `winner` | `1` or `2` |
| `device` | `keyboard`, `joypad`, later `cpu` (#32). No ids. `none` = the idle side in solo play, `unassigned` = `game.tscn` run straight from the editor. |
| `picks` | Upgrades in the order they were taken. Stat upgrades by `class_name` (`attack_rate`, `speed_boost`, `health_max`, `shield_regen`, `shield_max`), bullet upgrades by mode (`spread`, `bounce`, `big`, `tracking`, `cardinal`, `burst`). |
| `rooms_cleared`, `kills`, `deaths` | Dungeon only. A death there means a respawn. |

## How it's collected

`GameState` (`scripts/game/game_state.gd`) keeps `picks`, `rooms_cleared` and `deaths` per player,
and `start_match()` resets them.
- `Upgrade._on_body_entered` calls `record_pick(index, pick_id())`.
- `RoomManager._on_room_cleared` calls `record_room_cleared`.
- `game.gd` watches each player's `is_dead` and calls `record_death` when it flips on.
- `final_battle.gd` calls `log_match_result(winner)`, which builds the record and hands it to
  `BalanceLog.append` (`scripts/game/balance_log.gd`). Only the first call per match writes.

To log a new field, add it in `log_match_result` and update the table above.

## Where the file is

- **macOS:** `~/Library/Application Support/Godot/app_userdata/DungeonDuels/balance_log.jsonl`
  (Godot: Project > Open User Data Folder).
- **Web:** `user://` is stored in the browser's IndexedDB, where you can't easily read it. Open
  the dev tools console instead (⌥⌘J in Chrome) and copy the line that starts with `{"time"`.
- **Smoke test:** it writes to `user://balance_log_smoke.jsonl` and deletes the file afterwards,
  so test runs never touch the real log.

## Summarizing it

```bash
cd ~/Library/Application\ Support/Godot/app_userdata/DungeonDuels
```

Win rate by first pick (both players count, `none` = won without picking anything):

```bash
jq -s -c '[.[] | {pick: (.p1.picks[0] // "none"), won: (.winner == 1)}, {pick: (.p2.picks[0] // "none"), won: (.winner == 2)}] | group_by(.pick) | map({first_pick: .[0].pick, players: length, win_pct: ((map(select(.won)) | length) * 100 / length | round)})' balance_log.jsonl
```

Most picked upgrades:

```bash
jq -s -c '[.[] | .p1.picks[], .p2.picks[]] | group_by(.) | map({pick: .[0], times: length}) | sort_by(-.times)' balance_log.jsonl
```
