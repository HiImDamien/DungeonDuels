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
## In the final battle it duels the other player (#32). In the dungeon it
## fights its own enemies, dodges their bullets and collects upgrades (#33).
## Design: docs/cpu-opponent.md.

## Picked on the join screen (PlayerDevices.cpu_difficulty). Difficulty only
## changes these numbers, never the code below.
const PROFILES := {
	"easy": preload("res://resources/cpu/easy.tres"),
	"medium": preload("res://resources/cpu/medium.tres"),
	"hard": preload("res://resources/cpu/hard.tres"),
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
## Once it picks a sidestep, it keeps that direction this long (no jitter
## between two bullets).
const DODGE_COMMIT := 0.25
## A bullet upgrade always beats a stat upgrade (they're the big pickups).
const BULLET_UPGRADE_BONUS := 100.0
## Random spread added to upgrade scores, so equal weights don't always pick
## the same one.
const UPGRADE_JITTER := 0.1

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
## The upgrade it's walking to, kept until it's picked up or freed.
var _chosen_upgrade: Upgrade = null
## The enemy it's fighting; re-picked only at decisions or when it dies.
var _target_enemy: Node2D = null
## "fight", "collect" or "wait": a change starts a notice_time hesitation.
var _situation := "wait"
var _hesitate_until := -INF
var _dodge_dir := Vector2.ZERO
var _dodge_until := -INF
## Bullet instance id → {"since": first-seen time, "shield": rolled choice}.
var _seen := {}

## Makes `p` a CPU if PlayerDevices says its side is the CPU. Call it after
## the player is in the tree. Returns the brain, or null for human players.
static func attach_if_cpu(p: player) -> CpuBrain:
	if PlayerDevices.devices.get(p.player_index, "") != PlayerDevices.CPU:
		return null
	var brain := CpuBrain.new()
	brain.name = "CpuBrain"
	brain.profile = PROFILES.get(PlayerDevices.cpu_difficulty_for(p.player_index),
		PROFILES[DEFAULT_DIFFICULTY])
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
	# Grace stun: a human may shuffle about during the countdown, but the CPU
	# simply waits for "GO" so it never gets a head start.
	if _player.is_dead or _player.stunned:
		_idle()
		return

	_decision_left -= delta
	if _decision_left <= 0.0:
		_decide()
		_decision_left = profile.decision_interval

	# An opponent in our world means the final battle; otherwise the dungeon.
	var target: Node2D = _find_opponent()
	if target != null and target.is_dead:
		_idle()
		return
	if target == null:
		if not _is_alive_enemy(_target_enemy):
			_target_enemy = _nearest_enemy()
		target = _target_enemy
		if _noticing("fight" if target != null else \
				("collect" if not _offered_upgrades().is_empty() else "wait")):
			_steer_to(Vector2.ZERO, delta)
			_input.shoot = false
			_input.shield = false
			return
	if target == null:
		_collect(delta)
		return

	var to_target := target.global_position - _player.global_position
	var move := _strafe(to_target)
	var aim := _lead_aim(target).rotated(_aim_offset)

	var threat := _most_urgent_threat()
	if _clock < _dodge_until:
		move = _dodge_dir
	elif threat != null:
		if _seen[threat.get_instance_id()].shield and _shield_usable():
			_shield_dir = -threat.direction
			_shield_until = _clock + SHIELD_LINGER
		else:
			_dodge_dir = _dodge(threat)
			_dodge_until = _clock + DODGE_COMMIT
			move = _dodge_dir

	var shielding := _clock < _shield_until and _shield_usable()
	if shielding:
		aim = _shield_dir  # the shield faces the aim direction

	_steer_to(_avoid_walls(move), delta)
	_input.aim = aim
	_input.shield = shielding
	_input.shoot = not shielding

func _idle() -> void:
	_input.move = Vector2.ZERO
	_input.shoot = false
	_input.shield = false

## Room cleared: walk straight to the best offered upgrade, or wait for the
## next room. No wall sliding here: pickups sit close to the walls and the
## rooms are open, so move_and_slide is enough.
func _collect(delta: float) -> void:
	_input.shoot = false
	_input.shield = false
	if not is_instance_valid(_chosen_upgrade) or _chosen_upgrade.is_queued_for_deletion():
		_chosen_upgrade = _best_upgrade()
	if _chosen_upgrade == null:
		_steer_to(Vector2.ZERO, delta)
		return
	var to_upgrade := _chosen_upgrade.global_position - _player.global_position
	if to_upgrade.length() > 0.5:
		_steer_to(to_upgrade.normalized(), delta)
		_input.aim = to_upgrade.normalized()

## True while it's still "noticing" a new situation (a room's enemies, or
## upgrades appearing): a human needs a moment to see them and react.
func _noticing(situation: String) -> bool:
	if situation != _situation:
		_situation = situation
		if situation != "wait":
			_hesitate_until = _clock + profile.notice_time * _rng.randf_range(0.75, 1.25)
	return _clock < _hesitate_until

## Writes `desired` to the stick, turning at most profile.turn_rate rad/s from
## the current direction. Starting and stopping stay instant, like a human's.
func _steer_to(desired: Vector2, delta: float) -> void:
	var current := _input.move
	if profile.turn_rate <= 0.0 or desired == Vector2.ZERO or current == Vector2.ZERO:
		_input.move = desired
		return
	var max_turn := profile.turn_rate * delta
	var angle := clampf(current.angle_to(desired), -max_turn, max_turn)
	_input.move = current.normalized().rotated(angle) * desired.length()

func _decide() -> void:
	_target_enemy = null  # re-pick the nearest enemy (commit until then)
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

## Living enemies chasing this player. Their `target` already ties them to
## our world; the world check is a second guard.
func _my_enemies() -> Array[Node2D]:
	var mine: Array[Node2D] = []
	for e: Node2D in get_tree().get_nodes_in_group("enemy"):
		if e.get("target") == _player and _same_world(e) and not e.is_queued_for_deletion():
			mine.append(e)
	return mine

## Untyped on purpose: a freed node can't be passed as a Node2D argument.
func _is_alive_enemy(e) -> bool:
	return is_instance_valid(e) and not e.is_queued_for_deletion()

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for e in _my_enemies():
		var d := _player.global_position.distance_squared_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best

## Every bullet in our world, ours and the enemies'.
func _bullets_in_world() -> Array[Area2D]:
	var found: Array[Area2D] = []
	for b: Area2D in get_tree().get_nodes_in_group("player_bullet") \
			+ get_tree().get_nodes_in_group("enemy_bullet"):
		if _same_world(b):
			found.append(b)
	return found

## Upgrades offered in our world that we can still take.
func _offered_upgrades() -> Array[Upgrade]:
	var found: Array[Upgrade] = []
	for u: Upgrade in get_tree().get_nodes_in_group("upgrade"):
		if _same_world(u) and not u.is_queued_for_deletion() and u.is_available(_player):
			found.append(u)
	return found

## Score = profile.upgrade_weights[pick_id] (default 1) plus a little jitter;
## a bullet upgrade always wins.
func _best_upgrade() -> Upgrade:
	var best: Upgrade = null
	var best_score := -INF
	for u in _offered_upgrades():
		var score: float = profile.upgrade_weights.get(u.pick_id(), 1.0)
		score += _rng.randf() * UPGRADE_JITTER
		if u is BulletUpgrade:
			score += BULLET_UPGRADE_BONUS
		if score > best_score:
			best_score = score
			best = u
	return best

## The incoming bullet that will reach us soonest, counting only bullets seen
## for at least reaction_time. Each bullet gets one roll for whether it
## reacts at all (dodge_skill) and one for shield-or-dodge (shield_skill).
func _most_urgent_threat() -> Area2D:
	var alive := {}
	var best: Area2D = null
	var best_time := INF
	for b in _bullets_in_world():
		if b.get("shooter") == _player:
			continue
		var id := b.get_instance_id()
		alive[id] = true
		if not _seen.has(id):
			_seen[id] = {"since": _clock, "react": _rng.randf() < profile.dodge_skill,
				"shield": _rng.randf() < profile.shield_skill}
		if not _seen[id].react or _clock - _seen[id].since < profile.reaction_time:
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

## Circle the target (opponent or enemy) while pulling toward preferred_range.
func _strafe(to_target: Vector2) -> Vector2:
	var distance := to_target.length()
	if distance < 0.01:
		return Vector2.RIGHT * _strafe_sign
	var radial := to_target / distance
	var push := clampf((distance - profile.preferred_range) / RANGE_SOFTNESS, -1.0, 1.0)
	return (radial.orthogonal() * _strafe_sign + radial * push * 1.5).normalized()

## Aim where the target will be when the bullet arrives, scaled by skill.
## Players and enemies are both CharacterBody2D, so both have a velocity.
func _lead_aim(target: Node2D) -> Vector2:
	var to_target := target.global_position - _player.global_position
	var flight_time := to_target.length() / BULLET_SPEED
	var velocity: Vector2 = target.get("velocity") if "velocity" in target else Vector2.ZERO
	var predicted := target.global_position + velocity * flight_time * profile.lead_accuracy
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
