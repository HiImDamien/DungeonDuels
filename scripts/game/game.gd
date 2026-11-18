extends Control

@onready var p1_opponent_ticker: Label = $HBoxContainer/LeftPanel/LeftSubViewportContainer/P1OpponentTicker
@onready var p2_opponent_ticker: Label = $HBoxContainer/RightPanel/RightSubViewportContainer/P2OpponentTicker

func _ready() -> void:
	MusicManager.play_game_music()
	var overlay := CountdownOverlay.new()
	add_child(overlay)
	overlay.follow_grace_period()
	# Resets phase, stats and timer so a rematch from the title screen starts clean.
	GameState.start_match()
	GameState.timer_expired.connect(_on_timer_expired, CONNECT_ONE_SHOT)

	# Opponent ticker — overlays the top of each player's viewport
	p1_opponent_ticker.modulate.a = 0.0
	p2_opponent_ticker.modulate.a = 0.0
	GameState.opponent_event.connect(_on_opponent_event)

func _process(delta: float) -> void:
	GameState.tick(delta)
	# tick() can end the dungeon and change scene, taking this node out of the tree.
	if is_inside_tree():
		_count_deaths()

# ── Dungeon deaths (balance log) ──────────────────────────────────────────────

# Player index → whether that player was dead last frame.
var _was_dead := {}

## Counts each moment a player goes from alive to dead. Watching is_dead keeps
## player.gd untouched; a `died` signal there would be the tidier long-term hook.
func _count_deaths() -> void:
	for p: player in get_tree().get_nodes_in_group("player"):
		if p.is_dead and not _was_dead.get(p.player_index, false):
			GameState.record_death(p.player_index)
		_was_dead[p.player_index] = p.is_dead

# ── Timer expired → transition to Final Battle ────────────────────────────────

func _on_timer_expired() -> void:
	# Snapshot player stats so the final battle can restore them
	GameState.save_player_stats(get_tree().get_nodes_in_group("player"))
	get_tree().change_scene_to_file("res://scenes/game/final_battle.tscn")

# ── Opponent ticker ───────────────────────────────────────────────────────────

func _on_opponent_event(from_player: int, message: String) -> void:
	# Show the message on the OPPOSITE player's screen.
	if from_player == 1:
		_flash_ticker(p2_opponent_ticker, message)
	else:
		_flash_ticker(p1_opponent_ticker, message)

func _flash_ticker(label: Label, message: String) -> void:
	label.text = message
	if label.has_meta("tween"):
		var prev: Tween = label.get_meta("tween")
		if prev and prev.is_valid():
			prev.kill()
	var tw := create_tween()
	label.set_meta("tween", tw)
	tw.tween_property(label, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
