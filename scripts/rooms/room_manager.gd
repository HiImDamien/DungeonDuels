extends Node

var player_instance: player = null
var world: Node = null
var current_room_node: Node = null
var current_def_index: int = -1
var enemies_remaining: int = 0
var completed_rooms: int = 0
var upgrade_1: Upgrade = null
var upgrade_2: Upgrade = null
var loading: bool = false

const ROOM_SCENE = preload("res://scenes/rooms/room.tscn")
#const UPGRADE_SCENES = [preload("res://scenes/upgrades/shield_regen.tscn"), preload("res://scenes/upgrades/shield_max_increase.tscn")]
const UPGRADE_SCENES = [preload("res://scenes/upgrades/attack_rate.tscn"), preload("res://scenes/upgrades/health_pickup.tscn"),
preload("res://scenes/upgrades/shield_regen.tscn"), preload("res://scenes/upgrades/shield_max_increase.tscn")]
const NORMAL_ROOM_TYPES = [preload("res://scripts/rooms/room1.gd"), preload("res://scripts/rooms/room2.gd"), preload("res://scripts/rooms/room3.gd")]
const BOSS_ROOM_TYPE = preload("res://scripts/rooms/room_boss.gd")
const BOSS_ROOM_INTERVAL: int = 3

func start(player_node: CharacterBody2D, world_node: Node):
	player_instance = player_node
	world = world_node
	load_random_room()

func load_random_room():
	var definition
	if (completed_rooms + 1) % BOSS_ROOM_INTERVAL == 0:
		current_def_index = -1
		definition = BOSS_ROOM_TYPE.new()
	else:
		var available = range(NORMAL_ROOM_TYPES.size()).filter(func(i): return i != current_def_index)
		current_def_index = available[randi() % available.size()]
		definition = NORMAL_ROOM_TYPES[current_def_index].new()

	var room = ROOM_SCENE.instantiate()
	world.add_child(room)

	if current_room_node:
		current_room_node.queue_free()
	current_room_node = room

	room.setup(definition, self )
func load_upgrades():
	var label_1: Label = current_room_node.get_node("CanvasLayer/Upgrade1_label")
	var label_2: Label = current_room_node.get_node("CanvasLayer/Upgrade2_label")
	
	var upgrade_1_avail = range(UPGRADE_SCENES.size())
	var upgrade_1_index = upgrade_1_avail[randi() % upgrade_1_avail.size()]
	
	var upgrade_2_avail = range(UPGRADE_SCENES.size()).filter(func(i): return i != upgrade_1_index)
	var upgrade_2_index = upgrade_2_avail[randi() % upgrade_2_avail.size()]
	
	self.upgrade_1 = UPGRADE_SCENES[upgrade_1_index].instantiate()
	upgrade_1.position = Vector2(50, 50)
	upgrade_1.room_manager = self
	
	
	self.upgrade_2 = UPGRADE_SCENES[upgrade_2_index].instantiate()
	upgrade_2.position = Vector2(110, 50)
	upgrade_2.room_manager = self
	
	current_room_node.add_child(upgrade_1)
	current_room_node.add_child(upgrade_2)
	label_1.text = upgrade_1.description
	label_2.text = upgrade_2.description

func register_room(room: Node, spawn_pos: Vector2, enemy_count: int):
	enemies_remaining = enemy_count
	if player_instance.get_parent():
		player_instance.get_parent().remove_child(player_instance)
	player_instance.global_position = spawn_pos
	room.add_child(player_instance)

func on_upgrade_pickup(picked_upgrade: Upgrade):
	print("Item picked up")
	if upgrade_1 == picked_upgrade:
		if is_instance_valid(upgrade_2):
			upgrade_2.queue_free()
		upgrade_2 = null
	else:
		if is_instance_valid(upgrade_1):
			upgrade_1.queue_free()
		upgrade_1 = null
	upgrade_1 = null
	upgrade_2 = null
	load_random_room.call_deferred()
	
func on_enemy_died():
	print("Enemy Died! There are ${enemies_remaining} left")
	enemies_remaining -= 1
	if enemies_remaining <= 0:
		if loading == false:
			loading = true
			await get_tree().create_timer(1).timeout
			print("Load the upgrades!")
			completed_rooms += 1
		call_deferred("load_upgrades")
		loading = false
