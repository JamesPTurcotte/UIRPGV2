class_name SealComposer
extends RefCounted

## Deterministic heraldry from (def_id, attribute, lineage, set, rarity).
## One to three colors, readable at 24 px in one color, no depicted subject.

static func draw(
	ci: CanvasItem,
	rect: Rect2,
	def: CardDef,
	instance: CardInstance,
	seal_bg: Color,
	line_color: Color,
	accent_color: Color
) -> void:
	if def == null:
		return
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.41
	var rng := GameRng.new(def.id.hash(), 3)
	var attribute := Tokens.attribute_color(def.attribute)
	var brass := Tokens.BRASS
	var field := seal_bg
	# Seal field: a quiet disc so the line work reads at every size.
	ci.draw_circle(center, radius * 1.18, field.darkened(0.12))
	ci.draw_circle(center, radius * 1.10, field)
	ci.draw_arc(center, radius * 1.10, 0.0, TAU, 56, line_color * Color(1, 1, 1, 0.30), maxf(1.0, radius * 0.018), true)

	# Craft ring: one segment per mod, outside the set ring.
	if instance != null and not instance.mods.is_empty():
		var segments := mini(instance.mods.size(), 4)
		for i in range(segments):
			var start := -PI * 0.5 + float(i) * TAU / float(segments) + 0.12
			var finish := start + TAU / float(segments) - 0.24
			ci.draw_arc(center, radius * 1.24, start, finish, 12, brass * Color(1, 1, 1, 0.75), maxf(1.0, radius * 0.06), true)

	# Set ring: dashed outer band with a set mark at the bottom.
	var dash_count := 20 + rng.next_int(12)
	var dash_width := TAU / float(dash_count)
	for i in range(dash_count):
		if i % 7 == 0:
			continue
		var start := -PI * 0.5 + float(i) * dash_width
		ci.draw_arc(center, radius, start, start + dash_width * 0.55, 6, line_color * Color(1, 1, 1, 0.7), maxf(1.0, radius * 0.026), true)
	var set_mark := PackedVector2Array([
		center + Vector2(-radius * 0.16, radius * 0.91),
		center + Vector2(0, radius * 1.00),
		center + Vector2(radius * 0.16, radius * 0.91),
	])
	ci.draw_polyline(set_mark, brass, maxf(1.0, radius * 0.035), true)

	# Attribute armature.
	_draw_armature(ci, center, radius * 0.62, def.attribute, attribute, field, line_color)

	# Lineage mark at center.
	_draw_lineage(ci, center, radius * 0.25, def.lineage, brass, field)

	# Rarity notch at the top: a cut that matches the frame material.
	var notch_color := Tokens.rarity_color(def.rarity)
	var notch := PackedVector2Array([
		center + Vector2(-radius * 0.24, -radius * 1.03),
		center + Vector2(0, -radius * 1.28),
		center + Vector2(radius * 0.24, -radius * 1.03),
		center + Vector2(0, -radius * 0.92),
	])
	ci.draw_colored_polygon(notch, notch_color)
	ci.draw_polyline(PackedVector2Array([notch[0], notch[1], notch[2]]), notch_color.lightened(0.18), maxf(1.0, radius * 0.03), true)

	# Fracture pin and corruption seal.
	if instance != null:
		if not instance.fractured_mod.is_empty():
			ci.draw_line(center + Vector2(-radius * 0.18, radius * 0.42), center + Vector2(radius * 0.18, radius * 0.6), Tokens.GOLD, maxf(1.0, radius * 0.055), true)
			ci.draw_circle(center + Vector2(radius * 0.18, radius * 0.6), radius * 0.045, Tokens.GOLD)
		if instance.corrupted:
			ci.draw_arc(center, radius * 1.31, 0.0, TAU, 48, Tokens.VERDIGRIS * Color(1, 1, 1, 0.8), maxf(1.0, radius * 0.05), true)
			ci.draw_circle(center + Vector2(radius * 0.78, radius * 0.72), radius * 0.1, Tokens.VERDIGRIS)

static func _draw_armature(ci: CanvasItem, center: Vector2, radius: float, attribute: String, color: Color, field: Color, line_color: Color) -> void:
	match attribute:
		"ember":
			for i in range(3):
				var offset := (float(i) - 1.0) * radius * 0.42
				var points := PackedVector2Array([
					center + Vector2(-radius * 0.7, -radius * 0.38 + offset),
					center + Vector2(0, radius * 0.12 + offset),
					center + Vector2(radius * 0.7, -radius * 0.38 + offset),
				])
				ci.draw_polyline(points, color * Color(1, 1, 1, 0.85), maxf(1.0, radius * 0.055), true)
			for angle in [0.35, 2.1, 4.1]:
				var origin := center + Vector2(cos(angle), sin(angle)) * radius * 0.82
				ci.draw_line(origin, origin + Vector2(cos(angle), sin(angle)) * radius * 0.2, color * Color(1, 1, 1, 0.35), maxf(1.0, radius * 0.025), true)
		"tide":
			for i in range(3):
				ci.draw_arc(center, radius * (0.35 + i * 0.17), -2.7, 1.4, 28, color * Color(1, 1, 1, 0.8), maxf(1.0, radius * 0.05), true)
			ci.draw_circle(center + Vector2(radius * 0.58, -radius * 0.06), radius * 0.07, color)
		"verdant":
			ci.draw_line(center + Vector2(0, radius * 0.85), center + Vector2(0, -radius * 0.8), color * Color(1, 1, 1, 0.8), maxf(1.0, radius * 0.05), true)
			for side in [-1.0, 1.0]:
				for i in range(3):
					var y := center.y - radius * 0.45 + float(i) * radius * 0.4
					var tip := Vector2(center.x + side * radius * 0.62, y - radius * 0.28)
					ci.draw_line(Vector2(center.x, y), tip, color * Color(1, 1, 1, 0.72), maxf(1.0, radius * 0.04), true)
					ci.draw_circle(tip, radius * 0.045, color)
		"umbra":
			ci.draw_arc(center, radius * 0.72, 0.0, TAU, 40, color * Color(1, 1, 1, 0.8), maxf(1.0, radius * 0.05), true)
			ci.draw_circle(center + Vector2(radius * 0.27, -radius * 0.15), radius * 0.52, field)
			ci.draw_arc(center + Vector2(radius * 0.27, -radius * 0.15), radius * 0.52, 0.0, TAU, 32, line_color * Color(1, 1, 1, 0.35), maxf(1.0, radius * 0.018), true)
		"neutral":
			ci.draw_arc(center, radius * 0.7, 0.0, TAU, 40, color * Color(1, 1, 1, 0.85), maxf(1.0, radius * 0.05), true)
			ci.draw_arc(center, radius * 0.45, 0.0, TAU, 32, color * Color(1, 1, 1, 0.45), maxf(1.0, radius * 0.025), true)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				ci.draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.45, center + Vector2(cos(angle), sin(angle)) * radius * 0.7, color * Color(1, 1, 1, 0.5), maxf(1.0, radius * 0.02), true)
		_:
			ci.draw_arc(center, radius * 0.7, 0.0, TAU, 40, color, maxf(1.0, radius * 0.05), true)

static func _draw_lineage(ci: CanvasItem, center: Vector2, radius: float, lineage: String, color: Color, field: Color) -> void:
	ci.draw_circle(center, radius * 1.25, field)
	ci.draw_arc(center, radius * 1.25, 0.0, TAU, 24, color * Color(1, 1, 1, 0.35), 1.0, true)
	match lineage:
		"beast":
			for i in range(3):
				var x := center.x + (float(i) - 1.0) * radius * 0.48
				ci.draw_line(Vector2(x, center.y - radius * 0.55), Vector2(x, center.y + radius * 0.55), color, maxf(1.0, radius * 0.14), true)
		"spirit":
			var points := PackedVector2Array([
				center + Vector2(0, -radius * 0.75),
				center + Vector2(radius * 0.62, 0),
				center + Vector2(0, radius * 0.75),
				center + Vector2(-radius * 0.62, 0),
				center + Vector2(0, -radius * 0.75),
			])
			ci.draw_polyline(points, color, maxf(1.0, radius * 0.1), true)
		"construct":
			var rect := Rect2(center - Vector2(radius * 0.6, radius * 0.6), Vector2(radius * 1.2, radius * 1.2))
			ci.draw_rect(rect, color, false, maxf(1.0, radius * 0.12), true)
			for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
				ci.draw_circle(corner, radius * 0.12, color)
		"wanderer":
			var points := PackedVector2Array([
				center + Vector2(-radius * 0.6, radius * 0.45),
				center + Vector2(-radius * 0.1, radius * 0.45),
				center + Vector2(-radius * 0.1, -radius * 0.35),
				center + Vector2(radius * 0.45, -radius * 0.35),
			])
			ci.draw_polyline(points, color, maxf(1.0, radius * 0.1), true)
			var tip := points[points.size() - 1] + Vector2(radius * 0.2, 0)
			ci.draw_colored_polygon(PackedVector2Array([
				tip,
				tip + Vector2(-radius * 0.3, -radius * 0.2),
				tip + Vector2(-radius * 0.3, radius * 0.2),
			]), color)
		_:
			ci.draw_circle(center, radius * 0.28, color)
