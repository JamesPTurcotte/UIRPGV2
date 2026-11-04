class_name CraftService
extends RefCounted

## Deterministic craft operations. Costs are deterministic; outcomes are random.
## No operation changes the card silhouette: only mods, quality, and finish.

static func apply(instance: CardInstance, reagent_id: String, rng: GameRng, mod_db: Dictionary) -> Dictionary:
	if instance == null:
		return _fail("No card on the stand.")
	if instance.locked:
		return _fail("This copy is locked.")
	if instance.corrupted:
		return _fail("Corrupted. Further crafting is locked.")
	match reagent_id:
		"reagent.pale_ink":
			if not instance.mods.is_empty():
				return _fail("Already Inscribed. Pale Ink only affects a plain card.")
			var rolled := _roll_mod(instance, GameConst.MOD_PREFIX, rng, mod_db, false)
			if not bool(rolled.get("ok", false)):
				rolled = _roll_mod(instance, GameConst.MOD_SUFFIX, rng, mod_db, false)
			if not bool(rolled.get("ok", false)):
				return _fail("No eligible mod at this provenance.")
			return rolled
		"reagent.deep_ink":
			if instance.mods.size() >= 4:
				return _fail("Four mods is the maximum.")
			var kind := GameConst.MOD_PREFIX if rng.chance(0.5) else GameConst.MOD_SUFFIX
			var rolled := _roll_mod(instance, kind, rng, mod_db, false)
			if not bool(rolled.get("ok", false)):
				rolled = _roll_mod(instance, GameConst.MOD_SUFFIX if kind == GameConst.MOD_PREFIX else GameConst.MOD_PREFIX, rng, mod_db, false)
			if not bool(rolled.get("ok", false)):
				return _fail("No eligible mod at this provenance.")
			return rolled
		"reagent.prism_ink", "reagent.crucible":
			if instance.mods.is_empty():
				return _fail("No mods to reroll.")
			return _reroll(instance, rng, mod_db)
		"reagent.solvent":
			var removable: Array[Dictionary] = []
			for mod in instance.mods:
				if str(mod.get("id", "")) != instance.fractured_mod:
					removable.append(mod)
			if removable.is_empty():
				return _fail("No removable mod. The fractured mod is pinned.")
			var chosen: Dictionary = rng.pick(removable)
			var removed_name := CardResolver.mod_name(chosen, mod_db)
			instance.remove_mod(str(chosen.get("id", "")))
			return _ok("Removed %s." % removed_name, {"removed": removed_name})
		"reagent.varnish":
			if instance.quality >= 20:
				return _fail("Quality is already 20%.")
			var gain := rng.range_int(1, 3)
			var before := instance.quality
			instance.quality = mini(20, instance.quality + gain)
			return _ok("Quality %d%% -> %d%%." % [before, instance.quality], {"quality": instance.quality})
		"reagent.fracture":
			if not instance.fractured_mod.is_empty():
				return _fail("One mod is already fractured.")
			if instance.mods.is_empty():
				return _fail("No mods to fracture.")
			var candidates: Array[Dictionary] = []
			for mod in instance.mods:
				if str(mod.get("id", "")) != instance.fractured_mod:
					candidates.append(mod)
			if candidates.is_empty():
				return _fail("No mod can be pinned.")
			var chosen: Dictionary = rng.pick(candidates)
			instance.fractured_mod = str(chosen.get("id", ""))
			return _ok("Fractured %s. It survives rerolls." % CardResolver.mod_name(chosen, mod_db), {"fractured": instance.fractured_mod})
		"reagent.verdigris":
			if instance.mods.size() >= 4:
				return _fail("Remove a mod before corruption.")
			var rolled := _roll_mod(instance, GameConst.MOD_VERDIGRIS, rng, mod_db, false)
			if not bool(rolled.get("ok", false)):
				return _fail("No Verdigris mod available.")
			instance.corrupted = true
			return rolled
		"reagent.gold_leaf":
			if instance.shimmer_id != "shimmer.none":
				return _fail("This card already has a shimmer.")
			var options := ["shimmer.gilt", "shimmer.iridescent", "shimmer.verdigris", "shimmer.moon"]
			instance.shimmer_id = str(rng.pick(options))
			return _ok("Gold Leaf applied: %s." % instance.shimmer_id.capitalize(), {"shimmer": instance.shimmer_id})
		"reagent.echo":
			return {"ok": true, "message": "Echo prepared.", "duplicate": true, "consumed": true}
		_:
			return _fail("Unknown reagent.")

static func _roll_mod(instance: CardInstance, kind: String, rng: GameRng, mod_db: Dictionary, allow_duplicate: bool = false) -> Dictionary:
	var max_tier := GameConst.tier_for_provenance(instance.provenance)
	var eligible: Array[Dictionary] = []
	for mod_id in mod_db.keys():
		var mod_def: Dictionary = mod_db[mod_id]
		if str(mod_def.get("kind", "")) != kind:
			continue
		if int(mod_def.get("tier_min", 1)) > max_tier:
			continue
		if not allow_duplicate and instance.has_mod(str(mod_id)):
			continue
		var incompatible: Array = mod_def.get("incompatible", [])
		var blocked := false
		for other_id in incompatible:
			if instance.has_mod(str(other_id)):
				blocked = true
				break
		if blocked:
			continue
		eligible.append(mod_def)
	if eligible.is_empty():
		return _fail("No eligible %s mod at provenance %d." % [kind, instance.provenance])
	var chosen = rng.pick_weighted(eligible, "weight")
	if chosen == null or not (chosen is Dictionary):
		return _fail("No eligible mod.")
	var chosen_def: Dictionary = chosen
	var tier_ceiling := mini(int(chosen_def.get("tier_max", 5)), max_tier)
	var tier_floor := int(chosen_def.get("tier_min", 1))
	var tier := rng.range_int(tier_floor, tier_ceiling)
	var values: Dictionary = chosen_def.get("values", {})
	var value := int(values.get(str(tier), values.get(tier, 0)))
	var mod_id := str(chosen_def.get("id", ""))
	instance.add_mod(mod_id, tier, value)
	var roman_values: Array[String] = ["", "I", "II", "III", "IV", "V"]
	var roman: String = roman_values[clampi(tier, 0, 5)]
	var text := str(chosen_def.get("text", "")).replace("{value}", str(value))
	return _ok("%s [%s] %s" % [str(chosen_def.get("name", mod_id)), roman, text], {
		"mod_id": mod_id,
		"tier": tier,
		"value": value,
		"text": text,
	})

static func _reroll(instance: CardInstance, rng: GameRng, mod_db: Dictionary) -> Dictionary:
	var kept: Array[Dictionary] = []
	for mod in instance.mods:
		if str(mod.get("id", "")) == instance.fractured_mod:
			kept.append(mod)
	var old_count := instance.mods.size()
	instance.mods.clear()
	for mod in kept:
		instance.mods.append(mod)
	var fresh: Array[String] = []
	while instance.mods.size() < old_count:
		var kind := GameConst.MOD_PREFIX if rng.chance(0.5) else GameConst.MOD_SUFFIX
		var rolled := _roll_mod(instance, kind, rng, mod_db, false)
		if not bool(rolled.get("ok", false)):
			rolled = _roll_mod(instance, GameConst.MOD_SUFFIX if kind == GameConst.MOD_PREFIX else GameConst.MOD_PREFIX, rng, mod_db, false)
		if not bool(rolled.get("ok", false)):
			break
		fresh.append(str(rolled.get("text", "")))
	return _ok("Rerolled %d mods." % fresh.size(), {"rerolled": fresh})

static func _ok(message: String, detail: Dictionary = {}) -> Dictionary:
	return {"ok": true, "message": message, "consumed": true, "detail": detail, "duplicate": false}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "consumed": false, "detail": {}, "duplicate": false}
