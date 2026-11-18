extends PlayerInput
class_name DeviceInput
## A human player: reads the InputMap actions with this player's prefix
## ("" for P1, "p2_" for P2). PlayerDevices decides which device those
## actions are bound to.

var _prefix: String

func _init(prefix: String) -> void:
	_prefix = prefix

func get_move() -> Vector2:
	return Input.get_vector(_prefix + "move_left", _prefix + "move_right", _prefix + "move_up", _prefix + "move_down")

func get_aim() -> Vector2:
	return Input.get_vector(_prefix + "aim_left", _prefix + "aim_right", _prefix + "aim_up", _prefix + "aim_down")

func is_shooting() -> bool:
	return Input.is_action_pressed(_prefix + "shoot")

func is_shielding() -> bool:
	return Input.is_action_pressed(_prefix + "shield_activate")
