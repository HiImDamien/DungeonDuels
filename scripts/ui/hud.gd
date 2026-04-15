extends Control

@export var full_heart: Texture2D
@export var empty_heart: Texture2D

@onready var p1_title_label  = $VBoxContainer/P1Center/P1VBox/P1TitleLabel
@onready var p1_hearts       = $VBoxContainer/P1Center/P1VBox/P1Hearts
@onready var p1_kills_label  = $VBoxContainer/P1Center/P1VBox/P1KillsLabel
@onready var p1_shield_label = $VBoxContainer/P1Center/P1VBox/P1ShieldLabel
@onready var timer_label     = $VBoxContainer/DividerCenter/DividerVBox/TimerLabel
@onready var status_label    = $VBoxContainer/DividerCenter/DividerVBox/StatusLabel
@onready var p2_title_label  = $VBoxContainer/P2Center/P2VBox/P2TitleLabel
@onready var p2_hearts       = $VBoxContainer/P2Center/P2VBox/P2Hearts
@onready var p2_kills_label  = $VBoxContainer/P2Center/P2VBox/P2KillsLabel
@onready var p2_shield_label = $VBoxContainer/P2Center/P2VBox/P2ShieldLabel

var p1: CharacterBody2D = null
var p1_shield               = null
var p2: CharacterBody2D = null
var p2_shield               = null

func _ready() -> void:
	p1_title_label.text = "P-1"
	p2_title_label.text = "P-2"

	# Connect to GameState signals for timer and grace period
	GameState.timer_tick.connect(_on_timer_tick)
	GameState.timer_expired.connect(_on_timer_expired)
	GameState.grace_tick.connect(_on_grace_tick)
	GameState.grace_ended.connect(_on_grace_ended)
	GameState.grace_cleared.connect(_on_grace_cleared)

	# Show initial timer value; grace_tick will fill in the countdown immediately
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

func _on_grace_tick(seconds_left: int) -> void:
	status_label.text = str(seconds_left)

func _on_grace_ended() -> void:
	status_label.text = "BEGIN!"

func _on_grace_cleared() -> void:
	status_label.text = ""

# ── Player connection ─────────────────────────────────────────────────────────

func _connect_players() -> void:
	await get_tree().process_frame

	for player_instance in get_tree().get_nodes_in_group("player"):
		if player_instance.action_prefix == "":
			p1 = player_instance
		elif player_instance.action_prefix == "p2_":
			p2 = player_instance

	_connect_p1()
	_connect_p2()

func _connect_p1() -> void:
	if p1:
		p1.stats_changed.connect(_on_p1_stats_changed)
		_on_p1_stats_changed(p1.health, p1.max_health, p1.kills)

		p1_shield = p1.get_node_or_null("Shield")
		if p1_shield:
			p1_shield.shield_changed.connect(_on_p1_shield_changed)
			_on_p1_shield_changed(p1_shield.health)
		else:
			p1_shield_label.text = "S:-"
	else:
		push_warning("HUD: P1 not found in 'player' group")
		draw_hearts(p1_hearts, 0, 5)
		p1_kills_label.text  = "K:-"
		p1_shield_label.text = "S:-"

func _connect_p2() -> void:
	if p2:
		p2.stats_changed.connect(_on_p2_stats_changed)
		_on_p2_stats_changed(p2.health, p2.max_health, p2.kills)

		p2_shield = p2.get_node_or_null("Shield")
		if p2_shield:
			p2_shield.shield_changed.connect(_on_p2_shield_changed)
			_on_p2_shield_changed(p2_shield.health)
		else:
			p2_shield_label.text = "S:-"
	else:
		push_warning("HUD: P2 not found in 'player' group")
		draw_hearts(p2_hearts, 0, 5)
		p2_kills_label.text  = "K:-"
		p2_shield_label.text = "S:-"

# ── stat signal handlers ──────────────────────────────────────────────────────

func _on_p1_stats_changed(health: int, max_health: int, kills: int) -> void:
	draw_hearts(p1_hearts, health, max_health)
	p1_kills_label.text = "K:" + str(kills)

func _on_p1_shield_changed(shield_health: int) -> void:
	p1_shield_label.text = "S:" + str(shield_health)

func _on_p2_stats_changed(health: int, max_health: int, kills: int) -> void:
	draw_hearts(p2_hearts, health, max_health)
	p2_kills_label.text = "K:" + str(kills)

func _on_p2_shield_changed(shield_health: int) -> void:
	p2_shield_label.text = "S:" + str(shield_health)

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
