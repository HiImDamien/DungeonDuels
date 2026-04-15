extends Control

const SELECTED_COLOR := Color(1, 1, 0)   # yellow — highlighted option
const NORMAL_COLOR   := Color(1, 1, 1)   # white  — unselected option

@onready var play_btn: Button = $VBoxContainer/PlayButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

var selected: int = 0   # 0 = PLAY, 1 = QUIT
var _stick_moved := false

func _ready() -> void:
	_refresh_selection()

func _refresh_selection() -> void:
	play_btn.add_theme_color_override("font_color", SELECTED_COLOR if selected == 0 else NORMAL_COLOR)
	quit_btn.add_theme_color_override("font_color", SELECTED_COLOR if selected == 1 else NORMAL_COLOR)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:           # Xbox A / PS Cross — confirm only
				_confirm()
			JOY_BUTTON_DPAD_UP:
				selected = 0
				_refresh_selection()
			JOY_BUTTON_DPAD_DOWN:
				selected = 1
				_refresh_selection()

	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		# Debounce: only fire once per stick push, reset when stick returns to center
		if abs(event.axis_value) <= 0.3:
			_stick_moved = false
		elif not _stick_moved:
			_stick_moved = true
			selected = 0 if event.axis_value < 0 else 1
			_refresh_selection()

func _confirm() -> void:
	if selected == 0:
		_on_play_button_pressed()
	else:
		_on_quit_button_pressed()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
