extends Upgrade
class_name health_max

## Hard cap: players can never exceed this many hearts.
const MAX_HEARTS: int = 5

func _init() -> void:
	description = "+1 Max\nHealth"

func is_available(p: CharacterBody2D) -> bool:
	return p.max_health < MAX_HEARTS

func apply(p: CharacterBody2D) -> void:
	p.max_health += 1
	p.health = mini(p.health + 1, p.max_health)
