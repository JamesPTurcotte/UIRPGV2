class_name ReagentTile
extends Control

signal clicked(tile: ReagentTile)

var reagent: Dictionary = {}
var count: int = 0
var selected: bool = false
var disabled: bool = false
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

func set_reagent(data: Dictionary, amount: int) -> void:
	reagent = data
	count = amount
	disabled = amount <= 0
	tooltip_text = "%s — %s\n%s" % [str(data.get("name", "")), str(data.get("verb", "")), str(data.get("rule", ""))]
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var rarity := str(reagent.get("rarity", "common"))
	var accent := Tokens.rarity_color(rarity)
	if disabled:
		accent = Tokens.INK_MUTED
	var fill := Tokens.BG_LACQUER
	match str(reagent.get("tab", "inks")):
		"inks":
			fill = Color(Tokens.TIDE.r, Tokens.TIDE.g, Tokens.TIDE.b, 0.10)
		"solvents":
			fill = Color(Tokens.INK_SECONDARY.r, Tokens.INK_SECONDARY.g, Tokens.INK_SECONDARY.b, 0.06)
		"seals":
			fill = Color(Tokens.BRASS.r, Tokens.BRASS.g, Tokens.BRASS.b, 0.10)
		"foul":
			fill = Color(Tokens.VERDIGRIS.r, Tokens.VERDIGRIS.g, Tokens.VERDIGRIS.b, 0.12)
		"rare":
			fill = Color(Tokens.GOLD.r, Tokens.GOLD.g, Tokens.GOLD.b, 0.12)
	if selected:
		rect.position.y -= 2
	Chrome.draw_cut_rect(self, rect, 4.0, fill)
	if _hovered and not disabled:
		Chrome.draw_cut_rect(self, Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)), 3.0, accent * Color(1, 1, 1, 0.06))
	Chrome.draw_cut_outline(self, rect, 4.0, Tokens.BRASS_HI if selected else accent * Color(1, 1, 1, 0.8), 1.4 if selected else 1.0)
	var glyph := str(reagent.get("hotkey", "?"))
	var font := Tokens.font_display()
	var glyph_size := 28
	var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.48), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, accent if not disabled else Tokens.INK_MUTED)
	var name := str(reagent.get("name", ""))
	var name_size := 10
	var name_width := Tokens.font_ui().get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	draw_string(Tokens.font_ui(), Vector2((size.x - name_width) * 0.5, size.y - 10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Tokens.INK_PRIMARY if not disabled else Tokens.INK_MUTED)
	var count_text := "×%d" % count
	var count_width := Tokens.font_data().get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(Tokens.font_data(), Vector2(size.x - count_width - 7, 16), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Tokens.BRASS_HI if not disabled else Tokens.INK_MUTED)
	if selected:
		draw_rect(Rect2(0, size.y - 3, size.x, 2), Tokens.SELECTION)

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			clicked.emit(self)
			accept_event()
