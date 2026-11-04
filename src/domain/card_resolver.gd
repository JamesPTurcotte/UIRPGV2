class_name CardResolver
extends RefCounted

## The single stat-layer implementation. Printed base -> quality -> mods ->
## equips/lane auras -> temporary effects. Integer math, floored per layer,
## clamped at 0. The inspector and the AI read this same breakdown.

static func _mod_def(mod_db: Dictionary, mod_id: String) -> Dictionary:
	var raw = mod_db.get(mod_id, {})
	return raw if raw is Dictionary else {}

static func _mod_value(mod_def: Dictionary, tier: int) -> int:
	var values = mod_def.get("values", {})
	if values is Dictionary:
		return int(values.get(str(tier), values.get(tier, 0)))
	return 0

static func _mod_power(mod_def: Dictionary, tier: int) -> int:
	var values = mod_def.get("power", {})
	if values is Dictionary:
		return int(values.get(str(tier), values.get(tier, 0)))
	return 0

static func quality_atk(base: int, quality: int) -> int:
	return (base * clampi(quality, 0, 20)) / 100

static func effective_stats(
	instance: CardInstance,
	def: CardDef,
	mod_db: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var in_defense := bool(context.get("in_defense", false))
	var lane_buff := int(context.get("lane_buff", 0))
	var temp_atk := int(context.get("temp_atk", 0))
	var temp_def := int(context.get("temp_def", 0))
	var base_atk := def.atk if def != null and def.is_monster() else 0
	var base_def := def.defense if def != null and def.is_monster() else 0
	var quality_atk_bonus := quality_atk(base_atk, instance.quality)
	var quality_def_bonus := quality_atk(base_def, instance.quality)
	var mod_atk := 0
	var mod_def := 0
	var offer_value := def.offer if def != null else 0

	for mod in instance.mods:
		var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
		if mod_def_data.is_empty():
			continue
		var tier := int(mod.get("tier", 1))
		var value := int(mod.get("value", _mod_value(mod_def_data, tier)))
		var stat := str(mod_def_data.get("stat", ""))
		var condition := str(mod_def_data.get("condition", ""))
		match stat:
			"atk":
				mod_atk += value
			"defense":
				if condition == "defense_only" and not in_defense:
					continue
				mod_def += value
			"offer":
				offer_value += value
			_:
				pass

	var atk := maxi(0, base_atk + quality_atk_bonus + mod_atk + lane_buff + temp_atk)
	var defense := maxi(0, base_def + quality_def_bonus + mod_def + temp_def)
	offer_value = maxi(0, offer_value)
	return {
		"atk": atk,
		"defense": defense,
		"offer": offer_value,
		"atk_base": base_atk,
		"atk_quality": quality_atk_bonus,
		"atk_mods": mod_atk,
		"atk_lane": lane_buff,
		"atk_temp": temp_atk,
		"def_base": base_def,
		"def_quality": quality_def_bonus,
		"def_mods": mod_def,
		"def_temp": temp_def,
	}

static func offer_cost(instance: CardInstance, def: CardDef, mod_db: Dictionary) -> int:
	if def == null or not def.is_monster():
		return 0
	var offer_value := def.offer
	for mod in instance.mods:
		var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
		if str(mod_def_data.get("stat", "")) == "offer":
			offer_value += int(mod.get("value", 0))
	return maxi(0, offer_value)

static func keyword_set(instance: CardInstance, def: CardDef, mod_db: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if def != null:
		for keyword in def.keywords:
			result[keyword] = true
	for mod in instance.mods:
		var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
		for grant in mod_def_data.get("grants", []):
			result[str(grant)] = true
	return result

static func has_keyword(instance: CardInstance, def: CardDef, mod_db: Dictionary, keyword: String) -> bool:
	return keyword_set(instance, def, mod_db).has(keyword)

static func power(instance: CardInstance, def: CardDef, mod_db: Dictionary) -> int:
	if def == null:
		return 0
	var stats := effective_stats(instance, def, mod_db)
	var effect_value := def.effect_value
	var mod_power := 0
	for mod in instance.mods:
		var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
		mod_power += _mod_power(mod_def_data, int(mod.get("tier", 1)))
	var value := float(stats["atk"]) / 100.0 + float(stats["defense"]) / 150.0 \
		+ float(stats["offer"]) * 1.5 + float(effect_value)
	return int(floor(value)) + mod_power

static func mod_text(mod: Dictionary, mod_db: Dictionary) -> String:
	var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
	var template := str(mod_def_data.get("text", ""))
	return template.replace("{value}", str(int(mod.get("value", 0))))

static func mod_name(mod: Dictionary, mod_db: Dictionary) -> String:
	var mod_def_data := _mod_def(mod_db, str(mod.get("id", "")))
	return str(mod_def_data.get("name", mod.get("id", "")))

static func mod_lines(instance: CardInstance, mod_db: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for mod in instance.mods:
		var tier := int(mod.get("tier", 1))
		var roman_values: Array[String] = ["", "I", "II", "III", "IV", "V"]
		var roman: String = roman_values[clampi(tier, 0, 5)]
		lines.append("%s [%s] %s" % [mod_name(mod, mod_db), roman, mod_text(mod, mod_db)])
	return lines

static func quality_label(instance: CardInstance) -> String:
	return "%d%%" % instance.quality

static func deck_power(instances: Array, defs: Dictionary, mod_db: Dictionary) -> int:
	var total := 0
	for item in instances:
		if item is CardInstance:
			var def: CardDef = defs.get(item.def_id)
			total += power(item, def, mod_db)
	return total
