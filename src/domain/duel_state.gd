class_name DuelState
extends RefCounted

## Single source of truth for a duel. Manual, Suggest, and Auto are controllers
## over this object; none of them bypass DuelRules.

var seed_value: int = 1
var duel_id: String = ""
var rng: GameRng
var ai_rng: GameRng
var mod_db: Dictionary = {}
var def_db: Dictionary = {}

var players: Array[DuelPlayer] = []
var active: int = 0
var first_player: int = 0
var turn: int = 0
var phase: String = "dawn"
var skip_clash: bool = false
var winner: int = -1
var winner_reason: String = ""
var ended: bool = false
var turn_limit: int = GameConst.MAX_TURN_SOFT_CAP

var log: Array[Dictionary] = []
var events: Array[Dictionary] = []
var _seq: int = 0
var _next_uid: int = 1

var turn_limits: Dictionary = {}
var duel_limits: Dictionary = {}
var pending_dusk_discard: Array[int] = [0, 0]
var attack_context: Dictionary = {}
var trigger_depth: int = 0
var progress_marker: int = 0
var last_progress_marker: int = 0
var no_progress_turns: int = 0
var content_version: int = 1
var rules_version: int = 1
var config: Dictionary = {}

func setup(setup_config: Dictionary) -> void:
	config = setup_config.duplicate(true)
	seed_value = int(setup_config.get("seed", 1))
	duel_id = str(setup_config.get("duel_id", "duel-%d" % seed_value))
	rng = GameRng.new(seed_value, 1)
	ai_rng = GameRng.new(seed_value, 2)
	mod_db = setup_config.get("mod_db", {})
	def_db = setup_config.get("def_db", {})
	content_version = int(setup_config.get("content_version", 1))
	rules_version = int(setup_config.get("rules_version", 1))

	var player_cfg: Dictionary = setup_config.get("player", {})
	var opponent_cfg: Dictionary = setup_config.get("opponent", {})
	var player_name := str(player_cfg.get("name", "Keeper"))
	var opponent_name := str(opponent_cfg.get("name", "Warden"))
	players = [DuelPlayer.new(0, player_name), DuelPlayer.new(1, opponent_name)]
	players[0].doctrine = str(player_cfg.get("doctrine", "read"))
	players[1].doctrine = str(opponent_cfg.get("doctrine", "read"))
	players[0].resolve = int(player_cfg.get("resolve", GameConst.RESOLVE_START))
	players[1].resolve = int(opponent_cfg.get("resolve", GameConst.RESOLVE_START))
	players[0].max_resolve = players[0].resolve
	players[1].max_resolve = players[1].resolve

	var modifier := str(opponent_cfg.get("modifier", ""))
	if modifier == "ninth_veil":
		players[1].resolve += 500
		players[1].max_resolve += 500
	if modifier == "hard_hand":
		players[1].hand_limit = 6
	if bool(opponent_cfg.get("vault", false)):
		players[1].resolve += 300
		players[1].max_resolve += 300

	for raw in player_cfg.get("instances", []):
		_add_instance_to_deck(raw, 0)
	for raw in opponent_cfg.get("instances", []):
		_add_instance_to_deck(raw, 1)

	rng.shuffle(players[0].deck)
	rng.shuffle(players[1].deck)
	var opening := GameConst.OPENING_HAND
	var opponent_opening := opening + (1 if modifier == "opening_gambit" else 0)
	draw_cards(0, opening, true)
	draw_cards(1, opponent_opening, false)

	first_player = rng.next_int(2)
	active = first_player
	turn = 0
	begin_turn()

func _add_instance_to_deck(raw, owner: int) -> void:
	var instance: CardInstance
	if raw is CardInstance:
		instance = raw
	elif raw is Dictionary:
		instance = CardInstance.from_dict(raw)
	else:
		return
	var def: CardDef = def_db.get(instance.def_id)
	if def == null:
		push_error("DuelState: missing card definition %s" % instance.def_id)
		return
	var card := DuelCard.new()
	card.uid = _next_uid
	_next_uid += 1
	card.instance = instance
	card.def = def
	card.owner = owner
	card.zone = GameConst.ZONE_DECK
	players[owner].deck.append(card)

func actor_name(player: int) -> String:
	if player == 0:
		return "You"
	return players[1].name

func opponent_of(player: int) -> int:
	return 1 - player

func active_player() -> DuelPlayer:
	return players[active]

func inactive_player() -> DuelPlayer:
	return players[opponent_of(active)]

func begin_turn() -> void:
	if ended:
		return
	turn += 1
	if turn > turn_limit:
		end_duel(2, "stalemate")
		return
	var player: DuelPlayer = players[active]
	player.called_this_turn = false
	for card in player.monsters:
		if card != null:
			card.attacked_turn = -1
	clear_buffs(player, "until_next_turn")
	turn_limits.clear()
	skip_clash = (turn == 1 and active == first_player)

	phase = "dawn"
	log_event("Turn %d — %s." % [turn, actor_name(active)], "turn")
	emit_event("turn", {"player": active, "turn": turn})
	EffectEngine.dispatch_turn(self, active, "dawn")
	if ended:
		return
	phase = "draw"
	draw_cards(active, 1, active == 0)
	if ended:
		return
	phase = "call"
	emit_event("phase", {"phase": phase})

func advance_phase() -> void:
	if ended:
		return
	match phase:
		"call":
			phase = "actions"
			emit_event("phase", {"phase": phase})
		"actions":
			phase = "clash"
			emit_event("phase", {"phase": phase})
		"clash":
			phase = "dusk"
			resolve_dusk()
		"dusk":
			active = opponent_of(active)
			begin_turn()
		_:
			begin_turn()

func resolve_dusk() -> void:
	if ended:
		return
	log_event("Dusk.", "phase")
	EffectEngine.dispatch_turn(self, active, "dusk")
	if ended:
		return
	var player: DuelPlayer = players[active]
	var discard_count := pending_dusk_discard[active]
	pending_dusk_discard[active] = 0
	for i in range(discard_count):
		if player.hand.is_empty():
			break
		_discard_lowest(player, "the Ledger's dusk cost")
	while player.hand.size() > player.hand_limit:
		_discard_lowest(player, "the hand limit")
	clear_buffs(player, "until_dusk")
	if progress_marker == last_progress_marker:
		no_progress_turns += 1
	else:
		no_progress_turns = 0
		last_progress_marker = progress_marker
	if no_progress_turns >= 5:
		end_duel(2, "no progress")
		return
	emit_event("phase", {"phase": "dusk"})

func mark_progress() -> void:
	progress_marker += 1

func _discard_lowest(player: DuelPlayer, reason: String) -> void:
	if player.hand.is_empty():
		return
	var worst: DuelCard = player.hand[0]
	var worst_power := power_of(worst)
	for card in player.hand:
		var value := power_of(card)
		if value < worst_power:
			worst = card
			worst_power = value
	player.hand.erase(worst)
	worst.zone = GameConst.ZONE_REMAINS
	player.remains.append(worst)
	log_event("%s discards %s (%s)." % [actor_name(player.index), worst.display_name(), reason], "discard")
	emit_event("discard", {"player": player.index, "card_uid": worst.uid, "name": worst.display_name()})

func discard_lowest(player_index: int, reason: String) -> void:
	_discard_lowest(players[player_index], reason)

func draw_cards(player_index: int, count: int, reveal: bool) -> void:
	if ended:
		return
	var player: DuelPlayer = players[player_index]
	for i in range(count):
		if player.deck.is_empty():
			log_event("%s has no cards to draw." % actor_name(player_index), "draw")
			break
		var card: DuelCard = player.deck.pop_back()
		card.zone = GameConst.ZONE_HAND
		player.hand.append(card)
		player.stats["cards_drawn"] = int(player.stats.get("cards_drawn", 0)) + 1
		if reveal:
			log_event("%s draw%s %s." % [
				actor_name(player_index),
				"" if player_index == 0 else "s",
				card.display_name(),
			], "draw")
		else:
			log_event("%s draw%s a card." % [actor_name(player_index), "" if player_index == 0 else "s"], "draw")
		emit_event("draw", {
			"player": player_index,
			"card_uid": card.uid,
			"name": card.display_name() if reveal else "",
			"hidden": not reveal,
		})

func stats_for(card: DuelCard) -> Dictionary:
	var context := {
		"in_defense": card.is_defense_position(),
		"lane_buff": lane_buff(card.owner, card.lane) if card.is_monster() else 0,
		"temp_atk": card.temp_atk,
		"temp_def": card.temp_def,
	}
	return CardResolver.effective_stats(card.instance, card.def, mod_db, context)

func keywords_for(card: DuelCard) -> Dictionary:
	return CardResolver.keyword_set(card.instance, card.def, mod_db)

func has_keyword(card: DuelCard, keyword: String) -> bool:
	return keywords_for(card).has(keyword)

func power_of(card: DuelCard) -> int:
	return CardResolver.power(card.instance, card.def, mod_db)

func offer_cost(card: DuelCard) -> int:
	return CardResolver.offer_cost(card.instance, card.def, mod_db)

func lane_buff(player_index: int, lane: int) -> int:
	var total := 0
	var player: DuelPlayer = players[player_index]
	if lane < 0 or lane > 2:
		return 0
	for card in player.backrow:
		if card == null or card.face_down:
			continue
		if not card.def.has_effect:
			continue
		var trigger := str(card.def.effect.get("trigger", ""))
		if trigger != "continuous" and trigger != "on_activate":
			continue
		for step in card.def.effect.get("steps", []):
			if str(step.get("action", "")) == "lane_buff":
				total += int(step.get("amount", 0))
	return total

func has_attribute(player_index: int, attribute: String) -> bool:
	for card in players[player_index].monsters:
		if card != null and card.def.attribute == attribute:
			return true
	return false

func remains_count(player_index: int) -> int:
	return players[player_index].remains.size()

func monster_at(player_index: int, lane: int) -> DuelCard:
	if lane < 0 or lane > 2:
		return null
	return players[player_index].monsters[lane]

func backrow_at(player_index: int, lane: int) -> DuelCard:
	if lane < 0 or lane > 2:
		return null
	return players[player_index].backrow[lane]

func find_hand(player_index: int, uid: int) -> DuelCard:
	for card in players[player_index].hand:
		if card.uid == uid:
			return card
	return null

func find_backrow(player_index: int, uid: int) -> DuelCard:
	for card in players[player_index].backrow:
		if card != null and card.uid == uid:
			return card
	return null

func find_monster(player_index: int, uid: int) -> DuelCard:
	for card in players[player_index].monsters:
		if card != null and card.uid == uid:
			return card
	return null

func find_board(player_index: int, uid: int) -> DuelCard:
	var monster := find_monster(player_index, uid)
	if monster != null:
		return monster
	return find_backrow(player_index, uid)

func find_anywhere(player_index: int, uid: int) -> DuelCard:
	var card := find_hand(player_index, uid)
	if card != null:
		return card
	card = find_board(player_index, uid)
	if card != null:
		return card
	for pile in [players[player_index].remains, players[player_index].banished, players[player_index].deck]:
		for candidate in pile:
			if candidate.uid == uid:
				return candidate
	return null

func detach(card: DuelCard) -> void:
	var player: DuelPlayer = players[card.owner]
	if card.zone == GameConst.ZONE_MONSTER and card.lane >= 0 and card.lane < 3:
		if player.monsters[card.lane] == card:
			player.monsters[card.lane] = null
	elif card.zone == GameConst.ZONE_BACKROW and card.lane >= 0 and card.lane < 3:
		if player.backrow[card.lane] == card:
			player.backrow[card.lane] = null
	card.lane = -1

func destroy_card(card: DuelCard, source: String = "") -> void:
	if card == null or ended:
		return
	var player: DuelPlayer = players[card.owner]
	var lane := card.lane
	var was_monster := card.is_monster()
	mark_progress()
	detach(card)
	card.zone = GameConst.ZONE_REMAINS
	if card.is_token:
		log_event("%s token ceases." % card.display_name(), "destroy")
		emit_event("destroy", {"player": card.owner, "card_uid": card.uid, "name": card.display_name(), "token": true})
	else:
		player.remains.append(card)
		log_event("%s is destroyed%s." % [card.display_name(), " by %s" % source if not source.is_empty() else ""], "destroy")
		emit_event("destroy", {"player": card.owner, "card_uid": card.uid, "name": card.display_name()})
	if was_monster:
		player.stats["monsters_destroyed"] = int(player.stats.get("monsters_destroyed", 0)) + 1
	EffectEngine.dispatch_card(self, card, "on_destroy")
	if ended:
		return
	EffectEngine.dispatch_destroy_watchers(self, card, lane)
	# Verdigris: Ninth banishes the source after its Echo instead of leaving Remains.
	if not card.is_token and player.remains.has(card):
		for mod in card.instance.mods:
			var mod_def: Dictionary = mod_db.get(str(mod.get("id", "")), {})
			for step in mod_def.get("steps", []):
				if str(step.get("action", "")) == "banish_self_instead":
					player.remains.erase(card)
					card.zone = GameConst.ZONE_VOID
					player.banished.append(card)
					log_event("%s is banished instead." % card.display_name(), "banish")
					break

func banish_card(card: DuelCard, source: String = "") -> void:
	if card == null or ended:
		return
	var player: DuelPlayer = players[card.owner]
	mark_progress()
	detach(card)
	card.zone = GameConst.ZONE_VOID
	if card.is_token:
		log_event("%s token ceases." % card.display_name(), "banish")
	else:
		player.banished.append(card)
		log_event("%s is banished%s." % [card.display_name(), " by %s" % source if not source.is_empty() else ""], "banish")
	emit_event("banish", {"player": card.owner, "card_uid": card.uid, "name": card.display_name()})
	EffectEngine.dispatch_card(self, card, "on_banish")

func damage_player(target: int, amount: int, source_owner: int, source_name: String = "") -> void:
	if ended or amount <= 0:
		return
	var player: DuelPlayer = players[target]
	mark_progress()
	player.resolve = maxi(0, player.resolve - amount)
	player.stats["damage_taken"] = int(player.stats.get("damage_taken", 0)) + amount
	if source_owner >= 0 and source_owner != target:
		var source_player: DuelPlayer = players[source_owner]
		source_player.stats["damage_dealt"] = int(source_player.stats.get("damage_dealt", 0)) + amount
	log_event("-%d Resolve%s." % [
		amount,
		" (%s)" % source_name if not source_name.is_empty() else "",
	], "damage")
	emit_event("damage", {"player": target, "amount": amount, "source": source_name})
	if player.resolve <= 0:
		if players[0].resolve <= 0 and players[1].resolve <= 0:
			end_duel(2, "both at 0 Resolve")
		else:
			end_duel(opponent_of(target), "0 Resolve")

func heal_player(target: int, amount: int, source_name: String = "") -> void:
	if ended or amount <= 0:
		return
	var player: DuelPlayer = players[target]
	var healed := mini(amount, player.max_resolve - player.resolve)
	if healed <= 0:
		return
	mark_progress()
	player.resolve += healed
	player.stats["damage_healed"] = int(player.stats.get("damage_healed", 0)) + healed
	log_event("+%d Resolve%s." % [healed, " (%s)" % source_name if not source_name.is_empty() else ""], "heal")
	emit_event("heal", {"player": target, "amount": healed, "source": source_name})

func flip_card(card: DuelCard) -> void:
	if card == null or not card.face_down:
		return
	card.face_down = false
	log_event("%s is flipped face-up." % card.display_name(), "flip")
	emit_event("flip", {"player": card.owner, "card_uid": card.uid, "name": card.display_name()})
	EffectEngine.dispatch_card(self, card, "on_flip")

func can_attack(card: DuelCard) -> bool:
	if ended or card == null or not card.is_monster():
		return false
	if card.owner != active or phase != "clash" or skip_clash:
		return false
	if card.face_down or not card.is_attack_position():
		return false
	if card.attacked_turn == turn:
		return false
	if card.summoned_turn == turn and not has_keyword(card, "fleet"):
		return false
	if has_keyword(card, "bind"):
		return false
	return true

func clear_buffs(player: DuelPlayer, duration: String) -> void:
	for card in player.all_board_cards():
		var kept: Array[Dictionary] = []
		for buff in card.buffs:
			if str(buff.get("duration", "")) == duration:
				if str(buff.get("stat", "atk")) == "atk":
					card.temp_atk -= int(buff.get("amount", 0))
				else:
					card.temp_def -= int(buff.get("amount", 0))
			else:
				kept.append(buff)
		card.buffs = kept

func add_buff(card: DuelCard, stat: String, amount: int, duration: String) -> void:
	if card == null:
		return
	if stat == "atk":
		card.temp_atk += amount
	else:
		card.temp_def += amount
	card.buffs.append({"stat": stat, "amount": amount, "duration": duration})
	emit_event("buff", {"player": card.owner, "card_uid": card.uid, "stat": stat, "amount": amount})

func create_token(owner: int, lane: int, atk: int, defense: int, token_name: String = "Token") -> DuelCard:
	if lane < 0 or lane > 2 or players[owner].monsters[lane] != null:
		return null
	var def := CardDef.new()
	def.id = "token.%d.%d" % [atk, defense]
	def.name = token_name
	def.type = GameConst.TYPE_MONSTER
	def.attribute = "neutral"
	def.lineage = "construct"
	def.offer = 0
	def.atk = atk
	def.defense = defense
	def.rarity = "common"
	def.text = ""
	def.base_power = atk / 100 + defense / 150
	var instance := CardInstance.new(0, def.id, 1)
	instance.origin = "token"
	var card := DuelCard.new()
	card.uid = _next_uid
	_next_uid += 1
	card.instance = instance
	card.def = def
	card.owner = owner
	card.lane = lane
	card.zone = GameConst.ZONE_MONSTER
	card.position = GameConst.POSITION_DEFENSE
	card.summoned_turn = turn
	card.is_token = true
	players[owner].monsters[lane] = card
	log_event("%s summons a %d/%d token in Lane %d." % [actor_name(owner), atk, defense, lane + 1], "token")
	emit_event("token", {"player": owner, "lane": lane, "atk": atk, "defense": defense})
	return card

func end_duel(result: int, reason: String) -> void:
	if ended:
		return
	ended = true
	winner = result
	winner_reason = reason
	if result == 0 or result == 1:
		log_event("%s wins — %s." % [actor_name(result), reason], "end")
	elif result == 2:
		log_event("The duel ends in a draw — %s." % reason, "end")
	else:
		log_event("The duel ends — %s." % reason, "end")
	emit_event("end", {"winner": result, "reason": reason})

func log_event(text: String, kind: String = "info", data: Dictionary = {}) -> void:
	_seq += 1
	var entry := {
		"seq": _seq,
		"turn": turn,
		"phase": phase,
		"kind": kind,
		"text": text,
		"data": data,
	}
	log.append(entry)
	if log.size() > 1200:
		log.pop_front()

func emit_event(event_type: String, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["type"] = event_type
	event["turn"] = turn
	event["phase"] = phase
	event["seq"] = _seq
	events.append(event)
	if events.size() > 400:
		events.pop_front()

func drain_events() -> Array[Dictionary]:
	var drained: Array[Dictionary] = []
	drained.append_array(events)
	events.clear()
	return drained

func summary() -> Dictionary:
	var player_stats: Dictionary = players[0].stats.duplicate(true)
	var opponent_stats: Dictionary = players[1].stats.duplicate(true)
	return {
		"duel_id": duel_id,
		"seed": seed_value,
		"turns": turn,
		"winner": winner,
		"reason": winner_reason,
		"player": player_stats,
		"opponent": opponent_stats,
		"flawless": winner == 0 and int(player_stats.get("damage_taken", 0)) == 0,
		"player_resolve": players[0].resolve,
		"opponent_resolve": players[1].resolve,
		"player_deck_remaining": players[0].deck.size(),
		"opponent_deck_remaining": players[1].deck.size(),
	}
