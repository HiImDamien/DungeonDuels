extends Node2D
## A dungeon room. Each layout is a scene that inherits room_base.tscn:
## paint the tilemap, move PlayerSpawn, and add EnemySpawn markers under
## EnemySpawns. Then add the scene to a list on the RoomManager.

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemy_spawns: Node2D = $EnemySpawns

func get_spawn_points() -> Array[EnemySpawn]:
	var points: Array[EnemySpawn] = []
	for child in enemy_spawns.get_children():
		if child is EnemySpawn and child.enemy_scene != null:
			points.append(child)
	return points

## Hands the player to the room manager, then spawns this room's enemies.
func setup(manager: Node) -> void:
	var points := get_spawn_points()
	manager.register_room(self, player_spawn.global_position, points.size())
	for point in points:
		var enemy: Enemy = point.enemy_scene.instantiate()
		enemy.target = manager.player_instance
		enemy.global_position = point.global_position
		add_child(enemy)
		enemy.tree_exited.connect(manager._on_enemy_removed)
