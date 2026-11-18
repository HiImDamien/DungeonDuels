extends RefCounted
class_name PlayerInput
## Where a player reads its controls from. player.gd only ever asks this
## object, so a human (DeviceInput) and the CPU (CpuInput) drive the same code.
## The base class is a neutral controller: no movement, no buttons held.

## Movement direction, already deadzoned, with length ≤ 1.
func get_move() -> Vector2:
	return Vector2.ZERO

## Raw aim direction. player.gd applies the 0.2 threshold and keeps last_aim.
func get_aim() -> Vector2:
	return Vector2.ZERO

func is_shooting() -> bool:
	return false

func is_shielding() -> bool:
	return false
