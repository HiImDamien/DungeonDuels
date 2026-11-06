class_name JoinScreen
extends Control
## Select screen shown after Play. Each device (the keyboard, or one controller)
## joins by pressing any button, then moves left or right to pick a side:
## left is P1 (left half of the split screen, blue), right is P2 (right, red).
## A readies up, B un-readies / steps back / leaves. Once both players are
## ready a countdown runs, and backing out cancels it.
##
## Joining is driven purely by input events, never by a list of connected
## controllers: browsers don't report a gamepad until a button on it is pressed.

const LEFT := -1
const MIDDLE := 0
const RIGHT := 1
const COUNTDOWN := 3.0
const MAX_PLAYERS := 2
const STICK_THRESHOLD := 0.5
const STICK_RESET := 0.3
const MESSAGE_TIME := 3.0

const P1_COLOR := Color(0.38, 0.57, 1.0)   # matches the HUD's P1
const P2_COLOR := Color(1.0, 0.29, 0.23)   # matches the HUD's P2
const GOLD := Color(1.0, 0.85, 0.2)
const GRAY := Color(0.7, 0.7, 0.75)

## One entry per joined device: {device: String, side: int, ready: bool}.
var tokens: Array[Dictionary] = []
## Seconds left before the match starts, or -1 while not counting down.
var countdown_left := -1.0

var _started := false
var _stick_held := {}
var _side_labels := {}
var _middle_label: Label
var _countdown_label: Label
var _message_label: Label
var _message_id := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label("CHOOSE YOUR SIDE", ControlsScreen.FONT_BOLD, 16, Color.WHITE, Vector2(0, 6), Vector2(365, 20))
	_side_labels[LEFT] = _side_box("P1 - LEFT SCREEN", P1_COLOR, 10)
	_side_labels[RIGHT] = _side_box("P2 - RIGHT SCREEN", P2_COLOR, 235)
	_middle_label = _label("", ControlsScreen.FONT, 8, Color.WHITE, Vector2(130, 60), Vector2(105, 60))
	_label("Any button: join      Left / Right: pick side", ControlsScreen.FONT, 8, GRAY, Vector2(0, 150), Vector2(365, 10))
	_label("A / Enter: ready      B / Backspace: back", ControlsScreen.FONT, 8, GRAY, Vector2(0, 162), Vector2(365, 10))
	_message_label = _label("", ControlsScreen.FONT, 8, GOLD, Vector2(0, 180), Vector2(365, 10))
	_countdown_label = _label("", ControlsScreen.FONT_BOLD, 16, GOLD, Vector2(0, 124), Vector2(365, 20))

	# Fires when the OS (or browser) starts or stops reporting a controller.
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh()

func _process(delta: float) -> void:
	if not all_ready():
		countdown_left = -1.0
		_countdown_label.text = ""
		return
	if countdown_left < 0.0:
		countdown_left = COUNTDOWN
	countdown_left -= delta
	_countdown_label.text = "STARTING IN %d" % ceili(maxf(countdown_left, 0.01))
	if countdown_left <= 0.0:
		_start_match()

## Both players are on different sides and ready.
func all_ready() -> bool:
	return tokens.size() == MAX_PLAYERS and tokens.all(func(t): return t.ready and t.side != MIDDLE)

func token_for(device: String) -> Dictionary:
	for token in tokens:
		if token.device == device:
			return token
	return {}

func device_on(side: int) -> String:
	for token in tokens:
		if token.side == side:
			return token.device
	return ""

# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if _started:
		return
	var device := PlayerDevices.device_of(event)
	if device == "":
		return
	if event is InputEventJoypadMotion:
		_handle_stick(event, device)
		return
	if not _is_press(event):
		return
	# Mark handled before acting: going back to the title changes scene.
	get_viewport().set_input_as_handled()

	var token := token_for(device)
	if token.is_empty():
		if _is_back(event):
			if tokens.is_empty():
				get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
		elif tokens.size() < MAX_PLAYERS:
			tokens.append({device = device, side = MIDDLE, ready = false})
		else:
			show_message("Two players have already joined")
	elif _is_left(event):
		move(token, LEFT)
	elif _is_right(event):
		move(token, RIGHT)
	elif _is_confirm(event):
		if token.side != MIDDLE:
			token.ready = true
	elif _is_back(event):
		back(token)
	_refresh()

## Steps a token one place left or right (left side / middle / right side).
func move(token: Dictionary, direction: int) -> void:
	if token.ready:
		return
	var target := clampi(token.side + direction, LEFT, RIGHT)
	if target != MIDDLE and device_on(target) != "" and device_on(target) != token.device:
		show_message("That side is taken")
		return
	token.side = target

## B: un-ready, else step back to the middle, else leave.
func back(token: Dictionary) -> void:
	if token.ready:
		token.ready = false
	elif token.side != MIDDLE:
		token.side = MIDDLE
	else:
		tokens.erase(token)

func _handle_stick(event: InputEventJoypadMotion, device: String) -> void:
	# Sticks never join (they drift); they only move a token that has joined.
	var token := token_for(device)
	if token.is_empty() or event.axis != JOY_AXIS_LEFT_X:
		return
	get_viewport().set_input_as_handled()
	var held: bool = _stick_held.get(device, false)
	if absf(event.axis_value) <= STICK_RESET:
		_stick_held[device] = false
	elif absf(event.axis_value) >= STICK_THRESHOLD and not held:
		_stick_held[device] = true
		move(token, RIGHT if event.axis_value > 0 else LEFT)
		_refresh()

static func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo
	return event is InputEventJoypadButton and event.pressed

static func _is_left(event: InputEvent) -> bool:
	return MenuList._button(event, JOY_BUTTON_DPAD_LEFT) or MenuList._key(event, [KEY_A, KEY_LEFT])

static func _is_right(event: InputEvent) -> bool:
	return MenuList._button(event, JOY_BUTTON_DPAD_RIGHT) or MenuList._key(event, [KEY_D, KEY_RIGHT])

static func _is_confirm(event: InputEvent) -> bool:
	return MenuList._is_confirm(event) or MenuList._button(event, JOY_BUTTON_START)

static func _is_back(event: InputEvent) -> bool:
	return MenuList._is_back(event) or MenuList._key(event, [KEY_ESCAPE])

# ── Controllers appearing / disappearing ──────────────────────────────────────

func _on_joy_connection_changed(id: int, connected: bool) -> void:
	var device := "joypad:%d" % id
	var shown := PlayerDevices.device_name(device)
	if connected:
		if token_for(device).is_empty():
			show_message("%s connected - press a button to join" % shown)
		return
	var token := token_for(device)
	if not token.is_empty():
		tokens.erase(token)
		_refresh()
	show_message("%s disconnected" % shown)

func show_message(text: String) -> void:
	_message_label.text = text
	_message_id += 1
	var id := _message_id
	await get_tree().create_timer(MESSAGE_TIME).timeout
	if id == _message_id and is_instance_valid(_message_label):
		_message_label.text = ""

# ── Starting ──────────────────────────────────────────────────────────────────

func _start_match() -> void:
	if _started:
		return
	_started = true
	PlayerDevices.assign(device_on(LEFT), device_on(RIGHT))
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

# ── Drawing ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	for side in _side_labels:
		var device := device_on(side)
		var label: Label = _side_labels[side]
		if device == "":
			label.text = "\n(empty)"
		else:
			var token := token_for(device)
			label.text = "\n%s\n\n%s" % [PlayerDevices.device_name(device),
				"READY" if token.ready else "A / Enter: ready"]
	var waiting: Array[String] = []
	for token in tokens:
		if token.side == MIDDLE:
			waiting.append("< %s >" % PlayerDevices.device_name(token.device))
	_middle_label.text = "\n".join(waiting)

func _side_box(title: String, color: Color, x: float) -> Label:
	var box := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.12)
	style.border_color = color
	style.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", style)
	box.position = Vector2(x, 32)
	box.size = Vector2(120, 88)
	add_child(box)
	_label(title, ControlsScreen.FONT_BOLD, 8, color, Vector2(0, 6), Vector2(120, 10), box)
	return _label("", ControlsScreen.FONT, 8, Color.WHITE, Vector2(0, 18), Vector2(120, 60), box)

func _label(text: String, font: Font, font_size: int, color: Color, pos: Vector2,
		size_: Vector2, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = pos
	label.size = size_
	parent.add_child(label)
	return label
