class_name MiniHand
extends Control

## A compact stack of card backs for the Warden strip. It is a count, not a
## hand: at most four backs are drawn, never a card-sized object.

var count: int = 0
var tint: Color = Tokens.PINK

func _ready() -> void:
	custom_minimum_size = Vector2(62, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_count(value: int) -> void:
	count = maxi(0, value)
	queue_redraw()

func _draw() -> void:
	if count <= 0:
		draw_string(Tokens.font_label(), Vector2(2, size.y * 0.5 + 4), "EMPTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Tokens.INK_MUTED)
		return
	var visible := mini(count, 4)
	var back_size := Vector2(24, 34)
	var step := 8.0
	var total := back_size.x + step * float(visible - 1)
	var start := Vector2((size.x - total) * 0.5, (size.y - back_size.y) * 0.5)
	for i in range(visible):
		var rect := Rect2(start + Vector2(step * float(i), 0), back_size)
		Chrome.draw_cut_rect(self, rect, 3.0, Tokens.CARD_FACE_DEEP)
		Chrome.draw_cut_outline(self, rect, 3.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.34), 1.0)
		draw_line(rect.position + Vector2(4, rect.size.y * 0.5), rect.position + Vector2(rect.size.x - 4, rect.size.y * 0.5), Color(tint.r, tint.g, tint.b, 0.30), 1.0)
		draw_circle(rect.get_center(), 2.0, Color(tint.r, tint.g, tint.b, 0.55))
