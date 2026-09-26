extends Upgrade
class_name attack_rate

## Seconds removed from the weapon's delay between shots per pickup.
@export var shot_wait_decrease: float = 0.1

## Fastest allowed delay between shots. 0.3 → 0.2 → 0.1 is two pickups.
const MIN_FIRE_RATE := 0.1

func _init() -> void:
	description = "Attack\nSpeed"

func is_available(p: CharacterBody2D) -> bool:
	# Small epsilon so float error (0.3 - 0.1 - 0.1 = 0.0999…) can't leave it on offer.
	return p.current_weapon != null and p.current_weapon.fire_rate > MIN_FIRE_RATE + 0.001

func apply(p: CharacterBody2D) -> void:
	p.current_weapon.fire_rate = maxf(p.current_weapon.fire_rate - shot_wait_decrease, MIN_FIRE_RATE)
