extends Upgrade
class_name shield_max

@export var increase_amount := 5

func _init() -> void:
	description = "Max\nShield"

func apply(p: CharacterBody2D) -> void:
	var shield: Shield = p.get_node("Shield")
	shield.max_health += increase_amount  # setter also refills the shield
