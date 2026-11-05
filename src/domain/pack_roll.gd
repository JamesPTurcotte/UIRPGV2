class_name PackRoll
extends RefCounted

## Deterministic pack contents. Rolled once at acquisition; opening never
## rerolls. No pity, no hidden manipulation.

const EARLY_WEIGHTS := {"common": 70, "uncommon": 22, "rare": 7, "legendary": 1}
const MID_WEIGHTS := {"common": 40, "uncommon": 35, "rare": 20, "legendary": 5}
const DEEP_WEIGHTS := {"common": 30, "uncommon": 35, "rare": 25, "legendary": 10}

static func _weights_for(provenance: int) -> Dictionary:
	if provenance >= 50:
		return DEEP_WEIGHTS
	if provenance >= 25:
		return MID_WEIGHTS
	return EARLY_WEIGHTS

static func _roll_rarity(rng: GameRng, weights: Dictionary) -> String:
	var order := ["common", "uncommon", "rare", "legendary"]
	var total := 0.0
	for rarity in order:
		total += float(weights.get(rarity, 0))
	var u := float(rng.next_int(1_000_000)) / 1_000_000.0
	var cursor := 0.0
	for rarity in order:
		cursor += float(weights.get(rarity, 0)) / total
		if u <= cursor:
			return rarity
	return "common"

static func _cards_of_rarity(cards: Array, rarity: String) -> Array:
	var pool: Array = []
	for card in cards:
		if card.rarity == rarity:
			pool.append(card)
	return pool

static func _pick_card(rng: GameRng, cards: Array, rarity: String) -> CardDef:
	var pool := _cards_of_rarity(cards, rarity)
	if pool.is_empty():
		pool = cards
	return rng.pick(pool) as CardDef

static func roll_pack(pack: Dictionary, seed_value: int, cards: Array, reagents: Array, inks: Array, shimmers: Array) -> Dictionary:
	var rng := GameRng.new(seed_value, 7)
	var count := int(pack.get("cards", 3))
	var provenance := int(pack.get("provenance", 5))
	var guarantee := str(pack.get("guarantee", ""))
	var weights := _weights_for(provenance)
	var results: Array[Dictionary] = []
	var guarantee_met := false
	for i in range(count):
		var rarity := _roll_rarity(rng, weights)
		if guarantee == "rare" and rarity in ["common", "uncommon"]:
			guarantee_met = guarantee_met or false
		elif guarantee == "uncommon" and rarity in ["uncommon", "rare", "legendary"]:
			guarantee_met = true
		elif guarantee == "rare" and rarity in ["rare", "legendary"]:
			guarantee_met = true
		var card := _pick_card(rng, cards, rarity)
		if card == null:
			continue
		var ink_id := "ink.iron"
		if not inks.is_empty() and rng.chance(0.10):
			ink_id = str(rng.pick(inks)["id"])
		var shimmer_id := "shimmer.none"
		var shimmer_chance := float(pack.get("shimmer_chance", 0.0))
		if not shimmers.is_empty() and rng.chance(shimmer_chance):
			var options: Array = []
			for shimmer in shimmers:
				if str(shimmer.get("id", "")) != "shimmer.none":
					options.append(shimmer)
			if not options.is_empty():
				shimmer_id = str(rng.pick(options)["id"])
		results.append({
			"def_id": card.id,
			"rarity": card.rarity,
			"provenance": provenance,
			"ink_id": ink_id,
			"shimmer_id": shimmer_id,
		})
	if guarantee in ["uncommon", "rare"] and not guarantee_met and not results.is_empty():
		var required := "uncommon" if guarantee == "uncommon" else "rare"
		var pool := _cards_of_rarity(cards, required)
		if pool.is_empty():
			pool = cards
		var replacement := rng.pick(pool) as CardDef
		results[results.size() - 1] = {
			"def_id": replacement.id,
			"rarity": replacement.rarity,
			"provenance": provenance,
			"ink_id": "ink.iron",
			"shimmer_id": "shimmer.none",
		}
	var reagent_rewards: Array[String] = []
	var reagent_guarantee = pack.get("reagent_guarantee", null)
	if reagent_guarantee != null and not str(reagent_guarantee).is_empty():
		reagent_rewards.append(str(reagent_guarantee))
	return {"cards": results, "reagents": reagent_rewards}

## Legacy alias; remove after the one-version compatibility window.
static func roll_folio(folio: Dictionary, seed_value: int, cards: Array, reagents: Array, inks: Array, shimmers: Array) -> Dictionary:
	return roll_pack(folio, seed_value, cards, reagents, inks, shimmers)

static func roll_card_drop(seed_value: int, floor_number: int, cards: Array, index: int = 0) -> Dictionary:
	var rng := GameRng.new(seed_value, 1000 + index + floor_number * 13)
	var weights := _weights_for(floor_number * 3)
	var rarity := _roll_rarity(rng, weights)
	var card := _pick_card(rng, cards, rarity)
	if card == null:
		return {}
	return {
		"def_id": card.id,
		"rarity": card.rarity,
		"provenance": clampi(floor_number, 1, 100),
		"ink_id": "ink.iron",
		"shimmer_id": "shimmer.none",
	}
