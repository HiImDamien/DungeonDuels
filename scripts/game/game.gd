extends Control

func _ready() -> void:
	var overlay := preload("res://scripts/ui/grace_overlay.gd").new()
	add_child(overlay)
	GameState.start_match_timer()
	GameState.start_grace_period()
	GameState.timer_expired.connect(_on_timer_expired, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	GameState.tick(delta)

# ── Timer expired → transition to Final Battle ────────────────────────────────

func _on_timer_expired() -> void:
	# Snapshot player stats so the final battle can restore them
	var players = get_tree().get_nodes_in_group("player")
	var p1: CharacterBody2D = null
	var p2: CharacterBody2D = null
	for p in players:
		if p.action_prefix == "":
			p1 = p
		elif p.action_prefix == "p2_":
			p2 = p
	if p1 and p2:
		GameState.save_player_stats(p1, p2)

	get_tree().change_scene_to_file("res://scenes/game/final_battle.tscn")
