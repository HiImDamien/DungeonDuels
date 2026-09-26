class_name MenuList
extends VBoxContainer
## A vertical list of Buttons navigable by controller or keyboard.
##
## Add Buttons as children and connect their `pressed` signals as usual.
##   Up/down:  D-pad, left stick, arrow keys, W/S
##   Confirm:  A / ✕, Enter, Space
##   Back:     B / ○, Backspace  → emits `cancelled`
##
## Set `controlling_player` to only accept input from one player
## (keyboard and controller 1 are P1, controller 2 is P2).

signal cancelled

const SELECTED_COLOR := Color(1, 1, 0)
const NORMAL_COLOR := Color(1, 1, 1)
const STICK_THRESHOLD := 0.5
const STICK_RESET := 0.3

## 0 = anyone; 1 or 2 = only that player's inputs count.
var controlling_player: int = 0
## Set false while another screen (e.g. Controls) is open on top of this menu.
var active: bool = true
var selected: int = 0

# Per-device flag so holding the stick moves the selection only once.
var _stick_held := {}

## Which player an input event came from, or 0 if it can't be told.
static func player_for_event(event: InputEvent) -> int:
	if event is InputEventKey:
		return 1
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return event.device + 1
	return 0

func _ready() -> void:
	for button in get_buttons():
		# Navigation is handled here; built-in focus would double-press on A/Enter.
		button.focus_mode = Control.FOCUS_NONE
	select(0)

func get_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in get_children():
		if child is Button and child.visible:
			buttons.append(child)
	return buttons

func select(index: int) -> void:
	var buttons := get_buttons()
	if buttons.is_empty():
		return
	selected = wrapi(index, 0, buttons.size())
	for i in buttons.size():
		buttons[i].add_theme_color_override("font_color", SELECTED_COLOR if i == selected else NORMAL_COLOR)

func confirm() -> void:
	var buttons := get_buttons()
	if selected < buttons.size():
		buttons[selected].pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if controlling_player != 0 and player_for_event(event) != controlling_player:
		return

	var handled := true
	if _is_up(event):
		select(selected - 1)
	elif _is_down(event):
		select(selected + 1)
	elif _is_confirm(event):
		confirm()
	elif _is_back(event):
		cancelled.emit()
	else:
		handled = _handle_stick(event)
	if handled:
		get_viewport().set_input_as_handled()

func _handle_stick(event: InputEvent) -> bool:
	if not (event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y):
		return false
	var held: bool = _stick_held.get(event.device, false)
	if abs(event.axis_value) <= STICK_RESET:
		_stick_held[event.device] = false
	elif abs(event.axis_value) >= STICK_THRESHOLD and not held:
		_stick_held[event.device] = true
		select(selected + (1 if event.axis_value > 0 else -1))
	return true

static func _is_up(event: InputEvent) -> bool:
	return _button(event, JOY_BUTTON_DPAD_UP) or _key(event, [KEY_UP, KEY_W])

static func _is_down(event: InputEvent) -> bool:
	return _button(event, JOY_BUTTON_DPAD_DOWN) or _key(event, [KEY_DOWN, KEY_S])

static func _is_confirm(event: InputEvent) -> bool:
	return _button(event, JOY_BUTTON_A) or _key(event, [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])

static func _is_back(event: InputEvent) -> bool:
	return _button(event, JOY_BUTTON_B) or _key(event, [KEY_BACKSPACE])

static func _button(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and event.button_index == button

static func _key(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in keys
