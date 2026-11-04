class_name EffectEngine
extends RefCounted

## Executes the data-driven effect DSL. There is no per-card GDScript.
## Add an action here (and a test) before authoring content that uses it.

static func condition_met(state, owner: int, condition) -> bool:
	if condition == null or not (condition is Dictionary):
		return true
	var ctx := condition as Dictionary
	if ctx.has("controller_has_attribute"):
		if not state.has_attribute(owner, str(ctx["controller_has_attribute"])):
			return false
	if ctx.has("opponent_has_attribute"):
		if not state.has_attribute(state.opponent_of(owner), str(ctx["opponent_has_attribute"])):
			return false
	if ctx.has("remains_count_min"):
		if state.remains_count(owner) < int(ctx["remains_count_min"]):
			return false
	if ctx.has("hand_count_max"):
		if state.players[owner].hand.size() > int(ctx["hand_count_max"]):
			return false
	return true

static func _limit_key(card: DuelCard, trigger: String) -> String:
	return "%d:%s" % [card.uid, trigger]

static func _check_and_mark_limit(state, card: DuelCard, effect: Dictionary, trigger: String) -> bool:
	var limit := str(effect.get("limit", ""))
	if limit.is_empty():
		return true
	var key := _limit_key(card, trigger)
	if limit == "once_per_turn":
		if state.turn_limits.has(key):
			return false
		state.turn_limits[key] = true
		return true
	if limit == "once_per_duel":
		if state.duel_limits.has(key):
			return false
		state.duel_limits[key] = true
		return true
	return true

static func dispatch_card(state, card: DuelCard, trigger: String, context: Dictionary = {}) -> void:
	if card == null or state.ended:
		return
	if state.trigger_depth > 12:
		push_warning("Trigger depth exceeded for %s" % card.display_name())
		return
	state.trigger_depth += 1
	if card.def != null and card.def.has_effect:
		var effect: Dictionary = card.def.effect
		if str(effect.get("trigger", "")) == trigger:
			if condition_met(state, card.owner, effect.get("condition")):
				if _check_and_mark_limit(state, card, effect, trigger):
					resolve_effect(state, effect, card.owner, card, context)
	for mod in card.instance.mods:
		var mod_def: Dictionary = state.mod_db.get(str(mod.get("id", "")), {})
		if str(mod_def.get("trigger", "")) == trigger:
			var mod_context := context.duplicate(true)
			mod_context["value"] = int(mod.get("value", 0))
			resolve_steps(state, mod_def.get("steps", []), card.owner, card, mod_context)
	state.trigger_depth -= 1

static func dispatch_turn(state, owner: int, trigger: String) -> void:
	var player = state.players[owner]
	for card in player.all_board_cards():
		if card.face_down:
			continue
		dispatch_card(state, card, trigger)
		if state.ended:
			return

static func dispatch_destroy_watchers(state, destroyed: DuelCard, lane: int) -> void:
	# Continuous traps that watch destruction. They are revealed when they fire.
	for owner in [0, 1]:
		var player = state.players[owner]
		for card in player.backrow:
			if card == null or not card.is_trap():
				continue
			if not card.def.has_effect:
				continue
			var effect: Dictionary = card.def.effect
			if str(effect.get("trigger", "")) != "continuous":
				continue
			var has_watcher := false
			for step in effect.get("steps", []):
				if str(step.get("action", "")) == "on_destroy_summon":
					has_watcher = true
					break
			if not has_watcher:
				continue
			if not _check_and_mark_limit(state, card, effect, "on_destroy"):
				continue
			if card.face_down:
				card.face_down = false
				state.log_event("%s is activated." % card.display_name(), "activate")
				state.emit_event("activate", {"player": owner, "card_uid": card.uid, "name": card.display_name()})
			var context := {"lane": lane, "destroyed": destroyed}
			resolve_steps(state, effect.get("steps", []), owner, card, context)
			if state.ended:
				return

static func dispatch_attack_traps(state, defender: int, attacker: DuelCard, target_lane: int) -> bool:
	## Returns true when the attack was negated.
	var player = state.players[defender]
	for lane in range(3):
		var trap: DuelCard = player.backrow[lane]
		if trap == null or not trap.is_trap() or not trap.def.has_effect:
			continue
		if trap.set_turn >= state.turn:
			continue
		var effect: Dictionary = trap.def.effect
		if str(effect.get("trigger", "")) != "on_attack":
			continue
		if state.has_keyword(attacker, "veil"):
			continue
		trap.face_down = false
		state.log_event("%s is activated." % trap.display_name(), "activate")
		state.emit_event("activate", {"player": defender, "card_uid": trap.uid, "name": trap.display_name()})
		state.attack_context = {"negated": false, "attacker": attacker, "defender": defender, "lane": target_lane}
		resolve_effect(state, effect, defender, trap, state.attack_context)
		var negated := bool(state.attack_context.get("negated", false))
		if not trap.def.is_continuous():
			player.backrow[lane] = null
			trap.zone = GameConst.ZONE_REMAINS
			player.remains.append(trap)
			trap.lane = -1
			state.emit_event("destroy", {"player": defender, "card_uid": trap.uid, "name": trap.display_name()})
		if negated:
			return true
	return false

static func resolve_effect(state, effect: Dictionary, owner: int, source: DuelCard, context: Dictionary = {}) -> void:
	resolve_steps(state, effect.get("steps", []), owner, source, context)

static func resolve_steps(state, steps: Array, owner: int, source: DuelCard, context: Dictionary = {}) -> void:
	for step in steps:
		if state.ended:
			return
		if not (step is Dictionary):
			continue
		if step.has("condition") and not condition_met(state, owner, step.get("condition")):
			continue
		_execute_step(state, step, owner, source, context)
		if state.ended:
			return

static func _execute_step(state, step: Dictionary, owner: int, source: DuelCard, context: Dictionary) -> void:
	var action := str(step.get("action", ""))
	var opponent: int = state.opponent_of(owner)
	var amount := int(step.get("amount", 0))
	if bool(step.get("amount_from_value", false)):
		amount = int(context.get("value", 0))
	match action:
		"damage":
			var target_player := -1
			var target_card = _resolve_target(state, step.get("target", "opponent"), owner, source, context)
			if target_card is DuelCard:
				target_player = target_card.owner
			elif target_card is int:
				target_player = target_card
			if target_player >= 0:
				state.damage_player(target_player, amount, owner, source.display_name() if source != null else "")
		"heal":
			var target_player := owner
			var target = step.get("target", "controller")
			if str(target) == "opponent":
				target_player = opponent
			state.heal_player(target_player, amount, source.display_name() if source != null else "")
		"draw":
			state.draw_cards(owner, amount, owner == 0)
		"discard":
			for i in range(amount):
				if state.players[owner].hand.is_empty():
					break
				state.discard_lowest(owner, "an effect")
		"destroy":
			var target = _resolve_target_card(state, step.get("target", "enemy_monster"), owner, source, context)
			if target != null:
				state.destroy_card(target, source.display_name() if source != null else "")
		"banish":
			var target = _resolve_target_card(state, step.get("target", "enemy_monster"), owner, source, context)
			if target != null:
				state.banish_card(target, source.display_name() if source != null else "")
		"summon_token":
			var lane := int(context.get("lane", source.lane if source != null else -1))
			if lane < 0:
				var empty: Array = state.players[owner].empty_monster_lanes()
				lane = int(empty[0]) if not empty.is_empty() else -1
			if lane >= 0:
				state.create_token(owner, lane, int(step.get("atk", 500)), int(step.get("defense", 500)))
		"buff", "debuff":
			var target = _resolve_target_card(state, step.get("target", "self"), owner, source, context)
			if target != null:
				var signed_amount := amount if action == "buff" else -amount
				state.add_buff(target, str(step.get("stat", "atk")), signed_amount, str(step.get("duration", "until_dusk")))
		"return_from_remains":
			var player = state.players[owner]
			var pool: Array = []
			for card in player.remains:
				if card.is_monster():
					pool.append(card)
			if not pool.is_empty():
				var chosen: DuelCard = pool[0]
				for card in pool:
					if state.power_of(card) > state.power_of(chosen):
						chosen = card
				player.remains.erase(chosen)
				chosen.zone = GameConst.ZONE_HAND
				player.hand.append(chosen)
				state.log_event("%s returns %s from the Remains." % [state.actor_name(owner), chosen.display_name()], "remains")
				state.emit_event("return", {"player": owner, "card_uid": chosen.uid, "name": chosen.display_name()})
		"negate_attack":
			state.attack_context = state.attack_context if not state.attack_context.is_empty() else context
			state.attack_context["negated"] = true
			var attacker = state.attack_context.get("attacker")
			if attacker is DuelCard and bool(step.get("then_banish", false)):
				if not state.has_keyword(attacker, "veil"):
					state.banish_card(attacker, source.display_name() if source != null else "")
		"lane_buff":
			pass
		"on_destroy_summon":
			var lane := int(context.get("lane", -1))
			if lane >= 0 and state.players[owner].monsters[lane] == null:
				state.create_token(owner, lane, int(step.get("atk", 500)), int(step.get("defense", 500)))
		"dusk_discard":
			state.pending_dusk_discard[owner] += amount
		"banish_self_instead":
			pass
		_:
			push_warning("Unknown effect action: %s" % action)

static func _resolve_target(state, target_spec, owner: int, source: DuelCard, context: Dictionary) -> Variant:
	var target := str(target_spec)
	match target:
		"opponent":
			return state.opponent_of(owner)
		"controller", "self_player":
			return owner
		"self":
			return source
		"enemy_monster":
			if context.has("target_card") and context["target_card"] is DuelCard:
				return context["target_card"]
			return null
		"own_monster":
			if context.has("own_target") and context["own_target"] is DuelCard:
				return context["own_target"]
			return source
		_:
			return null

static func _resolve_target_card(state, target_spec, owner: int, source: DuelCard, context: Dictionary) -> DuelCard:
	var resolved = _resolve_target(state, target_spec, owner, source, context)
	if resolved is DuelCard:
		return resolved
	return null
