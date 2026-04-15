extends CharacterBody2D
class_name player
enum State {ALIVE, DEAD}

const BULLET = preload("res://scenes/player/player_bullet.tscn")
const SHIELD = preload("res://scenes/player/shield.tscn")

# Set to "p2_" for the second player so it reads p2_move_left, p2_shoot, etc.
@export var action_prefix: String = ""

var last_aim = Vector2.RIGHT
const SPEED = 75.0
const INVINCIBLE_TIME = 3
const STARTING_MAX_HEALTH = 3
var max_health: int = STARTING_MAX_HEALTH:
	set(value):
		max_health = value
		stats_changed.emit(health, max_health, kills)

var state: State = State.ALIVE

var is_dead: bool:
	get: return state == State.DEAD

signal stats_changed(health: int, max_health: int, kills: int)
# Emitted instead of starting the respawn timer when a player loses their
# last heart during the final battle.  final_battle.gd listens to this.
signal eliminated

var health: int = STARTING_MAX_HEALTH:
	set(value):
		health = value
		stats_changed.emit(health, max_health, kills)
var kills: int = 0:
	set(value):
		kills = value
		stats_changed.emit(health, max_health, kills)
var invincible: bool = false:
	set = _set_invincible

var current_weapon: Node2D = null
var weapon_ready: bool = false

# True during the opening grace period; blocks shooting and shield use.
var stunned: bool = true

@onready var aim_pivot: Node2D = $AimPivot
@onready var weapon_holder: Node2D = $AimPivot/WeaponHolder
@onready var camera_2d: Camera2D = get_node_or_null("../Camera2D")
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var respawn_timer: Timer = $RespawnTimer
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield: Area2D = $Shield

func _set_invincible(value: bool) -> void:
	if value:
		$InvincibilityTimer.start(INVINCIBLE_TIME)
	invincible = value

func _ready() -> void:
	health = max_health
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	safe_margin = 0.08
	equip_weapon(preload("res://scenes/weapons/bow_weapon.tscn"))
	# Lift the stun when the grace period ends. ONE_SHOT so it auto-disconnects;
	# fresh instances in the final battle will reconnect on their own _ready().
	GameState.grace_ended.connect(func(): stunned = false, CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
	if is_dead:
		return

	var aim = Input.get_vector(action_prefix + "aim_left", action_prefix + "aim_right", action_prefix + "aim_up", action_prefix + "aim_down")
	if aim.length() > 0.2:
		last_aim = aim.normalized()

	aim_pivot.rotation = last_aim.angle()
	shield.set_aim_direction(last_aim)

	var shield_pressed = Input.is_action_pressed(action_prefix + "shield_activate")

	# Shield is always available (even during grace stun).
	if shield_pressed and not shield.is_broken and not shield.on_cooldown:
		shield.activate()
	else:
		shield.deactivate()

	# Shooting is locked during the grace period only.
	if not stunned:
		if Input.is_action_pressed(action_prefix + "shoot") and not shield_pressed:
			if current_weapon:
				current_weapon.try_fire(last_aim)

func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var direction = Input.get_vector(action_prefix + "move_left", action_prefix + "move_right", action_prefix + "move_up", action_prefix + "move_down")
	var facing = Input.get_axis(action_prefix + "move_left", action_prefix + "move_right")
	var animation_state = 0
	if direction != Vector2.ZERO:
		animation_state = 1
		direction = direction.normalized()
		animated_sprite.flip_h = facing < 0
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO

	if not invincible:
		animated_sprite.play("Running" if animation_state == 1 else "idle")

	move_and_slide()

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("enemy") and collider is CharacterBody2D:
			collider.velocity += velocity * 0.6

func equip_weapon(weapon_scene: PackedScene) -> void:
	weapon_ready = false

	if current_weapon:
		current_weapon.queue_free()
		current_weapon = null

	current_weapon = weapon_scene.instantiate()
	weapon_holder.add_child(current_weapon)
	current_weapon.owner_player = self

	await current_weapon.ready

	weapon_ready = true

func player_hit(attacker = null) -> void:
	if invincible or is_dead:
		return

	if camera_2d:
		camera_2d.apply_noise_shake()
	health -= 1

	if health <= 0:
		if attacker != null and "kills" in attacker:
			attacker.kills += 1
		die()
	else:
		print("Knight got hit, remaining health is ", health)
		animated_sprite.play("Hit")
		invincible = true

func die() -> void:
	# In the final battle, any death is permanent elimination.
	# In the dungeon, players simply respawn at their full max_health.
	var is_final_death := (GameState.phase == GameState.Phase.FINAL_BATTLE)

	state = State.DEAD
	velocity = Vector2.ZERO
	invincibility_timer.stop()
	invincible = false
	shield.deactivate()
	shield.pause_regen()
	aim_pivot.visible = false
	print("Knight Died!")
	animated_sprite.play("Death")

	if is_final_death:
		eliminated.emit()
	else:
		respawn_timer.start()

func _play_getup_animation() -> void:
	var frames = animated_sprite.sprite_frames
	var fps = frames.get_animation_speed("Death")
	var frame_duration = 1.0 / fps
	var frame_count = frames.get_frame_count("Death")

	var tween = create_tween()
	# Step backwards through death frames (last frame already showing, start from second-to-last)
	for i in range(frame_count - 2, -1, -1):
		tween.tween_interval(frame_duration)
		tween.tween_callback(animated_sprite.set_frame.bind(i))
	tween.tween_interval(frame_duration)
	tween.tween_callback(_finish_respawn)

func _finish_respawn() -> void:
	state = State.ALIVE
	health = max_health
	kills = kills # re-emit signal to refresh HUD without resetting kills
	shield.reset()
	aim_pivot.visible = true
	animated_sprite.play("idle")
	print("Knight respawned!")

func _on_invincibility_timer_timeout() -> void:
	invincible = false

func _on_respawn_timer_timeout() -> void:
	_play_getup_animation()
