@tool
class_name EnemySpawn
extends Marker2D
## Spawn point for one enemy. Add these under a room's EnemySpawns node and
## pick which enemy scene appears here in the Inspector.

@export var enemy_scene: PackedScene:
	set(value):
		enemy_scene = value
		update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	if enemy_scene == null:
		return ["Choose an Enemy Scene in the Inspector, or nothing spawns here."]
	return []
