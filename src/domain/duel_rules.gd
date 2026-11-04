class_name DuelRules
extends RefCounted

## Legal-action generation and the only mutation path for a duel.
## Actions are dictionaries with stable card UIDs, not list indexes.

static func legal_actions(state) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if state == null or state.ended:
		return actions
	var player = state.players[state.active]
	if state.phase == "call" and not player.called_this_turn:
		for card in player.hand:
			if not card.is_monster():
				continue
			var offer_cost: int = state.offer_cost(card)
			if offer_cost > player.monster_count():
				continue
			var lanes: Array[int] = player.empty_monster_lanes()
			if lanes.is_empty() and offer_cost == 0:
				continue
			if lanes.is_empty():
				lanes = [0, 1, 2]
			for lane in lanes:
				if player.monsters[lane] != null and offer_cost == 0:
					continue
				actions.append({
					"type": "call",
					"uid": card.uid,
					"lane": lane,
					"position": GameConst.POSITION_ATTACK,
					"face_down": false,
					"offers": [],
					"label": "Call %s to Lane %d" % [card.display_name(), lane + 1],
				})
				actions.append({
					"type": "call",
					"uid": card.uid,
					"lane": lane,
					"position": GameConst.POSITION_DEFENSE,
					"face_down": true,
					"offers": [],
					"label": "Set %s to Lane %d (Defense)" % [card.display_name(), lane + 1],
				})
				actions.append({
					"type": "call",
					"uid": card.uid,
					"lane": lane,
					"position": GameConst.POSITION_ATTACK,
					"face_down": true,
					"offers": [],
					"label": "Set %s to Lane %d (Attack)" % [card.display_name(), lane + 1],
				})
	if state.phase == "actions":
		var empty_backrow: Array[int] = player.empty_backrow_lanes()
		for card in player.hand:
			if card.is_monster():
				continue
			for lane in empty_backrow:
				if card.is_spell():
					actions.append({
						"type": "play",
						"uid": card.uid,
						"lane": lane,
						"label": "Play %s to Backrow %d" % [card.display_name(), lane + 1],
					})
					actions.append({
						"type": "set_card",
						"uid": card.uid,
						"lane": lane,
						"label": "Set %s to Backrow %d" % [card.display_name(), lane + 1],
					})
				elif card.is_trap():
					actions.append({
						"type": "set_card",
						"uid": card.uid,
						"lane": lane,
						"label": "Set %s to Backrow %d" % [card.display_name(), lane + 1],
					})
		for card in player.backrow:
			if card == null:
				continue
			if card.face_down and card.is_spell() and card.set_turn < state.turn:
				actions.append({
					"type": "activate",
					"uid": card.uid,
					"label": "Activate set %s" % card.display_name(),
				})
	if state.phase == "clash" and not state.skip_clash:
		var guarded: bool = state.players[state.opponent_of(state.active)].monster_count() > 0
		for card in player.monsters:
			if card == null or not state.can_attack(card):
				continue
			for lane in range(3):
				var target = state.monster_at(state.opponent_of(state.active), lane)
				if target == null and guarded:
					continue
				var target_label := "Lane %d" % (lane + 1)
				if target != null:
					target_label = "%s in Lane %d" % [target.display_name() if not target.face_down else "a set card", lane + 1]
				actions.append({
					"type": "attack",
					"uid": card.uid,
					"target_lane": lane,
					"label": "%s attacks %s" % [card.display_name(), target_label],
				})
	if state.turn >= 50:
		actions.append({"type": "resign", "label": "Resign (turn 50)"})
	actions.append({"type": "end_phase", "label": "End %s" % GameConst.PHASE_LABELS.get(state.phase, state.phase)})
	return actions

static func validate(state, player: int, action: Dictionary) -> Dictionary:
	if state == null:
		return {"ok": false, "reason": "No duel."}
	if state.ended:
		return {"ok": false, "reason": "The duel is over."}
	if player != state.active:
		return {"ok": false, "reason": "Not your turn."}
	var action_type := str(action.get("type", ""))
	match action_type:
		"call":
			if state.phase != "call":
				return {"ok": false, "reason": "Calls happen in the Call phase."}
			if state.players[player].called_this_turn:
				return {"ok": false, "reason": "You have already Called this turn."}
			var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
			if card == null or not card.is_monster():
				return {"ok": false, "reason": "That card cannot be Called."}
			var lane := int(action.get("lane", -1))
			if lane < 0 or lane > 2:
				return {"ok": false, "reason": "No such lane."}
			var payment := _choose_offers(state, player, card, lane, action.get("offers", []))
			if not bool(payment.get("ok", false)):
				return payment
			var position := str(action.get("position", GameConst.POSITION_ATTACK))
			if position != GameConst.POSITION_ATTACK and position != GameConst.POSITION_DEFENSE:
				return {"ok": false, "reason": "Bad position."}
			return {"ok": true, "reason": "", "_offers": payment.get("uids", [])}
		"play":
			if state.phase != "actions":
				return {"ok": false, "reason": "Plays happen in the Actions phase."}
			var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
			if card == null or not card.is_spell():
				return {"ok": false, "reason": "That is not a Spell in hand."}
			var lane := int(action.get("lane", -1))
			if lane < 0 or lane > 2 or state.players[player].backrow[lane] != null:
				return {"ok": false, "reason": "That Backrow lane is not open."}
			return {"ok": true, "reason": ""}
		"set_card":
			if state.phase != "actions":
				return {"ok": false, "reason": "Settings happen in the Actions phase."}
			var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
			if card == null or card.is_monster():
				return {"ok": false, "reason": "That card cannot be set in the Backrow."}
			var lane := int(action.get("lane", -1))
			if lane < 0 or lane > 2 or state.players[player].backrow[lane] != null:
				return {"ok": false, "reason": "That Backrow lane is not open."}
			return {"ok": true, "reason": ""}
		"activate":
			if state.phase != "actions":
				return {"ok": false, "reason": "Activations happen in the Actions phase."}
			var card: DuelCard = state.find_backrow(player, int(action.get("uid", -1)))
			if card == null or not card.face_down:
				return {"ok": false, "reason": "That card is not set."}
			if not card.is_spell():
				return {"ok": false, "reason": "Traps activate on their trigger."}
			if card.set_turn >= state.turn:
				return {"ok": false, "reason": "A set card waits one full turn."}
			return {"ok": true, "reason": ""}
		"attack":
			if state.phase != "clash":
				return {"ok": false, "reason": "Attacks happen in the Clash phase."}
			if state.skip_clash:
				return {"ok": false, "reason": "The first player skips Clash on turn 1."}
			var card: DuelCard = state.find_monster(player, int(action.get("uid", -1)))
			if card == null or not state.can_attack(card):
				return {"ok": false, "reason": "That monster cannot attack."}
			var lane := int(action.get("target_lane", -1))
			if lane < 0 or lane > 2:
				return {"ok": false, "reason": "No such lane."}
			var defender: int = state.opponent_of(player)
			var target = state.monster_at(defender, lane)
			if target == null and state.players[defender].monster_count() > 0:
				return {"ok": false, "reason": "The face is sealed while any guard remains."}
			return {"ok": true, "reason": ""}
		"end_phase":
			return {"ok": true, "reason": ""}
		"resign":
			if state.turn < 50:
				return {"ok": false, "reason": "You can Resign after turn 50."}
			return {"ok": true, "reason": ""}
		_:
			return {"ok": false, "reason": "Unknown action."}

static func apply(state, player: int, action: Dictionary) -> Dictionary:
	var check := validate(state, player, action)
	if not bool(check.get("ok", false)):
		return check
	var action_type := str(action.get("type", ""))
	match action_type:
		"call":
			_apply_call(state, player, action, check.get("_offers", []))
		"play":
			_apply_play(state, player, action)
		"set_card":
			_apply_set_card(state, player, action)
		"activate":
			_apply_activate(state, player, action)
		"attack":
			_apply_attack(state, player, action)
		"end_phase":
			state.advance_phase()
		"resign":
			state.end_duel(state.opponent_of(player), "resigned")
	return {"ok": true, "reason": ""}

static func _choose_offers(state, player: int, card: DuelCard, lane: int, requested: Array) -> Dictionary:
	var required: int = state.offer_cost(card)
	var player_state = state.players[player]
	if required <= 0:
		if player_state.monsters[lane] != null:
			return {"ok": false, "reason": "That monster lane is occupied."}
		return {"ok": true, "uids": []}
	var pool: Array[DuelCard] = []
	for monster in player_state.monsters:
		if monster != null:
			pool.append(monster)
	if pool.size() < required:
		return {"ok": false, "reason": "Offer %d monsters; you have %d." % [required, pool.size()]}
	var chosen: Array[int] = []
	if not requested.is_empty():
		for raw_uid in requested:
			var uid := int(raw_uid)
			var found: DuelCard = state.find_monster(player, uid)
			if found == null:
				return {"ok": false, "reason": "Offer target is not on your mat."}
			if chosen.has(uid):
				return {"ok": false, "reason": "The same monster cannot be offered twice."}
			chosen.append(uid)
		if chosen.size() != required:
			return {"ok": false, "reason": "Offer exactly %d monsters." % required}
	else:
		var sorted: Array[DuelCard] = []
		sorted.append_array(pool)
		sorted.sort_custom(func(a: DuelCard, b: DuelCard) -> bool:
			return state.power_of(a) < state.power_of(b)
		)
		for monster in sorted:
			if chosen.size() >= required:
				break
			chosen.append(monster.uid)
		if player_state.monsters[lane] != null:
			var target_uid: int = player_state.monsters[lane].uid
			if not chosen.has(target_uid):
				chosen[chosen.size() - 1] = target_uid
	if player_state.monsters[lane] != null and not chosen.has(player_state.monsters[lane].uid):
		return {"ok": false, "reason": "That lane stays occupied. Offer its monster or choose another lane."}
	return {"ok": true, "uids": chosen}

static func _pay_offers(state, player: int, uids: Array) -> void:
	for raw_uid in uids:
		var offered: DuelCard = state.find_monster(player, int(raw_uid))
		if offered == null:
			continue
		state.detach(offered)
		offered.zone = GameConst.ZONE_REMAINS
		offered.face_down = false
		state.players[player].remains.append(offered)
		state.log_event("%s offers %s." % [state.actor_name(player), offered.display_name()], "offer")
		state.emit_event("offer", {"player": player, "card_uid": offered.uid, "name": offered.display_name()})

static func _apply_call(state, player: int, action: Dictionary, offers: Array) -> void:
	var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
	var lane := int(action.get("lane", 0))
	var position := str(action.get("position", GameConst.POSITION_ATTACK))
	var face_down := bool(action.get("face_down", false))
	var player_state = state.players[player]
	if player_state.monsters[lane] != null and not offers.has(player_state.monsters[lane].uid):
		return
	_pay_offers(state, player, offers)
	if player_state.monsters[lane] != null:
		return
	player_state.hand.erase(card)
	card.zone = GameConst.ZONE_MONSTER
	card.lane = lane
	card.position = position
	card.face_down = face_down
	card.summoned_turn = state.turn
	player_state.monsters[lane] = card
	player_state.called_this_turn = true
	if face_down:
		state.log_event("%s sets a monster in Lane %d." % [state.actor_name(player), lane + 1], "set")
		state.emit_event("set", {"player": player, "lane": lane, "card_uid": card.uid, "hidden": true})
		EffectEngine.dispatch_card(state, card, "on_set")
	else:
		state.log_event("%s calls %s in Lane %d (%s)." % [
			state.actor_name(player),
			card.display_name(),
			lane + 1,
			"Attack" if position == GameConst.POSITION_ATTACK else "Defense",
		], "call")
		state.emit_event("call", {"player": player, "lane": lane, "card_uid": card.uid, "name": card.display_name(), "position": position})
		EffectEngine.dispatch_card(state, card, "on_call")

static func _apply_play(state, player: int, action: Dictionary) -> void:
	var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
	var lane := int(action.get("lane", 0))
	var player_state = state.players[player]
	player_state.hand.erase(card)
	card.zone = GameConst.ZONE_BACKROW
	card.lane = lane
	card.face_down = false
	card.set_turn = state.turn
	player_state.backrow[lane] = card
	player_state.stats["cards_played"] = int(player_state.stats.get("cards_played", 0)) + 1
	state.log_event("%s plays %s." % [state.actor_name(player), card.display_name()], "play")
	state.emit_event("play", {"player": player, "lane": lane, "card_uid": card.uid, "name": card.display_name()})
	EffectEngine.dispatch_card(state, card, "on_activate")
	if state.ended:
		return
	if not card.def.is_continuous() and not card.def.subtype == "equip":
		player_state.backrow[lane] = null
		card.zone = GameConst.ZONE_REMAINS
		card.lane = -1
		player_state.remains.append(card)

static func _apply_set_card(state, player: int, action: Dictionary) -> void:
	var card: DuelCard = state.find_hand(player, int(action.get("uid", -1)))
	var lane := int(action.get("lane", 0))
	var player_state = state.players[player]
	player_state.hand.erase(card)
	card.zone = GameConst.ZONE_BACKROW
	card.lane = lane
	card.face_down = true
	card.set_turn = state.turn
	player_state.backrow[lane] = card
	state.log_event("%s sets a card in Backrow %d." % [state.actor_name(player), lane + 1], "set")
	state.emit_event("set", {"player": player, "lane": lane, "card_uid": card.uid, "hidden": true})

static func _apply_activate(state, player: int, action: Dictionary) -> void:
	var card: DuelCard = state.find_backrow(player, int(action.get("uid", -1)))
	var player_state = state.players[player]
	card.face_down = false
	player_state.stats["cards_played"] = int(player_state.stats.get("cards_played", 0)) + 1
	state.log_event("%s activates %s." % [state.actor_name(player), card.display_name()], "activate")
	state.emit_event("activate", {"player": player, "card_uid": card.uid, "name": card.display_name()})
	EffectEngine.dispatch_card(state, card, "on_activate")
	if state.ended:
		return
	if not card.def.is_continuous() and not card.def.subtype == "equip":
		player_state.backrow[card.lane] = null
		card.zone = GameConst.ZONE_REMAINS
		player_state.remains.append(card)
		card.lane = -1

static func _apply_attack(state, player: int, action: Dictionary) -> void:
	var attacker: DuelCard = state.find_monster(player, int(action.get("uid", -1)))
	if attacker == null:
		return
	var target_lane := int(action.get("target_lane", 0))
	var defender: int = state.opponent_of(player)
	attacker.attacked_turn = state.turn
	var target: DuelCard = state.monster_at(defender, target_lane)

	state.log_event("%s attacks Lane %d with %s." % [state.actor_name(player), target_lane + 1, attacker.display_name()], "attack")
	state.emit_event("attack", {"player": player, "card_uid": attacker.uid, "lane": attacker.lane, "target_lane": target_lane})

	var negated := EffectEngine.dispatch_attack_traps(state, defender, attacker, target_lane)
	if state.ended:
		return
	if negated:
		state.log_event("The attack is negated.", "attack")
		state.emit_event("negate", {"player": defender, "target_lane": target_lane})
		return

	EffectEngine.dispatch_card(state, attacker, "on_attack")
	if state.ended or state.find_monster(player, attacker.uid) == null:
		return

	if target != null and target.face_down:
		state.flip_card(target)
		if state.ended:
			return
		if state.find_monster(defender, target.uid) == null:
			state.log_event("The attack fizzles.", "attack")
			return

	target = state.monster_at(defender, target_lane)
	if target == null:
		var direct_stats: Dictionary = state.stats_for(attacker)
		var direct_atk := int(direct_stats["atk"])
		state.log_event("%s strikes directly for %d." % [attacker.display_name(), direct_atk], "direct")
		state.damage_player(defender, direct_atk, player, attacker.display_name())
		return

	var attacker_stats: Dictionary = state.stats_for(attacker)
	var defender_stats: Dictionary = state.stats_for(target)
	var a_atk := int(attacker_stats["atk"])
	var a_def := int(attacker_stats["defense"])
	var d_atk := int(defender_stats["atk"])
	var d_def := int(defender_stats["defense"])

	if target.is_defense_position():
		if a_atk > d_def:
			state.log_event("%s destroys %s in Defense." % [attacker.display_name(), target.display_name()], "battle")
			if state.has_keyword(attacker, "pierce"):
				var pierce := a_atk - d_def
				state.log_event("PIERCE carries %d." % pierce, "battle")
				state.damage_player(defender, pierce, player, attacker.display_name())
			state.destroy_card(target, attacker.display_name())
		elif a_atk < d_def:
			var recoil := d_def - a_atk
			state.log_event("%s is repelled for %d." % [attacker.display_name(), recoil], "battle")
			state.damage_player(player, recoil, defender, target.display_name())
		else:
			state.log_event("The attack is stopped.", "battle")
	else:
		if a_atk > d_atk:
			var difference := a_atk - d_atk
			state.log_event("%s destroys %s." % [attacker.display_name(), target.display_name()], "battle")
			if _last_word_prevents(state, target):
				pass
			else:
				state.destroy_card(target, attacker.display_name())
				state.damage_player(defender, difference, player, attacker.display_name())
		elif a_atk < d_atk:
			var difference := d_atk - a_atk
			state.log_event("%s destroys %s." % [target.display_name(), attacker.display_name()], "battle")
			if _last_word_prevents(state, attacker):
				pass
			else:
				state.destroy_card(attacker, target.display_name())
				state.damage_player(player, difference, defender, target.display_name())
		else:
			state.log_event("Both monsters are destroyed.", "battle")
			if not _last_word_prevents(state, target):
				state.destroy_card(target, attacker.display_name())
			if not _last_word_prevents(state, attacker):
				state.destroy_card(attacker, target.display_name())

static func _last_word_prevents(state, card: DuelCard) -> bool:
	if card == null or card.last_word_used:
		return false
	if not state.has_keyword(card, "last_word"):
		return false
	card.last_word_used = true
	state.log_event("%s invokes the Last Word; the attack is negated." % card.display_name(), "battle")
	return true
