extends Control
## Full-screen grace-period countdown overlay.
## Instantiated at runtime by game.gd and final_battle.gd so it sits above
## the viewport panels and is clearly visible to both players.
## Self-destructs after the grace period clears.

func _ready() -> void:
	# Cover the entire window, ignore mouse so it never blocks input.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.name = "CountdownLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))  # gold
	# Show the initial count immediately so it's visible from frame one,
	# even before the first grace_tick signal fires.
	label.text = "GAME BEGINS IN\n" + str(int(GameState.GRACE_DURATION))
	add_child(label)

	GameState.grace_tick.connect(_on_grace_tick)
	GameState.grace_ended.connect(_on_grace_ended)
	GameState.grace_cleared.connect(_on_grace_cleared)

func _on_grace_tick(seconds_left: int) -> void:
	$CountdownLabel.text = "GAME BEGINS IN\n" + str(seconds_left)

func _on_grace_ended() -> void:
	$CountdownLabel.text = "GO!"

func _on_grace_cleared() -> void:
	queue_free()
