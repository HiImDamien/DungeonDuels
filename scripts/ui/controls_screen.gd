class_name ControlsScreen
extends Control
## Full-screen overlay showing the controller layout (as a diagram) and the
## keyboard keys for P1. Opened from the title screen and the pause menu.
## Emits `closed` and frees itself when the player backs out.

signal closed

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf")
const GOLD := Color(1.0, 0.85, 0.2)
const GRAY := Color(0.7, 0.7, 0.75)

## 0 = anyone can close it; 1 or 2 = only that player (used when paused).
var controlling_player: int = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_add_label("CONTROLS", FONT_BOLD, 16, Color.WHITE, 4)
	_add_label("Same layout on both controllers", FONT, 8, GRAY, 22)

	var diagram := ControllerDiagram.new()
	diagram.position = Vector2(0, 36)
	diagram.custom_minimum_size = ControllerDiagram.DESIGN_SIZE
	diagram.size = ControllerDiagram.DESIGN_SIZE
	add_child(diagram)

	_add_label("KEYBOARD (P1)", FONT_BOLD, 8, GOLD, 142)
	var parts: Array[String] = []
	for row in InputLabels.ROWS:
		parts.append("%s: %s" % [row[0], InputLabels.keyboard_label(row[1])])
	_add_label("    ".join(parts.slice(0, 3)), FONT, 8, Color.WHITE, 154)
	_add_label("    ".join(parts.slice(3)), FONT, 8, Color.WHITE, 164)

	_add_label("B / Circle  or  Esc:  Back", FONT, 8, GRAY, 186)

func _add_label(text: String, font: Font, font_size: int, color: Color, y: float) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = y
	add_child(label)
	return label

func _unhandled_input(event: InputEvent) -> void:
	if controlling_player != 0 and MenuList.player_for_event(event) != controlling_player:
		return
	var back: bool = MenuList._is_back(event) \
		or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE)
	if back:
		get_viewport().set_input_as_handled()
		closed.emit()
		queue_free()
