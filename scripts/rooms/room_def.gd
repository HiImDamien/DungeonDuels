class_name RoomDefinition
extends Resource
## Describes one room layout: where the player starts and which enemies spawn
## where. Subclasses fill these in from _init() using add_spawns().

const BAT = preload("res://scenes/enemy/bat.tscn")
const SLIME = preload("res://scenes/enemy/slime.tscn")
const SLIME_HARD = preload("res://scenes/enemy/slime_hard.tscn")
const BOSS_SLIME = preload("res://scenes/enemy/boss_slime.tscn")

var player_spawn: Vector2 = Vector2(80, 105)

# Each entry is [PackedScene, Array[Vector2]].
var _spawns: Array = []

func add_spawns(enemy_scene: PackedScene, positions: Array[Vector2]) -> void:
	_spawns.append([enemy_scene, positions])

func get_enemy_count() -> int:
	var count := 0
	for entry in _spawns:
		count += entry[1].size()
	return count

func spawn_enemies(room: Node, manager: Node) -> void:
	for entry in _spawns:
		for pos: Vector2 in entry[1]:
			var enemy: Node2D = entry[0].instantiate()
			enemy.global_position = pos
			room.add_child(enemy)
			enemy.tree_exited.connect(manager._on_enemy_removed)
