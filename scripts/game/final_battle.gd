extends Control

const P1_SPAWN := Vector2(80, 100)
const P2_SPAWN := Vector2(220, 100)
const P2_BULLET_COLOR := Color(1.0, 0.25, 0.25)
const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")

@onready var world: Node2D = $HBoxContainer/BattlePanel/SubViewportContainer/SubViewport/FinalBattleWorld
@onready var _hud: Control  = $HBoxContainer/CenterPanel/HUD

var _game_over: bool = false

func _ready() -> void:
	GameState.phase = GameState.Phase.FINAL_BATTLE
	_hud.hide_timer()
	_spawn_players()
	add_child(preload("res://scripts/ui/grace_overlay.gd").new())
	GameState.start_grace_period.call_deferred()

func _spawn_players() -> void:
	_spawn_player("", P1_SPAWN)
	var p2 := _spawn_player("p2_", P2_SPAWN)
	p2.current_weapon.bullet_color = P2_BULLET_COLOR

func _spawn_player(prefix: String, spawn: Vector2) -> player:
	var p: player = PLAYER_SCENE.instantiate()
	p.action_prefix = prefix
	world.add_child(p)
	p.position = spawn
	GameState.stats_for(p).apply_to(p)
	p.eliminated.connect(_on_player_eliminated.bind(p))
	return p

func _on_player_eliminated(loser: CharacterBody2D) -> void:
	_game_over = true
	var winner_label := "P2 Wins!" if loser.action_prefix == "" else "P1 Wins!"
	_show_winner(winner_label)

func _show_winner(text: String) -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)

	var hint := Label.new()
	hint.text = "Press  Y / △  to return to menu"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.offset_bottom = -8
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 1.0))
	add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not _game_over:
		return
	var pressed_y: bool = (
		event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_Y
	)
	var pressed_esc: bool = (
		event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ESCAPE
	)
	if pressed_y or pressed_esc:
		MusicManager.stop_music()
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")