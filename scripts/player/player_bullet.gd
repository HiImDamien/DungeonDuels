extends Area2D

var speed: float        = 200
var direction: Vector2  = Vector2.RIGHT
var damage: int         = 1
var shooter             = null

# ── Bullet modifier state ─────────────────────────────────────────────────────
var bounces_left: int   = 0
var _is_tracking: bool  = false
var _is_bounce: bool    = false
var _owning_player      = null

# Tracks the previous position so the bounce raycast can shoot from
# *before* the bullet entered the wall, guaranteeing a surface hit.
var _prev_position: Vector2 = Vector2.ZERO

func apply_modes(modes: Array[String], owning_player) -> void:
	_owning_player = owning_player
	if "bounce" in modes:
		_is_bounce   = true
		bounces_left = 3
	if "big" in modes:
		scale  = Vector2(2.2, 2.2)
		damage = 2
	if "tracking" in modes:
		_is_tracking = true

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	monitoring  = true
	monitorable = true
	_prev_position = global_position

func _process(delta: float) -> void:
	_prev_position = global_position   # snapshot before moving

	if _is_tracking:
		var target = _find_nearest_enemy()
		if target != null:
			var desired = (target.global_position - global_position).normalized()
			direction = direction.lerp(desired, 6.0 * delta).normalized()

	global_position += direction * speed * delta

# ── Collision ─────────────────────────────────────────────────────────────────

func _on_kill_timer_timeout() -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, shooter)
		queue_free()
	elif GameState.phase == GameState.Phase.FINAL_BATTLE \
			and body.is_in_group("player") \
			and body.has_method("player_hit"):
		body.player_hit(shooter)
		queue_free()
	elif body.is_in_group("walls"):
		_handle_wall_hit()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield") and area.is_active:
		if area.get_parent() == shooter:
			return
		area.take_damage(damage)
		queue_free()
		return
	if area.is_in_group("walls"):
		_handle_wall_hit()

# ── Bounce ────────────────────────────────────────────────────────────────────

func _handle_wall_hit() -> void:
	if not _is_bounce or bounces_left <= 0:
		queue_free()
		return

	bounces_left -= 1

	# Raycast from the PREVIOUS frame position (guaranteed outside the wall)
	# toward the CURRENT position (inside/touching the wall).
	# This always intersects the wall surface and gives the correct normal,
	# even for diagonal travel where starting inside the wall gives no hit.
	var space  = get_world_2d().direct_space_state
	var from   = _prev_position
	var to     = global_position

	# Make sure from != to (can happen on first frame).
	if from.distance_squared_to(to) < 0.01:
		to = from + direction * 2.0

	var params = PhysicsRayQueryParameters2D.create(from, to, 2)
	params.exclude = [self]
	var result = space.intersect_ray(params)

	if result:
		direction = direction.bounce(result["normal"])
		# Place bullet at the hit point offset along the new direction
		# so it starts clearly outside the wall next frame.
		global_position = result["position"] + result["normal"] * 2.0
	else:
		# Fallback for edge cases: flip dominant axis.
		if abs(direction.x) >= abs(direction.y):
			direction.x *= -1
		else:
			direction.y *= -1
		global_position = _prev_position + direction * 2.0

	_prev_position = global_position

# ── Tracking ──────────────────────────────────────────────────────────────────

func _find_nearest_enemy() -> Node:
	var best_dist := INF
	var best_node = null

	var shooter_viewport: Viewport = null
	if is_instance_valid(_owning_player):
		shooter_viewport = _owning_player.get_viewport()

	var candidates: Array = []
	if GameState.phase == GameState.Phase.FINAL_BATTLE:
		for p in get_tree().get_nodes_in_group("player"):
			if p != _owning_player:
				candidates.append(p)
	else:
		candidates = get_tree().get_nodes_in_group("enemy")

	for target in candidates:
		if not is_instance_valid(target):
			continue
		# Ignore enemies in the other player's SubViewport.
		if shooter_viewport != null and target.get_viewport() != shooter_viewport:
			continue
		var d = global_position.distance_squared_to(target.global_position)
		if d < best_dist:
			best_dist = d
			best_node = target

	return best_node