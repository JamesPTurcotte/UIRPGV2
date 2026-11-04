class_name CardLayoutAudit
extends RefCounted

## Headless bounds checks for the card face. It does not render; it measures
## the same fonts and zones the composer uses so a content edit cannot silently
## create a text/ornament collision.

const TOKENS := ["S", "B", "B-", "B+", "T", "O", "A", "H", "H-", "H+", "M", "L", "XL"]

static func audit() -> Array[String]:
	var failures: Array[String] = []
	for token in TOKENS:
		var rect := Rect2(Vector2.ZERO, Tokens.card_size(token))
		if absf(rect.size.x / rect.size.y - 5.0 / 7.0) > 0.002:
			failures.append("%s: aspect %.4f" % [token, rect.size.x / rect.size.y])
		for def in Content.card_list:
			failures.append_array(_audit_card(def, token, rect))
	return failures

static func _audit_card(def: CardDef, token: String, rect: Rect2) -> Array[String]:
	var failures: Array[String] = []
	var metrics := Tokens.card_text(token)
	var zones := CardComposer._zones(rect)
	var face_font := Tokens.font_display()
	var ui_font := Tokens.font_ui()
	var data_font := Tokens.font_data_regular()
	# Name.
	var name_rect: Rect2 = zones["name"]
	var gem_radius := name_rect.size.y * 0.27
	var name_width := name_rect.size.x - gem_radius * 3.2
	var name_floor := 5 if token in ["B-", "H-", "T"] else 7
	var name_size := maxi(name_floor, int(float(metrics["name"]) * 0.55))
	var fitted_name := UI.fit_font_size(face_font, def.name, name_width, int(metrics["name"]), name_size)
	if face_font.get_string_size(def.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_name).x > name_width + 0.5:
		failures.append("%s/%s: name overflow" % [token, def.id])
	# Type line.
	var type_rect: Rect2 = zones["type"]
	var type_plate_width := type_rect.size.x * 0.82 - 8.0
	var type_min := 2 if token in ["B-", "H-", "T"] else 4
	var type_size := maxi(type_min, int(float(metrics["type"]) * 0.55))
	var fitted_type := UI.fit_font_size(ui_font, def.canonical_line(), type_plate_width, int(metrics["type"]), type_size)
	if ui_font.get_string_size(def.canonical_line(), HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_type).x > type_plate_width + 0.5:
		failures.append("%s/%s: type line overflow" % [token, def.id])
	# Footer: left + center + right must fit; the composer may drop the center.
	var footer_rect: Rect2 = zones["footer"]
	var footer_size := int(metrics["footer"])
	var set_code := def.set_id.get_slice(".", 1).to_upper() if def.set_id.contains(".") else def.set_id.to_upper()
	var left := "%s · %s" % [GameConst.rarity_letter(def.rarity), set_code]
	var left_w := data_font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, footer_size).x
	var right_w := data_font.get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, footer_size).x
	if left_w + right_w + 18.0 > footer_rect.size.x:
		failures.append("%s/%s: footer cells overflow" % [token, def.id])
	# Stat plate: label + value must fit in a cell.
	var stats_rect: Rect2 = zones["stats"]
	var cell_w := stats_rect.size.x / 3.0
	var label_size := int(metrics["label"])
	var stat_size := int(metrics["stat"])
	var labels := [["ATK", "9999"], ["DEF", "9999"], ["OFFER", "99"], ["POWER", "99"], ["QUALITY", "100%"], ["MODS", "4"]]
	if token in ["S", "B", "B-", "B+", "T", "O", "A", "M", "H", "H-", "H+"]:
		labels = [["ATK", "9999"], ["DEF", "9999"], ["OFR", "99"], ["PWR", "99"], ["Q", "100%"], ["MOD", "4"]]
	elif token == "L":
		labels = [["ATK", "9999"], ["DEF", "9999"], ["OFFER", "99"], ["PWR", "99"], ["QUAL", "100%"], ["MOD", "4"]]
	for pair in labels:
		var label_w := ui_font.get_string_size(str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, label_size).x
		var value_gap := 4.0 if token in ["B-", "H-", "T"] else 8.0
		var available := cell_w - label_w - value_gap
		var fitted := UI.fit_font_size(Tokens.font_data(), str(pair[1]), available, stat_size, maxi(5, stat_size - 4))
		var value_w := Tokens.font_data().get_string_size(str(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
		if available <= 0.0 or value_w > available + 0.5:
			failures.append("%s/%s: stat cell overflow %s" % [token, def.id, pair[0]])
			break
	return failures
