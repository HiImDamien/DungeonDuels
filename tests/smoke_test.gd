extends Node
## End-to-end smoke test: plays a real match headless and checks the core loop
## still works. Run it with tests/run_smoke_test.sh (or open smoke_test.tscn in
## the editor and press F6, or ⌘R on macOS). Exits with the number of failed checks.
##
## It drives the real game scenes, so it catches broken wiring that a play-test
## would, but it can't tell you whether the game *feels* right — still play it.

const TIMEOUT_SECONDS := 150.0

var _failures := 0
var _checks := 0

func _ready() -> void:
	# Keep running while the game is paused so the pause checks can drive it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout)
	_run.call_deferred()

func _on_timeout() -> void:
	_fail("test timed out after %d seconds" % TIMEOUT_SECONDS)
	_finish()

# ── Helpers ───────────────────────────────────────────────────────────────────

func check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  " + description)
	else:
		_fail(description)

func _fail(description: String) -> void:
	_failures += 1
	printerr("  FAIL  " + description)

func _finish() -> void:
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(_failures)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func find_player(index: int) -> player:
	for p: player in get_tree().get_nodes_in_group("player"):
		if p.player_index == index:
			return p
	return null

func room_manager_for(p: player) -> Node:
	return p.get_parent().get_parent().get_node("RoomManager")

## Enemies in the same room as the player.
func enemies_near(p: player) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(
		func(e): return e.get_parent() == p.get_parent())

func clear_room(p: player) -> void:
	for e in enemies_near(p):
		e.take_damage(999, p)
	await wait(1.6)  # room manager waits 1s, then spawns upgrades

## Taps a controller button (device 0 = controller 1, 1 = controller 2).
func press(button: JoyButton, device: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func press_key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

## Holds `keys` down together for `seconds`, then releases them.
func hold_keys(keys: Array, seconds: float) -> void:
	_send_keys(keys, true)
	await wait(seconds)
	_send_keys(keys, false)
	await get_tree().process_frame

func _send_keys(keys: Array, pressed: bool) -> void:
	for key: Key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)

## Arrow keys aim and fire (#16); shielding blocks it and E no longer shoots.
func _test_keyboard_shooting(p: player) -> void:
	var weapon: Node2D = p.current_weapon
	var cooldown: float = weapon.fire_rate + 0.05
	var fired_at: float = weapon.last_fire_time
	await hold_keys([KEY_RIGHT], 0.1)
	check(weapon.last_fire_time > fired_at and p.last_aim == Vector2.RIGHT,
		"holding Right aims right and fires")

	await wait(cooldown)
	fired_at = weapon.last_fire_time
	await hold_keys([KEY_SPACE, KEY_UP], 0.1)
	check(weapon.last_fire_time == fired_at and p.last_aim == Vector2.UP,
		"Space + Up aims up but the shield blocks firing")

	await wait(cooldown)
	fired_at = weapon.last_fire_time
	await hold_keys([KEY_E], 0.1)
	check(weapon.last_fire_time == fired_at, "E no longer shoots")

## Few, heavy shield points and a Shield Regen you can feel (#29). Runs in a
## cleared room so no stray enemy bullets interfere.
func _test_shield(p: player) -> void:
	var shield := p.shield
	check(shield.max_health == 4, "the shield starts with 4 heavy points")
	# A leftover enemy bullet may have downed P1 earlier; let them get back up.
	var downed := 0.0
	while p.is_dead and downed < 8.0:
		await wait(0.2)
		downed += 0.2

	# Hold the shield through PlayerInput, the way the CPU opponent will.
	var cpu := CpuInput.new()
	cpu.shield = true
	cpu.aim = Vector2.RIGHT
	p.input = cpu
	shield.reset()
	p.invincible = false
	await wait(0.1)
	var hp := p.health
	var bullet = Enemy.ENEMY_BULLET.instantiate()
	p.get_parent().add_child(bullet)
	bullet.global_position = p.global_position + Vector2(24, 0)
	bullet.direction = Vector2.LEFT
	await wait(0.3)
	check(p.health == hp and shield.health == shield.max_health - 1,
		"a raised shield takes an enemy bullet for the player and loses one point (hp %d, shield %d)"
		% [p.health, shield.health])
	p.input = DeviceInput.new(p._input_prefix)
	await wait(0.1)
	check(not shield.is_active, "letting go of the shield lowers it")

	var regen: Upgrade = load("res://scenes/upgrades/shield_regen.tscn").instantiate()
	var cooldown := shield.cooldown_time
	var interval := shield.recharge_interval
	regen.apply(p)
	regen.apply(p)
	regen.free()
	check(is_equal_approx(shield.cooldown_time, cooldown / 4.0)
		and is_equal_approx(shield.cooldown_timer.wait_time, shield.cooldown_time),
		"two Shield Regens quarter the break cooldown (%.1fs → %.1fs), timers updated immediately"
		% [cooldown, shield.cooldown_time])
	check(shield.recharge_interval <= interval * 0.4
		and is_equal_approx(shield.recharge_timer.wait_time, shield.recharge_interval),
		"two Shield Regens make recharge much faster (%.2fs → %.2fs per point)"
		% [interval, shield.recharge_interval])

## Moves the player onto a pickup so real physics triggers the pickup.
func walk_onto(p: player, pickup: Area2D) -> void:
	p.global_position = pickup.global_position
	await wait(0.3)

## Every room in the room manager's lists must have a player spawn and at
## least one fully set-up enemy spawn.
func _check_room_layout(scene: PackedScene) -> void:
	var room := scene.instantiate()
	var spawns: Array = room.get_node("EnemySpawns").get_children()
	var complete := spawns.filter(func(s): return s is EnemySpawn and s.enemy_scene != null)
	check(room.has_node("PlayerSpawn") and complete.size() > 0 and complete.size() == spawns.size(),
		"%s: player spawn and %d enemy spawns, all with an enemy chosen" % [scene.resource_path.get_file(), complete.size()])
	room.free()

func _key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	return event

func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

## Which buttons leave the win screen, and that none of them is a gameplay
## control (players keep playing after the win to celebrate).
func _check_win_screen(battle: Node) -> void:
	var exits := [_button_event(JOY_BUTTON_A), _button_event(JOY_BUTTON_Y),
		_key_event(KEY_ENTER), _key_event(KEY_KP_ENTER), _key_event(KEY_ESCAPE)]
	var non_exits := [_key_event(KEY_SPACE), _button_event(JOY_BUTTON_B),
		_button_event(JOY_BUTTON_START), _button_event(JOY_BUTTON_RIGHT_SHOULDER)]
	check(exits.all(battle.is_exit_event) and not non_exits.any(battle.is_exit_event),
		"A, Y, Enter and Esc leave the win screen; Space, B, Start and RB don't")

	var clashes: Array[String] = []
	for action in InputMap.get_actions():
		if action.begins_with("ui_") or action == "pause":  # pause is off after the win
			continue
		for event in InputMap.action_get_events(action):
			if battle.is_exit_event(event):
				clashes.append(action)
	check(clashes.is_empty(), "no gameplay action uses a win-screen exit button %s" % str(clashes))

	var hints: Array = battle.get_children().filter(func(c): return c is Label and c.text == battle.WIN_HINT)
	var ascii := Array(battle.WIN_HINT.to_utf8_buffer()).all(func(b): return b < 128)
	check(hints.size() == 1 and ascii and "Enter" in battle.WIN_HINT and "A / Cross" in battle.WIN_HINT,
		"win hint is shown, plain ASCII, and names Enter and A")

## Returns the game scene, started by pressing Play on the title screen.
func _test_title_and_controls() -> Node:
	print("Title screen and controls")
	# Make the title the current scene so pressing Play swaps it out like the
	# real game does, while this test node stays alive.
	var title: Node = load("res://scenes/ui/title_screen.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	await get_tree().process_frame
	var names: Array = title.menu.get_buttons().map(func(b): return b.text)
	check(names == ["PLAY", "CONTROLS", "QUIT"], "title menu is Play, Controls, Quit")

	# Headless runs can't have the "web" feature tag, so hide Quit by hand.
	title.show_quit(false)
	names = title.menu.get_buttons().map(func(b): return b.text)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	check(names == ["PLAY", "CONTROLS"] and title.menu.selected == 0,
		"without Quit (web) the menu is Play, Controls and Down wraps back to Play")
	title.show_quit(true)

	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_A, 0)
	var screens: Array = title.get_children().filter(func(c): return c is ControlsScreen)
	check(screens.size() == 1, "choosing Controls opens the controls screen")
	check(InputLabels.controller_label("shoot") == "RT / R2"
		and InputLabels.controller_label("shield_activate") == "LT / L2"
		and InputLabels.controller_label("move_left") == "Left Stick"
		and InputLabels.controller_label("pause") == "Start / Options",
		"controller labels come from the input map")
	check(InputLabels.keyboard_label(["move_up", "move_left", "move_down", "move_right"]) == "W A S D"
		and InputLabels.keyboard_label(["aim_up", "aim_left", "aim_down", "aim_right"]) == "Arrow Keys"
		and InputLabels.keyboard_label(["shoot"]) == "Arrow Keys"
		and InputLabels.keyboard_label(["pause"]) == "Esc / P",
		"keyboard labels come from the input map")
	check(ProjectSettings.get_setting("display/window/size/mode") == DisplayServer.WINDOW_MODE_FULLSCREEN
		and ProjectSettings.get_setting("display/window/size/mode.web") == DisplayServer.WINDOW_MODE_WINDOWED,
		"desktop starts fullscreen, but web builds don't force browser fullscreen")
	var font: Font = ControlsScreen.FONT
	var lines := ControlsScreen.keyboard_lines()
	var widest := 0.0
	for line in lines:
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	check("Aim + Shoot: Arrow Keys" in lines[0] and widest <= title.get_viewport_rect().size.x,
		"keyboard controls read 'Aim + Shoot: Arrow Keys' and fit on screen (%dpx)" % widest)
	check(ControlsScreen.keyboard_heading() == "KEYBOARD", "before anyone joins, the keyboard has no owner")
	await press(JOY_BUTTON_B, 0)
	await get_tree().process_frame
	check(title.get_children().filter(func(c): return c is ControlsScreen).is_empty() and title.menu.active,
		"B closes the controls screen and returns to the menu")

	await press(JOY_BUTTON_DPAD_UP, 0)
	await press(JOY_BUTTON_A, 0)
	await wait(0.3)
	var join := get_tree().current_scene
	check(join is JoinScreen, "pressing Play opens the join screen")
	if not join is JoinScreen:
		return join
	return await _test_join_screen(join)

## Presses `key` if `device` is the keyboard, else `button` on that controller.
func tap(device: String, key: Key, button: JoyButton) -> void:
	if device == PlayerDevices.KEYBOARD:
		await press_key(key)
	else:
		await press(button, PlayerDevices.joypad_id(device))

## Joins with `device`, moves it to `side` and readies up.
func join_side(device: String, side: int) -> void:
	await tap(device, KEY_ENTER, JOY_BUTTON_A)
	if side == JoinScreen.LEFT:
		await tap(device, KEY_A, JOY_BUTTON_DPAD_LEFT)
	else:
		await tap(device, KEY_D, JOY_BUTTON_DPAD_RIGHT)
	await tap(device, KEY_ENTER, JOY_BUTTON_A)

func move_stick(device: int, value: float) -> void:
	for v in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = v
		Input.parse_input_event(event)
		await get_tree().process_frame

## Left / Right on the keyboard cycles Easy / Medium / Hard (wrapping both
## ways) and ends back on Medium, so later solo checks see the default.
func _check_difficulty_cycle(join: JoinScreen) -> void:
	var steps := [[KEY_D, "hard"], [KEY_RIGHT, "easy"], [KEY_LEFT, "hard"], [KEY_A, "medium"]]
	var ok := true
	for step in steps:
		await press_key(step[0])
		var shown := "Difficulty: <%s>" % step[1].capitalize()
		ok = ok and PlayerDevices.cpu_difficulty == step[1] \
			and join._side_labels[JoinScreen.RIGHT].text.contains(shown) \
			and join.token_for("keyboard").get("side") == JoinScreen.LEFT
	check(ok, "keyboard Left / Right cycles the CPU's difficulty, wraps, and doesn't move the player")
	var font: Font = join._side_labels[JoinScreen.RIGHT].get_theme_font("font")
	var widest := 0.0
	for d in PlayerDevices.DIFFICULTIES:
		var text := "Difficulty: <%s>" % d.capitalize()
		widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var card: Control = join._side_labels[JoinScreen.RIGHT].get_parent()
	check(widest <= card.size.x,
		"every difficulty label fits inside the CPU's card (widest %d of %d px)" % [widest, card.size.x])

## Drives the join screen through its rules, then starts a match with the
## keyboard as P1 (left) and controller 2 as P2 (right). Returns the game.
func _test_join_screen(join: JoinScreen) -> Node:
	print("Join screen")
	const L := JoinScreen.LEFT
	const M := JoinScreen.MIDDLE
	const R := JoinScreen.RIGHT
	check(join.tokens.is_empty(), "the join screen starts with nobody joined")
	await move_stick(2, 1.0)
	check(join.tokens.is_empty(), "moving a stick doesn't join")
	await press_key(KEY_J)
	await press_key(KEY_K)
	check(join.tokens.size() == 1 and join.token_for("keyboard").get("side") == M,
		"a key joins the keyboard in the middle, and the keyboard can't join twice")
	await press(JOY_BUTTON_A, 1)
	await press(JOY_BUTTON_X, 0)
	check(join.tokens.size() == 2 and join.token_for("joypad:0").is_empty(), "a third device can't join")

	await press(JOY_BUTTON_DPAD_LEFT, 1)
	await press_key(KEY_A)
	check(join.device_on(L) == "joypad:1" and join.token_for("keyboard").get("side") == M,
		"a controller can take the left side, and a taken side is blocked")
	await press_key(KEY_D)
	await press_key(KEY_ENTER)
	check(join.countdown_left < 0.0, "no countdown until both players are ready")
	await press(JOY_BUTTON_A, 1)
	await get_tree().process_frame
	check(join.all_ready() and join.countdown_left > 0.0, "both players ready starts the countdown")
	await press_key(KEY_LEFT)
	check(join.token_for("keyboard").get("side") == R, "a ready player can't change sides")
	await press_key(KEY_BACKSPACE)
	await get_tree().process_frame
	check(not join.token_for("keyboard").get("ready") and join.countdown_left < 0.0, "un-readying cancels the countdown")
	await press_key(KEY_BACKSPACE)
	check(join.token_for("keyboard").get("side") == M, "back again steps off the side to the middle")
	await press_key(KEY_BACKSPACE)
	check(join.token_for("keyboard").is_empty(), "back from the middle leaves")
	for i in 3:
		await press(JOY_BUTTON_B, 1)
	check(join.tokens.is_empty(), "the controller can back all the way out too")

	await join_side(PlayerDevices.KEYBOARD, L)
	await get_tree().process_frame
	check(join.can_play_solo() and not join.solo and join.countdown_left < 0.0,
		"one ready player alone doesn't start a countdown by itself")
	check(join._side_labels[R].text.contains("play solo"), "the empty side offers solo play")
	await press_key(KEY_ENTER)
	await get_tree().process_frame
	check(join.solo and not join.difficulty_chosen and join.countdown_left < 0.0,
		"ready again asks for the CPU's difficulty instead of counting down")
	check(join._side_labels[R].text.contains("CPU")
		and join._side_labels[R].text.contains("Difficulty: <Medium>"),
		"the empty side shows the CPU and its difficulty, Medium by default")
	await _check_difficulty_cycle(join)
	await press_key(KEY_ENTER)
	await get_tree().process_frame
	check(join.difficulty_chosen and join.countdown_left > 0.0
		and join._side_labels[R].text.contains("Difficulty: Medium"),
		"Enter on the difficulty starts the solo countdown")
	await press_key(KEY_BACKSPACE)
	await get_tree().process_frame
	check(join.solo and not join.difficulty_chosen and join.countdown_left < 0.0,
		"back from the solo countdown returns to the difficulty")
	await press(JOY_BUTTON_A, 1)
	await get_tree().process_frame
	check(not join.solo and join.countdown_left < 0.0, "a second device joining cancels solo")
	await press(JOY_BUTTON_B, 1)
	await press_key(KEY_ENTER)
	await press_key(KEY_BACKSPACE)
	await get_tree().process_frame
	check(not join.solo and join.countdown_left < 0.0 and not join.token_for("keyboard").get("ready"),
		"backing out cancels solo")
	for i in 2:
		await press_key(KEY_BACKSPACE)
	check(join.tokens.is_empty(), "everyone has left again")

	await press_key(KEY_ESCAPE)
	await wait(0.3)
	check(get_tree().current_scene.name == "TitleScreen", "back with nobody joined returns to the title")
	await press(JOY_BUTTON_A, 0)
	await wait(0.3)
	join = get_tree().current_scene
	check(join is JoinScreen and join.tokens.is_empty(), "Play again opens the join screen with empty slots")

	# Headless isn't web, so turn the hint on by hand and skip the wait.
	check(not join.controller_hint_enabled, "the no-controller hint is off outside web builds")
	check(join.saw_controller, "the controller that pressed Play already counts as seen")
	join.controller_hint_enabled = true
	join.saw_controller = false  # as if Play had been chosen with the keyboard
	join._elapsed = JoinScreen.CONTROLLER_HINT_DELAY
	await wait(0.1)  # process_frame resumes before nodes run _process, so wait a beat
	var hint_shown: bool = join._hint_label.text == JoinScreen.CONTROLLER_HINT
	await move_stick(3, 0.1)  # any controller input, without joining
	await wait(0.1)
	check(hint_shown and join._hint_label.text == "",
		"with no controller seen the hint appears, and controller input clears it")

	await join_side(PlayerDevices.KEYBOARD, L)
	await join_side("joypad:1", R)
	await get_tree().process_frame
	check(join.countdown_left > 0.0, "keyboard on the left and controller 2 on the right, both ready")
	await wait(JoinScreen.COUNTDOWN + 0.3)
	var game := get_tree().current_scene
	check(game != null and game.name == "Game", "the countdown starts the match")

	var shoot: Array = InputMap.action_get_events("shoot")
	var p2_shoot: Array = InputMap.action_get_events("p2_shoot")
	check(shoot.size() > 0 and shoot.all(func(e): return e is InputEventKey)
		and p2_shoot.size() > 0 and p2_shoot.all(func(e): return not e is InputEventKey and e.device == 1),
		"P1's actions are rebound to the keyboard only, P2's to controller 2 only")
	var key := InputEventKey.new()
	var joy0 := InputEventJoypadButton.new()
	var joy1 := InputEventJoypadButton.new()
	joy1.device = 1
	check(PlayerDevices.player_for_event(key) == 1 and PlayerDevices.player_for_event(joy1) == 2
		and PlayerDevices.player_for_event(joy0) == 0,
		"keyboard is P1, controller 2 is P2, controller 1 belongs to nobody")
	return game

func _test_pause(game: Node) -> void:
	print("Pause menu")
	var pause_menu: PauseMenu = game.get_node("PauseMenu")
	await press(JOY_BUTTON_START, 1)
	check(get_tree().paused and pause_menu.paused_by == 2, "controller 2's Start pauses the game as P2")
	check(GameState.pauses_left[2] == GameState.PAUSES_PER_PLAYER - 1, "P2 used one of their pauses")

	var time_left := GameState.time_remaining
	var enemy_positions: Array = get_tree().get_nodes_in_group("enemy").map(func(e): return e.global_position)
	await wait(1.0)
	var enemies_frozen := get_tree().get_nodes_in_group("enemy").map(func(e): return e.global_position) == enemy_positions
	check(GameState.time_remaining == time_left and enemies_frozen, "everything is frozen while paused")

	await press_key(KEY_ESCAPE)
	await press_key(KEY_BACKSPACE)
	check(get_tree().paused and pause_menu._root.visible, "P1 (keyboard) can't resume or use P2's pause menu")
	check(pause_menu._messages[1].visible and pause_menu._messages[1].text == "Only P2 can resume"
		and not pause_menu._messages[2].visible, "P1 is told on their own side that only P2 can resume")

	await press(JOY_BUTTON_DPAD_DOWN, 1)
	await press(JOY_BUTTON_A, 1)
	check(pause_menu._controls != null, "P2 can open Controls from the pause menu")
	check(ControlsScreen.keyboard_heading() == "KEYBOARD (P1)", "Controls shows the keyboard belongs to P1")
	await press(JOY_BUTTON_START, 1)
	check(get_tree().paused and pause_menu._controls != null, "Start doesn't resume while Controls is open")
	await press(JOY_BUTTON_B, 1)
	check(pause_menu._controls == null, "B closes Controls back to the pause menu")

	await press(JOY_BUTTON_B, 1)
	await wait(1.5)
	check(get_tree().paused and not pause_menu._root.visible, "resuming counts down before unpausing")
	await wait(2.2)
	check(not get_tree().paused, "game unpauses after the countdown")

	await press(JOY_BUTTON_START, 0)
	check(not get_tree().paused, "controller 1 didn't join, so its Start can't pause")

	GameState.pauses_left[1] = 0
	await press_key(KEY_ESCAPE)
	check(not get_tree().paused, "a player with no pauses left can't pause")
	check(pause_menu._messages[1].visible and pause_menu._messages[1].text == "No pauses left",
		"P1 sees 'No pauses left' on their side")
	GameState.pauses_left[1] = GameState.PAUSES_PER_PLAYER
	await press_key(KEY_ESCAPE)
	check(get_tree().paused and pause_menu.paused_by == 1, "Esc pauses as P1")
	await press_key(KEY_ESCAPE)
	await wait(3.8)
	check(not get_tree().paused, "Esc resumes for P1")
	# P is a second pause key, since in browser fullscreen Esc only exits fullscreen.
	await press_key(KEY_P)
	check(get_tree().paused and pause_menu.paused_by == 1, "P also pauses as P1")
	await press_key(KEY_P)
	await wait(3.8)
	check(not get_tree().paused, "P resumes for P1")
	GameState.pauses_left[1] = GameState.PAUSES_PER_PLAYER

# ── The test ──────────────────────────────────────────────────────────────────

func _run() -> void:
	_balance_log_setup()
	var game := await _test_title_and_controls()
	if game == null or game.name != "Game":
		_finish()
		return
	await wait(0.3)

	print("Dungeon setup")
	var p1 := find_player(1)
	var p2 := find_player(2)
	check(p1 != null and p2 != null, "both players exist")
	check(p1._input_prefix == "" and p2._input_prefix == "p2_", "players read their own input actions")
	var rm = room_manager_for(p1)
	var enemies := enemies_near(p1)
	check(enemies.size() > 0 and enemies.size() == rm.enemies_remaining,
		"first room spawned %d enemies, matching the room manager's count" % enemies.size())
	check(enemies.all(func(e): return e.target == p1), "P1's enemies target P1")
	check(enemies_near(p2).all(func(e): return e.target == p2), "P2's enemies target P2")
	check(GameState.is_grace and p1.stunned, "grace period active at start")

	print("Room layouts")
	check(rm.normal_rooms.size() > 0 and rm.boss_rooms.size() > 0, "room manager has normal and boss rooms")
	for scene: PackedScene in rm.normal_rooms + rm.boss_rooms:
		_check_room_layout(scene)

	await wait(3.2)
	check(not GameState.is_grace and not p1.stunned, "grace period ends and players can shoot")
	await _test_keyboard_shooting(p1)

	print("Combat")
	var enemy = enemies[0]
	var enemy_hp: int = enemy.health
	var bullet = load("res://scenes/player/player_bullet.tscn").instantiate()
	p1.get_parent().add_child(bullet)
	bullet.global_position = enemy.global_position + Vector2(-12, 0)
	bullet.direction = Vector2.RIGHT
	bullet.shooter = p1
	await wait(0.3)
	check(not is_instance_valid(enemy) or enemy.health < enemy_hp, "a player bullet damages an enemy")

	var p1_hp := p1.health
	await wait(4.0)  # only enemy bullets can hurt a player in the dungeon
	check(p1.health < p1_hp or p1.is_dead, "enemy bullets hit the player (hp %d → %d)" % [p1_hp, p1.health])
	await wait(3.5)  # give a downed player time to get back up

	await _test_pause(game)

	print("Room flow and upgrades")
	var kills_before := p1.kills
	var alive := enemies_near(p1).size()
	await clear_room(p1)
	check(p1.kills == kills_before + alive, "kills credited for every enemy")
	check(rm.rooms_completed == 1, "room counts as cleared")
	check(rm._offered_upgrades.size() == 2, "two stat upgrades offered")
	var label: Label = rm.current_room_node.get_node("CanvasLayer/Upgrade1_label")
	check(label.text != "", "upgrade label shows '%s'" % label.text.replace("\n", " "))
	var label2: Label = rm.current_room_node.get_node("CanvasLayer/Upgrade2_label")
	var label_font := label.get_theme_font("font")
	var label_size := label.get_theme_font_size("font_size")
	var widest := 0.0
	for scene: PackedScene in rm.UPGRADE_SCENES:
		var u: Upgrade = scene.instantiate()
		for line in u.description.split("\n"):
			widest = maxf(widest, label_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x)
		u.free()
	check(widest <= label.size.x and widest <= label2.size.x
		and label.position.x + label.size.x <= label2.position.x,
		"every stat upgrade description fits its label and the two labels don't overlap (widest %d px)" % widest)

	await _test_shield(p1)

	await walk_onto(p1, rm._offered_upgrades[0])
	check(rm._offered_upgrades.is_empty(), "walking onto an upgrade picks it up and removes the other")
	check(enemies_near(p1).size() > 0, "next room loads with enemies")

	await wait(0.2)
	await clear_room(p1)
	await walk_onto(p1, rm._offered_upgrades[0])

	print("Boss")
	var bosses: Array = enemies_near(p1).filter(func(e): return e is BossSlime)
	check(bosses.size() == 1, "third room is the boss room")
	if bosses.size() == 1:
		bosses[0].take_damage(bosses[0].max_health / 2 + 1, p1)
		check(bosses[0].is_enraged, "boss enrages below half health")
	await clear_room(p1)
	var ticker: Label = game.p2_opponent_ticker
	check(ticker.text == "Opponent Cleared Boss", "boss clear is announced on P2's screen")
	check(rm._offered_upgrades.size() == 3, "boss clear offers two stat upgrades and a bullet upgrade")
	var bullet_upgrades: Array = rm._offered_upgrades.filter(func(u): return u is BulletUpgrade)
	if bullet_upgrades.size() == 1:
		var bu: BulletUpgrade = bullet_upgrades[0]
		var bu_label: Label = rm.current_room_node.get_node("CanvasLayer/Upgrade3_label")
		check(bu_label.text == bu.description, "bullet upgrade label shows '%s'" % bu_label.text)
		var mode := bu.bullet_mode  # read now; the pickup is freed once collected
		await walk_onto(p1, bu)
		check(p1.current_weapon.has_bullet_mode(mode), "bullet mode '%s' added to the bow" % mode)

	await _balance_log_p2_pick(p2)

	print("Final battle")
	var kills := p1.kills
	var modes: Array[String] = p1.current_weapon.bullet_modes.duplicate()
	var speed := p1.speed
	var shield_max := p1.shield.max_health
	var shield_interval := p1.shield.recharge_interval
	GameState.time_remaining = 0.05
	await wait(0.5)
	check(GameState.phase == GameState.Phase.FINAL_BATTLE, "timer running out starts the final battle")
	var f1 := find_player(1)
	var f2 := find_player(2)
	check(f1 != null and f2 != null and f1 != p1, "both players respawn in the arena")
	if f1 == null or f2 == null:
		_finish()
		return
	check(f1.kills == kills and f1.speed == speed, "kills and speed carry over")
	check(f1.current_weapon.bullet_modes == modes, "bullet modes carry over %s" % str(modes))
	check(f1.shield.max_health == shield_max
		and is_equal_approx(f1.shield.recharge_interval, shield_interval)
		and is_equal_approx(f1.shield.cooldown_timer.wait_time, f1.shield.cooldown_time),
		"shield upgrades carry over")
	check(f2.current_weapon.bullet_color != Color.WHITE, "P2's bullets are tinted")

	await wait(3.5)  # final-battle grace period
	for i in f2.max_health:
		f2.invincible = false
		f2.player_hit(f1)
	await wait(0.3)
	await press(JOY_BUTTON_START, 1)  # P2 has joined; Start isn't a win-screen exit
	check(not get_tree().paused, "pausing is disabled once someone has won")
	var win_labels: Array = get_tree().current_scene.get_children().filter(
		func(c): return c is Label and c.text.ends_with("Wins!"))
	check(win_labels.size() == 1 and win_labels[0].text == "P1 Wins!", "eliminating P2 shows 'P1 Wins!'")
	_check_balance_log_written(kills)

	var battle := get_tree().current_scene
	_check_win_screen(battle)
	await press_key(KEY_SPACE)
	await wait(0.3)
	check(get_tree().current_scene == battle, "Space (P1's shield) doesn't leave the win screen")

	print("Back to the menu and rematch")
	await press_key(KEY_ENTER)
	await wait(0.3)
	check(get_tree().current_scene.name == "TitleScreen", "Enter on the win screen returns to the title")
	await press(JOY_BUTTON_A, 0)
	await wait(0.3)
	var join: Node = get_tree().current_scene
	check(join is JoinScreen and join.tokens.is_empty(), "Play opens a fresh join screen for the rematch")
	# Two controllers this time, so controller 1 is P1.
	await join_side("joypad:0", JoinScreen.LEFT)
	await join_side("joypad:1", JoinScreen.RIGHT)
	await wait(JoinScreen.COUNTDOWN + 0.3)
	check(get_tree().current_scene.name == "Game", "two controllers can start a rematch")
	check(GameState.player_stats[1].kills == 0 and GameState.pauses_left[1] == GameState.PAUSES_PER_PLAYER,
		"the rematch resets stats and pauses")
	_check_balance_log_reset()
	check(ControlsScreen.keyboard_heading() == "KEYBOARD (NOT IN USE)"
		and InputLabels.keyboard_label(["shoot"]) == "Arrow Keys",
		"with two controllers the keyboard is unused, but its labels still show")
	await wait(3.5)  # grace period
	await press_key(KEY_ESCAPE)
	check(not get_tree().paused, "the keyboard can't pause when nobody picked it")
	await press(JOY_BUTTON_START, 0)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_A, 0)
	await wait(0.3)
	check(get_tree().current_scene.name == "TitleScreen" and not get_tree().paused,
		"Quit to Menu returns to the title, unpaused")
	_check_balance_log_after_quit()

	await _test_solo_match()
	_balance_log_teardown()
	_finish()

func _test_solo_match() -> void:
	print("Solo play")
	await press_key(KEY_ENTER)
	await wait(0.3)
	var join: Node = get_tree().current_scene
	if not join is JoinScreen:
		_fail("Play from the title should open the join screen for solo play")
		return
	await join_side(PlayerDevices.KEYBOARD, JoinScreen.LEFT)
	await press_key(KEY_ENTER)  # play solo
	await press_key(KEY_ENTER)  # keep the default difficulty
	await wait(JoinScreen.COUNTDOWN + 0.3)
	check(get_tree().current_scene.name == "Game", "a solo countdown starts the match")
	check(InputMap.action_get_events("shoot").all(func(e): return e is InputEventKey)
		and PlayerDevices.ACTIONS.all(func(a): return InputMap.action_get_events("p2_" + a).is_empty()),
		"solo: P1 is on the keyboard and P2 has no bindings")
	check(PlayerDevices.devices[2] == PlayerDevices.CPU, "solo: the empty side is the CPU")
	var joy0 := InputEventJoypadButton.new()
	check(PlayerDevices.player_for_event(joy0) == 0, "solo: controllers don't control the CPU's P2")
	var p1 := find_player(1)
	var p2 := find_player(2)
	var brain: CpuBrain = p2.get_node_or_null("CpuBrain")
	check(brain != null and p2.input is CpuInput
		and p1.get_node_or_null("CpuBrain") == null and p1.input is DeviceInput,
		"solo dungeon: P2 gets a CpuBrain and P1 stays human on DeviceInput")
	if brain == null:
		return
	brain.rng_seed = 33
	await wait(3.5)  # grace period
	var p1_start := p1.global_position
	await hold_keys([KEY_D], 0.4)
	check(p1.global_position.distance_to(p1_start) > 1.0, "solo: P1 moves with the keyboard")
	check(PlayerDevices.ACTIONS.all(func(a): return InputMap.action_get_events("p2_" + a).is_empty()),
		"the CPU plays without touching the InputMap")

	await _test_cpu_dungeon(p1, p2, brain)
	var dungeon_stats := PlayerStats.new()
	dungeon_stats.capture(p2)
	await _test_cpu_final_battle(dungeon_stats)
	await _test_cpu_difficulty_pick()

# ── CPU difficulty (#34) ──────────────────────────────────────────────────────

## The solo player's CPU card (P2's side when the player is on the left).
func _cpu_card(join: JoinScreen) -> String:
	return join._side_labels[JoinScreen.RIGHT].text

## Picks Hard with a controller, then checks the brain gets the hard profile
## and that the choice is kept for the next solo match.
func _test_cpu_difficulty_pick() -> void:
	print("CPU difficulty")
	await press_key(KEY_ENTER)  # win screen → title
	await wait(0.3)
	await press(JOY_BUTTON_A, 0)  # Play
	await wait(0.3)
	var join: Node = get_tree().current_scene
	if not join is JoinScreen:
		_fail("Play from the title should open the join screen")
		return
	await join_side("joypad:0", JoinScreen.LEFT)
	await press(JOY_BUTTON_A, 0)  # play solo
	await press(JOY_BUTTON_DPAD_RIGHT, 0)
	var dpad_ok: bool = PlayerDevices.cpu_difficulty == "hard" and _cpu_card(join).contains("<Hard>")
	await move_stick(0, 1.0)
	var stick_ok: bool = PlayerDevices.cpu_difficulty == "easy"
	await move_stick(0, -1.0)
	check(dpad_ok and stick_ok and PlayerDevices.cpu_difficulty == "hard",
		"a controller's D-pad and stick cycle the difficulty too")
	await press(JOY_BUTTON_A, 0)
	await wait(JoinScreen.COUNTDOWN + 0.3)
	var p2 := find_player(2)
	var brain: CpuBrain = p2.get_node_or_null("CpuBrain") if p2 != null else null
	check(brain != null and brain.profile == CpuBrain.PROFILES["hard"],
		"picking Hard on the join screen gives the CPU's brain the hard profile")

	await wait(3.5)  # grace period
	await press(JOY_BUTTON_START, 0)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_DPAD_DOWN, 0)
	await press(JOY_BUTTON_A, 0)  # Quit to Menu
	await wait(0.3)
	await press(JOY_BUTTON_A, 0)  # Play
	await wait(0.3)
	join = get_tree().current_scene
	if not join is JoinScreen:
		_fail("Quit to Menu then Play should open the join screen")
		return
	await join_side("joypad:0", JoinScreen.LEFT)
	await press(JOY_BUTTON_A, 0)
	check(_cpu_card(join).contains("Difficulty: <Hard>"), "the difficulty is kept for the next solo match")
	PlayerDevices.cpu_difficulty = "medium"

# ── CPU opponent in the dungeon (#33) ─────────────────────────────────────────

## The CPU only sees its own world. Both worlds use the same coordinates, so a
## bullet in P1's world sitting on P2's position would fool a missing filter.
func _check_cpu_perception(p1: player, p2: player, brain: CpuBrain) -> void:
	var mine := brain._my_enemies()
	var theirs := enemies_near(p1)
	check(not mine.is_empty() and mine.all(func(e): return e.target == p2)
		and theirs.all(func(e): return not mine.has(e)),
		"the CPU only sees enemies chasing it (%d), none of P1's (%d)" % [mine.size(), theirs.size()])

	var bullet_scene := load("res://scenes/enemy/enemy_bullet.tscn")
	var foreign: Area2D = bullet_scene.instantiate()
	foreign.speed = 0.0
	p1.get_parent().add_child(foreign)
	foreign.global_position = p2.global_position
	var own: Area2D = bullet_scene.instantiate()
	own.speed = 0.0
	p2.get_parent().add_child(own)
	own.global_position = Vector2(-500, -500)  # far outside the room, harmless
	var seen := brain._bullets_in_world()
	check(seen.has(own) and not seen.has(foreign),
		"the CPU sees bullets in its own world but not one from P1's world on its position")
	foreign.queue_free()
	own.queue_free()

	# P1 only just let go of D; a process frame doesn't guarantee a physics
	# tick has zeroed its velocity yet, and lead would then aim off its body.
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Shots leave the bow on the AimPivot, 8 px above the feet, so the aim line
	# must run from there to the target's hitbox. P1 stands still, so even with
	# lead the line has to pass through P1's body centre.
	var from: Vector2 = p2.aim_pivot.global_position
	var body: Vector2 = p1.get_node("CollisionShape2D").global_position
	var aim := brain._lead_aim(p1)
	var off_line := absf((body - from).cross(aim))
	check(p1.velocity == Vector2.ZERO and off_line < 0.5,
		"the CPU aims from its bow at the target's body (%.2f px off, P1 velocity %s)" % [off_line, p1.velocity])

## The bow holds two modes (#35). A third would push out the oldest, so the
## label says so and the CPU stops treating it as a must-take pickup.
func _check_full_bow(p2: player, brain: CpuBrain) -> void:
	var bow = p2.current_weapon
	var saved_modes: Array[String] = bow.bullet_modes.duplicate()
	var saved_rng := brain._rng.state  # scoring rolls jitter; keep the run deterministic
	var big := BulletUpgrade.create("big")

	bow.bullet_modes.assign(["spread"])
	check(big.description_for(p2) == "Big Bullets" and big.replaced_mode(p2) == "",
		"with room on the bow, the bullet upgrade label is just its name")
	check(brain._upgrade_score(big) >= CpuBrain.BULLET_UPGRADE_BONUS,
		"with room on the bow, the CPU always takes the bullet upgrade")

	bow.bullet_modes.assign(["spread", "bounce"])
	check(big.description_for(p2) == "Big Bullets\n(replaces Spread Shot)",
		"with a full bow, the label names the mode it replaces: '%s'" % big.description_for(p2).replace("\n", " "))
	check(brain._upgrade_score(big) < CpuBrain.BULLET_UPGRADE_BONUS,
		"with a full bow, the CPU weighs the bullet upgrade like a stat upgrade")

	big.free()
	bow.bullet_modes.assign(saved_modes)
	brain._rng.state = saved_rng

## Values changed on purpose by the #35 balance pass (see docs/balance.md).
func _check_balance_tuning(p2: player, brain: CpuBrain) -> void:
	var saved_max: int = p2.max_health
	var hm: Upgrade = load("res://scenes/upgrades/health_max.tscn").instantiate()
	p2.max_health = player.STARTING_MAX_HEALTH
	var offered_at_start := hm.is_available(p2)
	p2.max_health = player.STARTING_MAX_HEALTH + 1
	check(player.STARTING_MAX_HEALTH == 4 and offered_at_start and not hm.is_available(p2),
		"players start with 4 hearts and max health caps at 5 (one pickup)")
	p2.max_health = saved_max
	hm.free()

	var bow = p2.current_weapon
	var saved_modes: Array[String] = bow.bullet_modes.duplicate()
	var bullet = load("res://scenes/player/player_bullet.tscn").instantiate()
	bullet.apply_modes(["bounce"] as Array[String], p2)
	bow.bullet_modes.assign(["bounce"])
	check(is_equal_approx(bullet.speed, 250.0) and is_equal_approx(brain._bullet_speed(), bullet.speed),
		"bouncing bullets fly at 250 and the CPU leads its shots for that speed")
	bow.bullet_modes.assign(saved_modes)
	bullet.free()

	var hard: CpuProfile = load("res://resources/cpu/hard.tres")
	check(hard.upgrade_weights.get("shield_max") == 2.0 and hard.upgrade_weights.get("shield_regen") == 2.0,
		"Hard weighs the shield upgrades at 2")

func _test_cpu_dungeon(p1: player, p2: player, brain: CpuBrain) -> void:
	print("Solo dungeon: the CPU plays its own world")
	await _check_cpu_perception(p1, p2, brain)
	_check_full_bow(p2, brain)
	_check_balance_tuning(p2, brain)
	var rm2 = room_manager_for(p2)
	var limit := 30.0
	var waited := 0.0
	var moved := false
	var fired := false
	var start := p2.global_position
	var fired_before: float = p2.current_weapon.last_fire_time
	while waited < limit and not (rm2.rooms_completed >= 1 and GameState.picks[2].size() >= 1):
		await wait(0.25)
		waited += 0.25
		moved = moved or p2.global_position.distance_to(start) > 4.0
		fired = fired or p2.current_weapon.last_fire_time > fired_before
	check(moved and fired, "the CPU moves and shoots in the dungeon")
	check(rm2.rooms_completed >= 1 and p2.kills > 0,
		"the CPU clears a room on its own (%d rooms, %d kills in %.1fs)" % [rm2.rooms_completed, p2.kills, waited])
	check(GameState.picks[2].size() >= 1,
		"the CPU walks onto an upgrade after the clear (picks %s)" % str(GameState.picks[2]))
	check(GameState.picks[1].is_empty() and rm2.rooms_completed == GameState.rooms_cleared[2],
		"the CPU's clears and picks are counted for P2 only")
	# The next room loads with fresh enemies, but it takes a moment to react.
	var fired_at_pick: float = p2.current_weapon.last_fire_time
	await wait(0.3)  # the pick was at most 0.25s ago; Medium hesitates ≥ 0.6s
	check(brain._my_enemies().size() > 0, "after its pick the CPU's next room loads with enemies")
	check(p2.current_weapon.last_fire_time == fired_at_pick,
		"the CPU hesitates before fighting a new room instead of firing on the first frame")

# ── CPU opponent in the final battle (#32) ────────────────────────────────────

func _cpu_frozen_while_paused(cpu: player) -> void:
	var pause_menu: PauseMenu = get_tree().current_scene.get_node("PauseMenu")
	await press_key(KEY_ESCAPE)
	var paused_at := cpu.global_position
	var fired_at: float = cpu.current_weapon.last_fire_time
	await wait(0.6)
	check(get_tree().paused and pause_menu.paused_by == 1
		and cpu.global_position == paused_at and cpu.current_weapon.last_fire_time == fired_at,
		"pausing freezes the CPU")
	await press_key(KEY_ESCAPE)
	await wait(3.8)
	check(not get_tree().paused, "P1 resumes the final battle")

func _test_cpu_final_battle(dungeon_stats: PlayerStats) -> void:
	print("Solo final battle vs the CPU")
	GameState.time_remaining = 0.05
	await wait(0.5)
	var f1 := find_player(1)
	var f2 := find_player(2)
	if GameState.phase != GameState.Phase.FINAL_BATTLE or f1 == null or f2 == null:
		_fail("solo: the timer running out should start the final battle")
		return
	check(f2.max_health == dungeon_stats.max_health and f2.speed == dungeon_stats.speed
		and f2.kills == dungeon_stats.kills
		and is_equal_approx(f2.current_weapon.fire_rate, dungeon_stats.fire_rate)
		and f2.current_weapon.bullet_modes == dungeon_stats.bullet_modes
		and f2.shield.max_health == dungeon_stats.shield_max_health
		and is_equal_approx(f2.shield.recharge_interval, dungeon_stats.shield_recharge_interval),
		"the CPU's dungeon stats carry into the final battle (%d kills)" % f2.kills)
	var brain: CpuBrain = f2.get_node_or_null("CpuBrain")
	check(brain != null and f2.input is CpuInput
		and f1.get_node_or_null("CpuBrain") == null and f1.input is DeviceInput,
		"solo final battle: P2 gets a CpuBrain and P1 stays human")
	if brain == null:
		return
	check(brain.profile == CpuBrain.PROFILES["medium"], "the CPU uses the Medium profile")
	var hard: CpuProfile = CpuBrain.PROFILES["hard"]
	check(brain.profile.turn_rate > 0.0 and brain.profile.notice_time > 0.0
		and brain.profile.dodge_skill < 1.0
		and hard.turn_rate == 0.0 and hard.notice_time == 0.0 and hard.dodge_skill == 1.0,
		"Medium turns, notices and dodges like a human; Hard keeps the instant reflexes")
	brain.rng_seed = 32

	var start := f2.global_position
	await wait(1.0)
	check(f2.stunned and f2.global_position.distance_to(start) < 1.0 and not f2.input.is_shooting(),
		"the CPU waits out the countdown")
	while f2.stunned:
		await get_tree().physics_frame

	var grace_pos := f2.global_position
	var fired_before: float = f2.current_weapon.last_fire_time
	var moved := false
	var fired := false
	var elapsed := 0.0
	while elapsed < 3.0 and not (moved and fired):
		await wait(0.1)
		elapsed += 0.1
		moved = moved or f2.global_position.distance_to(grace_pos) > 4.0
		fired = fired or f2.current_weapon.last_fire_time > fired_before
	check(moved and fired, "the CPU moves and fires within 3s after grace (%.1fs)" % elapsed)

	await _cpu_frozen_while_paused(f2)

	# P1 shoots straight at the CPU (kept invincible so the duel doesn't end).
	# Medium ignores some bullets (dodge_skill) and sidesteps others, so allow
	# up to 16 shots and stop at the first shield.
	var shielded := false
	for i in 16:
		if shielded:
			break
		f1.invincible = true
		f1.current_weapon.fire(f1.global_position.direction_to(f2.global_position))
		for j in 5:
			await wait(0.1)
			shielded = shielded or f2.shield.is_active
	check(shielded, "the CPU raises its shield against incoming shots")
	f1.invincible = false

	# P1 stands still from here on and should lose.
	var limit := 30.0
	var waited := 0.0
	while not f1.is_dead and waited < limit:
		await wait(0.25)
		waited += 0.25
	check(f1.is_dead, "the CPU eliminates an idle P1 within %ds (took %.1fs)" % [limit, waited])
	await wait(0.3)
	var win_labels: Array = get_tree().current_scene.get_children().filter(
		func(c): return c is Label and c.text.ends_with("Wins!"))
	check(win_labels.size() == 1 and win_labels[0].text == "P2 Wins!", "the CPU winning shows 'P2 Wins!'")
	var lines := _balance_log_lines()
	var record = JSON.parse_string(lines[0]) if lines.size() == 1 else null
	check(record is Dictionary and record.get("winner") == 2.0
		and record.get("p2", {}).get("device") == "cpu"
		and record.get("p2", {}).get("difficulty") == "medium"
		and not record.get("p1", {}).has("difficulty"),
		"the balance log records the CPU's win with device 'cpu' and its difficulty")
	check(record is Dictionary and not record.get("p2", {}).get("picks", []).is_empty(),
		"the balance log has the CPU's dungeon picks")

# ── Balance log (#30) ─────────────────────────────────────────────────────────
# Kept in one block so it merges cleanly with other sections' additions.

const BALANCE_LOG_PATH := "user://balance_log_smoke.jsonl"
var _p2_pick := ""

## Sends records to a throwaway file so test runs never touch the real log.
func _balance_log_setup() -> void:
	BalanceLog.path = BALANCE_LOG_PATH
	DirAccess.remove_absolute(BALANCE_LOG_PATH)

func _balance_log_lines() -> PackedStringArray:
	if not FileAccess.file_exists(BALANCE_LOG_PATH):
		return PackedStringArray()
	return FileAccess.get_file_as_string(BALANCE_LOG_PATH).strip_edges().split("\n", false)

## P2 clears a room and takes an upgrade, so both players have picks to log.
func _balance_log_p2_pick(p2: player) -> void:
	print("Balance log: P2 picks an upgrade")
	var rm2 = room_manager_for(p2)
	await clear_room(p2)
	if rm2._offered_upgrades.is_empty():
		_fail("P2's cleared room should offer upgrades")
		return
	var pickup: Upgrade = rm2._offered_upgrades[0]
	_p2_pick = pickup.pick_id()
	await walk_onto(p2, pickup)
	check(GameState.picks[2] == [_p2_pick] and GameState.rooms_cleared[2] == 1,
		"GameState records P2's pick '%s' and room clear" % _p2_pick)

func _check_balance_log_written(p1_dungeon_kills: int) -> void:
	var lines := _balance_log_lines()
	check(lines.size() == 1, "finishing the match appends exactly one balance log line (got %d)" % lines.size())
	if lines.size() != 1:
		return
	var record = JSON.parse_string(lines[0])
	if not record is Dictionary:
		_fail("the balance log line is a JSON object")
		return
	var r1: Dictionary = record.get("p1", {})
	var r2: Dictionary = record.get("p2", {})
	var p1_picks: Array = r1.get("picks", [])
	check(record.get("winner") == 1.0 and record.get("duration_s", 0.0) > 0.0
		and record.has("time") and record.has("version"),
		"the record has winner 1, a duration, a time and a version")
	check(p1_picks.size() == 3 and p1_picks[2] in BulletUpgrade.MODES
		and p1_picks.slice(0, 2).all(func(id): return id in ["attack_rate", "speed_boost", "health_max", "shield_regen", "shield_max"]),
		"P1's picks are two stat upgrades then a bullet mode %s" % str(p1_picks))
	check(r2.get("picks", []) == [_p2_pick], "P2's picks are logged %s" % str(r2.get("picks")))
	check(r1.get("device") == "keyboard" and r2.get("device") == "joypad",
		"devices are logged as keyboard / joypad without ids")
	check(r1.get("rooms_cleared") == 3.0 and r2.get("rooms_cleared") == 1.0
		and r1.get("kills") == float(p1_dungeon_kills) and r1.has("deaths") and r2.has("deaths"),
		"rooms cleared, kills and deaths are logged")

func _check_balance_log_reset() -> void:
	check(GameState.picks[1].is_empty() and GameState.picks[2].is_empty()
		and GameState.rooms_cleared[1] == 0 and GameState.deaths[1] == 0,
		"the rematch starts with empty pick lists")

func _check_balance_log_after_quit() -> void:
	check(_balance_log_lines().size() == 1, "quitting mid-match writes no balance log line")
	DirAccess.remove_absolute(BALANCE_LOG_PATH)  # the solo match writes a fresh one

func _balance_log_teardown() -> void:
	DirAccess.remove_absolute(BALANCE_LOG_PATH)
	BalanceLog.path = "user://balance_log.jsonl"
