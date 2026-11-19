extends Node2D

@onready var player_instance: player = $Player
@onready var room_manager: Node = $RoomManager

func _ready():
	CpuBrain.attach_if_cpu(player_instance)  # solo play: the CPU plays its own dungeon
	room_manager.start(player_instance, self)
