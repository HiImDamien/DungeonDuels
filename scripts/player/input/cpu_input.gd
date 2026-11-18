extends PlayerInput
class_name CpuInput
## A computer-controlled player: plain fields that a brain writes every tick
## and player.gd reads back. Touches no global Input or InputMap state.

var move := Vector2.ZERO
var aim := Vector2.ZERO
var shoot := false
var shield := false

func get_move() -> Vector2:
	return move.limit_length(1.0)

func get_aim() -> Vector2:
	return aim

func is_shooting() -> bool:
	return shoot

func is_shielding() -> bool:
	return shield
