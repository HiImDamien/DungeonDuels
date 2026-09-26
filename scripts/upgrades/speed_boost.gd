extends Upgrade
class_name speed_boost

const BOOST_AMOUNT: float = 25.0
const MAX_SPEED:    float = 175.0

func _init() -> void:
	description = "Speed\nBoost"

func is_available(p: CharacterBody2D) -> bool:
	return p.speed < MAX_SPEED

func apply(p: CharacterBody2D) -> void:
	p.speed = minf(p.speed + BOOST_AMOUNT, MAX_SPEED)
