extends Node2D

## Animated arc slash that sweeps and fades out.
## Call play(direction) to trigger. Lives on the Player, reused each swing.

var playing := false
var elapsed := 0.0

# Tunables
var duration := 0.15          # how long the full animation lasts (seconds)
var arc_angle := deg_to_rad(120.0)  # total sweep angle
var radius := 16.0            # how far from center the arc is drawn
var thickness := 2.5
var color := Color(0.85, 0.92, 1.0, 0.9)  # light blue-white

var sweep_progress := 0.0     # 0 → 1 over the animation
var base_angle := 0.0         # center angle of the slash (aim direction)

func play(direction: Vector2) -> void:
	base_angle = direction.angle()
	elapsed = 0.0
	sweep_progress = 0.0
	playing = true
	visible = true

func _process(delta: float) -> void:
	if not playing:
		return

	elapsed += delta
	sweep_progress = clampf(elapsed / duration, 0.0, 1.0)

	queue_redraw()

	if sweep_progress >= 1.0:
		playing = false
		visible = false

func _draw() -> void:
	if not playing:
		return

	var half_arc = arc_angle * 0.5
	# The arc sweeps from -half_arc to +half_arc relative to the aim direction.
	# sweep_progress controls how much of the arc has been drawn so far.
	var start_angle = base_angle - half_arc
	var end_angle = start_angle + arc_angle * sweep_progress

	# Fade out over the last 40% of the animation
	var alpha = 1.0
	if sweep_progress > 0.6:
		alpha = remap(sweep_progress, 0.6, 1.0, 1.0, 0.0)

	var draw_color = Color(color.r, color.g, color.b, color.a * alpha)

	# Draw the arc as a series of short line segments
	var segments = 12
	var angle_step = (end_angle - start_angle) / segments
	var points: PackedVector2Array = []

	for i in range(segments + 1):
		var angle = start_angle + angle_step * i
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	if points.size() >= 2:
		draw_polyline(points, draw_color, thickness, true)

		# Draw a slightly larger, more transparent arc behind for glow
		var glow_color = Color(draw_color.r, draw_color.g, draw_color.b, draw_color.a * 0.3)
		draw_polyline(points, glow_color, thickness + 2.0, true)
