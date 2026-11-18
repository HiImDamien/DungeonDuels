extends Resource
class_name CpuProfile
## How well a CPU opponent plays. Difficulty only changes these numbers: every
## profile runs the same CpuBrain code. Saved as resources/cpu/<difficulty>.tres.
## See docs/cpu-opponent.md for the starting values per difficulty.

## Seconds between re-decisions (strafe direction, aim error). Steering still
## runs every frame toward the last decision.
@export var decision_interval: float = 0.25
## Seconds a bullet has to be on screen before the CPU reacts to it.
@export var reaction_time: float = 0.3
## Each decision picks an aim offset in ±this many degrees.
@export var aim_error_deg: float = 12.0
## 0 = shoot at where the opponent is, 1 = fully lead to where they'll be.
@export_range(0.0, 1.0) var lead_accuracy: float = 0.5
## Chance (per incoming bullet) to raise the shield instead of sidestepping.
@export_range(0.0, 1.0) var shield_skill: float = 0.4
## A bullet that will pass closer than this (px) counts as a threat.
@export var dodge_radius: float = 14.0
## Distance (px) the CPU tries to keep from its target.
@export var preferred_range: float = 80.0
## Upgrade id → how much the CPU wants it. Empty = all equal. Used once the
## CPU plays the dungeon (#33).
@export var upgrade_weights: Dictionary = {}
