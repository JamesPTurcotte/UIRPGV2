class_name WardenSeal
extends Control

## The Warden's mark: a seal, not a portrait. Concentric rings, a tick ring,
## and one umbra glyph. It breathes unless reduced motion is on.

var tone: Color = Tokens.PURPLE
var _time: float = 0.0
var _motion: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion = not bool(Session.settings.get("reduced_motion", false))
	set_process(_motion)

func set_tone(color: Color) -> void:
	tone = color
	queue_redraw()

func _process(delta: float) -> void:
	if not _motion:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	var pulse := 0.5 + 0.5 * sin(_time * 1.35)
	var halo := Color(tone.r, tone.g, tone.b, 0.05 + pulse * 0.035)
	draw_circle(center, radius * 1.28, halo)
	draw_arc(center, radius * 1.06, 0.0, TAU, 48, Color(tone.r, tone.g, tone.b, 0.22), 1.0, true)
	draw_arc(center, radius * 0.94, 0.0, TAU, 48, Tokens.CYAN * Color(1, 1, 1, 0.38), 1.0, true)
	draw_circle(center, radius * 0.78, Tokens.BG_VOID * Color(1, 1, 1, 0.78))

	for i in range(20):
		var angle := TAU * float(i) / 20.0
		var direction := Vector2(cos(angle), sin(angle))
		var length := radius * (0.16 if i % 5 == 0 else 0.08)
		draw_line(center + direction * radius * 1.13, center + direction * (radius * 1.13 + length), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.34), 1.0, true)

	Chrome.draw_attribute_sigil(self, center, radius * 0.52, "umbra", tone, Tokens.BG_VOID)
	Chrome.draw_corner_brackets(self, Rect2(Vector2.ZERO, size).grow(-2.0), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.24), 6.0)
