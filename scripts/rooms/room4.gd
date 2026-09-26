class_name RoomDef4
extends RoomDefinition

func _init():
	add_spawns(BAT, [Vector2(40, 160), Vector2(40, 40)])
	add_spawns(SLIME, [Vector2(40, 160), Vector2(40, 105), Vector2(120, 105), Vector2(120, 160)])
	add_spawns(SLIME_HARD, [Vector2(120, 40)])
