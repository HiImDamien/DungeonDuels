extends Upgrade
class_name health_pickup
@export var heal_amount: int = 1

func _ready() -> void:
	self.description = "Heal"
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("player_hit"):
		# Only heal if not at max
		if body.health < body.max_health:
			body.health = mini(body.health + heal_amount, body.max_health)
			print("Player healed! Health: ", body.health)
		self.on_item_pickup()
