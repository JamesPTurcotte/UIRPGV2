class_name DuelPlayer
extends RefCounted

var index: int = 0
var name: String = "Keeper"
var resolve: int = GameConst.RESOLVE_START
var max_resolve: int = GameConst.RESOLVE_START
var deck: Array[DuelCard] = []
var hand: Array[DuelCard] = []
var monsters: Array = [null, null, null]
var backrow: Array = [null, null, null]
var remains: Array[DuelCard] = []
var banished: Array[DuelCard] = []
var called_this_turn: bool = false
var hand_limit: int = GameConst.HAND_LIMIT
var doctrine: String = "read"
var stats: Dictionary = {
	"damage_dealt": 0,
	"damage_taken": 0,
	"damage_healed": 0,
	"cards_played": 0,
	"monsters_destroyed": 0,
	"cards_drawn": 0,
}

func _init(player_index: int = 0, player_name: String = "Keeper") -> void:
	index = player_index
	name = player_name

func monster_count() -> int:
	var count := 0
	for card in monsters:
		if card != null:
			count += 1
	return count

func backrow_count() -> int:
	var count := 0
	for card in backrow:
		if card != null:
			count += 1
	return count

func empty_monster_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for lane in range(3):
		if monsters[lane] == null:
			lanes.append(lane)
	return lanes

func empty_backrow_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for lane in range(3):
		if backrow[lane] == null:
			lanes.append(lane)
	return lanes

func all_board_cards() -> Array[DuelCard]:
	var cards: Array[DuelCard] = []
	for card in monsters:
		if card != null:
			cards.append(card)
	for card in backrow:
		if card != null:
			cards.append(card)
	return cards

func all_cards() -> Array[DuelCard]:
	var cards: Array[DuelCard] = []
	cards.append_array(deck)
	cards.append_array(hand)
	cards.append_array(all_board_cards())
	cards.append_array(remains)
	cards.append_array(banished)
	return cards
