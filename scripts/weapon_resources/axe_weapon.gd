extends Weapon

@onready var hitbox: Area2D = $Hitbox

var swinging := false
var already_hit := []

var base_rotation := 0.0
var swing_amount := deg_to_rad(120) # arc size

func _ready() -> void:
	super ()
	hitbox.monitoring = false

	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func fire(_direction: Vector2) -> void:
	if swinging:
		return

	start_swing()

func start_swing() -> void:
	swinging = true
	hitbox.monitoring = true

	base_rotation = rotation

	var tween = create_tween()

	tween.tween_property(self , "rotation", base_rotation + deg_to_rad(120), 0.12)

	await get_tree().create_timer(0.2).timeout
	_finish_swing()

func _finish_swing() -> void:
	rotation = base_rotation
	hitbox.monitoring = false
	swinging = false
	already_hit.clear()

func _on_hitbox_body_entered(body: Node) -> void:
	if body in already_hit:
		return

	already_hit.append(body)

	if body.is_in_group("enemy"):
		body.take_damage(2, owner_player)
