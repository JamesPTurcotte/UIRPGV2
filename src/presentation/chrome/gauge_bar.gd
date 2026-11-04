class_name GaugeBar
extends Control

var value: int = 0
var maximum: int = 100
var label: String = ""
var color: Color = Tokens.BRASS
var show_numbers: bool = true
var compact: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(120, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_value(new_value: int, new_maximum: int = -1) -> void:
	value = new_value
	if new_maximum >= 0:
		maximum = new_maximum
	queue_redraw()

func _draw() -> void:
	var bar_height := 6.0 if compact else 10.0
	var bar_rect := Rect2(0, (size.y - bar_height) * 0.5, size.x, bar_height)
	Chrome.draw_gauge(self, bar_rect, value, maximum, color, Tokens.BG_VOID * Color(1, 1, 1, 0.5))
	if not label.is_empty():
		draw_string(Tokens.font_ui(), Vector2(0, size.y - 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Tokens.INK_MUTED)
	if show_numbers:
		var text := "%d / %d" % [value, maximum]
		var width := Tokens.font_data().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(Tokens.font_data(), Vector2(size.x - width, size.y - 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Tokens.INK_SECONDARY)
