class_name CardComposer
extends RefCounted

## One 5:7 face at every size. This is the only place card geometry lives.
## The face is nameplate -> seal -> type line -> rules -> 3x2 plate -> footer.

const KEYWORDS := {
	"KINDLE": true, "ECHO": true, "FLIP": true, "PIERCE": true, "FLEET": true,
	"VEIL": true, "BIND": true, "RITE": true, "BANISH": true, "OFFER": true,
	"SET": true, "CHAIN": true,
}

static func draw(ci: CanvasItem, def: CardDef, instance: CardInstance, token: String, state: Dictionary = {}) -> void:
	if def == null:
		return
	var rect := Rect2(Vector2.ZERO, Tokens.card_size(token))
	if bool(state.get("face_down", false)):
		draw_back(ci, def, token, state)
		return
	_draw_frame(ci, rect, def, instance, state)
	var zones := _zones(rect)
	_draw_nameplate(ci, zones["name"], def, instance, token, state)
	_draw_seal_window(ci, zones["seal"], def, instance, token, state)
	_draw_type_line(ci, zones["type"], def, token, state)
	_draw_rules(ci, zones["rules"], def, token, state)
	_draw_stats(ci, zones["stats"], def, instance, token, state)
	_draw_footer(ci, zones["footer"], def, instance, token, state)
	_draw_mod_notches(ci, rect, instance, token)
	_draw_state(ci, rect, state)

static func _zones(rect: Rect2) -> Dictionary:
	var pad := rect.size.y * 0.012
	var usable := rect.size.y - pad * 2.0
	var gap := usable * 0.008
	var unit := (usable - gap * 5.0) / 0.96
	var y := rect.position.y + pad
	var x := rect.position.x
	var w := rect.size.x
	var name_rect := Rect2(x + w * 0.04, y, w * 0.92, unit * 0.08)
	y += unit * 0.08 + gap
	var seal_rect := Rect2(x + w * 0.05, y, w * 0.90, unit * 0.31)
	y += unit * 0.31 + gap
	var type_rect := Rect2(x + w * 0.04, y, w * 0.92, unit * 0.05)
	y += unit * 0.05 + gap
	var rules_rect := Rect2(x + w * 0.05, y, w * 0.90, unit * 0.27)
	y += unit * 0.27 + gap
	var stats_rect := Rect2(x + w * 0.04, y, w * 0.92, unit * 0.18)
	y += unit * 0.18 + gap
	var footer_rect := Rect2(x + w * 0.05, y, w * 0.90, unit * 0.07)
	return {"name": name_rect, "seal": seal_rect, "type": type_rect, "rules": rules_rect, "stats": stats_rect, "footer": footer_rect}

static func _draw_frame(ci: CanvasItem, rect: Rect2, def: CardDef, instance: CardInstance, state: Dictionary) -> void:
	var rarity := def.rarity
	var face := Tokens.face_color(rarity)
	var attr := Tokens.attribute_color(def.attribute)
	var frame := attr.darkened(0.12)
	if rarity == "rare":
		frame = attr.lerp(Tokens.AMBER, 0.35)
	elif rarity == "legendary":
		frame = attr.lerp(Tokens.PINK, 0.40)
	var rarity_edge := Tokens.rarity_color(rarity)
	var ink_line := Tokens.ink_color(instance.ink_id if instance != null else "ink.iron")
	ci.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Tokens.SHADOW_DEEP)
	Chrome.draw_cut_rect(ci, rect, maxf(2.0, rect.size.x * 0.018), face)
	Chrome.draw_cut_outline(ci, rect, maxf(2.0, rect.size.x * 0.018), frame, maxf(1.0, rect.size.x * 0.006))
	# Layered frame: inner ink rule, rarity rim, and a top light.
	Chrome.draw_cut_outline(ci, rect.grow(1.5), maxf(2.0, rect.size.x * 0.018), rarity_edge * Color(1, 1, 1, 0.28), 1.0)
	var inner := rect.grow(-maxf(2.0, rect.size.x * 0.012))
	Chrome.draw_cut_outline(ci, inner, maxf(1.0, rect.size.x * 0.012), ink_line * Color(1, 1, 1, 0.55), 1.0)
	ci.draw_line(rect.position + Vector2(rect.size.x * 0.12, 0), rect.position + Vector2(rect.size.x * 0.88, 0), frame.lightened(0.25), 1.0)
	match rarity:
		"uncommon":
			var edge := Color(Tokens.VERDIGRIS.r, Tokens.VERDIGRIS.g, Tokens.VERDIGRIS.b, 0.22)
			for i in range(6):
				var inset := inner.grow(-float(i) * 1.4)
				Chrome.draw_cut_outline(ci, inset, maxf(1.0, rect.size.x * 0.01), edge, 1.0)
		"rare":
			Chrome.draw_guilloche(ci, Rect2(rect.position + Vector2(rect.size.x * 0.02, rect.size.y * 0.012), Vector2(rect.size.x * 0.96, rect.size.y * 0.06)), Tokens.AMBER, 2, 1.1, 0.11)
			# The footer has text; the lower frame ornament stays above it.
		"legendary":
			var center := rect.get_center()
			for i in range(18):
				var angle := TAU * float(i) / 18.0
				var start := center + Vector2(cos(angle), sin(angle)) * rect.size.y * 0.16
				var finish := center + Vector2(cos(angle), sin(angle)) * rect.size.y * 0.52
				ci.draw_line(start, finish, Tokens.GOLD * Color(1, 1, 1, 0.10), 1.0, true)
			Chrome.draw_guilloche(ci, Rect2(rect.position + Vector2(rect.size.x * 0.03, rect.size.y * 0.025), Vector2(rect.size.x * 0.94, rect.size.y * 0.055)), Tokens.GOLD, 2, 1.2, 0.1)
	# Fibers on rag-paper faces; a material, never a picture.
	if not Tokens.is_dark_face(rarity):
		var rng := GameRng.new(def.id.hash(), 8)
		for i in range(26):
			var yy := rect.position.y + float(rng.next_int(int(rect.size.y)))
			var start_x := rect.position.x + float(rng.next_int(int(rect.size.x * 0.5)))
			var len := rect.size.x * (0.1 + float(rng.next_int(30)) / 100.0)
			ci.draw_line(Vector2(start_x, yy), Vector2(start_x + len, yy), Tokens.PAPER_INK * Color(1, 1, 1, 0.035), 1.0)
	if instance != null and instance.corrupted:
		for i in range(5):
			var yy := rect.position.y + rect.size.y * float(2 + i) / 9.0
			ci.draw_line(Vector2(rect.position.x, yy), Vector2(rect.position.x + rect.size.x * 0.12, yy), Tokens.VERDIGRIS * Color(1, 1, 1, 0.35), 1.0)
	if instance != null and instance.shimmer_id != "shimmer.none":
		var shimmer := Tokens.shimmer_color(instance.shimmer_id)
		ci.draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.02),
			rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.02),
			rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.98),
			rect.position + Vector2(0.0, rect.size.y * 0.98),
		]), shimmer * Color(1, 1, 1, 0.08))

static func _draw_nameplate(ci: CanvasItem, rect: Rect2, def: CardDef, instance: CardInstance, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var rarity := def.rarity
	var plate_fill := Tokens.face_color(rarity).lightened(0.04) if not Tokens.is_dark_face(rarity) else Tokens.face_color(rarity).lightened(0.08)
	Chrome.draw_cut_rect(ci, rect, maxf(1.0, rect.size.y * 0.08), plate_fill)
	var line_color := Tokens.face_ink(rarity)
	var gem_radius := rect.size.y * 0.27
	var gem_center := Vector2(rect.end.x - gem_radius * 1.5, rect.get_center().y)
	var attr := Tokens.attribute_color(def.attribute)
	ci.draw_circle(gem_center, gem_radius, attr * Color(1, 1, 1, 0.18))
	ci.draw_arc(gem_center, gem_radius, 0.0, TAU, 22, attr, maxf(1.0, rect.size.y * 0.035), true)
	Chrome.draw_attribute_sigil(ci, gem_center, gem_radius * 0.55, def.attribute, attr, plate_fill)
	var name := instance.display_name(def) if instance != null else def.name
	var font := Tokens.font_display()
	var start_size := int(metrics["name"])
	var name_floor := 5 if token in ["B-", "H-", "T"] else 7
	var min_size := maxi(name_floor, int(start_size * 0.55))
	var max_width := rect.size.x - gem_radius * 3.2
	var size := UI.fit_font_size(font, name, max_width, start_size, min_size)
	var baseline := rect.get_center().y + font.get_ascent(size) * 0.5 - 1.0
	var name_color := Tokens.SELECTION if instance != null and not instance.custom_name.is_empty() else line_color
	ci.draw_string(font, Vector2(rect.position.x + rect.size.x * 0.035, baseline), name, HORIZONTAL_ALIGNMENT_LEFT, max_width, size, name_color)
	ci.draw_line(Vector2(rect.position.x + rect.size.x * 0.03, rect.end.y), Vector2(rect.end.x - rect.size.x * 0.03, rect.end.y), line_color * Color(1, 1, 1, 0.16), 1.0)

static func _draw_seal_window(ci: CanvasItem, rect: Rect2, def: CardDef, instance: CardInstance, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var field := Tokens.CARD_FACE_DEEP
	Chrome.draw_cut_rect(ci, rect, maxf(1.0, rect.size.y * 0.02), field)
	Chrome.draw_cut_outline(ci, rect, maxf(1.0, rect.size.y * 0.02), Tokens.BRASS_LO, 1.0)
	var seal_rect := rect.grow(-rect.size.y * 0.07)
	SealComposer.draw(ci, seal_rect, def, instance, field, Tokens.INK_PRIMARY, Tokens.BRASS)
	# The seal is the card's action point. A play glyph appears only when the
	# surface has an immediate action (selected shelf card, hovered table card).
	if bool(state.get("action_seal", false)):
		var medallion_center := seal_rect.get_center()
		var medallion_radius := minf(seal_rect.size.x, seal_rect.size.y) * 0.17
		ci.draw_circle(medallion_center, medallion_radius * 1.25, field.darkened(0.08))
		ci.draw_arc(medallion_center, medallion_radius * 1.25, 0.0, TAU, 40, Tokens.BRASS_HI * Color(1, 1, 1, 0.8), maxf(1.0, rect.size.y * 0.008), true)
		Chrome.draw_play_glyph(ci, medallion_center + Vector2(medallion_radius * 0.08, 0), medallion_radius * 0.9, Tokens.BRASS_HI, field)
	# Offer pips, top-left.
	var pips := def.offer
	if pips > 0:
		Chrome.draw_offer_pips(ci, rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.12), pips, Tokens.BRASS_HI, maxf(1.2, rect.size.y * 0.026))
	# Rarity gem and letter, top-right.
	var gem_center := Vector2(rect.end.x - rect.size.x * 0.07, rect.position.y + rect.size.y * 0.12)
	Chrome.draw_rarity_gem(ci, gem_center, maxf(2.0, rect.size.y * 0.045), def.rarity, Tokens.rarity_color(def.rarity))
	var letter := GameConst.rarity_letter(def.rarity)
	var letter_size := maxi(5, int(metrics["label"]))
	var font := Tokens.font_data()
	var letter_width := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
	ci.draw_string(font, gem_center + Vector2(-letter_width * 0.5, letter_size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, Tokens.BG_VOID if def.rarity == "common" or def.rarity == "uncommon" else Tokens.BG_VOID)
	# Honours: up to three tiny stamps, bottom-left. The full list lives in the Passport.
	if instance != null and not instance.honours.is_empty():
		var stamp_count := mini(instance.honours.size(), 3)
		for i in range(stamp_count):
			var stamp_center := Vector2(rect.position.x + rect.size.x * 0.08 + float(i) * rect.size.y * 0.08, rect.end.y - rect.size.y * 0.09)
			var honour_id := str(instance.honours[i].get("id", ""))
			match honour_id:
				"boss_slayer":
					Chrome.draw_rarity_gem(ci, stamp_center, maxf(1.5, rect.size.y * 0.028), "rare", Tokens.GOLD)
				"flawless":
					ci.draw_arc(stamp_center, maxf(1.5, rect.size.y * 0.028), 0.0, TAU, 12, Tokens.GOLD, 1.0, true)
				"deepest":
					ci.draw_polyline(PackedVector2Array([stamp_center + Vector2(-2, 1), stamp_center + Vector2(0, -2), stamp_center + Vector2(2, 1)]), Tokens.GOLD, 1.0, true)
				_:
					ci.draw_circle(stamp_center, maxf(1.2, rect.size.y * 0.022), Tokens.WAX)
	# Set mark, bottom-right.
	var set_mark := PackedVector2Array([
		Vector2(rect.end.x - rect.size.x * 0.10, rect.end.y - rect.size.y * 0.12),
		Vector2(rect.end.x - rect.size.x * 0.07, rect.end.y - rect.size.y * 0.06),
		Vector2(rect.end.x - rect.size.x * 0.04, rect.end.y - rect.size.y * 0.12),
	])
	ci.draw_polyline(set_mark, Tokens.BRASS * Color(1, 1, 1, 0.8), maxf(1.0, rect.size.y * 0.012), true)

static func _draw_type_line(ci: CanvasItem, rect: Rect2, def: CardDef, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var attr := Tokens.attribute_color(def.attribute)
	Chrome.draw_type_band(ci, rect, def.type, attr)
	# The band pattern is a material. Text gets an opaque plate so the trap
	# dashes / spell diagonals can never run through the glyphs.
	var sigil_slot := rect.size.x * 0.18
	var plate := Rect2(rect.position + Vector2(sigil_slot, 1), Vector2(rect.size.x - sigil_slot - 1, rect.size.y - 2))
	Chrome.draw_cut_rect(ci, plate, maxf(1.0, rect.size.y * 0.08), Tokens.face_color(def.rarity))
	var line_color := Tokens.face_ink(def.rarity)
	var text := def.canonical_line()
	var font := Tokens.font_ui()
	var size := int(metrics["type"])
	var max_width := plate.size.x - 8.0
	var sigil_center := Vector2(rect.position.x + sigil_slot * 0.5, rect.get_center().y)
	Chrome.draw_attribute_sigil(ci, sigil_center, minf(rect.size.y * 0.30, sigil_slot * 0.30), def.attribute, attr, Tokens.face_color(def.rarity))
	var min_type := 2 if token in ["B-", "H-", "T"] else 4
	var fitted := UI.fit_font_size(font, text, max_width, size, maxi(min_type, int(float(size) * 0.55)))
	var baseline := rect.get_center().y + font.get_ascent(fitted) * 0.5 - 1.0
	ci.draw_string(font, Vector2(plate.position.x + 4.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, fitted, line_color)

static func _draw_rules(ci: CanvasItem, rect: Rect2, def: CardDef, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var ink := Tokens.face_ink(def.rarity)
	var muted := Tokens.face_ink_muted(def.rarity)
	var attr := Tokens.attribute_color(def.attribute)
	if not Tokens.is_dark_face(def.rarity):
		attr = attr.darkened(0.18)
	var font := Tokens.font_ui()
	var size := int(metrics["rules"])
	var line_height := float(size) * 1.18
	var max_width := rect.size.x
	var line_count := 0
	var words := def.text.split(" ", false)
	if words.is_empty():
		ci.draw_string(font, Vector2(rect.position.x + 2, rect.position.y + size), "—", HORIZONTAL_ALIGNMENT_LEFT, -1, size, muted)
		return
	var x := rect.position.x + 2.0
	var y := rect.position.y + font.get_ascent(size) + 1.0
	var truncated := false
	for word in words:
		var clean := word.strip_edges().trim_suffix(":").trim_suffix(",").trim_suffix(".").to_upper()
		var color := attr if KEYWORDS.has(clean) else ink
		var word_width := font.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if x + word_width > rect.end.x - 2.0 and x > rect.position.x + 2.0:
			x = rect.position.x + 2.0
			y += line_height
			line_count += 1
			if line_count >= 5:
				truncated = true
				break
		ci.draw_string(font, Vector2(x, y), word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += word_width
	if truncated:
		# Make silent truncation visible; content validation should still catch it.
		var chevron := PackedVector2Array([
			Vector2(rect.end.x - 6, rect.end.y - 7),
			Vector2(rect.end.x - 2, rect.end.y - 4),
			Vector2(rect.end.x - 6, rect.end.y - 1),
		])
		ci.draw_polyline(chevron, muted, 1.0, true)
	ci.draw_line(Vector2(rect.position.x, rect.position.y - 1), Vector2(rect.position.x + rect.size.x * 0.18, rect.position.y - 1), attr * Color(1, 1, 1, 0.6), 1.0)

static func _draw_stats(ci: CanvasItem, rect: Rect2, def: CardDef, instance: CardInstance, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var ink := Tokens.face_ink(def.rarity)
	var secondary := Tokens.face_ink_secondary(def.rarity)
	var plate_fill := Tokens.face_color(def.rarity).darkened(0.045) if not Tokens.is_dark_face(def.rarity) else Tokens.face_color(def.rarity).lightened(0.05)
	Chrome.draw_cut_rect(ci, rect, maxf(1.0, rect.size.y * 0.018), plate_fill)
	Chrome.draw_cut_outline(ci, rect, maxf(1.0, rect.size.y * 0.018), Tokens.face_ink_muted(def.rarity) * Color(1, 1, 1, 0.45), 1.0)
	var row_h := rect.size.y * 0.5
	var col_w := rect.size.x / 3.0
	for i in range(1, 3):
		ci.draw_line(Vector2(rect.position.x + col_w * i, rect.position.y + 2), Vector2(rect.position.x + col_w * i, rect.end.y - 2), Tokens.face_ink_muted(def.rarity) * Color(1, 1, 1, 0.28), 1.0)
	ci.draw_line(Vector2(rect.position.x + 2, rect.position.y + row_h), Vector2(rect.end.x - 2, rect.position.y + row_h), Tokens.face_ink_muted(def.rarity) * Color(1, 1, 1, 0.35), 1.0)
	var resolved := _resolved_stats(def, instance, state)
	var labels := ["ATK", "DEF", "OFFER", "POWER", "QUALITY", "MODS"]
	if token in ["S", "B", "B-", "B+", "T", "O", "A", "M", "H", "H-", "H+"]:
		labels = ["ATK", "DEF", "OFR", "PWR", "Q", "MOD"]
	elif token == "L":
		labels = ["ATK", "DEF", "OFFER", "PWR", "QUAL", "MOD"]
	var values := [
		[str(resolved["atk"]) if def.is_monster() else "—", labels[0]],
		[str(resolved["defense"]) if def.is_monster() else "—", labels[1]],
		[str(resolved["offer"]), labels[2]],
		[str(resolved["power"]), labels[3]],
		["%d%%" % resolved["quality"], labels[4]],
		[str(resolved["mods"]), labels[5]],
	]
	var value_size := int(metrics["stat"])
	var label_size := int(metrics["label"])
	for index in range(6):
		var col := index % 3
		var row := int(index / 3)
		var cell := Rect2(rect.position.x + col_w * col, rect.position.y + row_h * row, col_w, row_h)
		var label_text: String = values[index][1]
		var value_text: String = values[index][0]
		var label_font := Tokens.font_ui()
		var value_font := Tokens.font_data()
		var label_width := label_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var value_gap := 4.0 if token in ["B-", "H-", "T"] else 8.0
		var available_value_width := cell.size.x - label_width - value_gap
		var fit := UI.fit_font_size(value_font, value_text, available_value_width, value_size, maxi(5, value_size - 4))
		var baseline := cell.get_center().y + label_size * 0.34
		ci.draw_string(label_font, Vector2(cell.position.x + 4, baseline), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, secondary * Color(1, 1, 1, 0.8))
		var value_width := value_font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x
		ci.draw_string(value_font, Vector2(cell.end.x - value_width - 4, baseline), value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fit, ink)

static func _resolved_stats(def: CardDef, instance: CardInstance, state: Dictionary) -> Dictionary:
	var plain := instance
	if plain == null:
		plain = CardInstance.new(0, def.id, 1)
	var stats := CardResolver.effective_stats(plain, def, Content.mods if Content.loaded else {})
	var power := CardResolver.power(plain, def, Content.mods if Content.loaded else {})
	var override: Dictionary = state.get("stats_override", {})
	if override.has("atk"):
		stats["atk"] = int(override["atk"])
	if override.has("defense"):
		stats["defense"] = int(override["defense"])
	if override.has("offer"):
		stats["offer"] = int(override["offer"])
	if override.has("power"):
		power = int(override["power"])
	return {
		"atk": int(stats["atk"]),
		"defense": int(stats["defense"]),
		"offer": int(stats["offer"]),
		"power": power,
		"quality": plain.quality,
		"mods": plain.mods.size(),
	}

static func _draw_footer(ci: CanvasItem, rect: Rect2, def: CardDef, instance: CardInstance, token: String, state: Dictionary) -> void:
	var metrics := Tokens.card_text(token)
	var ink := Tokens.face_ink_secondary(def.rarity)
	var muted := Tokens.face_ink_muted(def.rarity)
	var font := Tokens.font_data_regular()
	var size := int(metrics["footer"])
	var set_code := def.set_id.get_slice(".", 1).to_upper() if def.set_id.contains(".") else def.set_id.to_upper()
	var left := "%s · %s" % [GameConst.rarity_letter(def.rarity), set_code]
	var left_w := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var baseline := rect.position.y + size
	ci.draw_string(font, Vector2(rect.position.x + 1, baseline), left, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	var qtext := "%d%%" % (instance.quality if instance != null else 0)
	var right_w := font.get_string_size(qtext, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var right_x := rect.end.x - right_w - 8.0
	var center_text := "PROV —"
	if instance != null:
		center_text = "F%d" % instance.provenance
	var center_w := font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var center_x := rect.get_center().x - center_w * 0.5
	# Cells must not collide. Drop the lowest-priority element until they fit.
	var overlap := left_w + center_w + right_w + 14.0 > rect.size.x
	if overlap:
		center_text = ""
	if instance != null:
		var stamp_rect := Rect2(center_x - 2, rect.position.y - 0.5, center_w + 4, size + 1)
		Chrome.draw_cut_outline(ci, stamp_rect, 1.0, Tokens.BRASS * Color(1, 1, 1, 0.45), 1.0)
		ci.draw_string(font, Vector2(center_x, baseline), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Tokens.BRASS * Color(1, 1, 1, 0.8))
	else:
		ci.draw_string(font, Vector2(center_x, baseline), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, muted)
	# Quality is a number at every size; the gauge is a reading aid at M+.
	var gauge_tokens := ["M", "L", "XL", "H", "H+"]
	if instance != null and gauge_tokens.has(token):
		var gauge_w := minf(rect.size.x * 0.12, 26.0)
		var gauge_x := right_x - gauge_w - 6.0
		if gauge_x > left_w + 8.0 and gauge_x > center_x + center_w + 6.0:
			Chrome.draw_gauge(ci, Rect2(gauge_x, rect.get_center().y - 1.5, gauge_w, 3.0), instance.quality, 20, Tokens.VERDIGRIS, muted * Color(1, 1, 1, 0.25))
	ci.draw_string(font, Vector2(right_x, baseline), qtext, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	if instance != null:
		var rune_center := Vector2(rect.end.x - 3.5, rect.get_center().y)
		var rune := PackedVector2Array([
			rune_center + Vector2(0, -2.0), rune_center + Vector2(2.0, 0),
			rune_center + Vector2(0, 2.0), rune_center + Vector2(-2.0, 0),
			rune_center + Vector2(0, -2.0),
		])
		ci.draw_polyline(rune, Tokens.BRASS, 1.0, true)

static func _draw_mod_notches(ci: CanvasItem, rect: Rect2, instance: CardInstance, token: String) -> void:
	if instance == null or instance.mods.is_empty():
		return
	var count := mini(instance.mods.size(), 4)
	var top := rect.position.y + rect.size.y * 0.55
	var step := rect.size.y * 0.032
	for i in range(count):
		var y := top + step * float(i)
		var notch := PackedVector2Array([
			Vector2(rect.end.x - 5, y),
			Vector2(rect.end.x - 2, y + step * 0.35),
			Vector2(rect.end.x - 5, y + step * 0.7),
		])
		var mod_id := str(instance.mods[i].get("id", ""))
		var color := Tokens.BRASS
		if instance.corrupted:
			color = Tokens.VERDIGRIS
		if mod_id == instance.fractured_mod:
			color = Tokens.GOLD
		ci.draw_colored_polygon(notch, color)
		var tier := int(instance.mods[i].get("tier", 1))
		for pip in range(mini(tier, 5)):
			ci.draw_circle(Vector2(rect.end.x - 7, y + step * 0.58 + float(pip) * 1.2), 0.55, Tokens.BG_VOID)

static func _draw_state(ci: CanvasItem, rect: Rect2, state: Dictionary) -> void:
	if bool(state.get("playable", false)):
		Chrome.draw_cut_outline(ci, rect.grow(1.0), maxf(2.0, rect.size.x * 0.015), Tokens.CYAN * Color(1, 1, 1, 0.52), 1.0)
		ci.draw_circle(Vector2(rect.position.x + rect.size.x * 0.09, rect.position.y + rect.size.y * 0.09), maxf(1.6, rect.size.y * 0.018), Tokens.CYAN)
	if bool(state.get("legal", false)):
		Chrome.draw_cut_outline(ci, rect.grow(1.0), maxf(2.0, rect.size.x * 0.015), Tokens.BRASS_HI, maxf(1.0, rect.size.x * 0.008))
		# Corner ticks.
		var r := rect.grow(3.0)
		ci.draw_line(r.position, r.position + Vector2(8, 0), Tokens.SELECTION, 2.0)
		ci.draw_line(r.position, r.position + Vector2(0, 8), Tokens.SELECTION, 2.0)
		ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x - 8, r.position.y), Tokens.SELECTION, 2.0)
		ci.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + 8), Tokens.SELECTION, 2.0)
	if bool(state.get("illegal", false)):
		ci.draw_rect(rect, Color(0, 0, 0, 0.35))
		var notch := PackedVector2Array([
			Vector2(rect.end.x - 18, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y + 18),
		])
		ci.draw_colored_polygon(notch, Tokens.DANGER)
	if bool(state.get("selected", false)):
		Chrome.draw_cut_outline(ci, rect.grow(2.0), maxf(2.0, rect.size.x * 0.015), Tokens.SELECTION, maxf(1.0, rect.size.x * 0.01))
	if bool(state.get("new", false)):
		ci.draw_circle(Vector2(rect.end.x - 10, rect.position.y + 10), 4.0, Tokens.WAX)
		ci.draw_arc(Vector2(rect.end.x - 10, rect.position.y + 10), 5.5, 0.0, TAU, 16, Tokens.WAX * Color(1, 1, 1, 0.6), 1.0, true)
	if bool(state.get("decked", false)):
		var ribbon := Rect2(rect.position.x, rect.position.y + rect.size.y * 0.32, 3.0, rect.size.y * 0.22)
		ci.draw_rect(ribbon, Tokens.BRASS)
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(ribbon.end.x, ribbon.position.y),
			Vector2(ribbon.end.x + 5, ribbon.position.y + 3),
			Vector2(ribbon.end.x, ribbon.position.y + 6),
		]), Tokens.BRASS)
	if bool(state.get("locked", false)):
		var tab := Rect2(rect.end.x - 22, rect.position.y, 22, 8)
		Chrome.draw_cut_rect(ci, tab, 2.0, Tokens.BRASS_LO)
		ci.draw_string(Tokens.font_data(), tab.position + Vector2(4, 7), "LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Tokens.INK_PRIMARY)
	var count := int(state.get("count", 0))
	if count > 1:
		var text := "×%d" % count
		var font := Tokens.font_data()
		var size := maxi(8, int(rect.size.x * 0.08))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 10
		var badge := Rect2(rect.end.x - w - 4, rect.end.y - size - 8, w, size + 4)
		Chrome.draw_cut_rect(ci, badge, 2.0, Tokens.BG_VOID * Color(1, 1, 1, 0.82))
		Chrome.draw_cut_outline(ci, badge, 2.0, Tokens.BRASS_LO, 1.0)
		ci.draw_string(font, badge.position + Vector2(5, size), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Tokens.BRASS_HI)

static func draw_back(ci: CanvasItem, def: CardDef, token: String, state: Dictionary = {}) -> void:
	var rect := Rect2(Vector2.ZERO, Tokens.card_size(token))
	ci.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Tokens.SHADOW_DEEP)
	Chrome.draw_cut_rect(ci, rect, maxf(2.0, rect.size.x * 0.018), Tokens.BG_LACQUER)
	var frame := Tokens.BRASS_LO
	Chrome.draw_cut_outline(ci, rect, maxf(2.0, rect.size.x * 0.018), frame, maxf(1.0, rect.size.x * 0.007))
	var inner := rect.grow(-maxf(3.0, rect.size.x * 0.02))
	Chrome.draw_cut_outline(ci, inner, maxf(2.0, rect.size.x * 0.014), Tokens.BRASS * Color(1, 1, 1, 0.35), 1.0)
	Chrome.draw_guilloche(ci, inner.grow(-4.0), Tokens.BRASS * Color(1, 1, 1, 0.25), 3, 1.8, 0.08)
	Chrome.draw_corner_bosses(ci, inner, Tokens.BRASS * Color(1, 1, 1, 0.55), maxf(2.0, rect.size.x * 0.03))
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.17
	Chrome.draw_wax(ci, center, radius, "L", false, Tokens.WAX)
	ci.draw_arc(center, radius * 1.18, 0.0, TAU, 32, Tokens.BRASS * Color(1, 1, 1, 0.45), 1.0, true)
	var font := Tokens.font_ui()
	var label := "RAZEAH"
	var size := maxi(5, int(rect.size.x * 0.035))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, center + Vector2(-w * 0.5, rect.size.y * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Tokens.BRASS * Color(1, 1, 1, 0.55))
	if bool(state.get("selected", false)):
		Chrome.draw_cut_outline(ci, rect.grow(2.0), maxf(2.0, rect.size.x * 0.015), Tokens.SELECTION, 2.0)
