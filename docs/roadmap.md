# Roadmap

Planned Nov 18 2026 from [ideas.md](ideas.md). The issues are on the fork
([HiImDamien/DungeonDuels](https://github.com/HiImDamien/DungeonDuels/milestones)). Each issue is
self-contained: goal, files, acceptance criteria and how to test.

## Decisions

- **Identity: a quick competitive race.** Short matches, best of three, a tight set of weapons,
  shields and rooms. Characters are starting loadouts only. Roguelite depth is parked.
- **CPU right after the fixes.** Solo players get a real game early, and the CPU then serves as a
  balance-test bot (CPU vs CPU) for everything after it.
- **CPU drives the player through a `PlayerInput` controller object**, not fake InputMap
  presses. See [cpu-opponent.md](cpu-opponent.md).
- **Every combat addition must work with the CPU.** That's in each issue's acceptance criteria.

## Phases

Phases run in order. Within a phase, the order below follows the dependencies.

### 1. Online (existing, release work, can run alongside the others)
#8 browser test, #9 teammates' OK, #10 README, #11 publish, #12 a friend plays from the link.

### 2. Playable alone: fixes first, then the CPU
| # | Issue | Size | Depends on |
|---|---|---|---|
| #29 | Make shields worth using | S–M | — |
| #30 | Log upgrade picks and match results | S | — |
| #31 | Move player controls behind `PlayerInput` | S–M | — |
| #32 | CPU fights in the final battle | M | #31 |
| #33 | CPU plays the dungeon | M | #32 |
| #34 | CPU difficulty Easy / Medium / Hard (+ CPU vs CPU) | M | #33 |
| #35 | Balance pass on power-ups | S–M | #29, #30, #34 |

#13 was decided (CPU opponent), #14 was replaced by #31–#34, and #15 was already done by CI.

### 3. Best of three
| # | Issue | Size | Depends on |
|---|---|---|---|
| #36 | Best 2 out of 3 rounds | M | — |
| #37 | Settings screen: match length, rounds, CPU difficulty | S–M | #36, #34 |

### 4. Combat depth
| # | Issue | Size | Depends on |
|---|---|---|---|
| #38 | Weapon pickups and the axe (melee) | M | — |
| #39 | Heavy weapon: slow, high damage | M | #38 |
| #63 | Shield decides blocks: `Shield.try_block()` | S | #29 |
| #58 | Perfect block: a center hit costs nothing and reflects | M | #63 |
| #64 | Balance the parry: discourage turtling | S–M | #58 |
| #41 | Absorb shield (deferred) | M | #63 |
| #42 | Boomerang and pierce bullet modes | M | — |

Shield council, Nov 27 2026: #40 (reflect shield) was closed because reflecting became what a perfect
block does (#58), so no shield-mode framework is needed. Block logic lives only in
`Shield.try_block()` (#63). #41 is deferred until after #64, and #55 is parked (see below).

### 5. More to fight
| # | Issue | Size | Depends on |
|---|---|---|---|
| #43 | Enemy: mortar (telegraphed lobbed shots) | M | — |
| #44 | Enemy: wisp (homing orbs you can shoot down) | M | — |
| #45 | New boss | M–L | #43, #44 |
| #46 | Room hazards: spikes and pits | M | — |
| #47 | New room layouts with walls and hazards | M | #46 |
| #48 | CPU navigates walls and avoids hazards | M | #47 |
| #49 | New final battle arenas | M | #48 |
| #50 | Characters as starting loadouts | M | #38, #39 |

## Parked (revisit if the identity shifts toward a roguelite; only #55 has an issue)

- Achievements (local, `user://`, IndexedDB on web)
- Unique character abilities beyond loadouts
- Dungeon themes and maps beyond new arenas
- More than one extra boss
- More projectile-pattern enemies beyond the mortar and wisp
- Slime contact damage and a shield bash (#55): revisit together with melee weapons (#38)
