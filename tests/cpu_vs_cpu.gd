extends SceneTree
## Debug tool: plays full CPU vs CPU matches headless, back to back, and logs
## each one to the balance log (with each CPU's difficulty). See docs/balance.md.
##
##   $GODOT --headless --path . -s res://tests/cpu_vs_cpu.gd -- \
##       --p1=hard --p2=easy --matches=10
##
## Matches run in real time (about 70s each). Don't add --fixed-fps to speed
## it up: weapon.gd times its fire rate with the wall clock, so the CPUs would
## barely shoot. Other options:
##   --log=<path>   where records go (default user://balance_log_cpu.jsonl, so
##                  CPU runs never mix into the human log)
##
## Autoloads aren't known by name when a -s script compiles, so it reaches them
## through the root node.

const DUEL_LIMIT := 120.0  # seconds of final battle before giving up on a match

var _p1 := "medium"
var _p2 := "medium"
var _matches := 1
var _played := 0
var _results := {1: 0, 2: 0, 0: 0}  # winner index → matches (0 = no result)
var _duel_time := 0.0
var _waiting_for_scene := false

func _initialize() -> void:
	var log_path := "user://balance_log_cpu.jsonl"
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--p1="):
			_p1 = value
		elif arg.begins_with("--p2="):
			_p2 = value
		elif arg.begins_with("--matches="):
			_matches = maxi(int(value), 1)
		elif arg.begins_with("--log="):
			log_path = value
	var devices := _autoload("PlayerDevices")
	for difficulty in [_p1, _p2]:
		if not difficulty in devices.DIFFICULTIES:
			printerr("Unknown difficulty '%s' (use %s)" % [difficulty, devices.DIFFICULTIES])
			quit(1)
			return
	BalanceLog.path = log_path
	print("CPU vs CPU: P1 %s vs P2 %s, %d matches, logging to %s"
		% [_p1, _p2, _matches, ProjectSettings.globalize_path(log_path)])
	_start_match.call_deferred()

func _autoload(autoload_name: String) -> Node:
	return root.get_node(autoload_name)

func _start_match() -> void:
	var devices := _autoload("PlayerDevices")
	devices.cpu_difficulty_override = {1: _p1, 2: _p2}
	devices.assign(devices.CPU, devices.CPU)
	_duel_time = 0.0
	_waiting_for_scene = true
	change_scene_to_file("res://scenes/game/game.tscn")

func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	if _waiting_for_scene:
		if current_scene.name == "Game":
			_waiting_for_scene = false
		return false
	if current_scene.name != "FinalBattle":
		return false
	var state := _autoload("GameState")
	# log_match_result() sets this once a winner is known (private, debug only).
	if state._match_logged:
		_finish_match(_winner())
	else:
		_duel_time += delta
		if _duel_time > DUEL_LIMIT:
			print("Match %d: no winner after %ds, skipped" % [_played + 1, DUEL_LIMIT])
			_finish_match(0)
	return false

func _winner() -> int:
	for p in get_nodes_in_group("player"):
		if not p.is_dead:
			return p.player_index
	return 0

func _finish_match(winner: int) -> void:
	_played += 1
	_results[winner] += 1
	if winner != 0:
		print("Match %d: P%d (%s) wins" % [_played, winner, _p1 if winner == 1 else _p2])
	if _played < _matches:
		_start_match()
		return
	print("Done: P1 %s won %d, P2 %s won %d, %d without a result"
		% [_p1, _results[1], _p2, _results[2], _results[0]])
	_autoload("PlayerDevices").cpu_difficulty_override = {}
	quit()
