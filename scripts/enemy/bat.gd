extends Enemy
## Drifts slowly toward the player and fires one of several bullet patterns.
## Only "triple" is in rotation right now; the others are ready for variants
## (add them to `patterns` and call change_pattern() to cycle).

@export var shoot_interval: float = 1.0
@export var move_speed: float = 5.0

const ACCELERATION := 200.0
const BURST_AMOUNT := 3
const BURST_INTERVAL := 0.15

@onready var shoot_timer: Timer = $ShootTimer
@onready var burst_timer: Timer = $BurstTimer

var burst_count := 0
var last_direction := Vector2.RIGHT
var spiral_angle := 0.0
var patterns: Array[String] = ["triple"]
var current_pattern_index := 0

func _ready() -> void:
	super()
	shoot_timer.wait_time = shoot_interval
	shoot_timer.start()
	burst_timer.wait_time = BURST_INTERVAL
	burst_timer.one_shot = false
	burst_timer.timeout.connect(_on_burst_timer_timeout)

func change_pattern() -> void:
	current_pattern_index = (current_pattern_index + 1) % patterns.size()

func _physics_process(delta: float) -> void:
	if GameState.is_grace:
		return

	var target_velocity := Vector2.ZERO
	if not target.is_dead:
		target_velocity = direction_to_player() * move_speed
	velocity = velocity.move_toward(target_velocity, ACCELERATION * delta)

	# Don't shove the player vertically when pressed up against them.
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null and collider.is_in_group("player"):
			if abs(collision.get_normal().y) > 0.7:
				velocity.y = 0
	move_and_slide()

func _on_shoot_timer_timeout() -> void:
	if can_attack():
		shoot_pattern()

func shoot_pattern() -> void:
	match patterns[current_pattern_index]:
		"circle":
			_shoot_circle()
		"fan":
			_shoot_fan()
		"spiral":
			_shoot_spiral()
		"line":
			_shoot_line()
		"triple":
			_shoot_triple()

func _shoot_circle() -> void:
	var count := 8
	var angle_step := TAU / count
	for i in range(count):
		spawn_bullet(Vector2.RIGHT.rotated(i * angle_step))

func _shoot_fan() -> void:
	var count := 5
	var spread := deg_to_rad(90)
	var step := spread / (count - 1)
	var start_angle := -spread / 2
	for i in range(count):
		spawn_bullet(Vector2.RIGHT.rotated(start_angle + i * step))

func _shoot_spiral() -> void:
	var count := 6
	var angle_step := TAU / count
	for i in range(count):
		spawn_bullet(Vector2.RIGHT.rotated(spiral_angle + i * angle_step))
	spiral_angle += deg_to_rad(15)

func _shoot_line() -> void:
	spawn_bullet(Vector2.RIGHT)

func _shoot_triple() -> void:
	burst_count = 0
	burst_timer.start()

func _on_burst_timer_timeout() -> void:
	if burst_count == 0:
		last_direction = direction_to_player()
	spawn_bullet(last_direction)
	burst_count += 1
	if burst_count >= BURST_AMOUNT:
		burst_timer.stop()
