extends Upgrade
class_name shield_max_increase

@export var increase_amount = 3

func _ready() -> void:
	self.description = "Max\nShield"
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var shield: Shield = body.get_node("Shield")
		if shield == null:
			print("Shield is null, why's that huh?")
		else:
			shield.MAX_HEALTH += increase_amount
			shield.health = shield.MAX_HEALTH
		self.on_item_pickup()
