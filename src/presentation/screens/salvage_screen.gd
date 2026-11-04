class_name SalvageScreen
extends UIScreen

var result: Dictionary = {}
var returned: bool = false

func build() -> void:
	result = payload.get("result", {})
	returned = bool(payload.get("returned", false)) or str(result.get("kind", "")) == "returned"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var root := UI.vbox(10)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	heading.add_child(UI.display("SALVAGE" if not returned else "RETURNED", 30))
	heading.add_child(UI.spacer())
	heading.add_child(UI.chip("FLOOR %d" % int(result.get("floor", 0)), Tokens.BRASS))
	heading.add_child(UI.chip("BEST STREAK %d" % int(result.get("best_streak", result.get("streak", 0))), Tokens.INK_SECONDARY))
	root.add_child(heading)
	var ledger := PanelContainer.new()
	ledger.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.PAPER, Tokens.WAX, 2, 5))
	ledger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(ledger)
	var ledger_margin := MarginContainer.new()
	for side in ["left", "right"]:
		ledger_margin.add_theme_constant_override("margin_" + side, 30)
	ledger_margin.add_theme_constant_override("margin_top", 20)
	ledger_margin.add_theme_constant_override("margin_bottom", 20)
	ledger.add_child(ledger_margin)
	var ledger_box := UI.vbox(10)
	ledger_margin.add_child(ledger_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	ledger_box.add_child(top)
	var seal := WaxSealButton.new()
	seal.label = "S" if not returned else "R"
	seal.caption = ""
	seal.custom_minimum_size = Vector2(86, 86)
	seal.enabled = true
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(seal)
	var title_box := UI.vbox(2)
	var title := UI.label("SALVAGE LEDGER" if not returned else "RETURNED LEDGER", 26, Tokens.PAPER_INK)
	title.add_theme_font_override("font", Tokens.font_display())
	title_box.add_child(title)
	title_box.add_child(UI.label("No cards lost. Wins banked." if not returned else "Wins banked.", 12, Color("#5A5144")))
	top.add_child(title_box)
	top.add_child(UI.spacer())
	var marks_big := UI.label("+%d" % int(result.get("marks", 0)), 30, Tokens.WAX)
	marks_big.add_theme_font_override("font", Tokens.font_data())
	top.add_child(marks_big)
	ledger_box.add_child(UI.hsep(Color("#B9AE97")))
	if not returned:
		_breakdown(ledger_box)
	else:
		var formula := UI.label("Return Bonus = (10 + 10 × Floors cleared) × (1 + Underdog).", 12, Color("#5A5144"))
		formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ledger_box.add_child(formula)
	ledger_box.add_child(UI.hsep(Color("#B9AE97")))
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 16)
	ledger_box.add_child(reward_row)
	var marks_box := UI.vbox(2)
	marks_box.add_child(UI.label("MARKS", 10, Color("#7A7060")))
	marks_box.add_child(UI.label("+%d" % int(result.get("marks", 0)), 18, Tokens.PAPER_INK, Tokens.font_data()))
	reward_row.add_child(marks_box)
	var reagent_box := UI.vbox(2)
	reagent_box.add_child(UI.label("REAGENTS", 10, Color("#7A7060")))
	var reagent_text := "—"
	var reagent_names: Array[String] = []
	for reagent_id in result.get("reagents", {}).keys():
		var reagent := Content.reagent(str(reagent_id))
		reagent_names.append("%s ×%d" % [str(reagent.get("name", reagent_id)), int(result["reagents"][reagent_id])])
	if not reagent_names.is_empty():
		reagent_text = ", ".join(reagent_names)
	reagent_box.add_child(UI.label(reagent_text, 12, Tokens.PAPER_INK))
	reward_row.add_child(reagent_box)
	if not returned:
		var cache_box := UI.vbox(2)
		cache_box.add_child(UI.label("SALVAGE CACHE", 10, Color("#7A7060")))
		cache_box.add_child(UI.label("3 cards + 1 Common reagent" if bool(result.get("salvage_cache", false)) else "—", 11, Tokens.PAPER_INK))
		reward_row.add_child(cache_box)
	var scroll := UI.scroll()
	ledger_box.add_child(scroll)
	# Reward rows can grow with a cache, a boss payout, or a future bonus. Wrap
	# instead of clipping the last cards off the right edge.
	var cards_row := HFlowContainer.new()
	cards_row.add_theme_constant_override("h_separation", 10)
	cards_row.add_theme_constant_override("v_separation", 10)
	cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards_row)
	var cards: Array = result.get("cards", [])
	for drop in cards:
		var def: CardDef = Content.cards.get(str(drop.get("def_id", "")))
		if def == null:
			continue
		var temp := CardInstance.new(0, def.id, int(drop.get("provenance", 1)))
		temp.ink_id = str(drop.get("ink_id", "ink.iron"))
		temp.shimmer_id = str(drop.get("shimmer_id", "shimmer.none"))
		var view := CardView.new()
		view.set_card(def, temp, "S")
		cards_row.add_child(view)
	if cards.is_empty():
		cards_row.add_child(UI.label("No card drops." if returned else "No cards.", 11, Color("#5A5144")))
	var note := UI.label("No cards lost. No deck changes." if not returned else "", 11, Color("#7A7060"))
	ledger_box.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)
	buttons.add_child(UI.button("RETURN TO LIBRARY", func() -> void: app.go_library(), Tokens.BRASS))
	buttons.add_child(UI.button("THE GATE", func() -> void: app.go_gate(), Tokens.BRASS))
	if not Session.unopened_packs().is_empty():
		buttons.add_child(UI.button("OPEN A FOLIO", func() -> void: app.go_folio(), Tokens.VERDIGRIS))
	buttons.add_child(UI.spacer())

func _breakdown(parent: VBoxContainer) -> void:
	var perf: Dictionary = result.get("performance", {})
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 2)
	for pair in [
		["Floors cleared × 20", str(perf.get("floor_points", 0))],
		["Best streak × 5", str(perf.get("streak_points", 0))],
		["Flawless duels × 25", str(perf.get("flawless_points", 0))],
		["Damage dealt", str(perf.get("damage_points", 0))],
		["Damage healed", str(perf.get("heal_points", 0))],
		["Cards played", str(perf.get("cards_points", 0))],
		["Performance total", str(perf.get("total", 0))],
		["Underdog bonus", "+%d%%" % int(round(float(result.get("underdog", 0.0)) * 100.0))],
	]:
		grid.add_child(UI.label(pair[0], 12, Color("#5A5144")))
		grid.add_child(UI.label(pair[1], 12, Tokens.PAPER_INK, Tokens.font_data()))
	parent.add_child(grid)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			app.go_library()
