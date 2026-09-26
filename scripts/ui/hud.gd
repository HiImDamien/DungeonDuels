extends Control

@export var full_heart: Texture2D
@export var empty_heart: Texture2D

@onready var timer_label  = $VBoxContainer/DividerCenter/DividerVBox/TimerLabel
@onready var status_label = $VBoxContainer/DividerCenter/DividerVBox/StatusLabel

# action_prefix → the HUD panel ("P1"/"P2") that shows that player's stats.
const PANELS := {"": "P1", "p2_": "P2"}

func _ready() -> void:
	for panel_name in PANELS.values():
		_panel_node(panel_name, "TitleLabel").text = panel_name.insert(1, "-")

	GameState.timer_tick.connect(_on_timer_tick)
	GameState.timer_expired.connect(_on_timer_expired)
	timer_label.text  = str(int(GameState.MATCH_DURATION))
	status_label.text = ""

	_connect_players.call_deferred()

# ── Timer / status display ────────────────────────────────────────────────────

func _on_timer_tick(seconds_left: int) -> void:
	timer_label.text = str(seconds_left)
	# Turn red in the final 10 seconds
	if seconds_left <= 10:
		timer_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	else:
		timer_label.remove_theme_color_override("font_color")

func _on_timer_expired() -> void:
	timer_label.text  = "0"
	status_label.text = "FINAL!"

# ── Player connection ─────────────────────────────────────────────────────────

func _panel_node(panel_name: String, suffix: String) -> Node:
	return get_node("VBoxContainer/%sCenter/%sVBox/%s%s" % [panel_name, panel_name, panel_name, suffix])

func _connect_players() -> void:
	await get_tree().process_frame
	for p: player in get_tree().get_nodes_in_group("player"):
		_connect_player(p, PANELS[p.action_prefix])

func _connect_player(p: player, panel_name: String) -> void:
	var hearts: HBoxContainer = _panel_node(panel_name, "Hearts")
	var kills_label: Label = _panel_node(panel_name, "KillsLabel")
	var shield_label: Label = _panel_node(panel_name, "ShieldLabel")

	var on_stats := func(health: int, max_health: int, kills: int) -> void:
		draw_hearts(hearts, health, max_health)
		kills_label.text = "K:" + str(kills)
	var on_shield := func(shield_health: int) -> void:
		shield_label.text = "S:" + str(shield_health)

	p.stats_changed.connect(on_stats)
	p.shield.shield_changed.connect(on_shield)
	on_stats.call(p.health, p.max_health, p.kills)
	on_shield.call(p.shield.health)

# ── Final-battle mode ─────────────────────────────────────────────────────────
# Call this once after the HUD is ready to strip the timer from the display.
# The final battle has no countdown, so the whole divider section is hidden.

func hide_timer() -> void:
	$VBoxContainer/DividerCenter.hide()
	if GameState.timer_tick.is_connected(_on_timer_tick):
		GameState.timer_tick.disconnect(_on_timer_tick)
	if GameState.timer_expired.is_connected(_on_timer_expired):
		GameState.timer_expired.disconnect(_on_timer_expired)

# ── helpers ───────────────────────────────────────────────────────────────────

func draw_hearts(container: HBoxContainer, health: int, max_health: int) -> void:
	# Immediate removal (not queue_free) so the layout reflows in the same frame
	# and the container resizes before new hearts are added.
	for child in container.get_children():
		child.free()
	# Shrink-centre so the HBoxContainer wraps its content and stays centred
	# inside the parent CenterContainer regardless of heart count.
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in range(max_health):
		var heart = TextureRect.new()
		heart.texture = full_heart if i < health else empty_heart
		heart.custom_minimum_size = Vector2(5, 5)
		container.add_child(heart)
