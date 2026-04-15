extends Upgrade
class_name attack_rate

@export var shot_wait_decrease: float = 0.1

func _ready() -> void:
	self.description = "Attack\nSpeed"
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var weapon: Node2D = body.current_weapon
		if weapon != null:
			if weapon.fire_rate != 0.1:
				weapon.fire_rate -= shot_wait_decrease
		self.on_item_pickup()
