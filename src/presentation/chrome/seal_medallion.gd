class_name SealMedallion
extends Control

## The shared primary-action seal. Action mode is a play button: a recessed
## brass medallion with a play glyph and a verb caption. Identity mode is a
## mark only (no pointer, no glyph) and is used by decorative seals.

signal pressed

@export var mode: String = "action"
@export var caption: String = ""
@export var accent: Color = Tokens.BRASS_HI
@export var enabled: bool = true

var _hovered: bool = false
var _down: bool = false
var _pulse: float = 0.0

func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(112, 112)
	focus_mode = Control.FOCUS_ALL if mode == "action" else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if mode == "action" else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if mode == "action" else Control.CURSOR_ARROW
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	var target := 1.0 if _hovered and enabled and mode == "action" else 0.0
	if not is_equal_approx(_pulse, target):
		_pulse = move_toward(_pulse, target, delta * 8.0)
		queue_redraw()

func _draw() -> void:
	var diameter := minf(size.x, size.y - 20.0)
	var center := Vector2(size.x * 0.5, diameter * 0.5 + 2.0)
	var radius := diameter * 0.46
	var lift := -2.0 * _pulse
	center.y += lift
	var ring_color := accent if enabled else Tokens.INK_MUTED
	var fill := Tokens.BG_LACQUER
	if _down and enabled:
		fill = Tokens.BG_VOID
		center.y += 2.0
	# Recessed well.
	draw_circle(center + Vector2(0, 3), radius * 1.10, Tokens.SHADOW_DEEP)
	draw_circle(center, radius * 1.10, Tokens.BG_VOID)
	draw_arc(center, radius * 1.10, 0.0, TAU, 56, Tokens.BRASS_LO * Color(1, 1, 1, 0.7), 1.0, true)
	# Medallion.
	draw_circle(center, radius, fill)
	draw_circle(center, radius * 0.97, Tokens.BG_PANEL)
	draw_arc(center, radius * 0.97, 0.0, TAU, 56, ring_color, maxf(1.0, radius * 0.035), true)
	draw_arc(center, radius * 0.84, 0.0, TAU, 48, ring_color * Color(1, 1, 1, 0.30), 1.0, true)
	# Deterministic ticks around the rim; reads as a struck medallion, not a picture.
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		var start := center + Vector2(cos(angle), sin(angle)) * radius * 0.88
		var finish := center + Vector2(cos(angle), sin(angle)) * radius * 0.94
		draw_line(start, finish, ring_color * Color(1, 1, 1, 0.28), 1.0, true)
	if mode == "action":
		Chrome.draw_play_glyph(self, center + Vector2(radius * 0.05, 0), radius * 0.40, ring_color if enabled else Tokens.INK_MUTED)
	else:
		# Identity mode: a quiet lineage diamond, not a play affordance.
		var r := radius * 0.22
		var diamond := PackedVector2Array([
			center + Vector2(0, -r), center + Vector2(r, 0),
			center + Vector2(0, r), center + Vector2(-r, 0),
		])
		draw_colored_polygon(diamond, Tokens.BG_VOID)
		var closed := diamond.duplicate()
		closed.append(diamond[0])
		draw_polyline(closed, ring_color, maxf(1.0, radius * 0.03), true)
	if not caption.is_empty():
		var font := Tokens.font_ui()
		var text_size := 11
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y - 3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Tokens.INK_SECONDARY if enabled else Tokens.INK_MUTED)

func _gui_input(event: InputEvent) -> void:
	if mode != "action" or not enabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_down = true
				queue_redraw()
			else:
				if _down:
					_down = false
					queue_redraw()
					pressed.emit()
				accept_event()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			pressed.emit()
			accept_event()

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	_down = false
	queue_redraw()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_hovered = false
		_down = false
	queue_redraw()

func pulse() -> void:
	_pulse = 1.0
	queue_redraw()
