class_name InputLabels
## Turns the Input Map into readable labels for the Controls screen, so it
## always matches Project Settings → Input Map. Reads the bindings as saved
## (PlayerDevices.template_events), not the live per-player rebinding, so the
## labels don't change with who picked which side. Controller names show both
## layouts, e.g. "RT / R2". PlayStation face buttons are spelled out
## ("A / Cross") because the pixel font has no ✕ ○ △ □ glyphs.

## The rows on the Controls screen: [label, actions]. Multi-action rows (like
## Move) list their actions in up, left, down, right order.
const ROWS := [
	["Move",   ["move_up", "move_left", "move_down", "move_right"]],
	["Aim",    ["aim_up", "aim_left", "aim_down", "aim_right"]],
	["Shoot",  ["shoot"]],
	["Shield", ["shield_activate"]],
	["Pause",  ["pause"]],
]

## Short id of the physical controller input an action uses — "left_stick",
## "rt", "start", … — so the diagram knows where to point. "" if none.
static func controller_id(action: String) -> String:
	for event in PlayerDevices.template_events(action, false):
		if event is InputEventJoypadMotion:
			match event.axis:
				JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "left_stick"
				JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "right_stick"
				JOY_AXIS_TRIGGER_LEFT: return "lt"
				JOY_AXIS_TRIGGER_RIGHT: return "rt"
		elif event is InputEventJoypadButton:
			match event.button_index:
				JOY_BUTTON_A: return "a"
				JOY_BUTTON_B: return "b"
				JOY_BUTTON_X: return "x"
				JOY_BUTTON_Y: return "y"
				JOY_BUTTON_START: return "start"
				JOY_BUTTON_BACK: return "back"
				JOY_BUTTON_LEFT_SHOULDER: return "lb"
				JOY_BUTTON_RIGHT_SHOULDER: return "rb"
	return ""

static func controller_label(action: String) -> String:
	match controller_id(action):
		"left_stick": return "Left Stick"
		"right_stick": return "Right Stick"
		"lt": return "LT / L2"
		"rt": return "RT / R2"
		"a": return "A / Cross"
		"b": return "B / Circle"
		"x": return "X / Square"
		"y": return "Y / Triangle"
		"start": return "Start / Options"
		"back": return "View / Share"
		"lb": return "LB / L1"
		"rb": return "RB / R1"
	return "-"

## Keyboard keys for a row's actions, e.g. "W A S D", "Arrow Keys" or "Space".
## Multi-action rows (Move) use each action's first key; a single action (Shoot)
## lists all of its keys, since one action can be bound to several.
static func keyboard_label(actions: Array) -> String:
	var keys: Array[String] = []
	for action: String in actions:
		for event in PlayerDevices.template_events(action, true):
			if event is InputEventKey:
				keys.append(_key_name(event))
				if actions.size() > 1:
					break
	if keys.is_empty():
		return "-"
	var sorted := keys.duplicate()
	sorted.sort()
	if sorted == ["Down", "Left", "Right", "Up"]:
		return "Arrow Keys"
	return " ".join(keys)

static func _key_name(event: InputEventKey) -> String:
	var keycode := event.keycode
	if keycode == KEY_NONE:
		keycode = event.physical_keycode
	return OS.get_keycode_string(keycode)
