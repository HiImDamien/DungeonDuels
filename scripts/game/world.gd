extends Node2D

@onready var player_instance: player = $Player
@onready var room_manager: Node = $RoomManager

func _ready():
	room_manager.start(player_instance, self)
