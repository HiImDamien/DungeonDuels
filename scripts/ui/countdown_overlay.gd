extends Control
## Full-screen grace-period countdown overlay.
## Instantiated at runtime by game.gd and final_battle.gd so it sits above
## the viewport panels and is clearly visible to both players.
## Self-destructs after the grace period clears.

var _label: Label

func _ready() -> void:
	# Cover the entire window, ignore mouse so it never blocks input.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Centre container so the box sits in the middle of the screen.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Semi-transparent dark background panel.
	var bg := PanelContainer.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_content_margin_all(16.0)
	bg.add_theme_stylebox_override("panel", style)
	center.add_child(bg)

	# Countdown label inside the panel.
	_label = Label.new()
	_label.name = "CountdownLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))  # gold
	# Show the initial count immediately so it's visible from frame one,
	# even before the first grace_tick signal fires.
	_label.text = "GAME BEGINS IN\n" + str(int(GameState.GRACE_DURATION))
	bg.add_child(_label)

	GameState.grace_tick.connect(_on_grace_tick)
	GameState.grace_ended.connect(_on_grace_ended)
	GameState.grace_cleared.connect(_on_grace_cleared)

func _on_grace_tick(seconds_left: int) -> void:
	_label.text = "GAME BEGINS IN\n" + str(seconds_left)

func _on_grace_ended() -> void:
	_label.text = "GO!"

func _on_grace_cleared() -> void:
	queue_free()
