class_name DuelCard
extends RefCounted

var uid: int = 0
var instance: CardInstance
var def: CardDef
var owner: int = 0
var lane: int = -1
var zone: String = GameConst.ZONE_DECK
var position: String = GameConst.POSITION_ATTACK
var face_down: bool = false
var set_turn: int = 0
var summoned_turn: int = 0
var attacked_turn: int = -1
var temp_atk: int = 0
var temp_def: int = 0
var buffs: Array[Dictionary] = []
var is_token: bool = false
var last_word_used: bool = false
var flags: Dictionary = {}

func display_name() -> String:
	if def == null:
		return "Unknown"
	if instance != null and not instance.custom_name.is_empty():
		return instance.custom_name
	return def.name

func is_monster() -> bool:
	return def != null and def.is_monster()

func is_spell() -> bool:
	return def != null and def.is_spell()

func is_trap() -> bool:
	return def != null and def.is_trap()

func is_face_up() -> bool:
	return not face_down

func is_attack_position() -> bool:
	return position == GameConst.POSITION_ATTACK

func is_defense_position() -> bool:
	return position == GameConst.POSITION_DEFENSE
