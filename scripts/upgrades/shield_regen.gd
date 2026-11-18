extends Upgrade
class_name shield_regen
## Each pick halves the break cooldown and speeds up recharge (#29), so two
## picks are easy to see: a broken shield is back in 1s instead of 4s, and a
## full refill takes about 1.4s instead of 4s.

@export var cooldown_multiplier := 0.5
@export var recharge_interval_multiplier := 0.6
@export var recharge_delay_multiplier := 0.6

## Timers can't run with a wait time of zero, so every stat bottoms out here.
const MIN_TIME := 0.05

func _init() -> void:
	description = "Shield\nRegen"

func is_available(p: CharacterBody2D) -> bool:
	var shield: Shield = p.get_node("Shield")
	return shield.cooldown_time > MIN_TIME \
		or shield.recharge_interval > MIN_TIME \
		or shield.recharge_delay > MIN_TIME

func apply(p: CharacterBody2D) -> void:
	var shield: Shield = p.get_node("Shield")
	shield.cooldown_time     = maxf(shield.cooldown_time * cooldown_multiplier, MIN_TIME)
	shield.recharge_interval = maxf(shield.recharge_interval * recharge_interval_multiplier, MIN_TIME)
	shield.recharge_delay    = maxf(shield.recharge_delay * recharge_delay_multiplier, MIN_TIME)
