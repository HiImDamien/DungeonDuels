# Balance log

Every finished match appends one JSON line to `user://balance_log.jsonl`, so upgrades can be
compared with data instead of gut feel (#35, and CPU-vs-CPU runs in #34). The line is also
`print()`ed.

Only a match that ends with a winner is logged. Quitting from the pause menu writes nothing, so
the log never has half records.

## Record

```json
{"time":"2026-11-18T18:22:02Z","version":"dev","duration_s":26.8,"winner":1,
 "p1":{"device":"keyboard","picks":["health_max","shield_regen","cardinal"],"rooms_cleared":3,"kills":14,"deaths":1,"perfect_blocks":2},
 "p2":{"device":"joypad","picks":["shield_regen"],"rooms_cleared":1,"kills":6,"deaths":1,"perfect_blocks":0}}
```

| Field | Meaning |
|---|---|
| `time` | UTC time the match ended |
| `version` | Project Settings > Application > Config > Version, or `dev` while it's blank |
| `duration_s` | Seconds played, dungeon + final battle. Pauses don't count. |
| `winner` | `1` or `2` |
| `device` | `keyboard`, `joypad` or `cpu` (the solo opponent). No ids. `none` = an empty side, `unassigned` = `game.tscn` run straight from the editor. |
| `picks` | Upgrades in the order they were taken. Stat upgrades by `class_name` (`attack_rate`, `speed_boost`, `health_max`, `shield_regen`, `shield_max`), bullet upgrades by mode (`spread`, `bounce`, `big`, `tracking`, `cardinal`, `burst`). |
| `rooms_cleared`, `kills`, `deaths` | Dungeon only. A death there means a respawn. |
| `perfect_blocks` | Centre-hit blocks that reflected a bullet (#58), dungeon and final battle together. |
| `difficulty` | Only on a `cpu` player: `easy`, `medium` or `hard`. |

## How it's collected

`GameState` (`scripts/game/game_state.gd`) keeps `picks`, `rooms_cleared`, `deaths` and `perfect_blocks` per player,
and `start_match()` resets them.
- `Upgrade._on_body_entered` calls `record_pick(index, pick_id())`.
- `RoomManager._on_room_cleared` calls `record_room_cleared`.
- `game.gd` watches each player's `is_dead` and calls `record_death` when it flips on.
- `Shield._perfect_block` calls `record_perfect_block`.
- `final_battle.gd` calls `log_match_result(winner)`, which builds the record and hands it to
  `BalanceLog.append` (`scripts/game/balance_log.gd`). Only the first call per match writes.

To log a new field, add it in `log_match_result` and update the table above.

## Where the file is

- **macOS:** `~/Library/Application Support/Godot/app_userdata/DungeonDuels/balance_log.jsonl`
  (Godot: Project > Open User Data Folder).
- **Web:** `user://` is stored in the browser's IndexedDB, where you can't easily read it. Open
  the dev tools console instead (⌥⌘J in Chrome) and copy the line that starts with `{"time"`.
- **CPU vs CPU:** `user://balance_log_cpu.jsonl` by default (see below), so CPU runs never
  mix into the human log.
- **Smoke test:** it writes to `user://balance_log_smoke.jsonl` and deletes the file afterwards,
  so test runs never touch the real log.

## Summarizing it

`tests/balance_summary.sh` prints, for every upgrade and bullet mode, how many players took it
and their win rate, plus win rates for stacking a stat upgrade 2+ times:

```bash
tests/balance_summary.sh                     # the CPU vs CPU log
tests/balance_summary.sh path/to/log.jsonl   # any log (several files are merged)
```

A player counts once per match, so 20 matches = 40 players. A win rate from fewer than about 10
players is mostly noise.

One-off `jq` queries:

```bash
cd ~/Library/Application\ Support/Godot/app_userdata/DungeonDuels
```

Win rate by first pick (both players count, `none` = won without picking anything):

```bash
jq -s -c '[.[] | {pick: (.p1.picks[0] // "none"), won: (.winner == 1)}, {pick: (.p2.picks[0] // "none"), won: (.winner == 2)}] | group_by(.pick) | map({first_pick: .[0].pick, players: length, win_pct: ((map(select(.won)) | length) * 100 / length | round)})' balance_log.jsonl
```

Win rate by CPU difficulty (CPU vs CPU log; a player counts once per match):

```bash
jq -s -c '[.[] | {d: .p1.difficulty, won: (.winner == 1)}, {d: .p2.difficulty, won: (.winner == 2)}] | map(select(.d)) | group_by(.d) | map({difficulty: .[0].d, players: length, wins: (map(select(.won)) | length)})' balance_log_cpu.jsonl
```

Most picked upgrades:

```bash
jq -s -c '[.[] | .p1.picks[], .p2.picks[]] | group_by(.) | map({pick: .[0], times: length}) | sort_by(-.times)' balance_log.jsonl
```

## CPU vs CPU

`tests/cpu_vs_cpu.gd` plays full CPU vs CPU matches headless, back to back, and logs each one
(with both difficulties) to `user://balance_log_cpu.jsonl`:

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path . -s res://tests/cpu_vs_cpu.gd -- --p1=hard --p2=easy --matches=10
```

- `--p1` / `--p2`: `easy`, `medium` or `hard` (default `medium`). `--log=<path>` writes elsewhere.
- Each match runs in real time (about 70 s). `--fixed-fps` doesn't speed it up usefully, because
  `weapon.gd` times its fire rate with the wall clock, so the CPUs would barely shoot.
- A final battle with no winner after 120 s is skipped and not logged.
- It sets `PlayerDevices.cpu_difficulty_override` for each side; normal play leaves that empty.
- To collect data faster, run several runners at once, each with its own `--log`, and pass all
  the files to `tests/balance_summary.sh`. Four at once worked fine on a MacBook.
- **For upgrade balance, use Medium vs Medium.** Medium has no `upgrade_weights`, so each CPU
  takes one of the two offered stat upgrades at random, and the bullet mode is random too (the
  room offers one; the CPU always takes it while the bow has room, and once the bow holds two
  modes it weighs it like a stat upgrade). With equal skill on both sides, the upgrades are what
  differs between winner and loser.
- **Caveat:** Medium only shields 40% of the time (`shield_skill = 0.4`), so CPU data undervalues
  the shield upgrades and overvalues extra hearts. Check those against human matches.

## Balance pass, Nov 20 2026 (#35)

Three batches of 60 Medium vs Medium matches (120 players each). Win rate of the players who
took each pick at least once; ±6 points of noise for stat upgrades, ±10 for bullet modes.

| Pick | Before | After tuning | Final (4 hearts) |
|---|---|---|---|
| health_max | **75%** (x2: 90%) | **71%** | **69%** |
| attack_rate | 46% | 51% | 59% |
| shield_max | 42% | 51% | 40% |
| shield_regen | 47% | 51% | 42% |
| speed_boost | 50% | 48% | 47% |
| spread | **69%** | 58% | 59% |
| bounce | **35%** | 53% | 52% |
| big | 53% | 63% | 66% |
| tracking | 52% | 42% | 50% |
| cardinal | 57% | 45% | 39% |
| burst | 41% | 61% | 39% |

Changes:
- **health_max: one pickup only** (cap 5 → 4, then start 3 → 4 hearts with cap 5). Two pickups
  won 90%. A duel hit always costs 1 heart, so going from 3 to 5 meant surviving 67% more hits.
- **Players start with 4 hearts** (was 3), so the one pickup is +25% hits instead of +33%. It
  barely moved the win rate (71% → 69%) and duels got about 3 s longer (74.5 s → 77.9 s average).
- **spread: outer bullets at ±22°** (was ±15°). The narrow fan covered Medium's 12° aim error;
  now a sloppy aim can fall between the bullets at duel range.
- **bounce: bullets fly 25% faster** (200 → 250). The open duel arena rarely gives a bounce. The
  CPU leads its shots for the faster speed.
- **Hard weighs shield_max and shield_regen at 2** (was 1.5), after the #34 playtest found them
  very noticeable.
- **Full bow:** the bow holds two modes. The bullet upgrade label now says what a third would
  replace ("Big Bullets (replaces Spread Shot)"), and the CPU stops treating it as a must-take.

Known exception: **health_max stays at ~69%**, above the ~65% target. In an even hit-trading duel
one extra heart decides most close fights whatever the starting number. It's accepted for now
and left to human playtests, where players shield far more than Medium does. If it still feels
dominant, the next idea is a cost (e.g. −15 move speed).

Big (66%), cardinal and burst (39%) swing ±10–20 points between batches on 20–35 players each,
so they're treated as noise. Shield max has come in low every batch, which matches the shield
caveat above.
