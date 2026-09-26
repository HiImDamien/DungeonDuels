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
const TOAST_TIME := 1.5

var enabled := true
## The player who paused (1 or 2), or 0 when not paused.
var paused_by := 0

var _resuming := false
var _controls: ControlsScreen = null

@onready var _root: Control = $Root
@onready var _info: Label = $Root/Center/Panel/VBox/Info
@onready var _menu: MenuList = $Root/Center/Panel/VBox/Menu
@onready var _toast: Label = $Toast

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_toast.hide()
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
		_show_toast("Only P%d can resume" % paused_by)

func can_pause() -> bool:
	return enabled and not get_tree().paused and not _resuming and not GameState.is_grace

## Pauses for `who` if they have pauses left. Returns whether it paused.
func try_pause(who: int) -> bool:
	if who == 0 or not can_pause():
		return false
	if GameState.pauses_left[who] <= 0:
		_show_toast("P%d has no pauses left" % who)
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

func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.show()
	if _toast.has_meta("tween"):
		var old: Tween = _toast.get_meta("tween")
		if old.is_valid():
			old.kill()
	_toast.modulate.a = 1.0
	var tween := create_tween()
	_toast.set_meta("tween", tween)
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_toast.hide)
