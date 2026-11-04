class_name DeckModel
extends RefCounted

var deck_id: int = 0
var name: String = "Untitled Deck"
var doctrine: String = "read"
var main: Array[int] = []
var side: Array[int] = []
var cover_instance_id: int = 0
var created_at: int = 0
var updated_at: int = 0

func total_main() -> int:
	return main.size()

func total_side() -> int:
	return side.size()

func all_instance_ids() -> Array[int]:
	var result: Array[int] = []
	result.append_array(main)
	result.append_array(side)
	return result

func validate(instances_by_id: Dictionary, defs_by_id: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if main.size() != GameConst.DECK_SIZE:
		errors.append("Main deck is %d / %d." % [main.size(), GameConst.DECK_SIZE])
	if side.size() > GameConst.SIDE_SIZE:
		errors.append("Sideboard is %d / %d." % [side.size(), GameConst.SIDE_SIZE])
	var seen: Dictionary = {}
	var copy_counts: Dictionary = {}
	var legendary_count := 0
	for instance_id in all_instance_ids():
		if seen.has(instance_id):
			errors.append("Copy #%d appears twice." % instance_id)
			continue
		seen[instance_id] = true
		var instance: CardInstance = instances_by_id.get(instance_id)
		if instance == null:
			errors.append("Missing copy #%d." % instance_id)
			continue
		var def: CardDef = defs_by_id.get(instance.def_id)
		if def == null:
			errors.append("Missing card definition %s." % instance.def_id)
			continue
		copy_counts[def.id] = int(copy_counts.get(def.id, 0)) + 1
		if def.rarity == "legendary":
			legendary_count += 1
	for def_id in copy_counts.keys():
		var def: CardDef = defs_by_id.get(def_id)
		if def == null:
			continue
		var limit := 1 if def.rarity == "legendary" else GameConst.MAX_COPIES
		if int(copy_counts[def_id]) > limit:
			errors.append("%s has %d copies (max %d)." % [def.name, copy_counts[def_id], limit])
	if legendary_count > 1:
		errors.append("A deck may contain at most 1 Legendary copy.")
	for instance_id in main:
		if side.has(instance_id):
			errors.append("Copy #%d is in both main and sideboard." % instance_id)
	return errors

func is_legal(instances_by_id: Dictionary, defs_by_id: Dictionary) -> bool:
	return validate(instances_by_id, defs_by_id).is_empty()

func power(instances_by_id: Dictionary, defs_by_id: Dictionary, mod_db: Dictionary) -> int:
	var total := 0
	for instance_id in main:
		var instance: CardInstance = instances_by_id.get(instance_id)
		if instance != null:
			total += CardResolver.power(instance, defs_by_id.get(instance.def_id), mod_db)
	return total

func to_dict() -> Dictionary:
	return {
		"id": deck_id,
		"name": name,
		"doctrine": doctrine,
		"main": main.duplicate(),
		"side": side.duplicate(),
		"cover_instance_id": cover_instance_id,
		"created_at": created_at,
		"updated_at": updated_at,
	}

static func from_dict(data: Dictionary) -> DeckModel:
	var deck := DeckModel.new()
	deck.deck_id = int(data.get("id", 0))
	deck.name = str(data.get("name", "Untitled Deck"))
	deck.doctrine = str(data.get("doctrine", "read"))
	deck.cover_instance_id = int(data.get("cover_instance_id", 0))
	deck.created_at = int(data.get("created_at", 0))
	deck.updated_at = int(data.get("updated_at", 0))
	for raw in data.get("main", []):
		deck.main.append(int(raw))
	for raw in data.get("side", []):
		deck.side.append(int(raw))
	return deck
