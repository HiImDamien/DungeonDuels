extends Area2D

var speed: float = 200
var direction: Vector2 = Vector2.RIGHT

func _process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("player_hit"):
		body.player_hit()
		queue_free()
	elif body.is_in_group("walls"):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield"):
		if area.is_active:
			area.take_damage(1)
			queue_free()
	elif area.is_in_group("walls"):
		queue_free()
