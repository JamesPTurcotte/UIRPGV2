class_name Chrome
extends RefCounted

## Procedural furniture and ornament. Everything here is drawn from tokens and
## geometry; no bitmaps, no depicted subjects.

static func cut_rect_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var c := maxf(0.0, minf(cut, minf(rect.size.x, rect.size.y) * 0.4))
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	return PackedVector2Array([
		Vector2(x + c, y),
		Vector2(x + w - c, y),
		Vector2(x + w, y + c),
		Vector2(x + w, y + h - c),
		Vector2(x + w - c, y + h),
		Vector2(x + c, y + h),
		Vector2(x, y + h - c),
		Vector2(x, y + c),
	])

static func draw_cut_rect(ci: CanvasItem, rect: Rect2, cut: float, color: Color) -> void:
	ci.draw_colored_polygon(cut_rect_points(rect, cut), color)

static func draw_cut_outline(ci: CanvasItem, rect: Rect2, cut: float, color: Color, width: float = 1.0) -> void:
	var points := cut_rect_points(rect, cut)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, color, width, true)

static func draw_panel(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, cut: float = 5.0, border_width: float = 1.0) -> void:
	draw_cut_rect(ci, rect, cut, fill)
	draw_cut_outline(ci, rect, cut, border, border_width)

static func draw_layered_panel(ci: CanvasItem, rect: Rect2, fill: Color, border: Color, accent: Color, cut: float = 5.0) -> void:
	draw_cut_rect(ci, rect.grow(2.0), cut + 1.0, border.darkened(0.55))
	draw_cut_rect(ci, rect, cut, fill)
	draw_cut_outline(ci, rect, cut, border, 1.0)
	var inner := rect.grow(-3.0)
	draw_cut_outline(ci, inner, maxf(1.0, cut - 1.0), accent * Color(1, 1, 1, 0.22), 1.0)

static func draw_hairline(ci: CanvasItem, from: Vector2, to: Vector2, color: Color = Tokens.BRASS_LO, width: float = 1.0) -> void:
	ci.draw_line(from, to, color, width, true)

static func draw_corner_bosses(ci: CanvasItem, rect: Rect2, color: Color, size: float = 6.0) -> void:
	var points := [
		rect.position + Vector2(size, size),
		Vector2(rect.position.x + rect.size.x - size, rect.position.y + size),
		rect.position + rect.size - Vector2(size, size),
		Vector2(rect.position.x + size, rect.position.y + rect.size.y - size),
	]
	for point in points:
		ci.draw_circle(point, size * 0.22, color)
		ci.draw_arc(point, size * 0.55, 0.0, TAU, 18, color * Color(1, 1, 1, 0.55), 1.0, true)

static func draw_guilloche(ci: CanvasItem, rect: Rect2, color: Color, lines: int = 3, amplitude: float = 2.0, frequency: float = 0.09) -> void:
	if lines <= 0 or rect.size.x < 8.0:
		return
	for line_index in range(lines):
		var base_y := rect.position.y + rect.size.y * float(line_index + 1) / float(lines + 1)
		var points := PackedVector2Array()
		var x := rect.position.x + 4.0
		while x <= rect.position.x + rect.size.x - 4.0:
			var y := base_y + sin(x * frequency + line_index * 1.7) * amplitude
			points.append(Vector2(x, y))
			x += 3.0
		if points.size() >= 2:
			ci.draw_polyline(points, color * Color(1, 1, 1, 0.5), 1.0, true)

static func draw_noise(ci: CanvasItem, rect: Rect2, color: Color, count: int, seed_value: int = 1) -> void:
	var rng := GameRng.new(seed_value, 9)
	for i in range(count):
		var x := rect.position.x + float(rng.next_int(int(rect.size.x)))
		var y := rect.position.y + float(rng.next_int(int(rect.size.y)))
		var alpha := 0.04 + float(rng.next_int(8)) / 100.0
		ci.draw_circle(Vector2(x, y), 0.7, color * Color(1, 1, 1, alpha))

static func draw_attribute_sigil(ci: CanvasItem, center: Vector2, radius: float, attribute: String, color: Color, background: Color = Tokens.BG_VOID) -> void:
	var r := radius
	match attribute:
		"ember":
			for i in range(3):
				var offset := (float(i) - 1.0) * r * 0.38
				var points := PackedVector2Array([
					center + Vector2(-r * 0.62, -r * 0.65 + offset),
					center + Vector2(0, -r * 0.12 + offset),
					center + Vector2(r * 0.62, -r * 0.65 + offset),
				])
				ci.draw_polyline(points, color, maxf(1.0, r * 0.16), true)
		"tide":
			for i in range(3):
				ci.draw_arc(center, r * (0.35 + i * 0.2), -2.5, 1.6, 26, color, maxf(1.0, r * 0.12), true)
			ci.draw_circle(center + Vector2(r * 0.55, -r * 0.1), r * 0.12, color)
		"verdant":
			ci.draw_line(center + Vector2(0, r * 0.8), center + Vector2(0, -r * 0.7), color, maxf(1.0, r * 0.14), true)
			for side in [-1.0, 1.0]:
				for i in range(2):
					var y := center.y - r * 0.15 + float(i) * r * 0.38
					ci.draw_line(Vector2(center.x, y), Vector2(center.x + side * r * 0.55, y - r * 0.35), color, maxf(1.0, r * 0.11), true)
		"umbra":
			ci.draw_arc(center, r * 0.7, 0.0, TAU, 32, color, maxf(1.0, r * 0.12), true)
			ci.draw_circle(center + Vector2(r * 0.28, -r * 0.16), r * 0.52, background)
		"neutral":
			ci.draw_arc(center, r * 0.68, 0.0, TAU, 32, color, maxf(1.0, r * 0.12), true)
			ci.draw_line(center + Vector2(-r * 0.3, r * 0.3), center + Vector2(r * 0.3, -r * 0.3), color, maxf(1.0, r * 0.1), true)
		_:
			ci.draw_arc(center, r * 0.65, 0.0, TAU, 32, color, maxf(1.0, r * 0.12), true)

static func draw_rarity_gem(ci: CanvasItem, center: Vector2, radius: float, rarity: String, color: Color) -> void:
	match rarity:
		"common":
			ci.draw_circle(center, radius, color)
		"uncommon":
			ci.draw_rect(Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), color)
		"rare":
			var points := PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius, 0),
			])
			ci.draw_colored_polygon(points, color)
		"legendary":
			var crown := PackedVector2Array([
				center + Vector2(-radius * 0.9, radius * 0.55),
				center + Vector2(-radius * 0.75, -radius * 0.6),
				center + Vector2(-radius * 0.25, radius * 0.0),
				center + Vector2(0, -radius * 0.9),
				center + Vector2(radius * 0.25, radius * 0.0),
				center + Vector2(radius * 0.75, -radius * 0.6),
				center + Vector2(radius * 0.9, radius * 0.55),
			])
			ci.draw_colored_polygon(crown, color)
		_:
			ci.draw_circle(center, radius, color)

static func draw_type_band(ci: CanvasItem, rect: Rect2, card_type: String, color: Color) -> void:
	# Decoration lives in the top and bottom 18% of the band. The middle is a
	# text-safe lane; CardComposer paints an opaque plate there as a second
	# guarantee, so no hatch can ever run through the type line.
	var strip := clampf(rect.size.y * 0.18, 1.0, 4.0)
	match card_type:
		"monster":
			ci.draw_rect(rect, color * Color(1, 1, 1, 0.20))
		"spell":
			ci.draw_rect(rect, color * Color(1, 1, 1, 0.07))
			var step := 7.0
			var x := rect.position.x
			while x < rect.position.x + rect.size.x:
				ci.draw_line(Vector2(x, rect.position.y), Vector2(x + strip * 1.8, rect.position.y + strip), color * Color(1, 1, 1, 0.22), 1.0, true)
				x += step
		"trap":
			ci.draw_rect(rect, color * Color(1, 1, 1, 0.07))
			var step := 9.0
			var x2 := rect.position.x
			while x2 < rect.position.x + rect.size.x:
				ci.draw_rect(Rect2(x2, rect.position.y + strip * 0.2, 4.0, strip * 0.6), color * Color(1, 1, 1, 0.26))
				x2 += step
		_:
			ci.draw_rect(rect, color * Color(1, 1, 1, 0.14))

static func draw_offer_pips(ci: CanvasItem, origin: Vector2, count: int, color: Color, radius: float = 2.4) -> void:
	for i in range(count):
		ci.draw_circle(origin + Vector2(float(i) * (radius * 2.6), 0), radius, color)

static func draw_wax(ci: CanvasItem, center: Vector2, radius: float, label: String, pressed: bool = false, color: Color = Tokens.WAX) -> void:
	var rng := GameRng.new(label.hash(), 4)
	var points := PackedVector2Array()
	var steps := 26
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		var wobble := 0.86 + float(rng.next_int(100)) / 500.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble)
	ci.draw_colored_polygon(points, color.darkened(0.16 if pressed else 0.0))
	ci.draw_arc(center, radius * 0.78, 0.0, TAU, 32, color.lightened(0.12), maxf(1.0, radius * 0.08), true)
	ci.draw_arc(center, radius * 0.64, 0.0, TAU, 32, color.darkened(0.25), 1.0, true)
	if not label.is_empty():
		var font := Tokens.font_display()
		var size := int(radius * 0.95)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(font, center + Vector2(-width * 0.5, radius * 0.28), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Tokens.PAPER)

static func draw_parchment(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, Tokens.PAPER)
	ci.draw_rect(rect, Color(0.35, 0.28, 0.18, 0.12))
	# Deckled edge: short irregular ticks along the border.
	var rng := GameRng.new(int(rect.size.x) + int(rect.size.y), 6)
	var steps := int(rect.size.x / 7.0)
	for i in range(steps):
		var x := rect.position.x + float(i) * 7.0 + float(rng.next_int(4))
		ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + 2.0), Color(0.4, 0.32, 0.2, 0.25), 1.0)
		ci.draw_line(Vector2(x, rect.position.y + rect.size.y), Vector2(x, rect.position.y + rect.size.y - 2.0), Color(0.4, 0.32, 0.2, 0.25), 1.0)
	ci.draw_rect(Rect2(rect.position + Vector2(10, 10), rect.size - Vector2(20, 20)), Color(0.35, 0.28, 0.18, 0.18), false, 1.0)
	draw_guilloche(ci, Rect2(rect.position + Vector2(14, 14), Vector2(rect.size.x - 28, 24)), Color(0.35, 0.28, 0.18, 0.35), 2, 1.5, 0.12)

static func draw_gauge(ci: CanvasItem, rect: Rect2, value: int, maximum: int, color: Color, background: Color = Color(0, 0, 0, 0.35)) -> void:
	ci.draw_rect(rect, background)
	var ratio := clampf(float(value) / float(maxi(1, maximum)), 0.0, 1.0)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), color)
	var segments := 10
	for i in range(1, segments):
		var x := rect.position.x + rect.size.x * float(i) / float(segments)
		ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), Tokens.BG_VOID * Color(1, 1, 1, 0.35), 1.0)

static func draw_play_glyph(ci: CanvasItem, center: Vector2, radius: float, color: Color = Tokens.BRASS_HI, outline: Color = Tokens.BG_VOID) -> void:
	## A solid right-pointing triangle. Geometry only; no icon asset.
	var r := maxf(1.0, radius)
	var points := PackedVector2Array([
		center + Vector2(-r * 0.46, -r * 0.62),
		center + Vector2(r * 0.64, 0),
		center + Vector2(-r * 0.46, r * 0.62),
	])
	ci.draw_colored_polygon(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, outline * Color(1, 1, 1, 0.55), maxf(1.0, r * 0.12), true)

static func draw_arrow(ci: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	ci.draw_line(from, to, color, width, true)
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var tip := to
	ci.draw_colored_polygon(PackedVector2Array([
		tip,
		tip - direction * 10.0 + normal * 5.0,
		tip - direction * 10.0 - normal * 5.0,
	]), color)

static func draw_wax_button(ci: CanvasItem, rect: Rect2, label: String, hovered: bool, enabled: bool = true) -> void:
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.46
	var color := Tokens.WAX if enabled else Tokens.INK_MUTED
	if hovered and enabled:
		radius *= 1.04
	draw_wax(ci, center, radius, label, false, color)
	ci.draw_arc(center, radius * 1.02, 0.0, TAU, 40, Tokens.BRASS_LO if enabled else Tokens.INK_MUTED, 1.0, true)

static func text_center(ci: CanvasItem, font: Font, center_x: float, baseline_y: float, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(center_x - width * 0.5, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func text_right(ci: CanvasItem, font: Font, right_x: float, baseline_y: float, text: String, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(right_x - width, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_dot(ci: CanvasItem, center: Vector2, radius: float, color: Color, ring: Color = Color(0, 0, 0, 0)) -> void:
	ci.draw_circle(center, radius, color)
	if ring.a > 0.0:
		ci.draw_arc(center, radius + 1.0, 0.0, TAU, 18, ring, 1.0, true)

static func draw_scanlines(ci: CanvasItem, rect: Rect2, color: Color = Color(0.96, 0.92, 1.0, 0.02), step: float = 4.0) -> void:
	var y := rect.position.y
	while y <= rect.end.y:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)
		y += maxf(2.0, step)

static func draw_grid(ci: CanvasItem, rect: Rect2, color: Color, step: float = 64.0) -> void:
	var x := rect.position.x
	while x <= rect.end.x:
		ci.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), color, 1.0)
		x += maxf(8.0, step)
	var y := rect.position.y
	while y <= rect.end.y:
		ci.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)
		y += maxf(8.0, step)

static func draw_corner_brackets(ci: CanvasItem, rect: Rect2, color: Color, size: float = 10.0, width: float = 1.0) -> void:
	var s := maxf(2.0, size)
	ci.draw_line(rect.position, rect.position + Vector2(s, 0), color, width)
	ci.draw_line(rect.position, rect.position + Vector2(0, s), color, width)
	ci.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x - s, rect.position.y), color, width)
	ci.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + s), color, width)
	ci.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + s, rect.end.y), color, width)
	ci.draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x, rect.end.y - s), color, width)
	ci.draw_line(rect.end, Vector2(rect.end.x - s, rect.end.y), color, width)
	ci.draw_line(rect.end, Vector2(rect.end.x, rect.end.y - s), color, width)

static func draw_neon_panel(ci: CanvasItem, rect: Rect2, fill: Color = Tokens.BG_PANEL, border: Color = Tokens.PANEL_LINE, cut: float = 6.0, accent: Color = Tokens.CYAN) -> void:
	draw_cut_rect(ci, rect, cut, fill)
	draw_cut_outline(ci, rect, cut, border, 1.0)
	var inner := rect.grow(-3.0)
	draw_cut_outline(ci, inner, maxf(1.0, cut - 1.5), accent * Color(1, 1, 1, 0.10), 1.0)
	draw_corner_brackets(ci, inner.grow(-2.0), accent * Color(1, 1, 1, 0.28), maxf(4.0, cut * 1.3))
