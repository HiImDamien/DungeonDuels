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
		and InputLabels.keyboard_label(["shoot"]) == "Arrow Keys",
		"keyboard labels come from the input map")
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

# ── The test ──────────────────────────────────────────────────────────────────

func _run() -> void:
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

	var regen: Upgrade = load("res://scenes/upgrades/shield_regen.tscn").instantiate()
	var cooldown := p1.shield.cooldown_time
	regen.apply(p1)
	check(p1.shield.cooldown_time < cooldown
		and is_equal_approx(p1.shield.cooldown_timer.wait_time, p1.shield.cooldown_time),
		"shield regen upgrade updates the shield's timers immediately")
	regen.free()

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

	print("Final battle")
	var kills := p1.kills
	var modes: Array[String] = p1.current_weapon.bullet_modes.duplicate()
	var speed := p1.speed
	var shield_max := p1.shield.max_health
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

	_finish()
