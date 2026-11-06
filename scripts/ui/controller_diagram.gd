class_name ControllerDiagram
extends Control
## A gamepad drawn with simple shapes, with a callout for every action in
## InputLabels.ROWS pointing at the stick/trigger/button it's bound to.
## Everything is read from the Input Map, so remapping updates the picture.

const FONT := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8.ttf")
const FONT_BOLD := preload("res://assets/brackeys_platformer_assets/fonts/PixelOperator8-Bold.ttf")
const FONT_SIZE := 8

const BODY := Color(0.30, 0.31, 0.38)
const DETAIL := Color(0.18, 0.18, 0.23)
const TRIGGER := Color(0.42, 0.43, 0.52)
const LINE := Color(1.0, 0.85, 0.2)      # gold, like the other UI highlights
const ACTION_TEXT := Color.WHITE
const INPUT_TEXT := Color(0.7, 0.7, 0.75)

## Drawing is laid out for this size; the node is scaled to fit anything else.
const DESIGN_SIZE := Vector2(365, 100)
const CENTER_X := 182.0

# Where each physical input sits on the drawing, relative to (CENTER_X, 0).
const INPUT_POSITIONS := {
	"lt": Vector2(-31, 16), "rt": Vector2(31, 16),
	"lb": Vector2(-31, 24), "rb": Vector2(31, 24),
	"left_stick": Vector2(-26, 42), "right_stick": Vector2(14, 58),
	"back": Vector2(-8, 36), "start": Vector2(8, 36),
	"y": Vector2(26, 36), "x": Vector2(20, 42), "b": Vector2(32, 42), "a": Vector2(26, 48),
}
const LEFT_SIDE := ["lt", "lb", "left_stick", "back"]
const LABEL_GAP := 64.0     # distance from the pad's centre to the label column
const LABEL_TOP := 6.0
const LABEL_BOTTOM := 90.0

func _draw() -> void:
	var s := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	draw_set_transform(Vector2((size.x - DESIGN_SIZE.x * s) / 2, 0), 0, Vector2(s, s))
	# Leader lines go between the body and the buttons so they tuck under
	# the sticks and face buttons instead of crossing over them.
	_draw_body()
	var targets := _draw_callouts()
	_draw_details()
	for target in targets:
		draw_circle(target, 1.5, LINE)

func _p(offset: Vector2) -> Vector2:
	return Vector2(CENTER_X, 0) + offset

func _draw_body() -> void:
	# Triggers and bumpers peek out behind the body.
	draw_rect(Rect2(_p(Vector2(-42, 12)), Vector2(22, 8)), TRIGGER)
	draw_rect(Rect2(_p(Vector2(20, 12)), Vector2(22, 8)), TRIGGER)
	# Body: a bar with rounded shoulders and two grips.
	draw_rect(Rect2(_p(Vector2(-42, 26)), Vector2(84, 30)), BODY)
	for x in [-34, 34]:
		draw_circle(_p(Vector2(x, 34)), 12, BODY)
		draw_circle(_p(Vector2(x, 60)), 13, BODY)

func _draw_details() -> void:
	# Sticks
	for key in ["left_stick", "right_stick"]:
		draw_circle(_p(INPUT_POSITIONS[key]), 6, DETAIL)
		draw_circle(_p(INPUT_POSITIONS[key]), 4, TRIGGER)
	# D-pad
	draw_rect(Rect2(_p(Vector2(-17, 52)), Vector2(4, 12)), DETAIL)
	draw_rect(Rect2(_p(Vector2(-21, 56)), Vector2(12, 4)), DETAIL)
	# View / Start
	draw_circle(_p(INPUT_POSITIONS["back"]), 2, DETAIL)
	draw_circle(_p(INPUT_POSITIONS["start"]), 2, DETAIL)
	# Face buttons in Xbox colours (A green, B red, X blue, Y yellow).
	var face := {"a": Color(0.3, 0.8, 0.3), "b": Color(0.9, 0.3, 0.3),
		"x": Color(0.3, 0.5, 0.95), "y": Color(0.95, 0.85, 0.3)}
	for key in face:
		draw_circle(_p(INPUT_POSITIONS[key]), 3, face[key])

## Draws labels and leader lines; returns the points the lines end at.
func _draw_callouts() -> Array[Vector2]:
	var left: Array = []
	var right: Array = []
	for row in InputLabels.ROWS:
		var id := InputLabels.controller_id(row[1][0])
		if not INPUT_POSITIONS.has(id):
			continue
		var callout := [row[0], InputLabels.controller_label(row[1][0]), _p(INPUT_POSITIONS[id])]
		(left if id in LEFT_SIDE else right).append(callout)
	_draw_column(left, -1)
	_draw_column(right, 1)
	var targets: Array[Vector2] = []
	for callout in left + right:
		targets.append(callout[2])
	return targets

## Spreads a side's labels evenly down the column (ordered by where their
## input sits on the pad) and draws a leader line to each.
func _draw_column(callouts: Array, side: int) -> void:
	if callouts.is_empty():
		return
	callouts.sort_custom(func(a, b): return a[2].y < b[2].y)
	var step := (LABEL_BOTTOM - LABEL_TOP) / callouts.size()
	var label_x := CENTER_X + side * LABEL_GAP
	for i in callouts.size():
		var action: String = callouts[i][0]
		var input: String = callouts[i][1]
		var target: Vector2 = callouts[i][2]
		var y := LABEL_TOP + step * (i + 0.5)
		var elbow := Vector2(label_x - side * 8, y)
		draw_polyline([target, Vector2(target.x + side * 4, y), elbow], LINE, 1.0)
		var align := HORIZONTAL_ALIGNMENT_LEFT if side > 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var box_x := label_x if side > 0 else label_x - 110
		draw_string(FONT_BOLD, Vector2(box_x, y - 1), action, align, 110, FONT_SIZE, ACTION_TEXT)
		draw_string(FONT, Vector2(box_x, y + 8), input, align, 110, FONT_SIZE, INPUT_TEXT)
