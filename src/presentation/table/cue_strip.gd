class_name CueStrip
extends Control

## Broadcast subtitle for the table. It is a foreground layer so a backrow card
## can never clip a cue; the text is the one thing allowed over a face briefly.

var stage: BattleStage
var _active: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 35
	set_process(true)

func _process(_delta: float) -> void:
	var active := stage != null and stage.cue_alpha > 0.0
	if active:
		_active = true
		queue_redraw()
	elif _active:
		_active = false
		queue_redraw()

func _draw() -> void:
	if stage == null or stage.cue_alpha <= 0.001 or stage.cue_text.is_empty():
		return
	var board := stage as DuelBoardStage
	var scale_value: int = board.access_scale if board != null else 100
	var large := scale_value >= 150
	var width := minf(640.0 if large else 560.0, stage.size.x * (0.64 if large else 0.58))
	var bar_h := 38.0 if large else 27.0
	var rect := Rect2((stage.size.x - width) * 0.5, stage.hand_zone_rect.position.y - bar_h - 20.0, width, bar_h)
	var alpha := stage.cue_alpha
	var tone := stage.cue_color
	Chrome.draw_neon_panel(self, rect, Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.92), Color(tone.r, tone.g, tone.b, 0.42 * alpha), 5.0, tone)
	var text := stage.cue_text.to_upper()
	var font := Tokens.font_display()
	var font_size := 14 if large else 10
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_width > rect.size.x - 24.0:
		font_size = 11 if large else 8
		text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := rect.position.y + (26.0 if large else 18.0)
	draw_string(font, Vector2(rect.get_center().x - text_width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(tone.r, tone.g, tone.b, alpha))
