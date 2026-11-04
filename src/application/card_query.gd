class_name CardQuery
extends RefCounted

## Shared collection query for the Library and Deck Workshop. The UI never
## scans a node tree; it asks this projection for entries and facet values.

const BANDS := {
	"quality": ["0", "1-24", "25-49", "50-74", "75-99", "100"],
	"provenance": ["1-10", "11-20", "21-50", "51-100"],
}

static func empty_query() -> Dictionary:
	return {
		"search": "",
		"type": [],
		"attribute": [],
		"rarity": [],
		"offer": [],
		"set": [],
		"lineage": [],
		"subtype": [],
		"role": [],
		"keyword": [],
		"craft": [],
		"quality": [],
		"provenance": [],
		"ink": [],
		"shimmer": [],
		"mod": [],
		"deck": [],
		"flags": [],
		"sort": "name",
		"desc": false,
	}

static func normalize(raw: Dictionary) -> Dictionary:
	var query := empty_query()
	for key in query.keys():
		if raw.has(key):
			query[key] = raw[key]
	return query

static func query_with(raw: Dictionary, key: String, value) -> Dictionary:
	var query := normalize(raw)
	query[key] = value
	return query

static func project(entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in entries:
		if not entry is Dictionary:
			continue
		var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
		if def == null:
			continue
		var instance: CardInstance = entry.get("best_instance")
		var stacks: Array = entry.get("stacks", [])
		var provenance := 0
		var ink_set: Dictionary = {}
		var shimmer_set: Dictionary = {}
		var quality := 0
		var mod_ids: Dictionary = {}
		var locked := false
		var favorite := false
		var crafted := false
		var named := false
		var honoured := false
		var corrupted := false
		var fractured := false
		for stack in stacks:
			provenance = maxi(provenance, int(stack.get("provenance", 1)))
			ink_set[str(stack.get("ink_id", "ink.iron"))] = true
			shimmer_set[str(stack.get("shimmer_id", "shimmer.none"))] = true
		if instance != null:
			provenance = maxi(provenance, instance.provenance)
			quality = instance.quality
			crafted = instance.is_crafted()
			named = not instance.custom_name.is_empty()
			honoured = not instance.honours.is_empty()
			corrupted = instance.corrupted
			fractured = not instance.fractured_mod.is_empty()
			locked = instance.locked
			favorite = instance.favorite
			ink_set[instance.ink_id] = true
			shimmer_set[instance.shimmer_id] = true
			for mod in instance.mods:
				mod_ids[str(mod.get("id", ""))] = true
		var deck: DeckModel = Session.active_deck()
		var in_main := false
		var in_side := false
		if deck != null:
			for raw_id in entry.get("plain_ids", []):
				if deck.main.has(int(raw_id)):
					in_main = true
				if deck.side.has(int(raw_id)):
					in_side = true
			if instance != null:
				in_main = in_main or deck.main.has(instance.instance_id)
				in_side = in_side or deck.side.has(instance.instance_id)
		var keywords: Dictionary = {}
		for keyword in def.keywords:
			keywords[str(keyword).to_upper()] = true
		result.append({
			"entry": entry,
			"def": def,
			"instance": instance,
			"kind": str(entry.get("kind", "")),
			"provenance": provenance,
			"quality": quality,
			"ink": ink_set,
			"shimmer": shimmer_set,
			"keywords": keywords,
			"mods": mod_ids,
			"crafted": crafted,
			"named": named,
			"honoured": honoured,
			"corrupted": corrupted,
			"fractured": fractured,
			"locked": locked,
			"favorite": favorite,
			"decked": bool(entry.get("decked", false)),
			"in_main": in_main,
			"in_side": in_side,
			"count": int(entry.get("count", 1)),
		})
	return result

static func filter(entries: Array, raw_query: Dictionary) -> Array[Dictionary]:
	var query := normalize(raw_query)
	var projected := project(entries)
	var result: Array[Dictionary] = []
	for row in projected:
		if _matches(row, query):
			result.append(row["entry"])
	_sort(result, query)
	return result

static func _matches(row: Dictionary, query: Dictionary) -> bool:
	var def: CardDef = row["def"]
	if not _matches_any(query["type"], def.type):
		return false
	if not _matches_any(query["attribute"], def.attribute):
		return false
	if not _matches_any(query["rarity"], def.rarity):
		return false
	if not _matches_any(query["offer"], str(def.offer)):
		return false
	if not _matches_any(query["set"], def.set_id):
		return false
	if not _matches_any(query["lineage"], def.lineage):
		return false
	if not _matches_any(query["subtype"], def.subtype):
		return false
	if not _matches_any(query["role"], def.role):
		return false
	if not _matches_any(query["keyword"], row["keywords"].keys()):
		return false
	if not _matches_any(query["ink"], row["ink"].keys()):
		return false
	if not _matches_any(query["shimmer"], row["shimmer"].keys()):
		return false
	if not _matches_any(query["mod"], row["mods"].keys()):
		return false
	if not _matches_any(query["quality"], [quality_band(int(row["quality"]))]):
		return false
	if not _matches_any(query["provenance"], [provenance_band(int(row["provenance"]))]):
		return false
	if not _matches_any(query["craft"], _craft_states(row)):
		return false
	if not _matches_any(query["deck"], _deck_states(row)):
		return false
	if not _matches_any(query["flags"], _flag_states(row)):
		return false
	var search := str(query.get("search", "")).strip_edges().to_lower()
	if not search.is_empty():
		var haystack := (def.name + " " + def.text + " " + def.type_line + " " + def.set_id + " " + " ".join(def.keywords)).to_lower()
		if not haystack.contains(search):
			return false
	return true

static func _matches_any(selected, value) -> bool:
	if selected == null:
		return true
	if selected is Array:
		if selected.is_empty():
			return true
		if value is Array:
			for candidate in value:
				if selected.has(str(candidate)) or selected.has(candidate):
					return true
			return false
		return selected.has(value) or selected.has(str(value))
	if value is Array:
		return value.has(selected)
	return value == selected

static func _craft_states(row: Dictionary) -> Array[String]:
	var states: Array[String] = ["plain"]
	if bool(row["crafted"]):
		states.append("crafted")
	if not row["mods"].is_empty() or int(row["quality"]) > 0:
		states.append("modded")
	if bool(row["fractured"]):
		states.append("fractured")
	if bool(row["corrupted"]):
		states.append("corrupted")
	if bool(row["named"]):
		states.append("named")
	if bool(row["honoured"]):
		states.append("honoured")
	return states

static func _deck_states(row: Dictionary) -> Array[String]:
	var states: Array[String] = []
	if bool(row["in_main"]):
		states.append("main")
	if bool(row["in_side"]):
		states.append("side")
	if not bool(row["in_main"]) and not bool(row["in_side"]):
		states.append("not")
	states.append("deckable")
	return states

static func _flag_states(row: Dictionary) -> Array[String]:
	var states: Array[String] = []
	if bool(row["locked"]):
		states.append("locked")
	if bool(row["favorite"]):
		states.append("favorite")
	return states

static func quality_band(value: int) -> String:
	if value <= 0:
		return "0"
	if value < 25:
		return "1-24"
	if value < 50:
		return "25-49"
	if value < 75:
		return "50-74"
	if value < 100:
		return "75-99"
	return "100"

static func provenance_band(value: int) -> String:
	if value <= 10:
		return "1-10"
	if value <= 20:
		return "11-20"
	if value <= 50:
		return "21-50"
	return "51-100"

static func _sort(entries: Array[Dictionary], query: Dictionary) -> void:
	var key := str(query.get("sort", "name"))
	var descending := bool(query.get("desc", false))
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_def: CardDef = Content.cards.get(str(a.get("def_id", "")))
		var b_def: CardDef = Content.cards.get(str(b.get("def_id", "")))
		var a_name := a_def.name if a_def != null else str(a.get("def_id", ""))
		var b_name := b_def.name if b_def != null else str(b.get("def_id", ""))
		var cmp := 0
		match key:
			"power":
				cmp = Session.entry_power(a) - Session.entry_power(b)
			"rarity":
				cmp = int(GameConst.RARITY_ORDER.get(a_def.rarity, 0) if a_def != null else 0) - int(GameConst.RARITY_ORDER.get(b_def.rarity, 0) if b_def != null else 0)
			"provenance":
				cmp = _max_provenance(a) - _max_provenance(b)
			"count":
				cmp = int(a.get("count", 0)) - int(b.get("count", 0))
			"quality":
				cmp = _max_quality(a) - _max_quality(b)
			"mods":
				cmp = _mod_count(a) - _mod_count(b)
			"offer":
				cmp = int(a_def.offer if a_def != null else 0) - int(b_def.offer if b_def != null else 0)
			_:
				cmp = a_name.naturalnocasecmp_to(b_name)
		if cmp == 0:
			cmp = a_name.naturalnocasecmp_to(b_name)
		if cmp == 0:
			cmp = str(a.get("def_id", "")).naturalnocasecmp_to(str(b.get("def_id", "")))
		if cmp == 0:
			cmp = str(a.get("best_instance", null)).naturalnocasecmp_to(str(b.get("best_instance", null)))
		return cmp > 0 if descending else cmp < 0
	)

static func _max_provenance(entry: Dictionary) -> int:
	var value := 0
	for stack in entry.get("stacks", []):
		value = maxi(value, int(stack.get("provenance", 1)))
	var instance: CardInstance = entry.get("best_instance")
	if instance != null:
		value = maxi(value, instance.provenance)
	return value

static func _max_quality(entry: Dictionary) -> int:
	var instance: CardInstance = entry.get("best_instance")
	return instance.quality if instance != null else 0

static func _mod_count(entry: Dictionary) -> int:
	var instance: CardInstance = entry.get("best_instance")
	return instance.mods.size() if instance != null else 0

static func selection_key(entry: Dictionary) -> String:
	var instance: CardInstance = entry.get("best_instance")
	var instance_id := instance.instance_id if instance != null else 0
	return "%s|%s|%d" % [str(entry.get("def_id", "")), str(entry.get("kind", "")), instance_id]

static func facet_values() -> Dictionary:
	return {
		"type": ["monster", "spell", "trap"],
		"attribute": ["ember", "tide", "verdant", "umbra", "neutral"],
		"rarity": ["common", "uncommon", "rare", "legendary"],
		"offer": ["0", "1", "2"],
		"set": ["set.core"],
		"lineage": ["beast", "spirit", "construct", "wanderer"],
		"subtype": ["monster", "normal", "continuous", "equip", "counter"],
		"role": ["resource", "threat", "answer", "glue", "payoff", "draw", "enabler"],
		"keyword": ["KINDLE", "ECHO", "FLIP", "PIERCE", "FLEET", "VEIL", "BIND", "RITE", "BANISH", "OFFER", "SET", "CHAIN"],
		"craft": ["plain", "crafted", "modded", "fractured", "corrupted", "named", "honoured"],
		"quality": BANDS["quality"],
		"provenance": BANDS["provenance"],
		"ink": ["ink.iron", "ink.verdigris", "ink.dusk", "ink.ember", "ink.frost", "ink.bone"],
		"shimmer": ["shimmer.none", "shimmer.gilt", "shimmer.iridescent", "shimmer.verdigris", "shimmer.moon"],
		"mod": [],
		"deck": ["main", "side", "not", "deckable"],
		"flags": ["locked", "favorite"],
	}
