class_name DeckDropHint
extends Control

## A non-interactive border that shows the current drop target during a drag.

var active_rect: Rect2 = Rect2()
var valid: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_target(rect: Rect2, is_valid: bool = true) -> void:
	active_rect = rect
	valid = is_valid
	queue_redraw()

func clear() -> void:
	active_rect = Rect2()
	valid = true
	queue_redraw()

func _draw() -> void:
	if active_rect.size.x <= 0 or active_rect.size.y <= 0:
		return
	var color := Tokens.BRASS_HI if valid else Tokens.DANGER
	draw_rect(active_rect, color * Color(1, 1, 1, 0.06))
	draw_rect(active_rect, color, false, 2.0)
