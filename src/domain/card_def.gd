class_name CardDef
extends RefCounted

## Immutable card definition. Instances point at this by id.

var id: String = ""
var set_id: String = ""
var name: String = ""
var type: String = GameConst.TYPE_MONSTER
var subtype: String = ""          # monster / normal / continuous / equip / counter
var attribute: String = "neutral"
var lineage: String = ""
var offer: int = 0
var atk: int = 0
var defense: int = 0
var rarity: String = "common"
var role: String = "glue"
var text: String = ""
var type_line: String = ""
var keywords: Array[String] = []
var effect: Dictionary = {}
var has_effect: bool = false
var base_power: int = 0
var effect_value: int = 0

static func from_dict(data: Dictionary) -> CardDef:
	var card := CardDef.new()
	card.id = str(data.get("id", ""))
	card.set_id = str(data.get("set", ""))
	card.name = str(data.get("name", ""))
	card.type = str(data.get("type", GameConst.TYPE_MONSTER))
	card.subtype = str(data.get("spell_kind", data.get("trap_kind", "monster")))
	card.attribute = str(data.get("attribute", "neutral"))
	card.lineage = str(data.get("lineage", "")) if data.get("lineage") != null else ""
	card.offer = int(data.get("offer", 0))
	card.atk = int(data.get("atk", 0))
	card.defense = int(data.get("defense", 0))
	card.rarity = str(data.get("rarity", "common"))
	card.role = str(data.get("role", "glue"))
	card.text = str(data.get("text", ""))
	card.type_line = str(data.get("type_line", ""))
	card.base_power = int(data.get("power", 0))
	card.effect_value = int(data.get("effect_value", 0))
	card.keywords.clear()
	for keyword in data.get("keywords", []):
		card.keywords.append(str(keyword))
	var raw_effect = data.get("effect", null)
	if raw_effect is Dictionary:
		card.effect = raw_effect
		card.has_effect = true
	return card

func is_monster() -> bool:
	return type == GameConst.TYPE_MONSTER

func is_spell() -> bool:
	return type == GameConst.TYPE_SPELL

func is_trap() -> bool:
	return type == GameConst.TYPE_TRAP

func is_continuous() -> bool:
	return subtype == "continuous"

func has_keyword(keyword: String) -> bool:
	return keywords.has(keyword)

func type_label() -> String:
	if type_line.is_empty():
		var bits: Array[String] = [type.to_upper(), attribute.to_upper()]
		if not lineage.is_empty():
			bits.append(lineage.to_upper())
		return " · ".join(bits)
	return type_line

func subtype_label() -> String:
	if subtype.is_empty() or subtype == "monster":
		return ""
	return subtype.capitalize()

func canonical_line() -> String:
	## "MONSTER · EMBER · BEAST" for the type band; includes subtype for S/T.
	var bits: Array[String] = [type.to_upper(), attribute.to_upper()]
	if not lineage.is_empty():
		bits.append(lineage.to_upper())
	elif not subtype.is_empty() and subtype != "monster":
		bits.append(subtype.to_upper())
	else:
		bits.append(subtype.to_upper())
	return " · ".join(bits)
