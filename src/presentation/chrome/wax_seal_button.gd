class_name WaxSealButton
extends Control

signal pressed

@export var label: String = "D"
@export var enabled: bool = true
@export var caption: String = ""

var _hovered: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hovered = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		queue_redraw()
	)

func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	Chrome.draw_wax_button(self, rect, label, _hovered and enabled, enabled)
	if not caption.is_empty():
		var font := Tokens.font_ui()
		var size_text := 11
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y - 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, size_text, Tokens.INK_SECONDARY if enabled else Tokens.INK_MUTED)

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			pressed.emit()
			accept_event()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_hovered = false
	queue_redraw()
