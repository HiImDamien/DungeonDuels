extends Control

@onready var menu: MenuList = $VBoxContainer/Menu
@onready var quit_button: Button = $VBoxContainer/Menu/QuitButton

func _ready() -> void:
	# "web" is a feature tag that only browser builds have.
	show_quit(not OS.has_feature("web"))

## Quit is hidden on web: a page can't close its own tab, so quitting there
## just freezes the game on its last frame.
func show_quit(shown: bool) -> void:
	quit_button.visible = shown
	# MenuList._ready() (children are ready before parents) already highlighted
	# a button; re-select so the highlight is clamped to the visible buttons.
	menu.select(menu.selected)

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
