extends Enemy
## Hops toward the player and periodically fires a single aimed shot.
## Used by both slime.tscn and slime_hard.tscn (which overrides the exports).

@export var shoot_interval: float = 2.5
@export var hop_duration: float = 0.35   # seconds of active movement per hop
@export var pause_duration: float = 0.7  # seconds of rest between hops
@export var move_speed: float = 45.0

const ACCELERATION := 300.0
const SHOOT_WINDUP := 0.45  # pause after the shoot animation before firing

@onready var shoot_timer: Timer = $ShootTimer
@onready var hop_timer: Timer = $HopTimer

var is_hopping: bool = false
var is_shooting: bool = false

func _ready() -> void:
	super()
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	_start_pause()
	animated_sprite.play("idle")

func _start_hop() -> void:
	is_hopping = true
	hop_timer.wait_time = hop_duration
	hop_timer.start()

func _start_pause() -> void:
	is_hopping = false
	hop_timer.wait_time = pause_duration
	hop_timer.start()

func _physics_process(delta: float) -> void:
	if GameState.is_grace:
		return

	var target_velocity := Vector2.ZERO
	if is_hopping and not target.is_dead:
		target_velocity = direction_to_player() * move_speed
	velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)
	move_and_slide()

func _on_hop_timer_timeout() -> void:
	if is_hopping:
		_start_pause()
	else:
		_start_hop()

func _on_shoot_timer_timeout() -> void:
	if not can_attack() or is_shooting:
		return
	_shoot_with_animation()

func _shoot_with_animation() -> void:
	is_shooting = true
	animated_sprite.play("shoot")
	await animated_sprite.animation_finished
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(SHOOT_WINDUP, false).timeout
	if not is_instance_valid(self):
		return
	if not GameState.is_grace:
		spawn_bullet(direction_to_player())
	animated_sprite.play("idle")
	is_shooting = false
