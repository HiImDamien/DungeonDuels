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

# ── Perfect block (#58) ───────────────────────────────────────────────────────
# A hit within this many units of the shield's centre line (shield-local y) is a
# perfect block: free, and the bullet goes back out along the aim. Local space
# undoes the shrink-with-health scale, so the zone is always the same fraction
# of the shield (the collider spans y ±16, so 5 is about its centre third).
const PERFECT_HALF_WIDTH := 5.0
# Shield-local x of the stripe that marks the perfect zone (the flat face is at 18).
const STRIPE_X := 16.5
const STRIPE_COLOR := Color(1.0, 0.95, 0.55, 0.9)
const FLASH_COLOR := Color(2.2, 2.2, 1.4)  # over 1.0 = brighter than the sprite
const FLASH_TIME := 0.2
const REFLECTED_BULLET := preload("res://scenes/player/player_bullet.tscn")

@onready var perfect_sound: AudioStreamPlayer = $PerfectSound
var _flash_tween: Tween

# Few, heavy points (#29): every hit visibly shrinks the shield, it can really
# break, and recharge is slow enough that Shield Regen is worth taking.
@export var max_health := 4:
	set(value):
		max_health = value
		health = value

# Setting these also updates the matching timer, so upgrades apply immediately.
@export var cooldown_time := 4.0:
	set(value):
		cooldown_time = value
		if is_node_ready():
			cooldown_timer.wait_time = value
@export var recharge_interval := 1.0:
	set(value):
		recharge_interval = value
		if is_node_ready():
			recharge_timer.wait_time = value
@export var recharge_delay := 1.0:
	set(value):
		recharge_delay = value
		if is_node_ready():
			recharge_delay_timer.wait_time = value

signal shield_changed(health: int)

var health := 4:
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
	_set_collision(true)
	visible = true
	rotation = aim_direction.angle()

func deactivate():
	if not is_active:
		return

	is_active = false
	_set_collision(false)
	visible = false

	if not is_broken and not on_cooldown and health < max_health:
		recharge_delay_timer.start()

## Deferred: deactivate() also runs inside physics callbacks (a bullet breaking
## the shield, a hit killing the player), where Godot refuses to change
## monitoring state directly. Both directions are deferred so they apply in
## order. Bullets check is_active, which still changes immediately.
func _set_collision(on: bool) -> void:
	set_deferred("monitoring", on)
	set_deferred("monitorable", on)
	collision_polygon.set_deferred("disabled", not on)

func take_damage(amount: int = 1) -> void:
	if is_broken:
		return

	health -= amount

	if health <= 0:
		break_shield()

## The one place that decides what a bullet hitting this shield does (#63).
## Bullets call it from _on_area_entered and free themselves when it returns
## true. Any future shield behavior (absorb) branches in here, never in the
## bullet scripts. Own shots pass through: the shield is a direct child of the
## player, who is the bullet's shooter.
func try_block(bullet) -> bool:
	if not is_active or bullet.shooter == get_parent():
		return false
	# A reflected bullet is always a normal block, so a rally ends after one return.
	if not bullet.reflected and is_perfect_hit(bullet.global_position):
		_perfect_block(bullet)
		return true
	take_damage(bullet.damage)
	return true

## True when a point (global coordinates) is inside the centre stripe.
## to_local() undoes position, rotation and scale, so this works at any aim
## and any shield size.
func is_perfect_hit(global_point: Vector2) -> bool:
	return absf(to_local(global_point).y) <= PERFECT_HALF_WIDTH

## Costs nothing and sends a fresh bullet back along the aim, owned by the
## blocker, with the original damage but no bullet modes (#58).
func _perfect_block(bullet) -> void:
	var blocker := get_parent()
	var shot = REFLECTED_BULLET.instantiate()
	shot.position  = bullet.position  # same parent, so local positions match
	shot.direction = aim_direction
	shot.shooter   = blocker
	shot.damage    = bullet.damage
	shot.reflected = true
	var weapon = blocker.get("current_weapon")
	if weapon != null:
		shot.modulate = weapon.bullet_color
	# Same parent as the blocked bullet, so it stays in the right world. Deferred:
	# this runs inside a physics callback, where adding a body is not allowed.
	bullet.get_parent().add_child.call_deferred(shot)
	_flash()
	perfect_sound.play()
	var index = blocker.get("player_index")
	if index != null:
		GameState.record_perfect_block(index)

func _flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate = FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, FLASH_TIME)

## Marks the perfect zone. Drawn in shield-local space, so it turns and shrinks
## with the shield. The Sprite2D has show_behind_parent on, so this is on top.
func _draw() -> void:
	draw_line(Vector2(STRIPE_X, -PERFECT_HALF_WIDTH), Vector2(STRIPE_X, PERFECT_HALF_WIDTH),
		STRIPE_COLOR, 1.0)

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
