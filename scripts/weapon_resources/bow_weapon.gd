extends Weapon

@export var bullet_scene: PackedScene
@onready var muzzle: Marker2D = $Muzzle

# ── Bullet modes (stacked) ────────────────────────────────────────────────────
# PATTERN modes:
#   "cardinal" → aim direction + 90°/180°/270° rotations of it
#   "spread"   → 3-bullet fan centred on aim direction
#   "burst"    → 3 rapid shots fired sequentially in aim direction
#   (default)  → single bullet
#
# MODIFIER modes (apply to every bullet regardless of pattern):
#   "bounce"   → reflects off walls up to 3 times
#   "big"      → larger bullet, 2 damage
#   "tracking" → homes toward nearest enemy/player
#
# Interesting combinations:
#   burst + spread   → 3 fans fired one after another
#   burst + cardinal → 4-way shot fired 3 times rapidly
#   burst + big      → 3 heavy shots in quick succession

const BURST_COUNT    := 3
const BURST_INTERVAL := 0.08   # seconds between each shot in the burst

const MAX_BULLET_MODES := 2

var bullet_modes: Array[String] = []
var _burst_firing: bool = false   # prevents overlapping bursts

func add_bullet_mode(mode: String) -> void:
	if mode in bullet_modes:
		return

	if bullet_modes.size() >= MAX_BULLET_MODES:
		bullet_modes.pop_front()  # remove oldest

	bullet_modes.append(mode)

func has_bullet_mode(mode: String) -> bool:
	return mode in bullet_modes

# ── Fire entry point ──────────────────────────────────────────────────────────

func fire(direction: Vector2) -> void:
	if bullet_scene == null or owner_player == null:
		return

	if has_bullet_mode("burst"):
		if not _burst_firing:
			_fire_burst(direction)
	else:
		_fire_volley(direction)

## Fire the current pattern once (used both directly and inside burst).
func _fire_volley(direction: Vector2) -> void:
	var has_cardinal := has_bullet_mode("cardinal")
	var has_spread   := has_bullet_mode("spread")

	if has_cardinal and has_spread:
		for i in range(4):
			_fire_spread_in_direction(direction.rotated(i * PI * 0.5))
	elif has_cardinal:
		for i in range(4):
			_spawn_bullet(direction.rotated(i * PI * 0.5))
	elif has_spread:
		_fire_spread_in_direction(direction)
	else:
		_spawn_bullet(direction)

## Fire BURST_COUNT volleys separated by BURST_INTERVAL seconds.
func _fire_burst(direction: Vector2) -> void:
	_burst_firing = true
	for i in range(BURST_COUNT):
		if not is_instance_valid(self):
			break
		_fire_volley(direction)
		if i < BURST_COUNT - 1:
			await get_tree().create_timer(BURST_INTERVAL, false).timeout
	_burst_firing = false

# ── Spawn helpers ─────────────────────────────────────────────────────────────

func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	owner_player.get_parent().add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.direction       = dir.normalized()
	bullet.shooter         = owner_player
	bullet.modulate        = bullet_color
	bullet.apply_modes(bullet_modes, owner_player)

func _fire_spread_in_direction(dir: Vector2) -> void:
	for deg in [-15.0, 0.0, 15.0]:
		_spawn_bullet(dir.rotated(deg_to_rad(deg)))