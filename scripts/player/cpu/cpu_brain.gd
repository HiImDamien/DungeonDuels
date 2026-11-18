extends Node
class_name CpuBrain
## Plays a player for the computer. It never touches Input or the InputMap: it
## writes a CpuInput, and player.gd reads that exactly like a human's controls,
## so grace stun and the shield rules apply to the CPU too.
##
## As a child of the player it pauses with the tree and is freed with the
## player. It re-decides (strafe direction, aim error) every
## profile.decision_interval seconds and steers every frame toward the last
## decision, which keeps it cheap on web and gives it human-like hesitation.
##
## Today it only fights the final battle (#32). The dungeon is #33.
## Design: docs/cpu-opponent.md.

const PROFILES := {
	"medium": preload("res://resources/cpu/medium.tres"),
}
const DEFAULT_DIFFICULTY := "medium"

## Matches player_bullet.gd's speed; used to lead shots.
const BULLET_SPEED := 200.0
## How far ahead (seconds) a bullet's path is checked for a near miss.
const THREAT_LOOKAHEAD := 0.6
## Keep the shield up this long after the last threat, so it doesn't flicker.
const SHIELD_LINGER := 0.2
## How far ahead (px) to look for a wall in the direction it's moving.
const WALL_PROBE := 18.0
## How sharply it closes or opens distance when off preferred_range (px).
const RANGE_SOFTNESS := 30.0
## Chance per decision to switch strafe direction.
const STRAFE_FLIP_CHANCE := 0.15
## After bouncing off a wall, don't flip again for this long (no jitter).
const WALL_FLIP_COOLDOWN := 0.5

@export var profile: CpuProfile
## 0 = random each match. Anything else makes its choices repeatable (the
## smoke test sets one). Setting it reseeds immediately.
@export var rng_seed: int = 0:
	set(value):
		rng_seed = value
		if value != 0:
			_rng.seed = value

var _player: player
var _input: CpuInput
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _decision_left := 0.0
var _strafe_sign := 1.0
var _aim_offset := 0.0
var _shield_until := -1.0
var _shield_dir := Vector2.RIGHT
var _wall_flip_at := -INF
## Bullet instance id → {"since": first-seen time, "shield": rolled choice}.
var _seen := {}

## Makes `p` a CPU if PlayerDevices says its side is the CPU. Call it after
## the player is in the tree. Returns the brain, or null for human players.
static func attach_if_cpu(p: player) -> CpuBrain:
	if PlayerDevices.devices.get(p.player_index, "") != PlayerDevices.CPU:
		return null
	var brain := CpuBrain.new()
	brain.name = "CpuBrain"
	brain.profile = PROFILES.get(PlayerDevices.cpu_difficulty, PROFILES[DEFAULT_DIFFICULTY])
	p.input = CpuInput.new()
	p.add_child(brain)
	return brain

func _ready() -> void:
	_player = get_parent()
	_input = _player.input as CpuInput
	if _input == null:
		_input = CpuInput.new()
		_player.input = _input
	if profile == null:
		profile = PROFILES[DEFAULT_DIFFICULTY]
	if rng_seed == 0:
		_rng.randomize()

func _physics_process(delta: float) -> void:
	_clock += delta
	var opponent := _find_opponent()
	# Grace stun: a human may shuffle about during the countdown, but the CPU
	# simply waits for "GO" so it never gets a head start.
	if _player.is_dead or _player.stunned or opponent == null or opponent.is_dead:
		_idle()
		return

	_decision_left -= delta
	if _decision_left <= 0.0:
		_decide()
		_decision_left = profile.decision_interval

	var to_opponent := opponent.global_position - _player.global_position
	var move := _strafe(to_opponent)
	var aim := _lead_aim(opponent).rotated(_aim_offset)

	var threat := _most_urgent_threat()
	if threat != null:
		if _seen[threat.get_instance_id()].shield and _shield_usable():
			_shield_dir = -threat.direction
			_shield_until = _clock + SHIELD_LINGER
		else:
			move = _dodge(threat)

	var shielding := _clock < _shield_until and _shield_usable()
	if shielding:
		aim = _shield_dir  # the shield faces the aim direction

	_input.move = _avoid_walls(move)
	_input.aim = aim
	_input.shield = shielding
	_input.shoot = not shielding

func _idle() -> void:
	_input.move = Vector2.ZERO
	_input.shoot = false
	_input.shield = false

func _decide() -> void:
	_aim_offset = deg_to_rad(_rng.randf_range(-profile.aim_error_deg, profile.aim_error_deg))
	if _rng.randf() < STRAFE_FLIP_CHANCE:
		_strafe_sign = -_strafe_sign

# ── Perception (only this player's world: split screen shares one tree) ──────

func _same_world(node: Node2D) -> bool:
	return node.get_world_2d() == _player.get_world_2d()

func _find_opponent() -> player:
	for p: player in get_tree().get_nodes_in_group("player"):
		if p != _player and _same_world(p):
			return p
	return null

## The incoming bullet that will reach us soonest, counting only bullets seen
## for at least reaction_time. Each bullet gets one shield-or-dodge roll.
func _most_urgent_threat() -> Area2D:
	var bullets := get_tree().get_nodes_in_group("player_bullet") \
		+ get_tree().get_nodes_in_group("enemy_bullet")
	var alive := {}
	var best: Area2D = null
	var best_time := INF
	for b: Area2D in bullets:
		if not _same_world(b) or b.get("shooter") == _player:
			continue
		var id := b.get_instance_id()
		alive[id] = true
		if not _seen.has(id):
			_seen[id] = {"since": _clock, "shield": _rng.randf() < profile.shield_skill}
		if _clock - _seen[id].since < profile.reaction_time:
			continue
		var velocity: Vector2 = b.direction * b.speed
		var rel := _player.global_position - b.global_position
		var t := rel.dot(velocity) / velocity.length_squared()
		if t < 0.0 or t > THREAT_LOOKAHEAD:
			continue
		if (rel - velocity * t).length() > profile.dodge_radius:
			continue
		if t < best_time:
			best_time = t
			best = b
	for id in _seen.keys():
		if not alive.has(id):
			_seen.erase(id)
	return best

func _shield_usable() -> bool:
	return not _player.shield.is_broken and not _player.shield.on_cooldown

# ── Steering ──────────────────────────────────────────────────────────────────

## Circle the opponent while pulling toward preferred_range.
func _strafe(to_opponent: Vector2) -> Vector2:
	var distance := to_opponent.length()
	if distance < 0.01:
		return Vector2.RIGHT * _strafe_sign
	var radial := to_opponent / distance
	var push := clampf((distance - profile.preferred_range) / RANGE_SOFTNESS, -1.0, 1.0)
	return (radial.orthogonal() * _strafe_sign + radial * push * 1.5).normalized()

## Aim where the opponent will be when the bullet arrives, scaled by skill.
func _lead_aim(opponent: player) -> Vector2:
	var to_target := opponent.global_position - _player.global_position
	var flight_time := to_target.length() / BULLET_SPEED
	var predicted := opponent.global_position + opponent.velocity * flight_time * profile.lead_accuracy
	return (predicted - _player.global_position).normalized()

## Step sideways off the bullet's line, toward whichever side we're already on.
func _dodge(bullet: Area2D) -> Vector2:
	var side: Vector2 = bullet.direction.orthogonal()
	var offset := (_player.global_position - bullet.global_position).dot(side)
	var side_sign := signf(offset) if absf(offset) > 1.0 else _strafe_sign
	var move := side * side_sign
	if _wall_ahead(move) != Vector2.ZERO:
		move = -move
	return move

## The wall normal if a wall is within WALL_PROBE in `direction`, else ZERO.
## Physics queries are per World2D, so this only sees our own arena.
func _wall_ahead(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO
	var from := _player.global_position
	var query := PhysicsRayQueryParameters2D.create(
		from, from + direction.normalized() * WALL_PROBE, PhysicsLayers.WALLS)
	var hit := _player.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.normal if hit else Vector2.ZERO

## Slide along a wall instead of pushing into it, and strafe the other way
## next time so it doesn't keep hugging the same wall.
func _avoid_walls(move: Vector2) -> Vector2:
	var normal := _wall_ahead(move)
	if normal == Vector2.ZERO:
		return move
	if _clock - _wall_flip_at > WALL_FLIP_COOLDOWN:
		_wall_flip_at = _clock
		_strafe_sign = -_strafe_sign
	var slid := move.slide(normal)
	if slid.length() < 0.2:
		slid = normal.orthogonal() * _strafe_sign
	return (slid + normal * 0.5).normalized()
