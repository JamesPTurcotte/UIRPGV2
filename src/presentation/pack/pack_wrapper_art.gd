class_name PackWrapperArt
extends Control

## The P1 Rip & Fan wrapper: a foil pack, a tear strip, a wax seal, and the
## pack label. Procedural only; no bitmap art. The screen connects `pressed`
## to the same ceremony as the TEAR medallion.

signal pressed

var pack_name: String = "Pack"
var set_label: String = "5 cards · rare guaranteed"
var pack_no: String = "01"
var tear_progress: float = 0.0:
	set(value):
		tear_progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var open_progress: float = 0.0:
	set(value):
		open_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			pressed.emit()
			accept_event()

func _draw() -> void:
	if size.x < 40.0 or size.y < 40.0:
		return
	var pack_w := minf(size.x * 0.40, 190.0)
	var pack_h := minf(size.y * 0.58, 230.0)
	var pack := Rect2(Vector2((size.x - pack_w) * 0.5, size.y * 0.055), Vector2(pack_w, pack_h))
	var foil := Color("#160C24")
	var foil_edge := Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.72)
	var amber := Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.72)
	var cyan := Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.42)
	var font := Tokens.font_label()
	var data := Tokens.font_data()

	# Table shadow and foil body.
	draw_rect(pack.grow(8.0), Color(0.0, 0.0, 0.0, 0.34), true)
	draw_rect(pack, foil, true)
	draw_rect(pack, foil_edge, false, 2.0)
	for i in range(11):
		var x := pack.position.x + 10.0 + float(i) * (pack.size.x - 20.0) / 10.0
		draw_line(Vector2(x, pack.position.y + 28.0), Vector2(x, pack.end.y - 12.0), Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.07), 1.0)

	# Inner frame.
	var inner := pack.grow(-12.0)
	draw_rect(inner, Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.10), false, 1.0)

	# Tear strip: it shifts and lifts with tear_progress.
	var strip_y := pack.position.y + 20.0 + tear_progress * 26.0
	var strip_x := pack.position.x - tear_progress * 30.0
	var strip := Rect2(Vector2(strip_x, strip_y), Vector2(pack.size.x, 10.0))
	draw_rect(strip, Color("#2A1538"), true)
	draw_line(Vector2(strip.position.x, strip.position.y), Vector2(strip.end.x, strip.position.y), amber, 1.0)
	for i in range(13):
		var dx := strip.position.x + 8.0 + float(i) * (strip.size.x - 16.0) / 12.0
		draw_line(Vector2(dx, strip.position.y), Vector2(dx + 5.0, strip.position.y - 4.0), amber, 1.0)

	# Pack number and label.
	draw_string(font, pack.position + Vector2(12.0, 15.0), "PACK %s" % pack_no, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Tokens.INK_SECONDARY)
	draw_string(font, pack.position + Vector2(12.0, pack.size.y - 30.0), pack_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tokens.PINK)
	draw_string(data, pack.position + Vector2(12.0, pack.size.y - 12.0), set_label.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Tokens.INK_MUTED)

	# Wax seal.
	var seal_center := pack.position + Vector2(pack.size.x * 0.5, pack.size.y * 0.47)
	draw_circle(seal_center, 31.0, Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.08))
	draw_arc(seal_center, 31.0, 0.0, TAU, 48, Tokens.PINK, 2.0, true)
	draw_arc(seal_center, 23.0, 0.0, TAU, 40, Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.30), 1.0, true)
	draw_string(font, seal_center + Vector2(-6.0, 7.0), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Tokens.PINK)

	# Light spill and the open mouth once the tear starts.
	if open_progress > 0.0:
		draw_rect(pack.grow(24.0), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.06 * open_progress), true)
	if tear_progress > 0.0:
		var mouth := Rect2(Vector2(pack.position.x + 14.0, pack.position.y + 34.0), Vector2(pack.size.x - 28.0, 8.0 + tear_progress * 18.0))
		draw_rect(mouth, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.12 * tear_progress), true)
		draw_line(Vector2(mouth.position.x, mouth.position.y), Vector2(mouth.end.x, mouth.position.y), cyan, 1.0)
