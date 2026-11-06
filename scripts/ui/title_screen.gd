extends Control

@onready var menu: MenuList = $VBoxContainer/Menu

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_controls_button_pressed() -> void:
	var screen := ControlsScreen.new()
	add_child(screen)
	menu.active = false
	await screen.closed
	menu.active = true

func _on_quit_button_pressed() -> void:
	get_tree().quit()
