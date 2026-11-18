# Ideas backlog (brainstorm, Nov 18 2026)

Raw ideas from a brainstorm, grouped and lightly sized. **Processed on Nov 18 2026 into
[roadmap.md](roadmap.md)** (issues #29–#50). The open questions at the bottom are answered there.
This file is kept as the original brainstorm record.

Sizes: **S** = an evening, **M** = a few sessions, **L** = multi-week / needs design first.

## Current state (for context)
- Enemies: slime, slime_hard, bat (shoots), boss_slime. One enemy bullet type.
- Upgrades: attack_rate, health_max, shield_max, shield_regen, speed_boost, plus BulletUpgrade (boss rooms).
- Rooms: 4 layouts (bat_flank, boss_arena, crossfire, slime_swarm). Open rooms, no hazards.
- Weapons: `axe_weapon.tscn`, `bow_weapon.tscn` and `weapon_pickup.tscn` exist in `scenes/weapons/`.
  It's unclear how much of this is wired up. The planning pass should check.
- Solo play exists, but P2 just stands still, so they're a sitting duck in the final arena.

## Fixes / balance (do first, cheap, high payoff)
- **Shields feel useless; shield regen stat is useless.** Rework shield value before adding shield variants. (S–M)
- **Balance pass on power-ups.** Needs a quick way to measure (e.g. log upgrade picks + match winner). (S)

## Shields & weapons (core combat depth)
- New shield types: **reflect** bullets, **absorb** bullets and convert them (to ammo, damage, heal...). (M)
- Weapons with different tradeoffs: **melee**, **heavy/slow** (high damage, low fire rate). (M)
- New bullet types: **boomerang**, others (pierce, bounce, spread). Could fold into BulletUpgrade. (M)

## Content
- New enemies with **different projectile patterns** (not just bat-style shots). (M each)
- New boss(es). (M–L)
- New rooms, including **complex rooms with walls and hazards** (spikes, pits, lava, moving parts). (M)
- New maps (different final arenas / dungeon themes). (M)
- New characters: start with "different starting weapon/stats"; unique abilities later. (M → L)

## Match structure & settings
- **Best 2 out of 3** rounds per game. Touches GameState, the final battle and the win screen. (M)
- **Settings screen:** match length, difficulty. Timer is currently a fixed 63s in GameState. (S–M)

## Single-player
- **CPU opponent for P2** with Easy / Medium / Hard. Biggest single feature. Fixes the solo
  sitting-duck problem. Needs to drive the same Player via a fake-input or controller layer. (L)

## Meta
- Achievements (local, saved to user://; web uses IndexedDB-backed storage). (M)

## Open questions for planning
- What's the core identity? A quick competitive race, or a deeper roguelite? This affects how far content/characters go.
- Should the CPU opponent come before content, so solo players get a real game?
- Can we feed the CPU's "brain" through the existing input-prefix system, or does it need its own controller abstraction?
