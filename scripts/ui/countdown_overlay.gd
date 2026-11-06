class_name CountdownOverlay
extends Control
## Full-screen countdown box ("GAME BEGINS IN 3", "GO!") that sits above the
## viewport panels so both players can see it. Used for the start-of-round
## grace period and for resuming from pause.

const GO_LINGER := 0.6  # how long "GO!" stays up after a countdown

var _label: Label

func _ready() -> void:
	# Cover the entire window, ignore mouse so it never blocks input.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var bg := PanelContainer.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_content_margin_all(16.0)
	bg.add_theme_stylebox_override("panel", style)
	center.add_child(bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))  # gold
	bg.add_child(_label)

## Mirror GameState's grace period, then free once it has cleared.
func follow_grace_period() -> void:
	_label.text = "GAME BEGINS IN\n" + str(int(GameState.GRACE_DURATION))
	GameState.grace_tick.connect(_on_grace_tick)
	GameState.grace_ended.connect(_on_grace_ended)
	GameState.grace_cleared.connect(queue_free)

func _on_grace_tick(seconds_left: int) -> void:
	_label.text = "GAME BEGINS IN\n" + str(seconds_left)

func _on_grace_ended() -> void:
	_label.text = "GO!"

## Counts down from `seconds` under `heading`, shows "GO!", and returns as the
## "GO!" appears. Frees itself shortly after. Keeps counting while the game is
## paused, so it can be used to resume.
func count_down(heading: String, seconds: int) -> void:
	for i in range(seconds, 0, -1):
		_label.text = "%s\n%d" % [heading, i]
		await get_tree().create_timer(1.0, true).timeout
	_label.text = "GO!"
	get_tree().create_timer(GO_LINGER, true).timeout.connect(queue_free)
