class_name CardInstance
extends RefCounted

## One physical copy. Plain copies may stack in the collection; anything with a
## mod, quality, name, honour, lock, or corruption is an individual instance.

var instance_id: int = 0
var def_id: String = ""
var provenance: int = 1
var quality: int = 0
var mods: Array[Dictionary] = []
var ink_id: String = "ink.iron"
var shimmer_id: String = "shimmer.none"
var corrupted: bool = false
var fractured_mod: String = ""
var locked: bool = false
var favorite: bool = false
var custom_name: String = ""
var parent_instance_id: int = 0
var created_at: int = 0
var origin: String = "unknown"
var honours: Array[Dictionary] = []
var history: Array[Dictionary] = []
var deck_bound: bool = false

func _init(id: int = 0, def_id_value: String = "", provenance_value: int = 1) -> void:
	instance_id = id
	def_id = def_id_value
	provenance = clampi(provenance_value, 1, 100)

func has_mod(mod_id: String) -> bool:
	for mod in mods:
		if str(mod.get("id", "")) == mod_id:
			return true
	return false

func mod_tier(mod_id: String) -> int:
	for mod in mods:
		if str(mod.get("id", "")) == mod_id:
			return int(mod.get("tier", 1))
	return 0

func mod_value(mod_id: String) -> int:
	for mod in mods:
		if str(mod.get("id", "")) == mod_id:
			return int(mod.get("value", 0))
	return 0

func add_mod(mod_id: String, tier: int, value: int) -> void:
	mods.append({"id": mod_id, "tier": tier, "value": value})

func remove_mod(mod_id: String) -> void:
	for i in range(mods.size() - 1, -1, -1):
		if str(mods[i].get("id", "")) == mod_id:
			mods.remove_at(i)

func quality_multiplier() -> float:
	return 1.0 + float(quality) / 100.0

func is_plain() -> bool:
	return mods.is_empty() and quality == 0 and custom_name.is_empty() \
		and honours.is_empty() and not corrupted and not locked and not favorite \
		and fractured_mod.is_empty()

func is_unique() -> bool:
	return not is_plain()

func is_crafted() -> bool:
	return not mods.is_empty() or quality > 0 or corrupted or not fractured_mod.is_empty()

func has_honour(honour_id: String) -> bool:
	for honour in honours:
		if str(honour.get("id", "")) == honour_id:
			return true
	return false

func add_honour(honour_id: String, ref_value: String = "", at: int = 0) -> void:
	if has_honour(honour_id):
		return
	honours.append({"id": honour_id, "ref": ref_value, "at": at})

func add_history(kind: String, detail: String, at: int = 0) -> void:
	history.append({"kind": kind, "detail": detail, "at": at})

func display_name(def: CardDef) -> String:
	if not custom_name.is_empty():
		return custom_name
	return def.name if def != null else def_id

func clone(new_id: int = 0) -> CardInstance:
	var copy := CardInstance.new(new_id if new_id > 0 else instance_id, def_id, provenance)
	copy.quality = quality
	copy.ink_id = ink_id
	copy.shimmer_id = shimmer_id
	copy.corrupted = corrupted
	copy.fractured_mod = fractured_mod
	copy.locked = locked
	copy.favorite = favorite
	copy.custom_name = custom_name
	copy.parent_instance_id = parent_instance_id
	copy.created_at = created_at
	copy.origin = origin
	copy.deck_bound = deck_bound
	copy.mods.clear()
	for mod in mods:
		copy.mods.append(mod.duplicate(true))
	copy.honours.clear()
	for honour in honours:
		copy.honours.append(honour.duplicate(true))
	copy.history.clear()
	for entry in history:
		copy.history.append(entry.duplicate(true))
	return copy

func to_dict() -> Dictionary:
	var mod_list: Array = []
	for mod in mods:
		mod_list.append(mod.duplicate(true))
	var honour_list: Array = []
	for honour in honours:
		honour_list.append(honour.duplicate(true))
	var history_list: Array = []
	for entry in history:
		history_list.append(entry.duplicate(true))
	return {
		"id": instance_id,
		"def_id": def_id,
		"provenance": provenance,
		"quality": quality,
		"mods": mod_list,
		"ink_id": ink_id,
		"shimmer_id": shimmer_id,
		"corrupted": corrupted,
		"fractured_mod": fractured_mod,
		"locked": locked,
		"favorite": favorite,
		"custom_name": custom_name,
		"parent_instance_id": parent_instance_id,
		"created_at": created_at,
		"origin": origin,
		"honours": honour_list,
		"history": history_list,
		"deck_bound": deck_bound,
	}

static func from_dict(data: Dictionary) -> CardInstance:
	var card := CardInstance.new(
		int(data.get("id", 0)),
		str(data.get("def_id", "")),
		int(data.get("provenance", 1))
	)
	card.quality = int(data.get("quality", 0))
	card.ink_id = str(data.get("ink_id", "ink.iron"))
	card.shimmer_id = str(data.get("shimmer_id", "shimmer.none"))
	card.corrupted = bool(data.get("corrupted", false))
	card.fractured_mod = str(data.get("fractured_mod", ""))
	card.locked = bool(data.get("locked", false))
	card.favorite = bool(data.get("favorite", false))
	card.custom_name = str(data.get("custom_name", ""))
	card.parent_instance_id = int(data.get("parent_instance_id", 0))
	card.created_at = int(data.get("created_at", 0))
	card.origin = str(data.get("origin", "unknown"))
	card.deck_bound = bool(data.get("deck_bound", false))
	card.mods.clear()
	for raw in data.get("mods", []):
		if raw is Dictionary:
			card.mods.append({
				"id": str(raw.get("id", "")),
				"tier": int(raw.get("tier", 1)),
				"value": int(raw.get("value", 0)),
			})
	card.honours.clear()
	for raw in data.get("honours", []):
		if raw is Dictionary:
			card.honours.append(raw.duplicate(true))
	card.history.clear()
	for raw in data.get("history", []):
		if raw is Dictionary:
			card.history.append(raw.duplicate(true))
	return card
