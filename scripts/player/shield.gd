class_name Shield
extends Area2D

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var recharge_timer: Timer = $RechargeTimer
@onready var recharge_delay_timer: Timer = $RechargeDelayTimer

var aim_direction := Vector2.RIGHT

# Distance from the shield's scene-origin to the collision polygon centre (x in
# shield-local space).  Used to compensate the shield's position when it scales
# so the face stays at the same distance from the player regardless of health.
const POLYGON_DISTANCE := 14.0

# Captured from the scene in _ready() so we never hardcode the offset.
var _base_position := Vector2.ZERO

@export var MAX_HEALTH := 10:
	set(value):
		MAX_HEALTH = value
		health = value
		
@export var cooldown_time := 2.2
@export var recharge_interval := 0.3
@export var recharge_delay := 0.5

signal shield_changed(health: int)

var health := 10:
	set(value):
		health = value
		shield_changed.emit(health)
		_update_size()
var is_broken := false
var on_cooldown := false
var is_active := false

func _ready():
	_base_position = position  # capture from scene; works for any player offset
	monitoring = false
	monitorable = false
	visible = false
	collision_polygon.disabled = true
	health = MAX_HEALTH

	cooldown_timer.wait_time = cooldown_time
	cooldown_timer.one_shot = true

	recharge_timer.wait_time = recharge_interval
	recharge_timer.one_shot = false

	recharge_delay_timer.wait_time = recharge_delay
	recharge_delay_timer.one_shot = true

func set_aim_direction(new_direction: Vector2) -> void:
	if new_direction.length() > 0.2:
		aim_direction = new_direction.normalized()

# Scales the shield arc (and its collider) along the aim-perpendicular axis so
# that lower health means a narrower blocking range.  Only scale.y is touched;
# scale.x is left at 1.0 so the shield stays at the same distance from the player.
func _update_size() -> void:
	var t := clampf(float(health) / float(MAX_HEALTH), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.15, 1.0, t)

func activate():
	if is_broken or on_cooldown or is_active:
		return

	recharge_timer.stop()
	recharge_delay_timer.stop()

	is_active = true
	monitoring = true
	monitorable = true
	visible = true
	collision_polygon.disabled = false
	rotation = aim_direction.angle()

func deactivate():
	if not is_active:
		return

	is_active = false
	monitoring = false
	monitorable = false
	visible = false
	collision_polygon.disabled = true

	if not is_broken and not on_cooldown and health < MAX_HEALTH:
		recharge_delay_timer.start()

func take_damage(amount: int = 1) -> void:
	if is_broken:
		return

	health -= amount
	print("Shield hit, health:", health)

	if health <= 0:
		break_shield()

func break_shield() -> void:
	is_broken = true
	on_cooldown = true

	recharge_timer.stop()
	recharge_delay_timer.stop()

	deactivate()
	print("Shield broke!")
	cooldown_timer.start()

func _on_cooldown_timer_timeout() -> void:
	health = 1
	is_broken = false
	on_cooldown = false
	print("Shield restored!")

	if not is_active and health < MAX_HEALTH:
		recharge_timer.start()

func _on_recharge_delay_timer_timeout() -> void:
	if not is_active and not is_broken and not on_cooldown and health < MAX_HEALTH:
		recharge_timer.start()

func _on_recharge_timer_timeout() -> void:
	if is_active or is_broken or on_cooldown:
		recharge_timer.stop()
		return

	if health < MAX_HEALTH:
		health += 1
		print("Shield recharged to:", health)
	else:
		recharge_timer.stop()

func _process(_delta):
	if is_active:
		rotation = aim_direction.angle()
	# Push the shield outward along the aim direction to compensate for scaling,
	# keeping the shield face at POLYGON_DISTANCE from the player at all health values.
	position = _base_position + aim_direction * POLYGON_DISTANCE * (1.0 - scale.x)

func pause_regen() -> void:
	cooldown_timer.stop()
	recharge_timer.stop()
	recharge_delay_timer.stop()

func reset() -> void:
	cooldown_timer.stop()
	recharge_timer.stop()
	recharge_delay_timer.stop()
	is_broken = false
	on_cooldown = false
	deactivate()
	health = MAX_HEALTH

## Restores all upgrade-affected stats after a scene transition.
## Must be called AFTER the shield node is in the scene tree (i.e. after _ready).
## Updates both the exported values and their corresponding Timer wait_times so
## the new values take effect immediately on the next timer cycle.
func apply_stats(
		p_max_health: int,
		p_cooldown_time: float,
		p_recharge_interval: float,
		p_recharge_delay: float
) -> void:
	MAX_HEALTH              = p_max_health          # setter also sets health = value
	cooldown_time           = p_cooldown_time
	cooldown_timer.wait_time = p_cooldown_time
	recharge_interval           = p_recharge_interval
	recharge_timer.wait_time    = p_recharge_interval
	recharge_delay              = p_recharge_delay
	recharge_delay_timer.wait_time = p_recharge_delay

func _on_area_entered(area):
	pass
