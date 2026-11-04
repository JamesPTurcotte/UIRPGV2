extends Node

## Headless test runner. Run:
##   godot --headless --path . res://tests/test_runner.tscn
## Exits non-zero on failure.

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []
var _uid_counter: int = 1

func _ready() -> void:
	await get_tree().process_frame
	_run_all()
	print("")
	print("UIRPG tests: %d passed, %d failed." % [passed, failed])
	for failure in failures:
		print("  FAIL: %s" % failure)
	get_tree().quit(1 if failed > 0 else 0)

func _run_all() -> void:
	print("test: content")
	_test_content()
	print("test: deck")
	_test_deck_legality()
	print("test: battle")
	_test_battle_math()
	print("test: offer")
	_test_offer_and_kindle()
	print("test: flip")
	_test_flip_and_traps()
	print("test: effects")
	_test_effects()
	print("test: economy")
	_test_economy()
	print("test: packs")
	_test_packs()
	print("test: crafting")
	_test_crafting()
	print("test: serialization")
	_test_serialization()
	_test_save_store()
	_test_session_loop()
	_test_deck_moves_and_query()
	_test_card_layout_audit()
	print("test: responsive layout")
	_test_responsive_layout()
	print("test: seeded duels")
	_test_seeded_duels()

func _ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		failures.append(label)
		print("FAIL: %s" % label)

func _eq(actual, expected, label: String) -> void:
	_ok(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])

func _near(actual: float, expected: float, epsilon: float, label: String) -> void:
	_ok(absf(actual - expected) <= epsilon, "%s (expected %f, got %f)" % [label, expected, actual])

func _defs() -> Dictionary:
	return Content.cards

func _fresh_state() -> DuelState:
	var state := DuelState.new()
	state.mod_db = Content.mods
	state.def_db = Content.cards
	state.players = [DuelPlayer.new(0, "You"), DuelPlayer.new(1, "Warden")]
	state.players[0].resolve = 4000
	state.players[0].max_resolve = 4000
	state.players[1].resolve = 4000
	state.players[1].max_resolve = 4000
	state.active = 0
	state.first_player = 1
	state.turn = 2
	state.phase = "clash"
	state.skip_clash = false
	state.rng = GameRng.new(1, 1)
	state.ai_rng = GameRng.new(1, 2)
	return state

func _make_instance(def_id: String, provenance: int = 1, quality: int = 0) -> CardInstance:
	var instance := CardInstance.new(_uid_counter, def_id, provenance)
	_uid_counter += 1
	instance.quality = quality
	return instance

func _make_card(state: DuelState, def_id: String, owner: int) -> DuelCard:
	var instance := _make_instance(def_id)
	var def: CardDef = Content.cards[def_id]
	var card := DuelCard.new()
	card.uid = _uid_counter
	_uid_counter += 1
	card.instance = instance
	card.def = def
	card.owner = owner
	return card

func _add_monster(state: DuelState, owner: int, lane: int, def_id: String, position: String = GameConst.POSITION_ATTACK, face_down: bool = false) -> DuelCard:
	var card := _make_card(state, def_id, owner)
	card.zone = GameConst.ZONE_MONSTER
	card.lane = lane
	card.position = position
	card.face_down = face_down
	card.summoned_turn = state.turn - 1
	state.players[owner].monsters[lane] = card
	return card

func _add_backrow(state: DuelState, owner: int, lane: int, def_id: String, face_down: bool = false, set_turn: int = 0) -> DuelCard:
	var card := _make_card(state, def_id, owner)
	card.zone = GameConst.ZONE_BACKROW
	card.lane = lane
	card.face_down = face_down
	card.set_turn = set_turn
	state.players[owner].backrow[lane] = card
	return card

func _add_hand(state: DuelState, owner: int, def_id: String) -> DuelCard:
	var card := _make_card(state, def_id, owner)
	card.zone = GameConst.ZONE_HAND
	state.players[owner].hand.append(card)
	return card

func _seed_deck(state: DuelState, owner: int, count: int = 10) -> void:
	for i in range(count):
		var card := _make_card(state, "ember.ash_moth", owner)
		card.zone = GameConst.ZONE_DECK
		state.players[owner].deck.append(card)

func _test_content() -> void:
	_ok(Content.loaded, "content loaded")
	_ok(Content.cards.size() >= 16, "at least 16 card definitions")
	for def in Content.card_list:
		_ok(not def.id.is_empty(), "card has id")
		_ok(def.name.length() <= 24, "card name fits: %s" % def.name)
		_ok(def.base_power >= 0, "card power non-negative: %s" % def.id)
	_ok(Content.mods.size() >= 10, "mod pool present")
	_ok(Content.reagents.size() == 10, "10 launch reagents")
	_ok(Content.folios.size() == 5, "5 folios")
	_ok(Content.starters.has("starter.ember"), "starter present")
	_ok(Content.opponent_for_floor(1).get("id", "") == "warden.damp", "floor 1 Warden")
	_ok(Content.opponent_for_floor(3).get("boss", false), "floor 3 boss")
	var cinder: CardDef = Content.cards["ember.cinder_hound"]
	_eq(cinder.attribute, "ember", "Cinder Hound attribute")
	_eq(cinder.atk, 1200, "Cinder Hound ATK")
	_eq(cinder.offer, 0, "Cinder Hound Offer")

func _test_deck_legality() -> void:
	var instances: Dictionary = {}
	var instances_arr: Array = []
	var index := 0
	for def_id in Content.cards.keys():
		var instance := _make_instance(str(def_id))
		instances[instance.instance_id] = instance
		instances_arr.append(instance)
	var legal := DeckModel.new()
	for i in range(40):
		var instance: CardInstance = instances_arr[i % instances_arr.size()]
		legal.main.append(instance.instance_id)
	# This list has duplicates beyond the copy limit; fix to a known legal starter.
	var starter: Dictionary = Content.starter("starter.ember")
	instances.clear()
	instances_arr.clear()
	legal.main.clear()
	for entry in starter.get("deck", []):
		for i in range(int(entry.get("count", 0))):
			var instance := _make_instance(str(entry.get("def", "")))
			instances[instance.instance_id] = instance
			legal.main.append(instance.instance_id)
	for entry in starter.get("sideboard", []):
		for i in range(int(entry.get("count", 0))):
			var instance := _make_instance(str(entry.get("def", "")))
			instances[instance.instance_id] = instance
			legal.side.append(instance.instance_id)
	_eq(legal.main.size(), 40, "starter main is 40")
	_eq(legal.side.size(), 5, "starter side is 5")
	_ok(legal.validate(instances, Content.cards).is_empty(), "starter deck is legal")
	_ok(legal.power(instances, Content.cards, Content.mods) > 0, "deck power calculated")

	var short := DeckModel.new()
	short.main.append(legal.main[0])
	_ok(not short.validate(instances, Content.cards).is_empty(), "short deck is illegal")

	var too_many := DeckModel.new()
	for i in range(40):
		too_many.main.append(legal.main[i])
	too_many.main.append(legal.main[0])
	_ok(not too_many.validate(instances, Content.cards).is_empty(), "41-card deck is illegal")

	var legendary := DeckModel.new()
	var first_legendary := ""
	for def_id in Content.cards.keys():
		if Content.cards[def_id].rarity == "legendary":
			first_legendary = str(def_id)
			break
	var legendary_instances: Dictionary = {}
	var count := 0
	for entry in Content.starter("starter.ember").get("deck", []):
		for i in range(int(entry.get("count", 0))):
			var def_id := str(entry.get("def", ""))
			if def_id == first_legendary:
				continue
			if count >= 38:
				break
			var instance := _make_instance(def_id)
			legendary_instances[instance.instance_id] = instance
			legendary.main.append(instance.instance_id)
			count += 1
	var l1 := _make_instance(first_legendary)
	var l2 := _make_instance(first_legendary)
	legendary_instances[l1.instance_id] = l1
	legendary_instances[l2.instance_id] = l2
	legendary.main.append(l1.instance_id)
	legendary.main.append(l2.instance_id)
	_ok(not legendary.validate(legendary_instances, Content.cards).is_empty(), "two Legendary copies are illegal")

func _test_battle_math() -> void:
	var state := _fresh_state()
	var attacker := _add_monster(state, 0, 1, "ember.cinder_hound")
	DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 1})
	_eq(state.players[1].resolve, 2800, "direct attack deals ATK")

	# The face is sealed while any enemy monster remains in a monster zone.
	state = _fresh_state()
	attacker = _add_monster(state, 0, 2, "ember.cinder_hound")
	_add_monster(state, 1, 0, "neutral.paper_warden")
	var sealed := DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 2})
	_ok(not bool(sealed.get("ok", false)), "empty lane cannot be attacked while a guard remains")
	_eq(state.players[1].resolve, 4000, "sealed attack deals no Resolve damage")
	var guarded_actions := DuelRules.legal_actions(state)
	var empty_lane_attack := false
	var guard_attack := false
	for action in guarded_actions:
		if str(action.get("type", "")) != "attack":
			continue
		if int(action.get("target_lane", -1)) == 2:
			empty_lane_attack = true
		if int(action.get("target_lane", -1)) == 0:
			guard_attack = true
	_ok(not empty_lane_attack, "legal actions omit attacks through an open lane while guarded")
	_ok(guard_attack, "legal actions keep attacks into a guard lane")
	var into_guard := DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 0})
	_ok(bool(into_guard.get("ok", false)), "attack into the guard lane is legal")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 2, "ember.cinder_hound")
	_add_monster(state, 1, 0, "neutral.paper_warden")
	var ai_action := DuelAI.choose_action(state, 100)
	_ok(str(ai_action.get("type", "")) != "attack" or int(ai_action.get("target_lane", -1)) == 0, "AI never attacks a sealed face")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 0, "ember.cinder_hound")
	_add_monster(state, 1, 0, "verdant.bramble_wall", GameConst.POSITION_DEFENSE)
	DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 0})
	_eq(state.players[0].resolve, 3000, "attack into higher DEF reflects 1000")
	_ok(state.players[1].monsters[0] != null, "higher DEF monster survives")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 0, "ember.ember_scout")
	var defender := _add_monster(state, 1, 0, "tide.tidebound_archivist")
	DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 0})
	_ok(state.players[1].monsters[0] == null, "higher ATK destroys defender")
	_eq(state.players[1].resolve, 3400, "attack-vs-attack difference is dealt")
	_ok(state.players[1].remains.has(defender), "destroyed monster goes to Remains")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 0, "neutral.paper_warden")
	state.destroy_card(attacker, "test")
	_ok(state.players[0].remains.size() == 1, "destroyed card enters Remains")

func _test_offer_and_kindle() -> void:
	var state := _fresh_state()
	state.phase = "call"
	_add_monster(state, 0, 0, "ember.ash_moth")
	_add_monster(state, 0, 1, "ember.cinder_hound")
	var colossus := _add_hand(state, 0, "verdant.verdant_colossus")
	var action := {"type": "call", "uid": colossus.uid, "lane": 0, "position": GameConst.POSITION_ATTACK, "face_down": false, "offers": []}
	var result := DuelRules.apply(state, 0, action)
	_ok(bool(result.get("ok", false)), "Offer 2 call is legal")
	_eq(state.players[0].remains.size(), 2, "Offer sends two monsters to Remains")
	_ok(state.players[0].monsters[0] != null and state.players[0].monsters[0].def.id == "verdant.verdant_colossus", "offered monster is called")

	state = _fresh_state()
	state.phase = "call"
	var hound := _add_hand(state, 0, "ember.cinder_hound")
	DuelRules.apply(state, 0, {"type": "call", "uid": hound.uid, "lane": 0, "position": GameConst.POSITION_ATTACK, "face_down": false, "offers": []})
	_eq(state.players[1].resolve, 3800, "KINDLE deals 200 on call")

	state = _fresh_state()
	_add_monster(state, 0, 0, "ember.cinder_hound")
	var set_hound := _add_hand(state, 0, "ember.cinder_hound")
	state.phase = "call"
	DuelRules.apply(state, 0, {"type": "call", "uid": set_hound.uid, "lane": 1, "position": GameConst.POSITION_DEFENSE, "face_down": true, "offers": []})
	_eq(state.players[1].resolve, 4000, "set monster does not trigger KINDLE")
	_ok(state.players[0].monsters[1].face_down, "set monster is face-down")

func _test_flip_and_traps() -> void:
	var state := _fresh_state()
	_seed_deck(state, 1, 10)
	var attacker := _add_monster(state, 0, 0, "ember.cinder_hound")
	var archivist := _add_monster(state, 1, 0, "tide.tidebound_archivist", GameConst.POSITION_DEFENSE, true)
	var hand_before := state.players[1].hand.size()
	DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 0})
	_ok(not archivist.face_down, "attacked set monster flips")
	_eq(state.players[1].hand.size(), hand_before + 1, "FLIP draws 1")
	_eq(state.players[0].resolve, 3600, "attacker takes DEF difference")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 0, "ember.cinder_hound")
	_add_backrow(state, 1, 0, "neutral.ninefold_seal", true, 0)
	DuelRules.apply(state, 0, {"type": "attack", "uid": attacker.uid, "target_lane": 1})
	_eq(state.players[0].monsters[0], null, "Ninefold Seal banishes the attacker")
	_ok(state.players[1].remains.size() == 1, "counter trap goes to Remains")
	_eq(state.players[1].resolve, 4000, "negated attack deals no damage")

	state = _fresh_state()
	attacker = _add_monster(state, 0, 0, "ember.cinder_hound")
	_add_monster(state, 1, 2, "ember.ash_moth")
	_add_backrow(state, 0, 0, "verdant.bone_orchard", true, 0)
	state.destroy_card(state.players[1].monsters[2], "test")
	_ok(state.players[0].monsters[2] != null, "Bone Orchard summons a token in the destroyed lane")
	_eq(state.players[0].monsters[2].def.atk, 500, "Bone Orchard token is 500 ATK")

func _test_effects() -> void:
	var state := _fresh_state()
	_add_monster(state, 0, 1, "ember.cinder_hound")
	_add_backrow(state, 0, 1, "umbra.hollow_lantern", false, 0)
	var stats := state.stats_for(state.players[0].monsters[1])
	_eq(stats["atk"], 1400, "Hollow Lantern grants +200 ATK in its lane")

	state = _fresh_state()
	var moth := _add_monster(state, 0, 0, "ember.ash_moth")
	state.destroy_card(moth, "test")
	_eq(state.players[1].resolve, 3900, "ECHO deals 100 when destroyed")

	state = _fresh_state()
	_seed_deck(state, 0, 10)
	state.phase = "actions"
	var ledger := _add_hand(state, 0, "neutral.quiet_ledger")
	var hand_before := state.players[0].hand.size()
	DuelRules.apply(state, 0, {"type": "play", "uid": ledger.uid, "lane": 0})
	_eq(state.players[0].hand.size(), hand_before + 1, "Quiet Ledger draws 2 (net +1 after playing it)")
	_eq(state.pending_dusk_discard[0], 1, "Quiet Ledger schedules a Dusk discard")
	state.resolve_dusk()
	_eq(state.players[0].hand.size(), hand_before, "Dusk discard resolves")

	state = _fresh_state()
	state.phase = "actions"
	var whisper := _add_hand(state, 0, "umbra.grave_whisper")
	var hound := _add_monster(state, 0, 0, "ember.cinder_hound")
	state.destroy_card(hound, "test")
	DuelRules.apply(state, 0, {"type": "play", "uid": whisper.uid, "lane": 0})
	_ok(state.players[0].hand.any(func(card: DuelCard) -> bool: return card.def.id == "ember.cinder_hound"), "Grave Whisper returns a monster from Remains")

	state = _fresh_state()
	state.players[0].deck.clear()
	var empty_hand := state.players[0].hand.size()
	state.draw_cards(0, 1, true)
	_ok(not state.ended, "empty deck does not cause a loss")
	_eq(state.players[0].hand.size(), empty_hand, "empty deck skips the draw")

	state = _fresh_state()
	_seed_deck(state, 0, 10)
	state.phase = "actions"
	var tidecall := _add_hand(state, 0, "tide.tidecall")
	_add_monster(state, 0, 0, "tide.tidebound_archivist")
	var hand_size := state.players[0].hand.size()
	DuelRules.apply(state, 0, {"type": "play", "uid": tidecall.uid, "lane": 0})
	_eq(state.players[0].hand.size(), hand_size + 1, "Tidecall draws 1 with a TIDE monster (extra draw needs a second Tidecall condition check)")

func _test_economy() -> void:
	_near(Economy.underdog_bonus(800, 1000), 0.2, 0.0001, "Underdog bonus")
	_eq(Economy.win_marks(5, 3, 0.2), 39, "win marks formula")
	_eq(Economy.performance({"damage_dealt": 3000, "damage_healed": 1000, "cards_played": 10, "flawless_duels": 2}, 3, 4).get("total", 0), 140, "performance formula")
	_eq(Economy.loss_marks(140, 0.2), 198, "loss marks formula")
	_eq(Economy.recall_marks(3, 0.2), 48, "recall marks formula")
	_eq(Economy.print_cost("legendary"), 2000, "legendary print cost")
	_eq(Economy.dissolve_value("rare"), 50, "rare dissolve value")
	_eq(Economy.mastery_level_for_xp(100), 5, "mastery level threshold")

func _test_packs() -> void:
	var folio: Dictionary = Content.folio("folio.paper")
	var inks: Array = Content.data.get("inks", [])
	var shimmers: Array = Content.data.get("shimmers", [])
	var a := PackRoll.roll_folio(folio, 42, Content.card_list, Content.reagent_list, inks, shimmers)
	var b := PackRoll.roll_folio(folio, 42, Content.card_list, Content.reagent_list, inks, shimmers)
	_eq(JSON.stringify(a), JSON.stringify(b), "folio contents are deterministic by seed")
	var c := PackRoll.roll_folio(folio, 43, Content.card_list, Content.reagent_list, inks, shimmers)
	_ok(JSON.stringify(a) != JSON.stringify(c), "different seed rolls a different folio")
	for i in range(30):
		var roll := PackRoll.roll_folio(folio, 100 + i, Content.card_list, Content.reagent_list, inks, shimmers)
		var has_guarantee := false
		for card in roll.get("cards", []):
			if card.get("rarity", "") in ["uncommon", "rare", "legendary"]:
				has_guarantee = true
		_ok(has_guarantee, "paper folio guarantees Uncommon+ (seed %d)" % (100 + i))
	var salvage := PackRoll.roll_folio(Content.folio("folio.salvage"), 7, Content.card_list, Content.reagent_list, inks, shimmers)
	_ok(salvage.get("reagents", []).size() >= 1, "salvage cache contains a reagent")

func _test_crafting() -> void:
	var instance := _make_instance("ember.cinder_hound", 25)
	var result := CraftService.apply(instance, "reagent.pale_ink", GameRng.new(1, 1), Content.mods)
	_ok(bool(result.get("ok", false)), "Pale Ink applies")
	_eq(instance.mods.size(), 1, "Pale Ink adds 1 mod")
	var second := CraftService.apply(instance, "reagent.pale_ink", GameRng.new(2, 1), Content.mods)
	_ok(not bool(second.get("ok", false)), "Pale Ink does not stack on Inscribed")

	while instance.mods.size() < 4:
		var deep := CraftService.apply(instance, "reagent.deep_ink", GameRng.new(10 + instance.mods.size(), 1), Content.mods)
		if not bool(deep.get("ok", false)):
			break
	_eq(instance.mods.size(), 4, "Deep Ink fills to 4 mods")
	_ok(not bool(CraftService.apply(instance, "reagent.deep_ink", GameRng.new(9, 1), Content.mods).get("ok", false)), "fifth mod is rejected")

	var fractured := _make_instance("ember.cinder_hound", 25)
	CraftService.apply(fractured, "reagent.deep_ink", GameRng.new(3, 1), Content.mods)
	CraftService.apply(fractured, "reagent.deep_ink", GameRng.new(4, 1), Content.mods)
	var fracture := CraftService.apply(fractured, "reagent.fracture", GameRng.new(5, 1), Content.mods)
	_ok(bool(fracture.get("ok", false)), "Fracture applies")
	var pinned := fractured.fractured_mod
	_ok(not pinned.is_empty(), "Fracture pins a mod")
	CraftService.apply(fractured, "reagent.prism_ink", GameRng.new(6, 1), Content.mods)
	_ok(fractured.has_mod(pinned), "Fractured mod survives a reroll")

	var corrupted := _make_instance("ember.cinder_hound", 45)
	var corrupt := CraftService.apply(corrupted, "reagent.verdigris", GameRng.new(7, 1), Content.mods)
	_ok(bool(corrupt.get("ok", false)), "Verdigris applies")
	_ok(corrupted.corrupted, "Verdigris marks the card corrupted")
	_ok(not bool(CraftService.apply(corrupted, "reagent.varnish", GameRng.new(8, 1), Content.mods).get("ok", false)), "corrupted card locks further craft")

	var quality := _make_instance("ember.cinder_hound", 1)
	quality.quality = 19
	CraftService.apply(quality, "reagent.varnish", GameRng.new(11, 1), Content.mods)
	_ok(quality.quality >= 20, "Varnish raises quality")
	_ok(quality.quality <= 20, "Quality caps at 20")

	var shimmer := _make_instance("ember.cinder_hound", 1)
	CraftService.apply(shimmer, "reagent.gold_leaf", GameRng.new(12, 1), Content.mods)
	_ok(shimmer.shimmer_id != "shimmer.none", "Gold Leaf applies a shimmer")

func _test_serialization() -> void:
	var instance := _make_instance("ember.cinder_hound", 33, 7)
	instance.add_mod("mod.gilded", 3, 150)
	instance.fractured_mod = "mod.gilded"
	instance.custom_name = "Ash"
	instance.add_honour("first_clear", "9", 123)
	var round_trip := CardInstance.from_dict(instance.to_dict())
	_eq(round_trip.instance_id, instance.instance_id, "instance id survives")
	_eq(round_trip.quality, instance.quality, "quality survives")
	_eq(round_trip.mods.size(), 1, "mods survive")
	_eq(round_trip.custom_name, "Ash", "custom name survives")
	_eq(round_trip.honours.size(), 1, "honours survive")
	var deck := DeckModel.new()
	deck.deck_id = 4
	deck.name = "Test"
	deck.main = [1, 2, 3]
	deck.side = [4]
	var deck_round_trip := DeckModel.from_dict(deck.to_dict())
	_eq(deck_round_trip.main.size(), 3, "deck main survives")
	_eq(deck_round_trip.side.size(), 1, "deck side survives")

func _make_instances_from_deck(deck_entries: Array) -> Array:
	var result: Array = []
	var counter := 10000
	for entry in deck_entries:
		for i in range(int(entry.get("count", 0))):
			var def_id := str(entry.get("def", ""))
			var instance := CardInstance.new(counter, def_id, 1)
			counter += 1
			result.append(instance)
	return result

func _test_save_store() -> void:
	var store := SaveStore.new()
	store.prefix = "user://uirpg_test_"
	store.delete_save()
	var doc := {"version": 1, "payload": {"marks": 123, "name": "Keeper"}}
	_ok(store.write_save(doc), "save store writes")
	var loaded := store.load_save()
	_ok(not loaded.is_empty(), "save store loads")
	_eq(int(loaded.get("payload", {}).get("marks", 0)), 123, "save store round-trips payload")
	_ok(store.has_save(), "save store reports a save")
	# A second write rotates the first into the backup.
	store.write_save({"version": 1, "payload": {"marks": 456, "name": "Keeper"}})
	# Corrupt the primary; the backup should be the previous good save.
	var file := FileAccess.open(store.save_path(), FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var fallback := store.load_save()
	_ok(not fallback.is_empty(), "save store falls back to backup")
	store.delete_save()

func _test_session_loop() -> void:
	print("test: session loop")
	var script = load("res://src/application/session.gd")
	var test_session = script.new()
	test_session.test_mode = true
	test_session.new_game("starter.ember", 12345)
	_ok(test_session.total_cards() >= 45, "new game seeds a deck and stock")
	_ok(test_session.deck_errors(test_session.active_deck()).is_empty(), "starter deck legal in session")
	_ok(test_session.unopened_packs().size() == 1, "starter folio present")
	var pack = test_session.unopened_packs()[0]
	var opened: Dictionary = test_session.open_pack(int(pack.get("id", 0)))
	_ok(bool(opened.get("ok", false)), "folio opens")
	_ok(opened.get("cards", []).size() >= 3, "folio reveals cards")
	var stack_entry: Dictionary = {}
	for entry in test_session.collection_entries():
		if str(entry.get("kind", "")) == "stack":
			stack_entry = entry
			break
	_ok(not stack_entry.is_empty(), "collection has a stack to craft")
	var pulled: Dictionary = test_session.pull_entry_to_bench(stack_entry)
	_ok(bool(pulled.get("ok", false)), "copy pulls to the bench")
	_ok(test_session.bench_instance() != null, "bench holds the copy")
	var reagent_before = int(test_session.reagents.get("reagent.pale_ink", 0))
	var craft: Dictionary = test_session.apply_reagent("reagent.pale_ink")
	_ok(bool(craft.get("ok", false)), "Pale Ink applies in session")
	_ok(test_session.bench_instance().mods.size() == 1, "session craft writes a mod")
	_eq(int(test_session.reagents.get("reagent.pale_ink", 0)), reagent_before - 1, "reagent consumed")
	test_session.close_bench()
	var won := false
	for attempt in range(12):
		test_session.new_game("starter.ember", 2000 + attempt)
		var started: Dictionary = test_session.start_descent(1, test_session.active_deck_id, "auto")
		if not bool(started.get("ok", false)):
			continue
		test_session.descent["seed"] = attempt + 1
		var state: DuelState = test_session.make_duel()
		DuelAI.simulate(state, 65)
		var result: Dictionary = test_session.finish_duel(state)
		if str(result.get("kind", "")) == "win":
			won = true
			_ok(int(result.get("marks", 0)) > 0, "win pays Marks")
			_ok(test_session.unlocked_floor >= 2, "win unlocks the next floor")
			_eq(int(test_session.descent.get("current_floor", 0)), 2, "win advances the Descent")
			_ok(bool(test_session.descent.get("door_pending", false)), "a door waits after a win")
			var door: Dictionary = test_session.apply_door("vault")
			_ok(bool(door.get("ok", false)), "Vault door opens")
			_ok(bool(test_session.descent.get("vault", false)), "Vault flag set for the next duel")
			var vault_opponent: Dictionary = test_session.current_opponent()
			_ok(bool(vault_opponent.get("vault", false)), "Vault opponent is marked")
			var next_state: DuelState = test_session.make_duel()
			_ok(next_state != null, "next floor makes a new duel")
			_ok(next_state.players[1].resolve > 4000, "Vault Warden begins with extra Resolve")
			_ok(not bool(test_session.apply_door("stair").get("ok", false)), "no second door without a win")
			var honour_found := false
			for instance_id in test_session.active_deck().main:
				var instance: CardInstance = test_session.instance_by_id(instance_id)
				if instance != null and not instance.honours.is_empty():
					honour_found = true
					break
			_ok(honour_found, "first clear stamps a deck copy")
			break
	_ok(won, "a seeded session descent reaches a win")
	test_session.free()

func _test_deck_moves_and_query() -> void:
	print("test: deck moves and query")
	var script = load("res://src/application/session.gd")
	var s = script.new()
	s.test_mode = true
	s.new_game("starter.ember", 98765)
	var starter_deck = s.active_deck()
	_ok(starter_deck != null, "deck exists for move test")
	if starter_deck == null:
		return
	var move_id := int(starter_deck.main[0])
	var test_deck := DeckModel.new()
	test_deck.deck_id = 900
	test_deck.main = [move_id]
	test_deck.side = []
	s.decks[900] = test_deck
	s.active_deck_id = 900
	var result: Dictionary = s.move_instance_in_deck(move_id, "side")
	_ok(bool(result.get("ok", false)), "main to side move succeeds")
	_ok(test_deck.side.has(move_id), "moved copy is in sideboard")
	_ok(not test_deck.main.has(move_id), "moved copy left main")
	_ok(s.instance_by_id(move_id) != null, "moved copy keeps its identity")
	var back: Dictionary = s.move_instance_in_deck(move_id, "main")
	_ok(bool(back.get("ok", false)), "side to main move succeeds")
	_ok(test_deck.main.has(move_id), "copy moved back to main")

	var free: Dictionary = {}
	for entry in s.collection_entries():
		if str(entry.get("kind", "")) == "stack":
			var pulled: Dictionary = s.pull_entry_to_bench(entry)
			if bool(pulled.get("ok", false)):
				free = pulled
				break
	if not free.is_empty():
		var free_instance = free.get("instance")
		var added: Dictionary = s.add_instance_to_deck(free_instance.instance_id, "main")
		_ok(bool(added.get("ok", false)), "specific instance bind succeeds")
		_ok(test_deck.main.has(free_instance.instance_id), "specific instance is in main")
		s.close_bench(false)

	var entries = s.collection_entries()
	var query := CardQuery.empty_query()
	query["type"] = ["monster"]
	var filtered := CardQuery.filter(entries, query)
	var all_monsters := true
	for entry in filtered:
		var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
		if def == null or not def.is_monster():
			all_monsters = false
	_ok(not filtered.is_empty() and all_monsters, "type filter returns only monsters")
	var query2 := CardQuery.empty_query()
	query2["attribute"] = ["ember"]
	query2["type"] = ["monster"]
	var filtered2 := CardQuery.filter(entries, query2)
	var all_ember := true
	for entry in filtered2:
		var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
		if def == null or def.attribute != "ember":
			all_ember = false
	_ok(not filtered2.is_empty() and all_ember, "attribute and type filters are ANDed")

func _test_card_layout_audit() -> void:
	print("test: card layout audit")
	var failures := CardLayoutAudit.audit()
	_ok(failures.is_empty(), "card layout audit: %s" % (failures[0] if not failures.is_empty() else "ok"))
	if not failures.is_empty():
		for failure in failures.slice(0, mini(8, failures.size())):
			print("  layout: %s" % failure)

func _test_responsive_layout() -> void:
	_eq(Responsive.library_shelf_columns(1440.0), 5, "library shelves at 1440 logical")
	_eq(Responsive.library_shelf_columns(1600.0), 6, "library shelves at 1600 logical")
	_eq(Responsive.library_shelf_columns(2133.0), 9, "library shelves at ultrawide")
	_eq(Responsive.card_token_for_height(900.0), "M", "bench uses M at reference height")
	_eq(Responsive.card_token_for_height(1080.0), "L", "bench uses L when tall")
	_eq(Responsive.columns(0.0, 150.0), 1, "zero width still yields one column")
	_eq(Responsive.columns(10000.0, 150.0, 8.0, 12), 12, "column count respects the cap")

func _test_seeded_duels() -> void:
	var player_deck := _make_instances_from_deck(Content.starter("starter.ember").get("deck", []))
	var opponent_deck := _make_instances_from_deck(Content.opponent("warden.damp").get("deck", []))
	var wins := 0
	var losses := 0
	var draws := 0
	var turns_total := 0
	for i in range(100):
		if i % 10 == 0:
			print("  duel %d" % i)
		var state := DuelState.new()
		state.setup({
			"seed": 4000 + i,
			"def_db": Content.cards,
			"mod_db": Content.mods,
			"player": {"name": "You", "doctrine": "press", "instances": player_deck},
			"opponent": {"name": "The Damp Warden", "doctrine": "hold", "instances": opponent_deck, "skill": 55},
		})
		DuelAI.simulate(state, 65)
		_ok(state.ended, "seed %d duel ends" % (4000 + i))
		_ok(state.turn <= 201, "seed %d duel respects turn safety" % (4000 + i))
		if state.winner == 0:
			wins += 1
		elif state.winner == 1:
			losses += 1
		else:
			draws += 1
		turns_total += state.turn
	print("  seeded duels: %d wins / %d losses / %d draws, avg turns %.1f" % [wins, losses, draws, float(turns_total) / 100.0])
	_ok(wins + losses + draws == 100, "seeded duel loop completed")
