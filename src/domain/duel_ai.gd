class_name DuelAI
extends RefCounted

## Utility AI. Reads only public information plus its own hand. Face-down
## opponent positions are estimated, never read. Manual and Suggest use the
## same legal actions.

static func choose_action(state, skill: int = 60) -> Dictionary:
	if state == null or state.ended:
		return {}
	var actions := DuelRules.legal_actions(state)
	if actions.is_empty():
		return {"type": "end_phase"}
	var scored: Array[Dictionary] = []
	for action in actions:
		if str(action.get("type", "")) == "resign":
			continue
		scored.append({"action": action, "score": _score_action(state, action)})
	if scored.is_empty():
		return {"type": "end_phase"}
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var best: Dictionary = scored[0]
	# Lower skill sometimes takes the second-best line. Never illegal.
	if scored.size() > 1 and skill < 95:
		var mistake_chance := float(95 - skill) / 100.0 * 0.35
		if state.ai_rng.chance(mistake_chance):
			var second: Dictionary = scored[1]
			if float(second["score"]) >= -2.0:
				best = second
	var action: Dictionary = best["action"]
	if str(action.get("type", "")) == "end_phase" and float(best["score"]) < 0.0:
		return {"type": "end_phase"}
	return action

static func simulate(state, skill: int = 60) -> Dictionary:
	var guard := 0
	while not state.ended and guard < 6000:
		var action := choose_action(state, skill)
		if action.is_empty():
			action = {"type": "end_phase"}
		var result := DuelRules.apply(state, state.active, action)
		if not bool(result.get("ok", false)):
			state.log_event("AI fallback: %s" % result.get("reason", "illegal action"), "info")
			DuelRules.apply(state, state.active, {"type": "end_phase"})
		guard += 1
	if not state.ended:
		state.end_duel(2, "simulation guard")
	return state.summary()

static func _score_action(state, action: Dictionary) -> float:
	match str(action.get("type", "")):
		"call":
			return _score_call(state, action)
		"play":
			return _score_play(state, action, false)
		"set_card":
			return _score_set_card(state, action)
		"activate":
			return _score_activate(state, action)
		"attack":
			return _score_attack(state, action)
		"end_phase":
			return 0.0
		_:
			return -100.0

static func _doctrine(state) -> String:
	return state.players[state.active].doctrine

static func _score_call(state, action: Dictionary) -> float:
	var player = state.players[state.active]
	var card: DuelCard = state.find_hand(state.active, int(action.get("uid", -1)))
	if card == null:
		return -100.0
	var position := str(action.get("position", GameConst.POSITION_ATTACK))
	var face_down := bool(action.get("face_down", false))
	var lane := int(action.get("lane", 0))
	var stats: Dictionary = state.stats_for(card)
	var score := float(state.power_of(card)) * 0.8
	var face_up_attack := not face_down and position == GameConst.POSITION_ATTACK
	var face_up_defense := not face_down and position == GameConst.POSITION_DEFENSE
	score += float(stats["atk"]) / 150.0 if face_up_attack else float(stats["defense"]) / 160.0
	var doctrine := _doctrine(state)
	var own_face_up := 0
	for monster in player.monsters:
		if monster != null and not monster.face_down and monster.is_attack_position():
			own_face_up += 1
	if doctrine == "press":
		score += 4.0 if face_up_attack else -4.0
		score += float(stats["atk"]) / 200.0
	elif doctrine == "hold":
		score += float(stats["defense"]) / 180.0
		if face_down:
			score += 3.0
		if face_up_attack:
			score -= 1.0
	else:
		if face_up_attack:
			score += 2.0
		elif face_down:
			score += 1.0 if int(stats["defense"]) > int(stats["atk"]) + 300 else -2.0
	if own_face_up == 0:
		if face_up_attack:
			score += 5.0
		elif face_down:
			score -= 3.0
	if face_up_defense:
		score += 1.0
	var enemy = state.players[state.opponent_of(state.active)]
	if enemy.monsters[lane] != null:
		if not face_up_attack:
			score += 1.0
		else:
			score -= 1.0
	else:
		score += 1.5
	var required: int = state.offer_cost(card)
	if required > 0:
		var own: Array[DuelCard] = []
		for monster in player.monsters:
			if monster != null:
				own.append(monster)
		own.sort_custom(func(a: DuelCard, b: DuelCard) -> bool:
			return state.power_of(a) < state.power_of(b)
		)
		var cost := 0
		for i in range(mini(required, own.size())):
			cost += state.power_of(own[i])
		score -= float(cost) * 0.7
	return score

static func _score_play(state, action: Dictionary, from_set: bool) -> float:
	var card: DuelCard = state.find_hand(state.active, int(action.get("uid", -1)))
	if card == null:
		card = state.find_backrow(state.active, int(action.get("uid", -1)))
	if card == null:
		return -100.0
	var score := _effect_value(state, card)
	if from_set:
		score += 2.0
	var doctrine := _doctrine(state)
	if doctrine == "read":
		score += 1.0
	if card.def.has_effect:
		var trigger := str(card.def.effect.get("trigger", ""))
		if trigger == "continuous":
			var lane := int(action.get("lane", 0))
			if state.players[state.active].monsters[lane] != null:
				score += 2.0
	return score

static func _score_set_card(state, action: Dictionary) -> float:
	var card: DuelCard = state.find_hand(state.active, int(action.get("uid", -1)))
	if card == null:
		return -100.0
	if card.is_spell():
		return _effect_value(state, card) - 3.0
	var score := _effect_value(state, card)
	var doctrine := _doctrine(state)
	if doctrine == "hold":
		score += 2.0
	elif doctrine == "press":
		score -= 1.0
	return score

static func _score_activate(state, action: Dictionary) -> float:
	var card: DuelCard = state.find_backrow(state.active, int(action.get("uid", -1)))
	if card == null:
		return -100.0
	return _effect_value(state, card) + 2.0

static func _effect_value(state, card: DuelCard) -> float:
	if not card.def.has_effect:
		return 1.0
	var effect: Dictionary = card.def.effect
	var score := 0.0
	for step in effect.get("steps", []):
		var action := str(step.get("action", ""))
		var amount := int(step.get("amount", 0))
		match action:
			"draw":
				score += 6.0 + float(amount) * 2.5
			"damage":
				score += 4.0 + float(amount) / 200.0
			"heal":
				score += 3.0 + float(amount) / 300.0
			"return_from_remains":
				score += 7.0 if state.remains_count(state.active) > 0 else -10.0
			"lane_buff":
				score += 6.0 + float(amount) / 100.0
			"on_destroy_summon":
				score += 7.0 if state.players[state.active].monster_count() > 0 else 2.0
			"negate_attack":
				score += 9.0 if state.players[state.opponent_of(state.active)].monster_count() > 0 else 3.0
			"dusk_discard":
				score -= 1.0
			"summon_token":
				score += 6.0
			_:
				score += 1.0
	var trigger := str(effect.get("trigger", ""))
	if trigger == "continuous":
		score += 1.0
	return score

static func _score_attack(state, action: Dictionary) -> float:
	var attacker: DuelCard = state.find_monster(state.active, int(action.get("uid", -1)))
	if attacker == null:
		return -100.0
	var target_lane := int(action.get("target_lane", 0))
	var target: DuelCard = state.monster_at(state.opponent_of(state.active), target_lane)
	var attacker_stats: Dictionary = state.stats_for(attacker)
	var atk := int(attacker_stats["atk"])
	var enemy_resolve: int = state.players[state.opponent_of(state.active)].resolve
	var doctrine := _doctrine(state)
	if target == null:
		var score := float(atk) / 100.0
		if atk >= enemy_resolve:
			score += 100.0
		if doctrine == "hold":
			score -= 0.5
		return score
	if target.face_down:
		# Hidden position: evaluate the average defense line, never the actual value.
		var assumed_def := 1400
		var score := (float(atk) - float(assumed_def)) / 150.0
		if atk >= 2200:
			score += 2.0
		if doctrine == "press":
			score += 1.0
		elif doctrine == "hold":
			score -= 1.5
		return score
	var defender_stats: Dictionary = state.stats_for(target)
	var d_atk := int(defender_stats["atk"])
	var d_def := int(defender_stats["defense"])
	if target.is_defense_position():
		if atk > d_def:
			var score := 2.0 + float(atk - d_def) / 150.0
			if state.has_keyword(attacker, "pierce"):
				score += float(atk - d_def) / 100.0
				if atk - d_def >= enemy_resolve:
					score += 100.0
			if doctrine == "press":
				score += 1.0
			return score
		elif atk < d_def:
			var score := -2.0 - float(d_def - atk) / 150.0
			if doctrine == "press":
				score += 1.0
			return score
		return 0.0
	if atk > d_atk:
		var score := 2.0 + float(atk - d_atk) / 120.0 + float(state.power_of(target)) / 50.0
		if atk - d_atk >= enemy_resolve:
			score += 100.0
		if doctrine == "press":
			score += 1.0
		return score
	elif atk < d_atk:
		var score := -2.0 - float(d_atk - atk) / 120.0 - float(state.power_of(attacker)) / 50.0
		if doctrine == "press":
			score += 1.5
		return score
	return float(state.power_of(target) - state.power_of(attacker)) / 50.0
