extends Node2D

## Maximum number of hearts a player can ever have.
const MAX_HEARTS: int = 5

## Called by the Area2D's body_entered signal (connect in the scene editor).
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.max_health >= MAX_HEARTS:
		return  # already capped; pickup stays in the world

	# Raise the ceiling by one, then fill the new slot so it arrives full.
	body.max_health += 1
	body.health = mini(body.health + 1, body.max_health)

	print("Max health increased to ", body.max_health)
	queue_free()
