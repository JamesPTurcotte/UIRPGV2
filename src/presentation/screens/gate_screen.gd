class_name GateScreen
extends UIScreen

var selected_floor: int = 1
var depth_box: VBoxContainer
var plaque_box: VBoxContainer
var deck_box: VBoxContainer
var descend_seal: SealMedallion
var floor_buttons: Array[Dictionary] = []

func build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	content.add_child(_build_depth_rail())
	content.add_child(_build_plaque())
	content.add_child(_build_deck_panel())
	root.add_child(_build_footer())
	selected_floor = clampi(int(Session.unlocked_floor), 1, maxi(1, int(Session.unlocked_floor)))
	if Session.has_active_descent():
		selected_floor = int(Session.descent.get("current_floor", selected_floor))
	_refresh_all()

func _build_top_bar() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := UI.vbox(0)
	title.add_child(UI.display("THE GATE", 28))
	title.add_child(UI.small_caps("THE DESCENT"))
	row.add_child(title)
	row.add_child(UI.spacer())
	row.add_child(UI.chip("%d MARKS" % int(Session.currency.get("marks", 0)), Tokens.BRASS_HI))
	row.add_child(UI.chip("%d FOLIOS" % Session.unopened_packs().size(), Tokens.VERDIGRIS))
	row.add_child(UI.chip("BEST DEPTH %d" % maxi(1, int(Session.deepest_floor)), Tokens.INK_SECONDARY))
	return panel

func _build_depth_rail() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	panel.custom_minimum_size = Vector2(230, 0)
	var box := UI.vbox(6)
	panel.add_child(box)
	box.add_child(UI.small_caps("DEPTH RAIL"))
	box.add_child(UI.hsep())
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	depth_box = UI.vbox(3)
	depth_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(depth_box)
	box.add_child(UI.hsep())
	return panel

func _build_plaque() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS, 16)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(10)
	panel.add_child(box)
	plaque_box = UI.vbox(10)
	box.add_child(plaque_box)
	box.add_child(UI.spacer())
	var seal_row := HBoxContainer.new()
	seal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(seal_row)
	descend_seal = SealMedallion.new()
	descend_seal.caption = "DESCEND"
	descend_seal.custom_minimum_size = Vector2(112, 128)
	descend_seal.pressed.connect(_on_descend)
	seal_row.add_child(descend_seal)
	return panel

func _build_deck_panel() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	panel.custom_minimum_size = Vector2(330, 0)
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.small_caps("YOUR DECK"))
	box.add_child(UI.hsep())
	deck_box = UI.vbox(6)
	box.add_child(deck_box)
	box.add_child(UI.spacer())
	box.add_child(UI.button("DECK WORKSHOP", func() -> void: app.go_deck(), Tokens.BRASS_LO))
	return panel

func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.label("Depth rail · current descent", 11, Tokens.INK_MUTED, Tokens.font_data_regular()))
	row.add_child(UI.spacer())
	var help := UI.button("?", func() -> void: app._toggle_help(), Tokens.BRASS_LO)
	help.custom_minimum_size = Vector2(32, 28)
	row.add_child(help)
	return row

func _refresh_all() -> void:
	_refresh_depth_rail()
	_refresh_plaque()
	_refresh_deck_panel()

func _refresh_depth_rail() -> void:
	for child in depth_box.get_children():
		depth_box.remove_child(child)
		child.queue_free()
	floor_buttons.clear()
	# A moving window, not a terminal cap. The rail keeps the selected floor in
	# view and can extend arbitrarily deep without materializing every rung.
	var start_floor := maxi(1, selected_floor - 20)
	var end_floor := maxi(selected_floor + 20, int(Session.unlocked_floor) + 6)
	end_floor = mini(end_floor, start_floor + 80)
	for floor_number in range(start_floor, end_floor + 1):
		var unlocked := floor_number <= int(Session.unlocked_floor)
		var cleared := Session.first_clear_floors.has(floor_number)
		var marker := "●" if cleared else ("○" if unlocked else "·")
		var line := "%s %02d  %s" % [marker, floor_number, _circuit_name(floor_number)]
		if not unlocked:
			line = "· %02d  LOCKED" % floor_number
		var button := UI.button(line, Callable(), Tokens.BRASS_LO if unlocked else Tokens.INK_MUTED)
		button.pressed.connect(_select_floor.bind(floor_number))
		button.toggle_mode = true
		button.button_pressed = floor_number == selected_floor
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 32)
		button.disabled = not unlocked
		button.add_theme_font_size_override("font_size", 11)
		depth_box.add_child(button)
		floor_buttons.append({"floor": floor_number, "button": button, "cleared": cleared, "unlocked": unlocked})

func _circuit_name(floor_number: int) -> String:
	if floor_number <= 9:
		return "THE SHALLOWS"
	if floor_number <= 18:
		return "THE COPPER STACKS"
	if floor_number <= 27:
		return "THE VERDIGRIS STACKS"
	return "THE DEEP"

func _gate_opponent() -> Dictionary:
	if Session.has_active_descent() and selected_floor == int(Session.descent.get("current_floor", selected_floor)):
		var active_opponent := Session.current_opponent()
		if not active_opponent.is_empty():
			return active_opponent
	var authored: Dictionary = Content.opponent_for_floor(selected_floor)
	if not authored.is_empty():
		return authored
	return {
		"name": "Stair Warden %d" % selected_floor,
		"floor": selected_floor,
		"circuit": int(ceil(float(selected_floor) / 9.0)),
		"doctrine": ["press", "hold", "read"][selected_floor % 3],
		"modifier": "ninth_veil" if selected_floor % 9 == 0 else ("opening_gambit" if selected_floor % 5 == 0 else ""),
		"boss": selected_floor % 9 == 0,
		"skill": clampi(45 + selected_floor * 2, 40, 95),
		"plan": "Procedural stair guard.",
		"tell": "Modifier: %s" % (["ninth_veil", "opening_gambit"][selected_floor % 2] if selected_floor % 5 == 0 or selected_floor % 9 == 0 else "none"),
		"counterplay": "Open lane pressure.",
		"reward_bias": {"rarity": "rare" if selected_floor % 9 == 0 else "uncommon", "reagent": "reagent.verdigris" if selected_floor % 9 == 0 else "reagent.prism_ink"},
	}

func _refresh_plaque() -> void:
	for child in plaque_box.get_children():
		plaque_box.remove_child(child)
		child.queue_free()
	var opponent := _gate_opponent()
	var deck: DeckModel = Session.active_deck()
	var power := Session.deck_power(deck)
	var recommended := Content.recommended_power(selected_floor)
	var underdog := Economy.underdog_bonus(power, recommended)
	var first_clear := not Session.first_clear_floors.has(selected_floor)
	var title_row := HBoxContainer.new()
	title_row.add_child(UI.display("FLOOR %02d" % selected_floor, 38))
	title_row.add_child(UI.spacer())
	title_row.add_child(UI.chip(_circuit_name(selected_floor), Tokens.BRASS))
	plaque_box.add_child(title_row)
	plaque_box.add_child(UI.label(str(opponent.get("name", "Warden")), 22, Tokens.INK_PRIMARY))
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	if bool(opponent.get("boss", false)):
		tags.add_child(UI.chip("BOSS", Tokens.WAX))
	var raw_modifier = opponent.get("modifier", null)
	var modifier_text := "" if raw_modifier == null else str(raw_modifier)
	if not modifier_text.is_empty():
		tags.add_child(UI.chip(modifier_text.to_upper().replace("_", " "), Tokens.VERDIGRIS))
	if first_clear:
		tags.add_child(UI.chip("FIRST CLEAR", Tokens.GOLD))
	tags.add_child(UI.chip("RECOMMENDED %d" % recommended, Tokens.INK_SECONDARY))
	tags.add_child(UI.chip("REWARD BIAS %s" % str(opponent.get("reward_bias", {}).get("rarity", "uncommon")).to_upper(), Tokens.VERDIGRIS))
	plaque_box.add_child(tags)
	plaque_box.add_child(UI.hsep())
	var plan := UI.label("PLAN  " + str(opponent.get("plan", "Hold the stair.")), 12, Tokens.INK_SECONDARY)
	plan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque_box.add_child(plan)
	var tell := UI.label("MODIFIER  " + str(opponent.get("tell", "No modifier.")), 12, Tokens.VERDIGRIS)
	tell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque_box.add_child(tell)
	var counter := UI.label("ANSWER  " + str(opponent.get("counterplay", "Open lane.")), 12, Tokens.INK_MUTED)
	counter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plaque_box.add_child(counter)
	var divider := UI.hsep()
	plaque_box.add_child(divider)
	var strengths := GridContainer.new()
	strengths.columns = 2
	for pair in [
		["Warden skill", str(opponent.get("skill", 60))],
		["First clear", "yes" if first_clear else "no"],
		["Reward bias", str(opponent.get("reward_bias", {}).get("rarity", "uncommon")).capitalize()],
		["Underdog", "+%d%%" % int(round(underdog * 100.0))],
	]:
		strengths.add_child(UI.label(pair[0], 11, Tokens.INK_MUTED))
		strengths.add_child(UI.label(pair[1], 11, Tokens.INK_SECONDARY))
	plaque_box.add_child(strengths)
	var active := Session.has_active_descent()
	descend_seal.caption = "RETURN TO TABLE" if active else "DESCEND"
	descend_seal.set_enabled(active or (deck != null and Session.deck_errors(deck).is_empty()))
	if not active and deck != null and not Session.deck_errors(deck).is_empty():
		var error := UI.label(Session.deck_errors(deck)[0], 11, Tokens.DANGER)
		plaque_box.add_child(error)

func _refresh_deck_panel() -> void:
	for child in deck_box.get_children():
		deck_box.remove_child(child)
		child.queue_free()
	var deck: DeckModel = Session.active_deck()
	if deck == null:
		deck_box.add_child(UI.label("No deck.", 12, Tokens.INK_MUTED))
		deck_box.add_child(UI.button("DECK WORKSHOP", func() -> void: app.go_deck(), Tokens.BRASS))
		return
	var errors := Session.deck_errors(deck)
	var power := Session.deck_power(deck)
	var recommended := Content.recommended_power(selected_floor)
	var underdog := Economy.underdog_bonus(power, recommended)
	deck_box.add_child(UI.display(deck.name, 20))
	deck_box.add_child(UI.label("%d / 40 main · %d / 5 side" % [deck.main.size(), deck.side.size()], 12, Tokens.INK_SECONDARY))
	var legal_text := "LEGAL" if errors.is_empty() else "ILLEGAL"
	var legal_color := Tokens.GOOD if errors.is_empty() else Tokens.DANGER
	deck_box.add_child(UI.chip(legal_text, legal_color))
	deck_box.add_child(UI.hsep())
	var grid := GridContainer.new()
	grid.columns = 2
	for pair in [
		["Deck power", str(power)],
		["Recommended", str(recommended)],
		["Underdog", "+%d%%" % int(round(underdog * 100.0))],
		["Best depth", str(maxi(1, int(Session.deepest_floor)))],
		["Doctrine", deck.doctrine.capitalize()],
		["Mode", str(Session.settings.get("mode", "auto")).capitalize()],
	]:
		grid.add_child(UI.label(pair[0], 11, Tokens.INK_MUTED))
		grid.add_child(UI.label(pair[1], 11, Tokens.INK_SECONDARY))
	deck_box.add_child(grid)
	deck_box.add_child(UI.hsep())
	deck_box.add_child(UI.small_caps("DOCTRINE"))
	var doctrine_row := HBoxContainer.new()
	doctrine_row.add_theme_constant_override("separation", 4)
	for doctrine in ["press", "hold", "read"]:
		var button := UI.button(doctrine.capitalize(), Callable(), Tokens.BRASS_LO)
		button.pressed.connect(_set_doctrine.bind(doctrine))
		button.toggle_mode = true
		button.button_pressed = deck.doctrine == doctrine
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		doctrine_row.add_child(button)
	deck_box.add_child(doctrine_row)
	deck_box.add_child(UI.small_caps("CONTROL"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	for mode in ["auto", "suggest", "manual"]:
		var button := UI.button(mode.capitalize(), Callable(), Tokens.BRASS_LO)
		button.pressed.connect(_set_mode.bind(mode))
		button.toggle_mode = true
		button.button_pressed = str(Session.settings.get("mode", "auto")) == mode
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		mode_row.add_child(button)
	deck_box.add_child(mode_row)
	deck_box.add_child(UI.small_caps("ROUTE POLICY"))
	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 4)
	for route in ["safe", "fast", "greedy"]:
		var button := UI.button(route.capitalize(), Callable(), Tokens.BRASS_LO)
		button.pressed.connect(_set_route.bind(route))
		button.toggle_mode = true
		button.button_pressed = str(Session.settings.get("route_policy", "safe")) == route
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 11)
		route_row.add_child(button)
	deck_box.add_child(route_row)
	if Session.has_active_descent():
		deck_box.add_child(UI.hsep())
		deck_box.add_child(UI.label("A Descent is active.", 11, Tokens.GOLD))
		deck_box.add_child(UI.button("RETURN TO TABLE", func() -> void: app.go_table(), Tokens.BRASS))
		deck_box.add_child(UI.button("RECALL FROM THE TABLE", func() -> void:
			app.go_table()
			app.toast("Use Recall on the Table; the current duel resolves first.", "info")
		, Tokens.VERDIGRIS))

func _select_floor(floor_number: int) -> void:
	if floor_number <= int(Session.unlocked_floor):
		selected_floor = floor_number
		_refresh_all()

func _set_doctrine(value: String) -> void:
	Session.set_doctrine(value)
	_refresh_deck_panel()

func _set_mode(value: String) -> void:
	Session.settings["mode"] = value
	Session.save_now()
	_refresh_deck_panel()

func _set_route(value: String) -> void:
	Session.settings["route_policy"] = value
	Session.save_now()
	_refresh_deck_panel()

func _on_descend() -> void:
	if Session.has_active_descent():
		app.go_table()
		return
	var deck: DeckModel = Session.active_deck()
	if deck == null:
		app.toast("No deck.", "bad")
		return
	var result: Dictionary = Session.start_descent(selected_floor, deck.deck_id, str(Session.settings.get("mode", "auto")))
	if bool(result.get("ok", false)):
		app.go_table()
	else:
		app.toast(str(result.get("reason", "Cannot descend.")), "bad")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				app.go_library()
			KEY_UP:
				if selected_floor < int(Session.unlocked_floor):
					selected_floor += 1
					_refresh_all()
			KEY_DOWN:
				if selected_floor > 1:
					selected_floor -= 1
					_refresh_all()
			KEY_D:
				var deck: DeckModel = Session.active_deck()
				if deck != null:
					var order := ["press", "hold", "read"]
					Session.set_doctrine(order[(order.find(deck.doctrine) + 1) % 3])
					_refresh_deck_panel()
			KEY_ENTER, KEY_KP_ENTER:
				_on_descend()
