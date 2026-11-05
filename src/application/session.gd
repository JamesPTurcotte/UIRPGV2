extends Node

## Player session: save document, collection binder, decks, crafting bench,
## pack satchel, and the active Descent. Presentation reads this; it never
## mutates rules directly.

signal game_ready
signal collection_changed
signal currency_changed
signal decks_changed
signal packs_changed
signal folios_changed # Legacy alias; remove after the compatibility window.
signal descent_changed
signal toast(message: String, kind: String)

const STARTER_ID := "starter.ember"
const STARTING_MARKS := 500

var store := SaveStore.new()
var loaded: bool = false
var meta: Dictionary = {}
var currency: Dictionary = {"marks": STARTING_MARKS}
var reagents: Dictionary = {}
var instances: Dictionary = {}
var stacks: Array[Dictionary] = []
var decks: Dictionary = {}
var active_deck_id: int = 0
var packs: Array[Dictionary] = []
var codex: Dictionary = {}
var settings: Dictionary = {}
var descent: Dictionary = {}
var last_result: Dictionary = {}
var first_clear_floors: Array[int] = []
var unlocked_floor: int = 1
var deepest_floor: int = 0
var best_streak: int = 0
var next_instance_id: int = 1
var next_deck_id: int = 1
var next_pack_id: int = 1

var bench_instance_id: int = 0
var bench_origin: String = ""
var bench_dirty: bool = false
var active_duel_state: DuelState
var test_mode: bool = false

func _ready() -> void:
	if not Content.loaded:
		push_error("Session: content did not load; cannot start.")
		return
	var doc := store.load_save()
	if doc.is_empty():
		new_game()
	else:
		_load_doc(doc)

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func default_settings() -> Dictionary:
	return {
		"theme": "lacquer",
		"ui_scale": 1.0,
		"hud": "calm",
		"mode": "auto",
		"reduced_motion": false,
		"show_log": true,
		"table_speed": 1,
		"route_policy": "safe",
		"library_query": {},
		"deck_query": {},
		"pack_mode": "ritual",
		"library_sort": "name",
		"deck_sort": "name",
		"saved_views": [],
		"hints_seen": {},
	}

func _emit_packs_changed() -> void:
	packs_changed.emit()
	folios_changed.emit()

## ---------------------------------------------------------------- new game

func new_game(starter_id: String = STARTER_ID, seed_value: int = 0) -> void:
	instances.clear()
	stacks.clear()
	decks.clear()
	packs.clear()
	codex.clear()
	first_clear_floors.clear()
	currency = {"marks": STARTING_MARKS}
	reagents = {
		"reagent.pale_ink": 10,
		"reagent.prism_ink": 2,
		"reagent.deep_ink": 2,
		"reagent.solvent": 3,
		"reagent.varnish": 4,
		"reagent.fracture": 1,
		"reagent.crucible": 0,
		"reagent.verdigris": 1,
		"reagent.echo": 0,
		"reagent.gold_leaf": 0,
	}
	settings = default_settings()
	meta = {"created_at": _now(), "player_name": "Keeper"}
	descent = {}
	last_result = {}
	unlocked_floor = 1
	deepest_floor = 0
	best_streak = 0
	next_instance_id = 1
	next_deck_id = 1
	next_pack_id = 1
	bench_instance_id = 0
	bench_origin = ""
	bench_dirty = false
	active_duel_state = null
	loaded = true

	var starter: Dictionary = Content.starter(starter_id)
	if starter.is_empty():
		push_error("Session: starter %s missing." % starter_id)
		return
	var deck := DeckModel.new()
	deck.deck_id = next_deck_id
	next_deck_id += 1
	deck.name = str(starter.get("name", "Ember Press"))
	deck.doctrine = str(starter.get("doctrine", "press"))
	deck.created_at = _now()
	deck.updated_at = deck.created_at
	for entry in starter.get("deck", []):
		for i in range(int(entry.get("count", 0))):
			var instance := _make_instance(str(entry.get("def", "")), 1, "starter", 0)
			if instance != null:
				instance.deck_bound = true
				deck.main.append(instance.instance_id)
	for entry in starter.get("sideboard", []):
		for i in range(int(entry.get("count", 0))):
			var instance := _make_instance(str(entry.get("def", "")), 1, "starter", 0)
			if instance != null:
				instance.deck_bound = true
				deck.side.append(instance.instance_id)
	decks[deck.deck_id] = deck
	active_deck_id = deck.deck_id

	# Extra craft stock so the first Bench visit has something to pull.
	var extra := [
		["ember.cinder_hound", 2, 1],
		["ember.ash_moth", 2, 1],
		["neutral.paper_warden", 2, 1],
		["verdant.bramble_wall", 2, 1],
		["verdant.thorn_sentinel", 2, 1],
		["ember.cinder_hound", 1, 10],
		["umbra.hollow_lantern", 1, 25],
		["verdant.verdant_colossus", 1, 45],
	]
	for row in extra:
		_add_stack(str(row[0]), int(row[2]), "ink.iron", "shimmer.none", int(row[1]), "starter", true)

	var pack_seed := seed_value if seed_value != 0 else randi()
	_acquire_pack("pack.paper", "starter", pack_seed)
	save_now()
	game_ready.emit()
	collection_changed.emit()
	currency_changed.emit()
	decks_changed.emit()
	_emit_packs_changed()

## ---------------------------------------------------------------- save/load

func _load_doc(doc: Dictionary) -> void:
	meta = doc.get("meta", {})
	currency = {"marks": int(doc.get("currency", {}).get("marks", STARTING_MARKS))}
	reagents = {}
	for key in doc.get("reagents", {}).keys():
		reagents[str(key)] = int(doc["reagents"][key])
	instances.clear()
	for raw in doc.get("instances", []):
		if raw is Dictionary:
			var instance := CardInstance.from_dict(raw)
			instances[instance.instance_id] = instance
			next_instance_id = maxi(next_instance_id, instance.instance_id + 1)
	stacks.clear()
	for raw in doc.get("stacks", []):
		if raw is Dictionary:
			stacks.append(raw.duplicate(true))
	decks.clear()
	for raw in doc.get("decks", []):
		if raw is Dictionary:
			var deck := DeckModel.from_dict(raw)
			decks[deck.deck_id] = deck
			next_deck_id = maxi(next_deck_id, deck.deck_id + 1)
	active_deck_id = int(doc.get("active_deck_id", 0))
	if not decks.has(active_deck_id) and not decks.is_empty():
		active_deck_id = int(decks.keys()[0])
	packs.clear()
	for raw in doc.get("packs", []):
		if raw is Dictionary:
			packs.append(raw.duplicate(true))
			next_pack_id = maxi(next_pack_id, int(raw.get("id", 0)) + 1)
	# v1 -> v2: content ids and stack origins used the folio prefix.
	for pack in packs:
		var kind := str(pack.get("kind", ""))
		if kind.begins_with("folio."):
			pack["kind"] = "pack." + kind.substr(6)
		if str(pack.get("source", "")) == "folio":
			pack["source"] = "pack"
	for stack in stacks:
		if str(stack.get("source", "")) == "folio":
			stack["source"] = "pack"
	codex = doc.get("codex", {}).duplicate(true) if doc.get("codex", {}) is Dictionary else {}
	settings = default_settings()
	for key in doc.get("settings", {}).keys():
		settings[str(key)] = doc["settings"][key]
	# v1 -> v2: folio_mode is now pack_mode. Keep the value if the new key is absent.
	var raw_settings: Dictionary = doc.get("settings", {})
	if raw_settings.has("folio_mode") and not raw_settings.has("pack_mode"):
		settings["pack_mode"] = raw_settings["folio_mode"]
	descent = doc.get("descent", {}).duplicate(true) if doc.get("descent", {}) is Dictionary else {}
	last_result = doc.get("last_result", {}).duplicate(true) if doc.get("last_result", {}) is Dictionary else {}
	if last_result.has("folios") and not last_result.has("packs"):
		last_result["packs"] = last_result["folios"]
	first_clear_floors.clear()
	for raw in doc.get("first_clear_floors", []):
		first_clear_floors.append(int(raw))
	unlocked_floor = int(doc.get("unlocked_floor", 1))
	deepest_floor = int(doc.get("deepest_floor", 0))
	best_streak = int(doc.get("best_streak", 0))
	next_instance_id = maxi(next_instance_id, int(doc.get("next_instance_id", 1)))
	next_deck_id = maxi(next_deck_id, int(doc.get("next_deck_id", 1)))
	next_pack_id = maxi(next_pack_id, int(doc.get("next_pack_id", 1)))
	bench_instance_id = 0
	bench_origin = ""
	bench_dirty = false
	active_duel_state = null
	loaded = true
	game_ready.emit()

func _doc() -> Dictionary:
	var instance_list: Array = []
	for instance_id in instances.keys():
		instance_list.append(instances[instance_id].to_dict())
	var deck_list: Array = []
	for deck_id in decks.keys():
		deck_list.append(decks[deck_id].to_dict())
	var pack_list: Array = []
	for pack in packs:
		pack_list.append(pack.duplicate(true))
	var stats := _collection_stats()
	return {
		"version": SaveStore.SAVE_VERSION,
		"meta": meta.duplicate(true),
		"currency": currency.duplicate(true),
		"reagents": reagents.duplicate(true),
		"instances": instance_list,
		"stacks": stacks.duplicate(true),
		"decks": deck_list,
		"active_deck_id": active_deck_id,
		"packs": pack_list,
		"codex": codex.duplicate(true),
		"collection_stats": stats,
		"settings": settings.duplicate(true),
		"descent": descent.duplicate(true) if not descent.is_empty() else null,
		"last_result": last_result.duplicate(true) if not last_result.is_empty() else null,
		"first_clear_floors": first_clear_floors.duplicate(),
		"unlocked_floor": unlocked_floor,
		"deepest_floor": deepest_floor,
		"best_streak": best_streak,
		"next_instance_id": next_instance_id,
		"next_deck_id": next_deck_id,
		"next_pack_id": next_pack_id,
	}

func _collection_stats() -> Dictionary:
	var stats: Dictionary = {}
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		var key: String = instance.def_id
		if not stats.has(key):
			stats[key] = {"owned": 0, "crafted": 0, "shimmered": 0}
		stats[key]["owned"] += 1
		if instance.is_crafted():
			stats[key]["crafted"] += 1
		if instance.shimmer_id != "shimmer.none":
			stats[key]["shimmered"] += 1
	for stack in stacks:
		var key: String = str(stack.get("def_id", ""))
		var count := int(stack.get("count", 0))
		if not stats.has(key):
			stats[key] = {"owned": 0, "crafted": 0, "shimmered": 0}
		stats[key]["owned"] += count
		if str(stack.get("shimmer_id", "shimmer.none")) != "shimmer.none":
			stats[key]["shimmered"] += count
	return stats

func save_now() -> void:
	if not loaded or test_mode:
		return
	store.write_save(_doc())

func reset_save() -> void:
	store.delete_save()
	new_game()

## ---------------------------------------------------------------- collection

func _touch_codex(def_id: String, xp: int = 0, seen: int = 1) -> void:
	if def_id.is_empty():
		return
	if not codex.has(def_id):
		codex[def_id] = {"discovered_at": _now(), "mastery_xp": 0, "total_seen": 0}
	codex[def_id]["mastery_xp"] = int(codex[def_id].get("mastery_xp", 0)) + xp
	codex[def_id]["total_seen"] = int(codex[def_id].get("total_seen", 0)) + seen

func _make_instance(def_id: String, provenance: int, origin: String, forced_id: int = 0) -> CardInstance:
	if not Content.cards.has(def_id):
		push_warning("Session: unknown card %s" % def_id)
		return null
	var instance_id := forced_id if forced_id > 0 else next_instance_id
	if forced_id > 0:
		next_instance_id = maxi(next_instance_id, forced_id + 1)
	else:
		next_instance_id += 1
	var instance := CardInstance.new(instance_id, def_id, provenance)
	instance.created_at = _now()
	instance.origin = origin
	instances[instance_id] = instance
	_touch_codex(def_id, 1, 1)
	return instance

func _add_stack(def_id: String, provenance: int, ink_id: String, shimmer_id: String, count: int, origin: String, grant_xp: bool = true) -> void:
	if count <= 0 or not Content.cards.has(def_id):
		return
	var found: Dictionary = {}
	for stack in stacks:
		if str(stack.get("def_id", "")) == def_id \
			and int(stack.get("provenance", 1)) == clampi(provenance, 1, 100) \
			and str(stack.get("ink_id", "ink.iron")) == ink_id \
			and str(stack.get("shimmer_id", "shimmer.none")) == shimmer_id:
			found = stack
			break
	if found.is_empty():
		found = {
			"def_id": def_id,
			"ink_id": ink_id,
			"shimmer_id": shimmer_id,
			"provenance": clampi(provenance, 1, 100),
			"count": count,
			"first_at": _now(),
			"last_at": _now(),
			"origin": origin,
		}
		stacks.append(found)
	else:
		found["count"] = int(found.get("count", 0)) + count
		found["last_at"] = _now()
	if grant_xp:
		_touch_codex(def_id, count, count)

func _add_stack_from_drop(drop: Dictionary, origin: String = "drop") -> void:
	_add_stack(
		str(drop.get("def_id", "")),
		int(drop.get("provenance", 1)),
		str(drop.get("ink_id", "ink.iron")),
		str(drop.get("shimmer_id", "shimmer.none")),
		1,
		origin,
		true
	)

func _find_stack(def_id: String, provenance: int, ink_id: String, shimmer_id: String) -> Dictionary:
	for stack in stacks:
		if str(stack.get("def_id", "")) == def_id \
			and int(stack.get("provenance", 1)) == provenance \
			and str(stack.get("ink_id", "ink.iron")) == ink_id \
			and str(stack.get("shimmer_id", "shimmer.none")) == shimmer_id:
			return stack
	return {}

func _decrement_stack(stack: Dictionary, amount: int = 1) -> bool:
	if stack.is_empty():
		return false
	var count := int(stack.get("count", 0))
	if count < amount:
		return false
	stack["count"] = count - amount
	if int(stack["count"]) <= 0:
		stacks.erase(stack)
	return true

func def_owned_count(def_id: String) -> int:
	var total := 0
	for stack in stacks:
		if str(stack.get("def_id", "")) == def_id:
			total += int(stack.get("count", 0))
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		if instance.def_id == def_id:
			total += 1
	return total

func total_cards() -> int:
	var total := 0
	for stack in stacks:
		total += int(stack.get("count", 0))
	return total + instances.size()

func total_definitions() -> int:
	var defs: Dictionary = {}
	for stack in stacks:
		defs[str(stack.get("def_id", ""))] = true
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		defs[instance.def_id] = true
	return defs.size()

func crafted_count() -> int:
	var total := 0
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		if instance.is_crafted():
			total += 1
	return total

func decked_count() -> int:
	var total := 0
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		if instance.deck_bound:
			total += 1
	return total

func instance_by_id(instance_id: int) -> CardInstance:
	return instances.get(instance_id)

func def_of_instance(instance: CardInstance) -> CardDef:
	if instance == null:
		return null
	return Content.cards.get(instance.def_id)

func is_decked(instance_id: int) -> bool:
	for raw_deck in decks.values():
		var deck: DeckModel = raw_deck
		if deck.main.has(instance_id) or deck.side.has(instance_id):
			return true
	return false

func _merge_instance_to_stack(instance: CardInstance) -> bool:
	if instance == null or not instance.is_plain() or instance.deck_bound:
		return false
	if is_decked(instance.instance_id):
		return false
	_add_stack(instance.def_id, instance.provenance, instance.ink_id, instance.shimmer_id, 1, "merge", false)
	instances.erase(instance.instance_id)
	if bench_instance_id == instance.instance_id:
		bench_instance_id = 0
	return true

func collection_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var def_ids: Dictionary = {}
	for stack in stacks:
		def_ids[str(stack.get("def_id", ""))] = true
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		def_ids[instance.def_id] = true
	for def_key in def_ids.keys():
		var def_id: String = str(def_key)
		var stacks_for_def: Array[Dictionary] = []
		var plain_instances: Array[CardInstance] = []
		var unique_instances: Array[CardInstance] = []
		for stack in stacks:
			if str(stack.get("def_id", "")) == def_id:
				stacks_for_def.append(stack)
		for raw_instance in instances.values():
			var instance: CardInstance = raw_instance
			if instance.def_id != def_id:
				continue
			if instance.is_plain():
				plain_instances.append(instance)
			else:
				unique_instances.append(instance)
		var plain_count := 0
		for stack in stacks_for_def:
			plain_count += int(stack.get("count", 0))
		plain_count += plain_instances.size()
		if plain_count > 0:
			var best_plain: CardInstance = null
			for instance in plain_instances:
				if best_plain == null or CardResolver.power(instance, Content.cards.get(def_id), Content.mods) > CardResolver.power(best_plain, Content.cards.get(def_id), Content.mods):
					best_plain = instance
			var decked := false
			for instance in plain_instances:
				if instance.deck_bound:
					decked = true
					break
			entries.append({
				"kind": "stack",
				"def_id": def_id,
				"count": plain_count,
				"stacks": stacks_for_def.duplicate(true),
				"plain_ids": _instance_ids(plain_instances),
				"best_instance": best_plain,
				"decked": decked,
			})
		for instance in unique_instances:
			entries.append({
				"kind": "instance",
				"def_id": def_id,
				"count": 1,
				"stacks": [],
				"plain_ids": [],
				"best_instance": instance,
				"decked": instance.deck_bound,
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_def: CardDef = Content.cards.get(a["def_id"])
		var b_def: CardDef = Content.cards.get(b["def_id"])
		var a_name: String = a_def.name if a_def != null else str(a["def_id"])
		var b_name: String = b_def.name if b_def != null else str(b["def_id"])
		if a_name == b_name:
			return str(a.get("best_instance", null)) < str(b.get("best_instance", null))
		return a_name < b_name
	)
	return entries

func _instance_ids(list: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for instance in list:
		ids.append(instance.instance_id)
	return ids

func entry_power(entry: Dictionary) -> int:
	var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
	var instance: CardInstance = entry.get("best_instance")
	if instance == null:
		return def.base_power if def != null else 0
	return CardResolver.power(instance, def, Content.mods)

func pull_entry_to_bench(entry: Dictionary) -> Dictionary:
	var kind := str(entry.get("kind", ""))
	if kind == "instance":
		var instance: CardInstance = entry.get("best_instance")
		if instance == null:
			return {"ok": false, "reason": "Copy not found."}
		return pull_to_bench({"kind": "instance", "instance_id": instance.instance_id})
	# Prefer a plain stack copy with the highest provenance.
	var sources: Array = entry.get("stacks", [])
	var chosen: Dictionary = {}
	for stack in sources:
		if int(stack.get("count", 0)) <= 0:
			continue
		if chosen.is_empty() or int(stack.get("provenance", 1)) > int(chosen.get("provenance", 1)):
			chosen = stack
	if not chosen.is_empty():
		return pull_to_bench({
			"kind": "stack",
			"def_id": str(chosen.get("def_id", "")),
			"provenance": int(chosen.get("provenance", 1)),
			"ink_id": str(chosen.get("ink_id", "ink.iron")),
			"shimmer_id": str(chosen.get("shimmer_id", "shimmer.none")),
		})
	var plain_ids: Array = entry.get("plain_ids", [])
	if not plain_ids.is_empty():
		return pull_to_bench({"kind": "instance", "instance_id": int(plain_ids[0])})
	return {"ok": false, "reason": "No copy to pull."}

func pull_to_bench(source: Dictionary) -> Dictionary:
	close_bench(false)
	var kind := str(source.get("kind", ""))
	if kind == "stack":
		var stack := _find_stack(
			str(source.get("def_id", "")),
			int(source.get("provenance", 1)),
			str(source.get("ink_id", "ink.iron")),
			str(source.get("shimmer_id", "shimmer.none"))
		)
		if stack.is_empty() or not _decrement_stack(stack, 1):
			return {"ok": false, "reason": "That stack is empty."}
		var instance := _make_instance(str(stack.get("def_id", "")), int(stack.get("provenance", 1)), "bench", 0)
		if instance == null:
			return {"ok": false, "reason": "Card definition missing."}
		instance.ink_id = str(stack.get("ink_id", "ink.iron"))
		instance.shimmer_id = str(stack.get("shimmer_id", "shimmer.none"))
		bench_instance_id = instance.instance_id
		bench_origin = "stack"
		bench_dirty = false
		collection_changed.emit()
		return {"ok": true, "instance": instance}
	if kind == "instance":
		var instance: CardInstance = instances.get(int(source.get("instance_id", 0)))
		if instance == null:
			return {"ok": false, "reason": "Copy not found."}
		bench_instance_id = instance.instance_id
		bench_origin = "instance"
		bench_dirty = false
		return {"ok": true, "instance": instance}
	return {"ok": false, "reason": "Unknown source."}

func bench_instance() -> CardInstance:
	return instances.get(bench_instance_id)

func apply_reagent(reagent_id: String) -> Dictionary:
	var instance := bench_instance()
	if instance == null:
		return {"ok": false, "reason": "No card on the bench."}
	if int(reagents.get(reagent_id, 0)) <= 0:
		return {"ok": false, "reason": "No %s left." % str(Content.reagent(reagent_id).get("name", reagent_id))}
	var rng := GameRng.new(randi() & 0x7FFFFFFF, 5)
	var result := CraftService.apply(instance, reagent_id, rng, Content.mods)
	if not bool(result.get("ok", false)):
		toast.emit(str(result.get("message", "That did not work.")), "bad")
		return result
	reagents[reagent_id] = int(reagents.get(reagent_id, 0)) - 1
	var reagent_name := str(Content.reagent(reagent_id).get("name", reagent_id))
	instance.add_history("craft", "%s — %s" % [reagent_name, str(result.get("message", ""))], _now())
	bench_dirty = true
	if bool(result.get("duplicate", false)):
		var clone := instance.clone(0)
		clone.instance_id = next_instance_id
		next_instance_id += 1
		clone.created_at = _now()
		clone.origin = "echo"
		clone.parent_instance_id = instance.instance_id
		clone.deck_bound = false
		clone.custom_name = ""
		clone.add_history("craft", "Echo of #%d" % instance.instance_id, _now())
		instances[clone.instance_id] = clone
		result["copy"] = clone
	save_now()
	collection_changed.emit()
	currency_changed.emit()
	toast.emit(str(result.get("message", "Craft applied.")), "good")
	return result

func close_bench(save: bool = true) -> void:
	var instance := bench_instance()
	if instance != null and bench_origin == "stack" and not bench_dirty and instance.is_plain() and not instance.deck_bound:
		instances.erase(instance.instance_id)
		_add_stack(instance.def_id, instance.provenance, instance.ink_id, instance.shimmer_id, 1, "bench-return", false)
	bench_instance_id = 0
	bench_origin = ""
	bench_dirty = false
	if save:
		save_now()

## ---------------------------------------------------------------- decks

func active_deck() -> DeckModel:
	return decks.get(active_deck_id)

func deck_by_id(deck_id: int) -> DeckModel:
	return decks.get(deck_id)

func set_active_deck(deck_id: int) -> void:
	if decks.has(deck_id):
		active_deck_id = deck_id
		save_now()
		decks_changed.emit()

func deck_instances(deck: DeckModel) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if deck == null:
		return result
	for instance_id in deck.main:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null:
			result.append(instance)
	return result

func side_instances(deck: DeckModel) -> Array[CardInstance]:
	var result: Array[CardInstance] = []
	if deck == null:
		return result
	for instance_id in deck.side:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null:
			result.append(instance)
	return result

func deck_power(deck: DeckModel) -> int:
	return CardResolver.deck_power(deck_instances(deck), Content.cards, Content.mods)

func deck_errors(deck: DeckModel) -> Array[String]:
	if deck == null:
		return ["No deck."]
	return deck.validate(instances, Content.cards)

func count_def_in_deck(def_id: String, deck: DeckModel) -> int:
	if deck == null:
		return 0
	var count := 0
	for instance_id in deck.main + deck.side:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null and instance.def_id == def_id:
			count += 1
	return count

func _free_plain_instance(def_id: String) -> CardInstance:
	# Any un-decked copy can enter a binder, including crafted, named, or honoured
	# copies. "Plain" is a merge rule for removal, not an eligibility rule for decks.
	for raw_instance in instances.values():
		var instance: CardInstance = raw_instance
		if instance.def_id == def_id and not instance.deck_bound and not is_decked(instance.instance_id):
			return instance
	return null

func add_def_to_deck(def_id: String, zone: String = "main") -> Dictionary:
	var deck := active_deck()
	if deck == null:
		return {"ok": false, "reason": "No deck."}
	var def: CardDef = Content.cards.get(def_id)
	if def == null:
		return {"ok": false, "reason": "Unknown card."}
	if zone == "main" and deck.main.size() >= GameConst.DECK_SIZE:
		return {"ok": false, "reason": "The main deck is full."}
	if zone == "side" and deck.side.size() >= GameConst.SIDE_SIZE:
		return {"ok": false, "reason": "The sideboard is full."}
	var limit := 1 if def.rarity == "legendary" else GameConst.MAX_COPIES
	if count_def_in_deck(def_id, deck) >= limit:
		return {"ok": false, "reason": "%s is at its copy limit." % def.name}
	if def.rarity == "legendary":
		for instance_id in deck.main + deck.side:
			var other: CardInstance = instances.get(instance_id)
			if other != null and Content.cards.get(other.def_id) != null and Content.cards[other.def_id].rarity == "legendary":
				return {"ok": false, "reason": "A deck may contain only 1 Legendary."}
	var instance := _free_plain_instance(def_id)
	if instance == null:
		var chosen_stack: Dictionary = {}
		for stack in stacks:
			if str(stack.get("def_id", "")) != def_id:
				continue
			if chosen_stack.is_empty() or int(stack.get("provenance", 1)) < int(chosen_stack.get("provenance", 1)):
				chosen_stack = stack
		if chosen_stack.is_empty() or not _decrement_stack(chosen_stack, 1):
			return {"ok": false, "reason": "No %s copy available." % def.name}
		instance = _make_instance(def_id, int(chosen_stack.get("provenance", 1)), "deck", 0)
		if instance == null:
			return {"ok": false, "reason": "Definition missing."}
		instance.ink_id = str(chosen_stack.get("ink_id", "ink.iron"))
		instance.shimmer_id = str(chosen_stack.get("shimmer_id", "shimmer.none"))
	instance.deck_bound = true
	if zone == "main":
		deck.main.append(instance.instance_id)
	else:
		deck.side.append(instance.instance_id)
	deck.updated_at = _now()
	save_now()
	collection_changed.emit()
	decks_changed.emit()
	return {"ok": true, "instance": instance}

func move_instance_in_deck(instance_id: int, zone: String) -> Dictionary:
	## Preserve the exact copy when moving between main and sideboard. Removing
	## and re-adding would merge/re-create the instance and could swap the copy.
	var deck := active_deck()
	if deck == null:
		return {"ok": false, "reason": "No deck."}
	if zone != "main" and zone != "side":
		return {"ok": false, "reason": "Unknown deck zone."}
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return {"ok": false, "reason": "Copy not found."}
	var from_main := deck.main.has(instance_id)
	var from_side := deck.side.has(instance_id)
	if not from_main and not from_side:
		return {"ok": false, "reason": "That copy is not in the active deck."}
	if (zone == "main" and from_main) or (zone == "side" and from_side):
		return {"ok": true, "instance": instance}
	if zone == "main" and deck.main.size() >= GameConst.DECK_SIZE:
		return {"ok": false, "reason": "The main deck is full."}
	if zone == "side" and deck.side.size() >= GameConst.SIDE_SIZE:
		return {"ok": false, "reason": "The sideboard is full."}
	if from_main:
		deck.main.erase(instance_id)
	else:
		deck.side.erase(instance_id)
	if zone == "main":
		deck.main.append(instance_id)
	else:
		deck.side.append(instance_id)
	instance.deck_bound = true
	deck.updated_at = _now()
	save_now()
	collection_changed.emit()
	decks_changed.emit()
	return {"ok": true, "instance": instance, "zone": zone}

func add_instance_to_deck(instance_id: int, zone: String = "main") -> Dictionary:
	## Bind one specific owned copy. Used by the card menu and the optional
	## Copies view; definition-level adds still go through add_def_to_deck.
	var deck := active_deck()
	if deck == null:
		return {"ok": false, "reason": "No deck."}
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return {"ok": false, "reason": "Copy not found."}
	if deck.main.has(instance_id) or deck.side.has(instance_id):
		return {"ok": false, "reason": "That copy is already in the deck."}
	if zone == "main" and deck.main.size() >= GameConst.DECK_SIZE:
		return {"ok": false, "reason": "The main deck is full."}
	if zone == "side" and deck.side.size() >= GameConst.SIDE_SIZE:
		return {"ok": false, "reason": "The sideboard is full."}
	var def: CardDef = Content.cards.get(instance.def_id)
	if def == null:
		return {"ok": false, "reason": "Unknown card."}
	var limit := 1 if def.rarity == "legendary" else GameConst.MAX_COPIES
	if count_def_in_deck(instance.def_id, deck) >= limit:
		return {"ok": false, "reason": "%s is at its copy limit." % def.name}
	if def.rarity == "legendary":
		for other_id in deck.main + deck.side:
			var other: CardInstance = instances.get(other_id)
			if other != null and Content.cards.get(other.def_id) != null and Content.cards[other.def_id].rarity == "legendary":
				return {"ok": false, "reason": "A deck may contain only 1 Legendary."}
	instance.deck_bound = true
	if zone == "main":
		deck.main.append(instance_id)
	else:
		deck.side.append(instance_id)
	deck.updated_at = _now()
	save_now()
	collection_changed.emit()
	decks_changed.emit()
	return {"ok": true, "instance": instance, "zone": zone}

func remove_instance_from_deck(instance_id: int) -> Dictionary:
	var deck := active_deck()
	if deck == null:
		return {"ok": false, "reason": "No deck."}
	var removed := false
	if deck.main.has(instance_id):
		deck.main.erase(instance_id)
		removed = true
	if deck.side.has(instance_id):
		deck.side.erase(instance_id)
		removed = true
	if not removed:
		return {"ok": false, "reason": "That copy is not in the active deck."}
	deck.updated_at = _now()
	var instance: CardInstance = instances.get(instance_id)
	if instance != null and instance.is_plain() and not is_decked(instance_id):
		instance.deck_bound = false
		_merge_instance_to_stack(instance)
	save_now()
	collection_changed.emit()
	decks_changed.emit()
	return {"ok": true}

func auto_fill_deck() -> int:
	var deck := active_deck()
	if deck == null:
		return 0
	var added := 0
	var guard := 0
	while deck.main.size() < GameConst.DECK_SIZE and guard < 200:
		guard += 1
		var best_def_id := ""
		var best_power := -1
		for def in Content.card_list:
			if count_def_in_deck(def.id, deck) >= (1 if def.rarity == "legendary" else GameConst.MAX_COPIES):
				continue
			if def_owned_count(def.id) <= count_def_in_deck(def.id, deck):
				continue
			if def.base_power > best_power:
				best_power = def.base_power
				best_def_id = def.id
		if best_def_id.is_empty():
			break
		var result := add_def_to_deck(best_def_id, "main")
		if not bool(result.get("ok", false)):
			break
		added += 1
	return added

func set_doctrine(doctrine: String) -> void:
	var deck := active_deck()
	if deck == null:
		return
	deck.doctrine = doctrine
	save_now()
	decks_changed.emit()

## ---------------------------------------------------------------- economy

func add_marks(amount: int, reason: String) -> void:
	if amount == 0:
		return
	currency["marks"] = maxi(0, int(currency.get("marks", 0)) + amount)
	currency_changed.emit()

func spend_marks(amount: int) -> bool:
	if int(currency.get("marks", 0)) < amount:
		return false
	currency["marks"] = int(currency.get("marks", 0)) - amount
	currency_changed.emit()
	return true

func add_reagent(reagent_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	reagents[reagent_id] = int(reagents.get(reagent_id, 0)) + amount

func buy_pack(kind: String) -> Dictionary:
	var pack_def: Dictionary = Content.pack(kind)
	if pack_def.is_empty():
		return {"ok": false, "reason": "Unknown pack."}
	var price := int(pack_def.get("price", 0))
	if price <= 0:
		return {"ok": false, "reason": "That pack is not for sale."}
	if not spend_marks(price):
		return {"ok": false, "reason": "Not enough Marks."}
	var pack := _acquire_pack(kind, "purchase", 0)
	save_now()
	_emit_packs_changed()
	return {"ok": true, "pack": pack}

## Legacy alias; remove after the one-version compatibility window.
func buy_folio(kind: String) -> Dictionary:
	return buy_pack(kind)

func _acquire_pack(kind: String, source: String, seed_value: int) -> Dictionary:
	var pack_def: Dictionary = Content.pack(kind)
	var actual_seed := seed_value if seed_value != 0 else (randi() & 0x7FFFFFFF)
	var contents := PackRoll.roll_pack(
		pack_def,
		actual_seed,
		Content.card_list,
		Content.reagent_list,
		Content.data.get("inks", []),
		Content.data.get("shimmers", [])
	)
	var pack := {
		"id": next_pack_id,
		"kind": kind,
		"seed": actual_seed,
		"contents": contents,
		"source": source,
		"acquired_at": _now(),
		"opened_at": 0,
	}
	next_pack_id += 1
	packs.append(pack)
	return pack

## Legacy alias; remove after the one-version compatibility window.
func _acquire_folio(kind: String, source: String, seed_value: int) -> Dictionary:
	return _acquire_pack(kind, source, seed_value)

func unopened_packs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pack in packs:
		if int(pack.get("opened_at", 0)) == 0:
			result.append(pack)
	return result

func pack_by_id(pack_id: int) -> Dictionary:
	for pack in packs:
		if int(pack.get("id", 0)) == pack_id:
			return pack
	return {}

func open_pack(pack_id: int) -> Dictionary:
	var pack := pack_by_id(pack_id)
	if pack.is_empty():
		return {"ok": false, "reason": "Pack not found."}
	if int(pack.get("opened_at", 0)) > 0:
		return {"ok": false, "reason": "That pack is already open."}
	var contents: Dictionary = pack.get("contents", {})
	var cards_revealed: Array[Dictionary] = []
	for drop in contents.get("cards", []):
		var def: CardDef = Content.cards.get(str(drop.get("def_id", "")))
		if def == null:
			continue
		_add_stack_from_drop(drop, "pack")
		cards_revealed.append({
			"def_id": def.id,
			"def": def,
			"provenance": int(drop.get("provenance", 1)),
			"ink_id": str(drop.get("ink_id", "ink.iron")),
			"shimmer_id": str(drop.get("shimmer_id", "shimmer.none")),
			"rarity": def.rarity,
			"is_new": not codex.has(def.id) or int(codex.get(def.id, {}).get("total_seen", 0)) <= 1,
		})
	var reagents_revealed: Array[String] = []
	for reagent_id in contents.get("reagents", []):
		add_reagent(str(reagent_id), 1)
		reagents_revealed.append(str(reagent_id))
	pack["opened_at"] = _now()
	save_now()
	collection_changed.emit()
	currency_changed.emit()
	_emit_packs_changed()
	return {"ok": true, "cards": cards_revealed, "reagents": reagents_revealed, "pack": pack}

func print_card(def_id: String) -> Dictionary:
	var def: CardDef = Content.cards.get(def_id)
	if def == null:
		return {"ok": false, "reason": "Unknown card."}
	if not codex.has(def_id):
		return {"ok": false, "reason": "Discover it first."}
	var cost := Economy.print_cost(def.rarity)
	if not spend_marks(cost):
		return {"ok": false, "reason": "Need %d Marks." % cost}
	var instance := _make_instance(def_id, 1, "press", 0)
	if instance == null:
		return {"ok": false, "reason": "Definition missing."}
	save_now()
	collection_changed.emit()
	return {"ok": true, "instance": instance, "cost": cost}

func dissolve_instance(instance_id: int) -> Dictionary:
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return {"ok": false, "reason": "Copy not found."}
	if instance.locked:
		return {"ok": false, "reason": "Unlock it first."}
	if instance.favorite:
		return {"ok": false, "reason": "Favorited. Unfavorite it first."}
	if is_decked(instance_id):
		return {"ok": false, "reason": "It is in a deck."}
	var def: CardDef = Content.cards.get(instance.def_id)
	var value := Economy.dissolve_value(def.rarity if def != null else "common")
	instances.erase(instance_id)
	add_marks(value, "dissolve")
	save_now()
	collection_changed.emit()
	return {"ok": true, "marks": value}

func dissolve_entry(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "")) == "instance":
		var instance: CardInstance = entry.get("best_instance")
		if instance == null:
			return {"ok": false, "reason": "Copy not found."}
		return dissolve_instance(instance.instance_id)
	var sources: Array = entry.get("stacks", [])
	var chosen: Dictionary = {}
	for stack in sources:
		if int(stack.get("count", 0)) <= 0:
			continue
		if chosen.is_empty() or int(stack.get("provenance", 1)) < int(chosen.get("provenance", 1)):
			chosen = stack
	if not chosen.is_empty():
		if not _decrement_stack(chosen, 1):
			return {"ok": false, "reason": "That stack is empty."}
		var def: CardDef = Content.cards.get(str(chosen.get("def_id", "")))
		var value := Economy.dissolve_value(def.rarity if def != null else "common")
		add_marks(value, "dissolve")
		save_now()
		collection_changed.emit()
		return {"ok": true, "marks": value}
	var plain_ids: Array = entry.get("plain_ids", [])
	for raw_id in plain_ids:
		var instance: CardInstance = instances.get(int(raw_id))
		if instance != null and not instance.locked and not instance.favorite and not is_decked(instance.instance_id):
			return dissolve_instance(instance.instance_id)
	return {"ok": false, "reason": "No free copy to dissolve."}

func rename_instance(instance_id: int, new_name: String, free: bool = false) -> Dictionary:
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return {"ok": false, "reason": "Copy not found."}
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty() or trimmed.length() > 24:
		return {"ok": false, "reason": "Name must be 1–24 characters."}
	var cost := 0 if instance.custom_name.is_empty() else 50
	if cost > 0 and not spend_marks(cost):
		return {"ok": false, "reason": "Need %d Marks." % cost}
	instance.custom_name = trimmed
	instance.add_history("name", "Named \"%s\"" % trimmed, _now())
	save_now()
	collection_changed.emit()
	return {"ok": true, "cost": cost}

func toggle_lock(instance_id: int) -> bool:
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return false
	instance.locked = not instance.locked
	save_now()
	collection_changed.emit()
	return instance.locked

func toggle_favorite(instance_id: int) -> bool:
	var instance: CardInstance = instances.get(instance_id)
	if instance == null:
		return false
	instance.favorite = not instance.favorite
	save_now()
	collection_changed.emit()
	return instance.favorite

## ---------------------------------------------------------------- descent

func has_active_descent() -> bool:
	return not descent.is_empty() and bool(descent.get("active", false))

func start_descent(gate_floor: int, deck_id: int = 0, mode: String = "") -> Dictionary:
	if has_active_descent():
		return {"ok": false, "reason": "A Descent is already active. Return to the Table."}
	if gate_floor < 1 or gate_floor > unlocked_floor:
		return {"ok": false, "reason": "That Gate is locked."}
	var deck: DeckModel = decks.get(deck_id if deck_id != 0 else active_deck_id)
	if deck == null:
		return {"ok": false, "reason": "No deck."}
	var errors := deck_errors(deck)
	if not errors.is_empty():
		return {"ok": false, "reason": errors[0]}
	var snapshot: Array = []
	for instance_id in deck.main:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null:
			snapshot.append(instance.to_dict())
	var side_snapshot: Array = []
	for instance_id in deck.side:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null:
			side_snapshot.append(instance.to_dict())
	var power := deck_power(deck)
	var recommended := Content.recommended_power(gate_floor)
	var underdog := Economy.underdog_bonus(power, recommended)
	var initial_mode := mode if not mode.is_empty() else str(settings.get("mode", "auto"))
	descent = {
		"active": true,
		"gate_floor": gate_floor,
		"current_floor": gate_floor,
		"seed": randi() & 0x7FFFFFFF,
		"started_at": _now(),
		"ended_at": 0,
		"ended_reason": "",
		"mode": initial_mode,
		"deck_id": deck.deck_id,
		"doctrine": deck.doctrine,
		"deck_snapshot": snapshot,
		"side_snapshot": side_snapshot,
		"cleared": 0,
		"streak": 0,
		"best_streak": 0,
		"deepest": gate_floor,
		"underdog": underdog,
		"deck_power": power,
		"recommended_power": recommended,
		"chapter_seal": false,
		"stats": {
			"damage_dealt": 0,
			"damage_healed": 0,
			"cards_played": 0,
			"flawless_duels": 0,
		},
		"marks_won": 0,
		"cards_won": 0,
		"reagents_won": {},
		"last_duel": {},
	}
	last_result = {}
	active_duel_state = null
	save_now()
	descent_changed.emit()
	return {"ok": true, "descent": descent}

func current_opponent() -> Dictionary:
	if descent.is_empty():
		return {}
	var floor_number := int(descent.get("current_floor", 1))
	var authored: Dictionary = Content.opponent_for_floor(floor_number)
	var base: Dictionary = authored if not authored.is_empty() else _procedural_opponent(floor_number)
	if bool(descent.get("vault", false)):
		var vault_opponent: Dictionary = base.duplicate(true)
		vault_opponent["name"] = "Vault " + str(base.get("name", "Warden"))
		vault_opponent["vault"] = true
		vault_opponent["modifier"] = "vault"
		vault_opponent["reward_bias"] = {"rarity": "rare", "reagent": "reagent.verdigris"}
		return vault_opponent
	return base

func _procedural_opponent(floor_number: int) -> Dictionary:
	var circuit := int(ceil(float(floor_number) / 9.0))
	var boss := floor_number % 9 == 0
	var rng := GameRng.new(int(descent.get("seed", 1)) + floor_number * 101, 11)
	var counts: Dictionary = {}
	var deck: Array[Dictionary] = []
	var pool: Array[CardDef] = Content.card_list.duplicate()
	rng.shuffle(pool)
	var guard := 0
	while deck.size() < GameConst.DECK_SIZE and guard < 400:
		guard += 1
		var def: CardDef = rng.pick(pool)
		if def == null:
			break
		var limit := 1 if def.rarity == "legendary" else GameConst.MAX_COPIES
		if int(counts.get(def.id, 0)) >= limit:
			continue
		if def.id == "neutral.razeah_unbound" and not boss:
			continue
		counts[def.id] = int(counts.get(def.id, 0)) + 1
		deck.append({"def": def.id, "count": 1})
	var doctrines := ["press", "hold", "read"]
	var modifier := ""
	if boss:
		modifier = "ninth_veil"
	elif floor_number % 5 == 0:
		modifier = "opening_gambit"
	var names := ["The Stair Warden", "The Copper Echo", "The Quiet Keeper", "The Ninth Shadow", "The Long Stair"]
	return {
		"id": "procedural.%d" % floor_number,
		"name": "%s %d" % [names[floor_number % names.size()], floor_number],
		"floor": floor_number,
		"circuit": circuit,
		"doctrine": doctrines[floor_number % doctrines.size()],
		"ai_profile": "warden",
		"skill": clampi(45 + floor_number * 2, 40, 95),
		"modifier": modifier,
		"boss": boss,
		"reward_bias": {"rarity": "rare" if boss else "uncommon", "reagent": "reagent.verdigris" if boss else "reagent.prism_ink"},
		"plan": "Procedural stair guard.",
		"tell": "Modifier: %s" % (modifier if not modifier.is_empty() else "none"),
		"counterplay": "Open lane pressure.",
		"deck": deck,
	}

func _opponent_instances(opponent: Dictionary, floor_number: int) -> Array:
	var result: Array = []
	var quality := 0
	if str(opponent.get("id", "")).begins_with("procedural."):
		quality = clampi((floor_number - 1) * 2, 0, 20)
	for entry in opponent.get("deck", []):
		var def_id := str(entry.get("def", ""))
		if not Content.cards.has(def_id):
			continue
		for i in range(int(entry.get("count", 0))):
			var instance := CardInstance.new(0, def_id, clampi(floor_number * 3, 1, 100))
			instance.quality = quality
			instance.origin = "warden"
			instance.created_at = _now()
			result.append(instance)
	return result

func make_duel() -> DuelState:
	if not has_active_descent():
		return null
	if active_duel_state != null and not active_duel_state.ended:
		return active_duel_state
	var floor_number := int(descent.get("current_floor", 1))
	var opponent := current_opponent()
	if opponent.is_empty():
		return null
	var player_instances: Array = []
	for raw in descent.get("deck_snapshot", []):
		player_instances.append(CardInstance.from_dict(raw))
	var opponent_instances := _opponent_instances(opponent, floor_number)
	var duel_seed := int(descent.get("seed", 1)) + floor_number * 7919
	var state := DuelState.new()
	state.setup({
		"seed": duel_seed,
		"duel_id": "descent-%d-floor-%d" % [int(descent.get("seed", 1)), floor_number],
		"def_db": Content.cards,
		"mod_db": Content.mods,
		"content_version": Content.content_version,
		"rules_version": Content.rules_version,
		"player": {
			"name": str(meta.get("player_name", "Keeper")),
			"doctrine": str(descent.get("doctrine", "read")),
			"instances": player_instances,
		},
		"opponent": {
			"name": str(opponent.get("name", "Warden")),
			"doctrine": str(opponent.get("doctrine", "read")),
			"modifier": "" if opponent.get("modifier", null) == null else str(opponent.get("modifier", "")),
			"vault": bool(descent.get("vault", false)),
			"instances": opponent_instances,
			"resolve": 4000 + maxi(0, floor_number - 9) * 100,
			"skill": int(opponent.get("skill", 60)),
			"boss": bool(opponent.get("boss", false)),
		},
	})
	active_duel_state = state
	return state

func finish_duel(state: DuelState) -> Dictionary:
	if not has_active_descent() or state == null or not state.ended:
		return {"ok": false, "reason": "No finished duel."}
	var summary := state.summary()
	active_duel_state = null
	if int(state.winner) == 0:
		return _award_win(state, summary)
	return _award_loss(state, summary)

func _grant_reagents_for_win(floor_number: int, first_clear: bool, boss: bool, rewards: Dictionary) -> Dictionary:
	var rng := GameRng.new(int(descent.get("seed", 1)) + floor_number * 31, 17)
	var granted: Dictionary = {}
	var common := ["reagent.pale_ink", "reagent.solvent", "reagent.varnish"]
	var uncommon := ["reagent.prism_ink", "reagent.deep_ink", "reagent.fracture"]
	var rare := ["reagent.crucible", "reagent.verdigris", "reagent.echo", "reagent.gold_leaf"]
	_grant_one_reagent(str(rng.pick(common)), 1, granted)
	if first_clear or director_roll(rng, 0.25):
		_grant_one_reagent(str(rng.pick(uncommon)), 1, granted)
	if boss or director_roll(rng, 0.05):
		_grant_one_reagent(str(rng.pick(rare)), 1, granted)
	if first_clear:
		_grant_one_reagent(str(rng.pick(uncommon)), 1, granted)
	for reagent_id in granted.keys():
		rewards[reagent_id] = int(rewards.get(reagent_id, 0)) + int(granted[reagent_id])
		add_reagent(str(reagent_id), int(granted[reagent_id]))
	return granted

func director_roll(rng: GameRng, chance: float) -> bool:
	return rng.chance(chance)

func _grant_one_reagent(reagent_id: String, amount: int, granted: Dictionary) -> void:
	granted[reagent_id] = int(granted.get(reagent_id, 0)) + amount

func _award_win(state: DuelState, summary: Dictionary) -> Dictionary:
	var floor_number := int(descent.get("current_floor", 1))
	var opponent := current_opponent()
	var boss := bool(opponent.get("boss", false))
	var was_vault := bool(descent.get("vault", false))
	var first_clear := not first_clear_floors.has(floor_number)
	var underdog := float(descent.get("underdog", 0.0))
	var streak_before := int(descent.get("streak", 0))
	var marks := Economy.win_marks(floor_number, streak_before, underdog, false)
	if first_clear:
		marks *= 3
	if boss:
		marks *= 4
	if was_vault:
		marks = int(floor(float(marks) * 1.5))
	var rewards_reagents: Dictionary = {}
	var granted := _grant_reagents_for_win(floor_number, first_clear, boss, rewards_reagents)
	var drop_count := 3 + (2 if first_clear else 0) + (5 if boss else 0) + (2 if was_vault else 0)
	var cards_revealed: Array[Dictionary] = []
	var drop_seed := int(descent.get("seed", 1)) + floor_number * 97
	for i in range(drop_count):
		var drop := PackRoll.roll_card_drop(drop_seed, floor_number, Content.card_list, i)
		if drop.is_empty():
			continue
		_add_stack_from_drop(drop, "duel")
		cards_revealed.append(drop)
	var packs_granted: Array[Dictionary] = []
	if first_clear:
		packs_granted.append(_acquire_pack("pack.paper", "first-clear", 0))
	if boss:
		packs_granted.append(_acquire_pack("pack.brass", "boss", 0))
	var player_stats: Dictionary = summary.get("player", {})
	descent["stats"]["damage_dealt"] = int(descent["stats"].get("damage_dealt", 0)) + int(player_stats.get("damage_dealt", 0))
	descent["stats"]["damage_healed"] = int(descent["stats"].get("damage_healed", 0)) + int(player_stats.get("damage_healed", 0))
	descent["stats"]["cards_played"] = int(descent["stats"].get("cards_played", 0)) + int(player_stats.get("cards_played", 0))
	if bool(summary.get("flawless", false)):
		descent["stats"]["flawless_duels"] = int(descent["stats"].get("flawless_duels", 0)) + 1
	descent["streak"] = streak_before + 1
	descent["best_streak"] = maxi(int(descent.get("best_streak", 0)), streak_before + 1)
	descent["cleared"] = int(descent.get("cleared", 0)) + 1
	descent["deepest"] = maxi(int(descent.get("deepest", floor_number)), floor_number)
	descent["marks_won"] = int(descent.get("marks_won", 0)) + marks
	descent["cards_won"] = int(descent.get("cards_won", 0)) + cards_revealed.size()
	for reagent_id in granted.keys():
		descent["reagents_won"][reagent_id] = int(descent["reagents_won"].get(reagent_id, 0)) + int(granted[reagent_id])
	descent["last_duel"] = summary
	descent["chapter_seal"] = floor_number % 9 == 0
	descent["door_pending"] = not bool(descent["chapter_seal"])
	descent["vault"] = false
	descent["current_floor"] = floor_number + 1
	unlocked_floor = maxi(unlocked_floor, floor_number + 1)
	var previous_deepest := deepest_floor
	deepest_floor = maxi(deepest_floor, floor_number)
	best_streak = maxi(best_streak, int(descent["streak"]))
	if first_clear:
		first_clear_floors.append(floor_number)
	add_marks(marks, "duel win")
	var deck: DeckModel = decks.get(int(descent.get("deck_id", 0)))
	var unique_defs: Dictionary = {}
	if deck != null:
		for instance_id in deck.main:
			var instance: CardInstance = instances.get(instance_id)
			if instance != null:
				unique_defs[instance.def_id] = true
	for def_id in unique_defs.keys():
		_touch_codex(str(def_id), 5, 0)
	if first_clear:
		_grant_deck_honour("first_clear", str(floor_number))
	if boss:
		_grant_deck_honour("boss_slayer", str(floor_number))
	if bool(summary.get("flawless", false)):
		_grant_deck_honour("flawless", str(floor_number))
	if floor_number > previous_deepest:
		_grant_deck_honour("deepest", str(floor_number))
	save_now()
	descent_changed.emit()
	collection_changed.emit()
	currency_changed.emit()
	_emit_packs_changed()
	var result := {
		"ok": true,
		"kind": "win",
		"floor": floor_number,
		"marks": marks,
		"reagents": granted,
		"cards": cards_revealed,
		"packs": packs_granted,
		"first_clear": first_clear,
		"boss": boss,
		"streak": int(descent.get("streak", 0)),
		"underdog": underdog,
		"chapter_seal": bool(descent.get("chapter_seal", false)),
		"vault": was_vault,
		"summary": summary,
	}
	last_result = result
	save_now()
	return result

func _award_loss(state: DuelState, summary: Dictionary) -> Dictionary:
	var floor_number := int(descent.get("current_floor", 1))
	var underdog := float(descent.get("underdog", 0.0))
	var player_stats: Dictionary = summary.get("player", {})
	var stats: Dictionary = descent.get("stats", {}).duplicate(true)
	stats["damage_dealt"] = int(stats.get("damage_dealt", 0)) + int(player_stats.get("damage_dealt", 0))
	stats["damage_healed"] = int(stats.get("damage_healed", 0)) + int(player_stats.get("damage_healed", 0))
	stats["cards_played"] = int(stats.get("cards_played", 0)) + int(player_stats.get("cards_played", 0))
	var cleared := int(descent.get("cleared", 0))
	var best := maxi(int(descent.get("best_streak", 0)), int(descent.get("streak", 0)))
	var perf := Economy.performance(stats, cleared, best)
	var marks := Economy.loss_marks(int(perf["total"]), underdog)
	var rng := GameRng.new(int(descent.get("seed", 1)) + floor_number * 53, 19)
	var reagents_granted: Dictionary = {}
	_grant_one_reagent(str(rng.pick(["reagent.pale_ink", "reagent.solvent", "reagent.varnish"])), 1, reagents_granted)
	var uncommon_count := cleared / 4
	for i in range(uncommon_count):
		_grant_one_reagent(str(rng.pick(["reagent.prism_ink", "reagent.deep_ink", "reagent.fracture"])), 1, reagents_granted)
	if rng.chance(0.10):
		_grant_one_reagent(str(rng.pick(["reagent.prism_ink", "reagent.deep_ink"])), 1, reagents_granted)
	for reagent_id in reagents_granted.keys():
		add_reagent(str(reagent_id), int(reagents_granted[reagent_id]))
	var drop_count := 2 + cleared / 3 + 3
	var cards_revealed: Array[Dictionary] = []
	var drop_seed := int(descent.get("seed", 1)) + floor_number * 193
	for i in range(drop_count):
		var drop := PackRoll.roll_card_drop(drop_seed, floor_number, Content.card_list, i + 50)
		if drop.is_empty():
			continue
		_add_stack_from_drop(drop, "salvage")
		cards_revealed.append(drop)
	_grant_one_reagent(str(rng.pick(["reagent.pale_ink", "reagent.solvent", "reagent.varnish"])), 1, reagents_granted)
	add_marks(marks, "salvage")
	var deck: DeckModel = decks.get(int(descent.get("deck_id", 0)))
	if deck != null:
		var unique_defs: Dictionary = {}
		for instance_id in deck.main:
			var instance: CardInstance = instances.get(instance_id)
			if instance != null:
				unique_defs[instance.def_id] = true
		var xp := Economy.xp_for_loss(floor_number, cleared)
		for def_id in unique_defs.keys():
			_touch_codex(str(def_id), xp, 0)
	descent["ended_at"] = _now()
	descent["ended_reason"] = "fell"
	descent["active"] = false
	descent["final_stats"] = stats
	descent["streak"] = 0
	deepest_floor = maxi(deepest_floor, floor_number)
	best_streak = maxi(best_streak, best)
	active_duel_state = null
	descent["last_duel"] = summary
	var result := {
		"ok": true,
		"kind": "fall",
		"floor": floor_number,
		"performance": perf,
		"marks": marks,
		"reagents": reagents_granted,
		"cards": cards_revealed,
		"salvage_cache": true,
		"underdog": underdog,
		"cleared": cleared,
		"best_streak": best,
		"summary": summary,
	}
	descent["result"] = result
	last_result = result
	save_now()
	descent_changed.emit()
	collection_changed.emit()
	currency_changed.emit()
	return result

func apply_door(choice: String) -> Dictionary:
	if not has_active_descent():
		return {"ok": false, "reason": "No active Descent."}
	if not bool(descent.get("door_pending", false)):
		return {"ok": false, "reason": "No door is waiting."}
	match choice:
		"warden":
			descent["vault"] = false
		"vault":
			descent["vault"] = true
		"stair":
			descent["vault"] = false
			descent["current_floor"] = int(descent.get("current_floor", 1)) + 1
			unlocked_floor = maxi(unlocked_floor, int(descent.get("current_floor", 1)))
			descent["deepest"] = maxi(int(descent.get("deepest", 1)), int(descent.get("current_floor", 1)))
		_:
			return {"ok": false, "reason": "Unknown door."}
	descent["door_pending"] = false
	descent["stair_skipped"] = choice == "stair"
	save_now()
	descent_changed.emit()
	return {"ok": true, "choice": choice, "vault": bool(descent.get("vault", false)), "current_floor": int(descent.get("current_floor", 1))}

func recall() -> Dictionary:
	if not has_active_descent():
		return {"ok": false, "reason": "No active Descent."}
	if active_duel_state != null and not active_duel_state.ended:
		return {"ok": false, "reason": "The current duel resolves first. Use Recall on the Table."}
	var cleared := int(descent.get("cleared", 0))
	var underdog := float(descent.get("underdog", 0.0))
	var marks := Economy.recall_marks(cleared, underdog)
	var rng := GameRng.new(int(descent.get("seed", 1)) + cleared * 71, 23)
	var reagents_granted: Dictionary = {}
	_grant_one_reagent(str(rng.pick(["reagent.pale_ink", "reagent.solvent", "reagent.varnish"])), 1, reagents_granted)
	for i in range(cleared / 5):
		_grant_one_reagent(str(rng.pick(["reagent.prism_ink", "reagent.deep_ink", "reagent.fracture"])), 1, reagents_granted)
	for reagent_id in reagents_granted.keys():
		add_reagent(str(reagent_id), int(reagents_granted[reagent_id]))
	add_marks(marks, "recall")
	deepest_floor = maxi(deepest_floor, int(descent.get("deepest", 0)))
	best_streak = maxi(best_streak, int(descent.get("best_streak", 0)))
	descent["ended_at"] = _now()
	descent["ended_reason"] = "recalled"
	descent["active"] = false
	active_duel_state = null
	var result := {
		"ok": true,
		"kind": "returned",
		"floor": int(descent.get("current_floor", 1)),
		"gate_floor": int(descent.get("gate_floor", 1)),
		"cleared": cleared,
		"marks": marks,
		"reagents": reagents_granted,
		"cards": [],
		"best_streak": int(descent.get("best_streak", 0)),
		"underdog": underdog,
	}
	descent["result"] = result
	last_result = result
	save_now()
	descent_changed.emit()
	currency_changed.emit()
	collection_changed.emit()
	return result

func abandon_descent() -> void:
	if descent.is_empty():
		return
	descent["ended_at"] = _now()
	descent["ended_reason"] = "abandoned"
	descent["active"] = false
	active_duel_state = null
	save_now()
	descent_changed.emit()

func _grant_deck_honour(honour_id: String, ref_value: String) -> void:
	var deck: DeckModel = decks.get(int(descent.get("deck_id", 0)))
	if deck == null:
		return
	for instance_id in deck.main:
		var instance: CardInstance = instances.get(instance_id)
		if instance != null:
			instance.add_honour(honour_id, ref_value, _now())

func next_gate_floor() -> int:
	if last_result.is_empty():
		return clampi(unlocked_floor, 1, unlocked_floor)
	return clampi(int(last_result.get("floor", unlocked_floor)) + 1, 1, unlocked_floor)
