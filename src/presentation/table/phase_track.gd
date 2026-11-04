class_name PhaseTrack
extends Control

## The six-phase rail. A segment warms and sweeps; it is not a row of buttons.

const SHORT_LABELS := {
	"dawn": "DAWN",
	"draw": "DRAW",
	"call": "CALL",
	"actions": "ACT",
	"clash": "CLASH",
	"dusk": "DUSK",
}

var current_phase: String = "dawn"
var active_player: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(300, 28)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_phase(phase: String, player: int = 0) -> void:
	current_phase = phase
	active_player = player
	queue_redraw()

func _draw() -> void:
	var phases := GameConst.PHASES
	var count := phases.size()
	if count == 0:
		return
	var index := maxi(0, phases.find(current_phase))
	var gap := 4.0
	var width := (size.x - gap * float(count - 1)) / float(count)
	var accent := Tokens.CYAN if active_player == 0 else Tokens.PINK
	for i in range(count):
		var phase: String = phases[i]
		var rect := Rect2(float(i) * (width + gap), size.y - 17.0, width, 2.0)
		var done := i < index
		var active := i == index
		var fill := Color(accent.r, accent.g, accent.b, 0.80) if active else (Tokens.PANEL_LINE if done else Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, 0.24))
		draw_rect(rect, fill)
		if active:
			draw_rect(Rect2(rect.position + Vector2(0, -2), Vector2(rect.size.x, 4)), Color(accent.r, accent.g, accent.b, 0.10))
		var label := str(SHORT_LABELS.get(phase, phase)).to_upper()
		var font := Tokens.font_label()
		var font_size := 8
		var color := accent if active else (Tokens.INK_MUTED if done else Tokens.INK_SECONDARY)
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(rect.position.x + (rect.size.x - text_width) * 0.5, size.y - 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
