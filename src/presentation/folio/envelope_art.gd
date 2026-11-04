class_name FolioEnvelopeArt
extends Control

## The physical envelope behind the folio labels: flap creases, a string, and
## a deckled paper edge. No bitmap and no depicted subject.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < 20 or rect.size.y < 20:
		return
	# Flap.
	var center := Vector2(rect.size.x * 0.5, rect.size.y * 0.43)
	var crease := Color(0.48, 0.42, 0.34, 0.20)
	draw_line(Vector2(rect.size.x * 0.04, rect.size.y * 0.04), center, crease, 1.0, true)
	draw_line(Vector2(rect.size.x * 0.96, rect.size.y * 0.04), center, crease, 1.0, true)
	draw_line(Vector2(rect.size.x * 0.04, rect.size.y * 0.96), center, crease * Color(1, 1, 1, 0.6), 1.0, true)
	draw_line(Vector2(rect.size.x * 0.96, rect.size.y * 0.96), center, crease * Color(1, 1, 1, 0.6), 1.0, true)
	# String / ribbon.
	var string_y := rect.size.y * 0.71
	draw_line(Vector2(rect.size.x * 0.08, string_y), Vector2(rect.size.x * 0.92, string_y), Color("#8E2F2F") * Color(1, 1, 1, 0.55), 1.0, true)
	draw_line(Vector2(rect.size.x * 0.08, string_y + 3), Vector2(rect.size.x * 0.92, string_y + 3), Color("#8E2F2F") * Color(1, 1, 1, 0.25), 1.0, true)
	# Deckled edge ticks.
	for i in range(int(rect.size.x / 12.0)):
		var x := 8.0 + float(i) * 12.0
		draw_line(Vector2(x, 1), Vector2(x + 3.0, 3.0), Color(0.35, 0.28, 0.18, 0.18), 1.0)
		draw_line(Vector2(x, rect.size.y - 1), Vector2(x + 3.0, rect.size.y - 3.0), Color(0.35, 0.28, 0.18, 0.18), 1.0)
