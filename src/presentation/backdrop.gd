class_name Backdrop
extends Control

## The Neon Reliquary room atmosphere: void, grid, scanlines, event light.
## No picture, no texture asset. Everything is geometry and light.

var screen_kind: String = "library"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Tokens.BG_VOID)

	# Deep field: a quiet vertical gradient toward the event lights.
	for i in range(36):
		var t := float(i) / 35.0
		var color := Tokens.BG_VOID.lerp(Tokens.BG_DEEP, t * 0.7)
		draw_rect(Rect2(0, size.y * t, size.x, size.y / 34.0 + 1.0), color)

	# Event light: cyan below, magenta above, violet at the seam.
	_glow(Vector2(size.x * 0.50, size.y * 0.10), size.x * 0.46, Tokens.PINK, 0.020)
	_glow(Vector2(size.x * 0.88, size.y * 0.46), size.x * 0.32, Tokens.CYAN, 0.014)
	_glow(Vector2(size.x * 0.10, size.y * 0.84), size.x * 0.36, Tokens.PURPLE, 0.012)
	_glow(Vector2(size.x * 0.50, size.y * 1.04), size.x * 0.58, Tokens.CYAN, 0.020)

	# A faint machine grid. It is a floor, not a spreadsheet.
	var grid_color := Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.032)
	var step := 64.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
		y += step

	# A low seal ring behind the focal room.
	_draw_ring(Vector2(size.x * 0.5, size.y * 0.43), size.x * 0.24, Tokens.CYAN, 0.045)
	_draw_ring(Vector2(size.x * 0.5, size.y * 0.43), size.x * 0.32, Tokens.PINK, 0.022)
	_draw_ring(Vector2(size.x * 0.5, size.y * 0.43), size.x * 0.42, Tokens.CYAN, 0.012)

	match screen_kind:
		"table":
			Chrome.draw_cut_outline(self, Rect2(size.x * 0.055, size.y * 0.115, size.x * 0.89, size.y * 0.79), 12.0, Tokens.CYAN * Color(1, 1, 1, 0.055), 1.0)
			Chrome.draw_corner_bosses(self, Rect2(size.x * 0.055, size.y * 0.115, size.x * 0.89, size.y * 0.79), Tokens.CYAN * Color(1, 1, 1, 0.16), 8.0)
		"pack":
			_draw_ring(Vector2(size.x * 0.5, size.y * 0.62), size.x * 0.18, Tokens.PINK, 0.09)
			_draw_ring(Vector2(size.x * 0.5, size.y * 0.62), size.x * 0.25, Tokens.CYAN, 0.035)
		"gate":
			draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), Tokens.CYAN * Color(1, 1, 1, 0.045), 1.0)
			_glow(Vector2(size.x * 0.5, size.y * 0.42), size.x * 0.38, Tokens.CYAN, 0.018)
		_:
			# Library / Deck / Bench / Salvage: vertical shelf light and a quiet
			# horizontal rail. Keep it behind the panels.
			for i in range(4):
				var px := size.x * (0.08 + float(i) * 0.28)
				draw_line(Vector2(px, size.y * 0.10), Vector2(px, size.y * 0.90), Tokens.CYAN * Color(1, 1, 1, 0.026), 1.0)
			draw_line(Vector2(size.x * 0.06, size.y * 0.71), Vector2(size.x * 0.94, size.y * 0.71), Tokens.PINK * Color(1, 1, 1, 0.04), 1.0)

	# Scanlines. Subtle; they never cross the card text.
	var scan := Color(Tokens.INK_PRIMARY.r, Tokens.INK_PRIMARY.g, Tokens.INK_PRIMARY.b, 0.018)
	y = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), scan, 1.0)
		y += 4.0

	# Vignette and edge fade.
	for i in range(7):
		var alpha := 0.035 + float(i) * 0.011
		var inset := float(i) * 10.0
		draw_rect(Rect2(inset, inset, size.x - inset * 2, size.y - inset * 2), Color(0, 0, 0, alpha), false, 12.0)

	Chrome.draw_noise(self, Rect2(Vector2.ZERO, size), Tokens.INK_PRIMARY, 80, 3)

func _glow(center: Vector2, radius: float, color: Color, strength: float) -> void:
	for i in range(7):
		var t := float(i) / 6.0
		draw_circle(center, radius * (0.32 + t * 0.75), Color(color.r, color.g, color.b, strength * (1.0 - t) * 0.42))

func _draw_ring(center: Vector2, radius: float, color: Color, alpha: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 96, Color(color.r, color.g, color.b, alpha), 1.0, true)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var ok := Vector2(cos(angle), sin(angle))
		draw_line(center + ok * radius * 0.985, center + ok * radius * 1.015, Color(color.r, color.g, color.b, alpha * 1.8), 1.0, true)
