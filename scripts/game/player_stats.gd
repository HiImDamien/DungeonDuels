class_name PlayerStats
extends RefCounted
## Snapshot of everything a player earned in the dungeon, carried across the
## scene change into the final battle.
##
## To persist a new stat: add a field, then read it in capture() and write it
## back in apply_to(). Defaults match a fresh player.

var max_health: int = player.STARTING_MAX_HEALTH
var kills: int = 0
var speed: float = 75.0
var fire_rate: float = 0.3
var bullet_modes: Array[String] = []
var shield_max_health: int = 10
var shield_cooldown_time: float = 2.2
var shield_recharge_interval: float = 0.3
var shield_recharge_delay: float = 0.5

func capture(p: player) -> void:
	max_health = p.max_health
	kills = p.kills
	speed = p.speed

	var weapon = p.current_weapon
	if weapon != null:
		fire_rate = weapon.fire_rate
		bullet_modes = weapon.bullet_modes.duplicate() if "bullet_modes" in weapon else []

	shield_max_health = p.shield.max_health
	shield_cooldown_time = p.shield.cooldown_time
	shield_recharge_interval = p.shield.recharge_interval
	shield_recharge_delay = p.shield.recharge_delay

## Must run after the player's _ready() so the weapon and shield exist.
func apply_to(p: player) -> void:
	p.max_health = max_health
	p.health = max_health
	p.kills = kills
	p.speed = speed

	var weapon = p.current_weapon
	if weapon != null:
		weapon.fire_rate = fire_rate
		if weapon.has_method("add_bullet_mode"):
			for mode in bullet_modes:
				weapon.add_bullet_mode(mode)

	p.shield.max_health = shield_max_health
	p.shield.cooldown_time = shield_cooldown_time
	p.shield.recharge_interval = shield_recharge_interval
	p.shield.recharge_delay = shield_recharge_delay
