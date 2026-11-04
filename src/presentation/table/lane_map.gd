class_name LaneMap
extends Control

## Three lane diamonds. The lit lane is the Warden's next target.

var lit_lane: int = -1
var tone: Color = Tokens.PINK

func _ready() -> void:
	custom_minimum_size = Vector2(0, 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_lane(lane: int, color: Color = Tokens.PINK) -> void:
	lit_lane = lane
	tone = color
	queue_redraw()

func _draw() -> void:
	var gap := 12.0
	var step := minf(46.0, (size.x + gap) / 3.0)
	var start := (size.x - (step * 3.0 - gap)) * 0.5
	for i in range(3):
		var center := Vector2(start + step * (float(i) + 0.5) - gap * 0.5, size.y * 0.5)
		var lit := i == lit_lane
		var radius := 5.0 if lit else 3.5
		var color := tone if lit else Tokens.INK_MUTED * Color(1, 1, 1, 0.45)
		var points := PackedVector2Array([
			center + Vector2(0, -radius),
			center + Vector2(radius, 0),
			center + Vector2(0, radius),
			center + Vector2(-radius, 0),
		])
		draw_colored_polygon(points, color)
		if lit:
			draw_arc(center, radius + 4.0, 0.0, TAU, 20, Color(tone.r, tone.g, tone.b, 0.30), 1.0, true)
