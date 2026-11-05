extends Node

## Content autoload. Loads the generated JSON once and exposes immutable
## definitions to the domain and presentation layers.

var data: Dictionary = {}
var cards: Dictionary = {}
var card_list: Array[CardDef] = []
var sets: Dictionary = {}
var opponents: Dictionary = {}
var opponents_by_floor: Dictionary = {}
var mods: Dictionary = {}
var reagents: Dictionary = {}
var reagent_list: Array[Dictionary] = []
var packs: Dictionary = {}
var starters: Dictionary = {}
var inks: Dictionary = {}
var shimmers: Dictionary = {}
var themes: Dictionary = {}
var content_version: int = 1
var rules_version: int = 1
var loaded: bool = false

func _ready() -> void:
	load_content()

func load_content() -> void:
	var path := "res://content/data.json"
	if not FileAccess.file_exists(path):
		push_error("Content: missing %s. Run tools/build_content.py." % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Content: cannot open %s." % path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("Content: %s is not valid JSON." % path)
		return
	data = parsed
	content_version = int(data.get("content_version", 1))
	rules_version = int(data.get("rules_version", 1))
	cards.clear()
	card_list.clear()
	for raw in data.get("cards", []):
		var def := CardDef.from_dict(raw)
		cards[def.id] = def
		card_list.append(def)
	card_list.sort_custom(func(a: CardDef, b: CardDef) -> bool: return a.id < b.id)
	for raw in data.get("sets", []):
		sets[str(raw.get("id", ""))] = raw
	for raw in data.get("opponents", []):
		opponents[str(raw.get("id", ""))] = raw
		opponents_by_floor[int(raw.get("floor", -1))] = raw
	for raw in data.get("mods", []):
		mods[str(raw.get("id", ""))] = raw
	for raw in data.get("reagents", []):
		reagents[str(raw.get("id", ""))] = raw
		reagent_list.append(raw)
	for raw in data.get("packs", data.get("folios", [])):
		packs[str(raw.get("id", ""))] = raw
	for raw in data.get("starters", []):
		starters[str(raw.get("id", ""))] = raw
	for raw in data.get("inks", []):
		inks[str(raw.get("id", ""))] = raw
	for raw in data.get("shimmers", []):
		shimmers[str(raw.get("id", ""))] = raw
	for raw in data.get("themes", []):
		themes[str(raw.get("id", ""))] = raw
	loaded = not cards.is_empty()
	if loaded:
		print("Content loaded: %d cards, %d opponents, %d mods." % [cards.size(), opponents.size(), mods.size()])

func card(def_id: String) -> CardDef:
	return cards.get(def_id)

func opponent(opponent_id: String) -> Dictionary:
	return opponents.get(opponent_id, {})

func opponent_for_floor(floor_number: int) -> Dictionary:
	return opponents_by_floor.get(floor_number, {})

func mod(mod_id: String) -> Dictionary:
	return mods.get(mod_id, {})

func reagent(reagent_id: String) -> Dictionary:
	return reagents.get(reagent_id, {})

func pack(pack_id: String) -> Dictionary:
	var found: Dictionary = packs.get(pack_id, {})
	if not found.is_empty():
		return found
	# One-version compatibility for saves and content authored before the rename.
	if pack_id.begins_with("folio."):
		return packs.get("pack." + pack_id.substr(6), {})
	return {}

## Legacy alias; remove after the one-version compatibility window.
func folio(folio_id: String) -> Dictionary:
	return pack(folio_id)

func starter(starter_id: String) -> Dictionary:
	return starters.get(starter_id, {})

func recommended_power(floor_number: int) -> int:
	if floor_number <= 9:
		return 800 + maxi(0, floor_number - 1) * 50
	if floor_number <= 18:
		return 1200 + (floor_number - 10) * 50
	if floor_number <= 27:
		return 1600 + (floor_number - 19) * 50
	return mini(4000, 2000 + (floor_number - 28) * 40)

func card_ids_by_rarity(rarity: String) -> Array[String]:
	var result: Array[String] = []
	for def in card_list:
		if def.rarity == rarity:
			result.append(def.id)
	return result

func reagent_ids() -> Array[String]:
	var result: Array[String] = []
	for raw in reagent_list:
		result.append(str(raw.get("id", "")))
	return result

func pack_ids() -> Array[String]:
	var result: Array[String] = []
	for raw in data.get("packs", data.get("folios", [])):
		result.append(str(raw.get("id", "")))
	return result

## Legacy alias; remove after the one-version compatibility window.
func folio_ids() -> Array[String]:
	return pack_ids()
