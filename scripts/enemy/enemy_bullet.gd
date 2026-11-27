extends Area2D

var speed: float = 200
var direction: Vector2 = Vector2.RIGHT
# Same fields as player_bullet so Shield.try_block() treats both alike (#63).
var damage: int = 1
var shooter = null
# Always false here (only player_bullets get reflected); kept so both bullets look alike to Shield.try_block() (#58).
var reflected: bool = false

func _ready() -> void:
	add_to_group("enemy_bullet")  # CpuBrain looks for incoming shots

func _process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("player_hit"):
		body.player_hit()
		queue_free()
	elif body.is_in_group("walls"):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is Shield and area.try_block(self):
		queue_free()
		return
	if area.is_in_group("walls"):
		queue_free()
