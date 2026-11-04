class_name GameConst
extends RefCounted

## Shared vocabulary for content, domain, and presentation.
## Strings are used at the content boundary; constants prevent typos in code.

const PHASES: Array[String] = ["dawn", "draw", "call", "actions", "clash", "dusk"]
const PHASE_LABELS := {
	"dawn": "Dawn",
	"draw": "Draw",
	"call": "Call",
	"actions": "Actions",
	"clash": "Clash",
	"dusk": "Dusk",
}

const TYPE_MONSTER := "monster"
const TYPE_SPELL := "spell"
const TYPE_TRAP := "trap"

const ATTRIBUTES: Array[String] = ["ember", "tide", "verdant", "umbra", "neutral"]
const LINEAGES: Array[String] = ["beast", "spirit", "construct", "wanderer"]
const RARITIES: Array[String] = ["common", "uncommon", "rare", "legendary"]
const RARITY_LETTER := {
	"common": "C",
	"uncommon": "U",
	"rare": "R",
	"legendary": "L",
}
const RARITY_ORDER := {
	"common": 0,
	"uncommon": 1,
	"rare": 2,
	"legendary": 3,
}

const POSITION_ATTACK := "attack"
const POSITION_DEFENSE := "defense"

const ZONE_DECK := "deck"
const ZONE_HAND := "hand"
const ZONE_MONSTER := "monster"
const ZONE_BACKROW := "backrow"
const ZONE_REMAINS := "remains"
const ZONE_VOID := "void"

const RESOLVE_START := 4000
const HAND_LIMIT := 7
const OPENING_HAND := 5
const MAX_TURN_SOFT_CAP := 200
const MAX_CHAIN := 3
const DECK_SIZE := 40
const SIDE_SIZE := 5
const MAX_COPIES := 3

const TIER_GATE := {1: 1, 2: 10, 3: 25, 4: 45, 5: 70}

const MOD_PREFIX := "prefix"
const MOD_SUFFIX := "suffix"
const MOD_VERDIGRIS := "verdigris"

const REAGENT_TABS := ["inks", "solvents", "seals", "foul", "rare", "history"]
const TAB_LABELS := {
	"inks": "Inks",
	"solvents": "Solvents",
	"seals": "Seals",
	"foul": "Foul",
	"rare": "Rare",
	"history": "History",
}

const KEYWORD_LABELS := {
	"kindle": "KINDLE",
	"echo": "ECHO",
	"flip": "FLIP",
	"pierce": "PIERCE",
	"fleet": "FLEET",
	"veil": "VEIL",
	"bind": "BIND",
	"rite": "RITE",
	"banish": "BANISH",
	"offer": "OFFER",
	"set": "SET",
	"chain": "CHAIN",
}

static func other(player: int) -> int:
	return 1 - player

static func phase_index(phase: String) -> int:
	return PHASES.find(phase)

static func next_phase(phase: String) -> String:
	var index := PHASES.find(phase)
	if index < 0 or index >= PHASES.size() - 1:
		return PHASES[0]
	return PHASES[index + 1]

static func rarity_letter(rarity: String) -> String:
	return RARITY_LETTER.get(rarity, "C")

static func tier_for_provenance(provenance: int) -> int:
	var best := 1
	for tier in [1, 2, 3, 4, 5]:
		if provenance >= TIER_GATE[tier]:
			best = tier
	return best
