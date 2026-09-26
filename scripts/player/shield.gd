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

@export var max_health := 10:
	set(value):
		max_health = value
		health = value

# Setting these also updates the matching timer, so upgrades apply immediately.
@export var cooldown_time := 2.2:
	set(value):
		cooldown_time = value
		if is_node_ready():
			cooldown_timer.wait_time = value
@export var recharge_interval := 0.3:
	set(value):
		recharge_interval = value
		if is_node_ready():
			recharge_timer.wait_time = value
@export var recharge_delay := 0.5:
	set(value):
		recharge_delay = value
		if is_node_ready():
			recharge_delay_timer.wait_time = value

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
	health = max_health

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
	var t := clampf(float(health) / float(max_health), 0.0, 1.0)
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

	if not is_broken and not on_cooldown and health < max_health:
		recharge_delay_timer.start()

func take_damage(amount: int = 1) -> void:
	if is_broken:
		return

	health -= amount

	if health <= 0:
		break_shield()

func break_shield() -> void:
	is_broken = true
	on_cooldown = true

	recharge_timer.stop()
	recharge_delay_timer.stop()

	deactivate()
	cooldown_timer.start()

func _on_cooldown_timer_timeout() -> void:
	health = 1
	is_broken = false
	on_cooldown = false

	if not is_active and health < max_health:
		recharge_timer.start()

func _on_recharge_delay_timer_timeout() -> void:
	if not is_active and not is_broken and not on_cooldown and health < max_health:
		recharge_timer.start()

func _on_recharge_timer_timeout() -> void:
	if is_active or is_broken or on_cooldown:
		recharge_timer.stop()
		return

	if health < max_health:
		health += 1
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
	health = max_health
