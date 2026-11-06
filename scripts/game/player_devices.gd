extends Node
## Autoload: which input device each player uses, chosen on the join screen.
##
## A device is a String: "keyboard" or "joypad:<id>". It's built from the event's
## class AND its device id, because ids alone are ambiguous (joypad ids start at
## 0, and keyboard ids have changed between Godot versions).
##
## assign() rewrites each player's actions in the InputMap ("" for P1, "p2_" for
## P2) so player.gd keeps reading actions by prefix and never needs to know
## which device it is. The rewrite is in memory only; project.godot is untouched.
##
## Until assign() is first called (e.g. game.tscn run straight from the editor),
## the InputMap is left as saved and the old fixed mapping applies:
## keyboard and controller 1 are P1, controller 2 is P2.

const KEYBOARD := "keyboard"
## The per-player actions that get rebound. "pause" stays shared (any device);
## PauseMenu works out who pressed it with player_for_event().
const ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"aim_left", "aim_right", "aim_up", "aim_down",
	"shoot", "shield_activate",
]
const PREFIXES := {1: "", 2: "p2_"}

## Player index → device, empty until assign() is called.
var devices := {}

# Action → the keyboard / joypad events P1 had in project.godot.
var _key_templates := {}
var _joy_templates := {}

func _ready() -> void:
	# Autoloads are ready before the first scene loads, so this sees the
	# InputMap exactly as saved in project.godot, before any rewriting.
	for action in ACTIONS:
		_key_templates[action] = []
		_joy_templates[action] = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				_key_templates[action].append(event.duplicate())
			elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
				_joy_templates[action].append(event.duplicate())

## The device that sent `event`, or "" for mouse/touch/other events.
static func device_of(event: InputEvent) -> String:
	if event is InputEventKey:
		return KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "joypad:%d" % event.device
	return ""

static func joypad_id(device: String) -> int:
	return int(device.get_slice(":", 1)) if device.begins_with("joypad:") else -1

## "KEYBOARD" or "CONTROLLER 1" (joypad ids are 0-based; people count from 1).
static func device_name(device: String) -> String:
	if device == KEYBOARD:
		return "KEYBOARD"
	return "CONTROLLER %d" % (joypad_id(device) + 1)

func is_assigned() -> bool:
	return not devices.is_empty()

## Gives P1 and P2 their devices and rebinds their actions to match.
func assign(p1_device: String, p2_device: String) -> void:
	devices = {1: p1_device, 2: p2_device}
	for index in PREFIXES:
		var device: String = devices[index]
		for action: String in ACTIONS:
			var player_action: String = PREFIXES[index] + action
			InputMap.action_erase_events(player_action)
			for template: InputEvent in template_events(action, device == KEYBOARD):
				var event: InputEvent = template.duplicate()
				# -1 = any device. Fine for keys: only one keyboard can join.
				event.device = -1 if device == KEYBOARD else joypad_id(device)
				InputMap.action_add_event(player_action, event)

## The keyboard or controller events an action had in project.godot. Used for
## rebinding and for the Controls screen labels, which must not depend on who
## currently holds P1's actions.
func template_events(action: String, keyboard: bool) -> Array:
	if action in ACTIONS:
		return _key_templates[action] if keyboard else _joy_templates[action]
	# Never rebound (e.g. "pause"), so the live InputMap is still as saved.
	return InputMap.action_get_events(action).filter(
		func(e): return (e is InputEventKey) == keyboard and not (e is InputEventMouse))

## Which player (1 or 2) sent `event`, or 0 if its device hasn't joined.
func player_for_event(event: InputEvent) -> int:
	var device := device_of(event)
	if device == "":
		return 0
	if not is_assigned():
		return 1 if device == KEYBOARD else joypad_id(device) + 1
	for index in devices:
		if devices[index] == device:
			return index
	return 0

## The player using the keyboard, or 0 if neither is (or nobody has joined).
func keyboard_owner() -> int:
	for index in devices:
		if devices[index] == KEYBOARD:
			return index
	return 0
