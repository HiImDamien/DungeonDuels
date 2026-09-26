extends Enemy
class_name BossSlime
## Two-phase boss. Phase 1 hops slowly and fires a telegraphed ring of bullets.
## Below half health it enrages: faster hops and aimed triple bursts.

const P1_SPEED: float           = 35.0
const P1_HOP_DURATION: float    = 0.5
const P1_PAUSE_DURATION: float  = 0.9
const P1_SHOOT_INTERVAL: float  = 2.2

const P2_SPEED: float           = 100.0
const P2_HOP_DURATION: float    = 0.45
const P2_PAUSE_DURATION: float  = 0.55
const P2_SHOOT_INTERVAL: float  = 1.6
const ENRAGED_TINT := Color(1.0, 0.45, 0.45)

const TELEGRAPH_TIME: float    = 0.5
const RING_BULLET_COUNT: int   = 8

const BURST_AMOUNT: int        = 3
const BURST_INTERVAL: float    = 0.15

const ANIM_IDLE  := &"new_animation"

@onready var hop_timer: Timer = $HopTimer
@onready var shoot_timer: Timer = $ShootTimer

var is_hopping: bool = false
var is_shooting: bool = false
var is_enraged: bool = false

func _ready() -> void:
	super()
	scale = Vector2(2.0, 2.0)
	animated_sprite.play(ANIM_IDLE)
	shoot_timer.wait_time = P1_SHOOT_INTERVAL
	shoot_timer.start()
	_start_pause()

func _base_tint() -> Color:
	return ENRAGED_TINT if is_enraged else Color.WHITE

func _on_damaged() -> void:
	if not is_enraged and health * 2 <= max_health:
		_enter_phase_2()

func _enter_phase_2() -> void:
	is_enraged = true
	animated_sprite.modulate = ENRAGED_TINT
	shoot_timer.wait_time = P2_SHOOT_INTERVAL
	if target.camera_2d:
		target.camera_2d.apply_noise_shake()

func _current_speed() -> float:
	return P2_SPEED if is_enraged else P1_SPEED

func _start_hop() -> void:
	is_hopping = true
	hop_timer.wait_time = P2_HOP_DURATION if is_enraged else P1_HOP_DURATION
	hop_timer.start()

func _start_pause() -> void:
	is_hopping = false
	hop_timer.wait_time = P2_PAUSE_DURATION if is_enraged else P1_PAUSE_DURATION
	hop_timer.start()

func _physics_process(delta: float) -> void:
	if GameState.is_grace:
		return

	if is_hopping and not is_shooting and not target.is_dead:
		velocity = velocity.move_toward(direction_to_player() * _current_speed(), 250 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
	move_and_slide()

func _on_hop_timer_timeout() -> void:
	if is_hopping:
		_start_pause()
	else:
		_start_hop()

func _on_shoot_timer_timeout() -> void:
	if not can_attack() or is_shooting:
		return
	if is_enraged:
		_attack_triple()
	else:
		_attack_ring()

func _attack_ring() -> void:
	is_shooting = true
	# Blink three times as a telegraph before firing.
	for i in 3:
		animated_sprite.modulate = Color(1.6, 1.6, 1.6)
		await get_tree().create_timer(TELEGRAPH_TIME / 6.0, false).timeout
		if not is_instance_valid(self):
			return
		animated_sprite.modulate = _base_tint()
		await get_tree().create_timer(TELEGRAPH_TIME / 6.0, false).timeout
		if not is_instance_valid(self):
			return

	if not GameState.is_grace:
		var angle_step: float = TAU / RING_BULLET_COUNT
		for i in range(RING_BULLET_COUNT):
			spawn_bullet(Vector2.RIGHT.rotated(i * angle_step))
	is_shooting = false

func _attack_triple() -> void:
	is_shooting = true
	var locked_direction := direction_to_player()
	for i in range(BURST_AMOUNT):
		if not can_attack():
			break
		spawn_bullet(locked_direction)
		if i < BURST_AMOUNT - 1:
			await get_tree().create_timer(BURST_INTERVAL, false).timeout
			if not is_instance_valid(self):
				return
	is_shooting = false
