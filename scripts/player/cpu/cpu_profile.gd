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
## How fast (radians per second) its aim swings toward the target, so it
## lands on a target that stands still and lags behind one that moves.
## 0 = snaps onto the target instantly.
@export var aim_track_rate: float = 0.0
## 0 = shoot at where the opponent is, 1 = fully lead to where they'll be.
@export_range(0.0, 1.0) var lead_accuracy: float = 0.5
## Chance (per incoming bullet) to raise the shield instead of sidestepping.
@export_range(0.0, 1.0) var shield_skill: float = 0.4
## A bullet that will pass closer than this (px) counts as a threat.
@export var dodge_radius: float = 14.0
## Chance (per incoming bullet) that it reacts at all, by dodging or shielding.
@export_range(0.0, 1.0) var dodge_skill: float = 0.75
## How fast (radians per second) its movement direction can turn, so a
## reversal is an arc instead of a snap. 0 = instant (inhumanly twitchy).
@export var turn_rate: float = 7.0
## Seconds it hesitates (±25%) before reacting to a new room's enemies or to
## upgrades appearing. 0 = reacts on the first frame.
@export var notice_time: float = 0.8
## Chance per decision to stop and stand while shooting, for plant_time
## seconds (±25%). It still sidesteps bullets. 0 = always on the move.
@export_range(0.0, 1.0) var plant_chance: float = 0.0
@export var plant_time: float = 0.8
## Chance per decision to hold fire until the next decision, so it shoots in
## bursts instead of holding the trigger down. 0 = always firing.
@export_range(0.0, 1.0) var rest_chance: float = 0.0
## Distance (px) the CPU tries to keep from its target.
@export var preferred_range: float = 80.0
## Upgrade id (Upgrade.pick_id(), e.g. "attack_rate") → how much the CPU
## wants it after a room clear. Missing ids weigh 1.0, so empty = all equal.
## A bullet upgrade (offered after a boss) always wins regardless.
@export var upgrade_weights: Dictionary = {}
