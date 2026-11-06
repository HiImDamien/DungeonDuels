extends Node
## Drives one player's dungeon run: loads rooms, tracks the enemies left in the
## current room, and offers upgrades once it's cleared.
##
## Room sequence repeats every ROOMS_PER_CYCLE rooms, with the last one a boss:
## normal, normal, boss, normal, normal, boss, …
##
## Room layouts live in scenes/rooms/layouts/. To add one, make a new scene
## inheriting room_base.tscn and drag it into Normal Rooms or Boss Rooms on
## the RoomManager (scenes/rooms/room_manager.tscn) in the Inspector.

const ROOMS_PER_CYCLE := 3

@export var normal_rooms: Array[PackedScene] = []
@export var boss_rooms: Array[PackedScene] = []

# ── Stat upgrade pool (two are offered after every room) ─────────────────────
const UPGRADE_SCENES = [
	preload("res://scenes/upgrades/attack_rate.tscn"),
	preload("res://scenes/upgrades/speed_boost.tscn"),
	preload("res://scenes/upgrades/health_max.tscn"),
	preload("res://scenes/upgrades/shield_regen.tscn"),
	preload("res://scenes/upgrades/shield_max.tscn"),
]
const STAT_UPGRADE_POSITIONS: Array[Vector2] = [Vector2(50, 50), Vector2(110, 50)]
const BULLET_UPGRADE_POSITION := Vector2(80, 155)

var player_instance: player = null
var world: Node = null
var current_room_node: Node = null
var enemies_remaining: int = 0
var rooms_completed: int = 0
var loading: bool = false

var _last_normal_room: PackedScene = null
var _offered_upgrades: Array[Upgrade] = []

# ── Public API ────────────────────────────────────────────────────────────────

func start(player_node: CharacterBody2D, world_node: Node) -> void:
	player_instance = player_node
	world = world_node
	_load_next_room()

## Called by room.gd once the room is instanced, before enemies spawn.
func register_room(room: Node, spawn_pos: Vector2, enemy_count: int) -> void:
	enemies_remaining = enemy_count
	loading = false
	if player_instance.get_parent():
		player_instance.get_parent().remove_child(player_instance)
	player_instance.global_position = spawn_pos
	room.add_child(player_instance)

func on_upgrade_pickup(picked_upgrade: Upgrade) -> void:
	# Bullet upgrades are the high-impact pickups — let the other side know
	if picked_upgrade is BulletUpgrade:
		GameState.notify_opponent(player_instance.player_index, "Opponent Got " + picked_upgrade.description)

	for u in _offered_upgrades:
		if u != picked_upgrade and is_instance_valid(u):
			u.queue_free()
	_offered_upgrades.clear()
	_load_next_room.call_deferred()

# ── Room clearing ─────────────────────────────────────────────────────────────

func _on_enemy_removed() -> void:
	if enemies_remaining <= 0:
		return
	enemies_remaining -= 1
	if enemies_remaining == 0 and not loading:
		_on_room_cleared()

func _on_room_cleared() -> void:
	# Enemies also leave the tree when the whole game scene is torn down.
	if not is_inside_tree():
		return
	loading = true
	await get_tree().create_timer(1.0, false).timeout

	var was_boss := _is_boss_room(rooms_completed)
	rooms_completed += 1

	if was_boss:
		GameState.notify_opponent(player_instance.player_index, "Opponent Cleared Boss")

	# Move the player to the centre before upgrades appear so they can't
	# accidentally walk into a pickup that spawns on top of them. Wait two
	# physics frames so the new position registers before pickups go live.
	player_instance.global_position = current_room_node.player_spawn.global_position
	player_instance.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame

	_spawn_stat_upgrades()
	if was_boss:
		_spawn_bullet_upgrade()

	loading = false

# ── Room loading ──────────────────────────────────────────────────────────────

func _is_boss_room(room_index: int) -> bool:
	return room_index % ROOMS_PER_CYCLE == ROOMS_PER_CYCLE - 1

func _load_next_room() -> void:
	var scene: PackedScene
	if _is_boss_room(rooms_completed):
		scene = boss_rooms.pick_random()
	else:
		# Never repeat the same normal room twice in a row (if there's a choice).
		var choices := normal_rooms.filter(func(r) -> bool: return r != _last_normal_room)
		if choices.is_empty():
			choices = normal_rooms
		scene = choices.pick_random()
		_last_normal_room = scene

	var room: Node = scene.instantiate()
	world.add_child(room)
	if current_room_node:
		current_room_node.queue_free()
	current_room_node = room
	room.setup(self)

# ── Upgrades ──────────────────────────────────────────────────────────────────

func _spawn_stat_upgrades() -> void:
	var pool: Array[Upgrade] = []
	for scene: PackedScene in UPGRADE_SCENES:
		var candidate := scene.instantiate() as Upgrade
		if candidate.is_available(player_instance):
			pool.append(candidate)
		else:
			candidate.free()
	pool.shuffle()

	var labels := [
		current_room_node.get_node("CanvasLayer/Upgrade1_label"),
		current_room_node.get_node("CanvasLayer/Upgrade2_label"),
	]
	for i in pool.size():
		if i >= STAT_UPGRADE_POSITIONS.size():
			pool[i].free()
			continue
		_offer_upgrade(pool[i], STAT_UPGRADE_POSITIONS[i], labels[i])

func _spawn_bullet_upgrade() -> void:
	var modes := BulletUpgrade.modes_available_for(player_instance)
	if modes.is_empty():
		return
	var label: Label = current_room_node.get_node("CanvasLayer/Upgrade3_label")
	_offer_upgrade(BulletUpgrade.create(modes.pick_random()), BULLET_UPGRADE_POSITION, label)

func _offer_upgrade(upgrade: Upgrade, pos: Vector2, label: Label) -> void:
	upgrade.position = pos
	upgrade.room_manager = self
	current_room_node.add_child(upgrade)
	label.text = upgrade.description
	_offered_upgrades.append(upgrade)
