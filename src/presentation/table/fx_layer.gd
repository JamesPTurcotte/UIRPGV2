class_name FxLayer
extends Control

## Procedural combat feedback: floating numbers, expanding rings, arrows, and
## impact glyphs. The layer is input-transparent and never covers card text
## with a persistent element.

var effects: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

func _process(delta: float) -> void:
	if effects.is_empty():
		return
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["age"] = float(effects[i].get("age", 0.0)) + delta
		if float(effects[i]["age"]) >= float(effects[i].get("duration", 0.5)):
			effects.remove_at(i)
	queue_redraw()

func float_number(position: Vector2, text: String, color: Color, size: int = 24, duration: float = 0.65) -> void:
	effects.append({"kind": "number", "pos": position, "text": text, "color": color, "size": size, "age": 0.0, "duration": duration})

func ring(position: Vector2, color: Color, radius: float = 26.0, duration: float = 0.38) -> void:
	effects.append({"kind": "ring", "pos": position, "color": color, "radius": radius, "age": 0.0, "duration": duration})

func arrow(from: Vector2, to: Vector2, color: Color, width: float = 2.0, duration: float = 0.32) -> void:
	effects.append({"kind": "arrow", "from": from, "to": to, "color": color, "width": width, "age": 0.0, "duration": duration})

func spark(position: Vector2, color: Color, duration: float = 0.30) -> void:
	effects.append({"kind": "spark", "pos": position, "color": color, "age": 0.0, "duration": duration})

func plate(position: Vector2, value: String, label: String, color: Color, duration: float = 0.95) -> void:
	effects.append({"kind": "plate", "pos": position, "value": value, "label": label, "color": color, "age": 0.0, "duration": duration})

func _draw() -> void:
	var font := Tokens.font_data()
	for effect in effects:
		var age := float(effect.get("age", 0.0))
		var duration := maxf(0.001, float(effect.get("duration", 0.5)))
		var t := clampf(age / duration, 0.0, 1.0)
		var alpha := 1.0 - t
		var color: Color = effect.get("color", Tokens.BRASS_HI)
		match str(effect.get("kind", "")):
			"number":
				var pos: Vector2 = effect.get("pos", Vector2.ZERO) + Vector2(0, -28.0 * t)
				var text := str(effect.get("text", ""))
				var size := int(effect.get("size", 24))
				draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8 * alpha))
				draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color * Color(1, 1, 1, alpha))
			"ring":
				var radius := float(effect.get("radius", 26.0)) * (0.55 + t * 0.75)
				draw_arc(effect.get("pos", Vector2.ZERO), radius, 0.0, TAU, 32, color * Color(1, 1, 1, alpha * 0.8), 2.0, true)
			"arrow":
				var from: Vector2 = effect.get("from", Vector2.ZERO)
				var to: Vector2 = effect.get("to", Vector2.ZERO)
				draw_line(from, to, color * Color(1, 1, 1, alpha), float(effect.get("width", 2.0)), true)
				var dir := (to - from).normalized()
				var normal := Vector2(-dir.y, dir.x)
				draw_colored_polygon(PackedVector2Array([to, to - dir * 10.0 + normal * 5.0, to - dir * 10.0 - normal * 5.0]), color * Color(1, 1, 1, alpha))
			"spark":
				var center: Vector2 = effect.get("pos", Vector2.ZERO)
				for i in range(5):
					var angle := TAU * float(i) / 5.0 + 0.3
					var length := 8.0 + 18.0 * t
					draw_line(center, center + Vector2(cos(angle), sin(angle)) * length, color * Color(1, 1, 1, alpha), 2.0, true)
			"plate":
				var center: Vector2 = effect.get("pos", Vector2.ZERO) + Vector2(0, -22.0 * t)
				var pop := 1.0 + 0.16 * maxf(0.0, 1.0 - t * 5.0)
				var plate_size := Vector2(164, 62) * pop
				var rect := Rect2(center - plate_size * 0.5, plate_size)
				var fill := Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.92 * alpha)
				var border := Color(color.r, color.g, color.b, 0.62 * alpha)
				Chrome.draw_cut_rect(self, rect, 7.0, fill)
				Chrome.draw_cut_outline(self, rect, 7.0, border, 1.0)
				draw_rect(Rect2(rect.position.x + 6, rect.position.y + rect.size.y - 3, rect.size.x - 12, 1), Color(color.r, color.g, color.b, 0.32 * alpha))
				Chrome.text_center(self, Tokens.font_label(), rect.get_center().x, rect.position.y + 18, str(effect.get("label", "")).to_upper(), 8, Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, alpha))
				var value := str(effect.get("value", ""))
				var value_width := Tokens.font_data().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
				draw_string(Tokens.font_data(), Vector2(rect.get_center().x - value_width * 0.5, rect.position.y + 52), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, color * Color(1, 1, 1, alpha))
