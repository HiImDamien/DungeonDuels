class_name PauseMenu
extends CanvasLayer
## In-game pause menu. Start/Options (or Esc for P1) freezes the whole game.
##
## Rules, to keep pausing from being abused:
##  - each player has GameState.PAUSES_PER_PLAYER pauses per match
##  - only the player who paused can use the menu or resume
##  - resuming counts down 3-2-1 first, so pausing can't be used to line up a shot
##
## Add pause_menu.tscn to any gameplay scene. Set `enabled = false` when
## pausing should stop working (e.g. once someone has won).

const RESUME_COUNTDOWN := 3
const MESSAGE_TIME := 1.5

## Horizontal screen span (0–1) where each player's pause messages appear,
## so they show up on that player's own side. Defaults fit the dungeon's
## split screen; the final battle overrides them for its single arena.
@export var p1_message_span := Vector2(0.0, 0.435)
@export var p2_message_span := Vector2(0.56, 1.0)

var enabled := true
## The player who paused (1 or 2), or 0 when not paused.
var paused_by := 0

var _resuming := false
var _controls: ControlsScreen = null

@onready var _root: Control = $Root
@onready var _info: Label = $Root/Center/Panel/VBox/Info
@onready var _menu: MenuList = $Root/Center/Panel/VBox/Menu
@onready var _messages := {1: $P1Message, 2: $P2Message}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	for who in _messages:
		var span: Vector2 = p1_message_span if who == 1 else p2_message_span
		_messages[who].anchor_left = span.x
		_messages[who].anchor_right = span.y
		_messages[who].hide()
	_menu.cancelled.connect(resume)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or not enabled:
		return
	get_viewport().set_input_as_handled()
	var who := MenuList.player_for_event(event)
	if not get_tree().paused:
		try_pause(who)
	elif who == paused_by and _controls == null and not _resuming:
		resume()
	elif who != paused_by and not _resuming:
		_show_message(who, "Only P%d can resume" % paused_by)

func can_pause() -> bool:
	return enabled and not get_tree().paused and not _resuming and not GameState.is_grace

## Pauses for `who` if they have pauses left. Returns whether it paused.
func try_pause(who: int) -> bool:
	if who == 0 or not can_pause():
		return false
	if GameState.pauses_left[who] <= 0:
		_show_message(who, "No pauses left")
		return false

	GameState.pauses_left[who] -= 1
	paused_by = who
	get_tree().paused = true

	var left: int = GameState.pauses_left[who]
	_info.text = "P%d  -  %d pause%s left" % [who, left, "" if left == 1 else "s"]
	_menu.controlling_player = who
	_menu.active = true
	_menu.select(0)
	_root.show()
	return true

## Hides the menu and counts down before the game actually unpauses.
func resume() -> void:
	if not get_tree().paused or _resuming:
		return
	_resuming = true
	_root.hide()
	var overlay := CountdownOverlay.new()
	add_child(overlay)
	await overlay.count_down("RESUMING", RESUME_COUNTDOWN)
	get_tree().paused = false
	paused_by = 0
	_resuming = false

func _on_resume_pressed() -> void:
	resume()

func _on_controls_pressed() -> void:
	_controls = ControlsScreen.new()
	_controls.controlling_player = paused_by
	add_child(_controls)
	_menu.active = false
	await _controls.closed
	_controls = null
	_menu.active = true

func _on_quit_pressed() -> void:
	get_tree().paused = false
	MusicManager.stop_music()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

## Briefly shows `text` on `who`'s side of the screen.
func _show_message(who: int, text: String) -> void:
	var label: Label = _messages[who]
	label.text = text
	label.show()
	if label.has_meta("tween"):
		var old: Tween = label.get_meta("tween")
		if old.is_valid():
			old.kill()
	label.modulate.a = 1.0
	var tween := create_tween()
	label.set_meta("tween", tween)
	tween.tween_interval(MESSAGE_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.hide)
