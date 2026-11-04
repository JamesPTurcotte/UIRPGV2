class_name BenchScreen
extends UIScreen

## The Bench: one card on a stand, a tabbed reagent vault, and a rule.
## Costs are deterministic; outcomes are random. No slot machine.

var instance: CardInstance
var return_def: String = ""
var selected_tab: String = "inks"
var selected_reagent: String = ""
var vault_grid: GridContainer
var tab_buttons: Dictionary = {}
var card_holder: CenterContainer
var detail_box: VBoxContainer
var apply_seal: SealMedallion
var rule_label: Label
var verb_label: Label
var history_box: VBoxContainer
var card_token: String = "L"

func build() -> void:
	instance = payload.get("instance")
	return_def = str(payload.get("return_def", ""))
	if instance == null:
		instance = Session.bench_instance()
	card_token = Responsive.card_token_for_height(get_viewport_rect().size.y)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := UI.vbox(8)
	margin.add_child(root)
	root.add_child(_build_top())
	# The content is taller than the reference view at 900 px. A scroll keeps
	# the apply rail pinned instead of pushing it below the window.
	var content_scroll := UI.scroll()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(content_scroll)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content)
	content.add_child(_build_vault())
	content.add_child(_build_card_side())
	root.add_child(_build_apply_rail())
	layout_changed.connect(_on_layout_changed)
	_refresh_all()

func _build_top() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 12)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := UI.vbox(0)
	var name := instance.display_name(Content.cards.get(instance.def_id)) if instance != null else "No card"
	title.add_child(UI.display("THE BENCH · " + name, 26))
	title.add_child(UI.small_caps("CRAFT · INSCRIBE · SEAL"))
	row.add_child(title)
	row.add_child(UI.spacer())
	if instance != null:
		row.add_child(UI.chip("F%d" % instance.provenance, Tokens.VERDIGRIS))
		row.add_child(UI.chip("QUALITY %d%%" % instance.quality, Tokens.BRASS_HI))
	return panel

func _build_vault() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UI.display("REAGENT VAULT", 20))
	head.add_child(UI.spacer())
	box.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	box.add_child(tabs)
	for tab in GameConst.REAGENT_TABS:
		var tab_key: String = tab
		var button := UI.button(str(GameConst.TAB_LABELS.get(tab, tab)), Callable(), Tokens.BRASS_LO)
		button.pressed.connect(_set_tab.bind(tab_key))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		tab_buttons[tab] = button
		tabs.add_child(button)
	box.add_child(UI.hsep())
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	vault_grid = GridContainer.new()
	vault_grid.columns = 5
	vault_grid.add_theme_constant_override("h_separation", 12)
	vault_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(vault_grid)
	history_box = UI.vbox(4)
	history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_box.visible = false
	box.add_child(history_box)
	return panel

func _build_card_side() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 12)
	# 640 leaves room for the content scrollbar at the 1440 reference width.
	panel.custom_minimum_size = Vector2(640, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.small_caps("THE CARD"))
	card_holder = CenterContainer.new()
	card_holder.custom_minimum_size = Vector2(0, Tokens.card_size(card_token).y + 4)
	box.add_child(card_holder)
	detail_box = UI.vbox(4)
	box.add_child(detail_box)
	box.add_child(UI.spacer())
	var rule_panel := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 10)
	box.add_child(rule_panel)
	var rule_box := UI.vbox(3)
	rule_panel.add_child(rule_box)
	verb_label = UI.small_caps("NO REAGENT")
	rule_label = UI.label("No reagent selected.", 12, Tokens.INK_SECONDARY)
	rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_box.add_child(verb_label)
	rule_box.add_child(rule_label)
	return panel

func _build_apply_rail() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(UI.spacer())
	apply_seal = SealMedallion.new()
	apply_seal.caption = "APPLY"
	apply_seal.custom_minimum_size = Vector2(104, 120)
	apply_seal.pressed.connect(_apply)
	row.add_child(apply_seal)
	row.add_child(UI.button("CANCEL", _close, Tokens.BRASS_LO))
	return panel

func _refresh_all() -> void:
	if instance == null:
		return
	_refresh_tabs()
	_refresh_vault()
	_refresh_card()
	_refresh_rule()

func _refresh_tabs() -> void:
	for tab in tab_buttons.keys():
		var button: Button = tab_buttons[tab]
		button.button_pressed = str(tab) == selected_tab

func _refresh_vault() -> void:
	for child in vault_grid.get_children():
		vault_grid.remove_child(child)
		child.queue_free()
	for child in history_box.get_children():
		history_box.remove_child(child)
		child.queue_free()
	vault_grid.visible = selected_tab != "history"
	history_box.visible = selected_tab == "history"
	if selected_tab == "history":
		history_box.add_child(UI.display("Craft ledger", 20))
		if instance.history.is_empty():
			history_box.add_child(UI.label("No history.", 12, Tokens.INK_MUTED))
		else:
			for entry in instance.history:
				history_box.add_child(UI.label("· " + str(entry.get("detail", "")), 12, Tokens.INK_SECONDARY))
		return
	for raw in Content.reagent_list:
		if str(raw.get("tab", "")) != selected_tab:
			continue
		var tile := ReagentTile.new()
		tile.set_reagent(raw, int(Session.reagents.get(str(raw.get("id", "")), 0)))
		tile.selected = str(raw.get("id", "")) == selected_reagent
		tile.clicked.connect(func(chosen: ReagentTile) -> void:
			selected_reagent = str(chosen.reagent.get("id", ""))
			_refresh_vault()
			_refresh_rule()
			_refresh_card()
		)
		vault_grid.add_child(tile)

func _refresh_rule() -> void:
	if selected_reagent.is_empty():
		verb_label.text = "NO REAGENT"
		rule_label.text = "No reagent selected."
		apply_seal.set_enabled(false)
		return
	var reagent := Content.reagent(selected_reagent)
	verb_label.text = "%s · %s" % [str(reagent.get("verb", "")).to_upper(), str(reagent.get("name", "")).to_upper()]
	rule_label.text = str(reagent.get("rule", ""))
	var can_apply := int(Session.reagents.get(selected_reagent, 0)) > 0 and not instance.corrupted and not instance.locked
	apply_seal.set_enabled(can_apply)
	if instance.corrupted:
		rule_label.text += "\nCORRUPTED: further crafting is locked."

func _refresh_card() -> void:
	for child in card_holder.get_children():
		card_holder.remove_child(child)
		child.queue_free()
	for child in detail_box.get_children():
		detail_box.remove_child(child)
		child.queue_free()
	var def: CardDef = Content.cards.get(instance.def_id)
	var card := CardView.new()
	card.set_card(def, instance, card_token)
	card.double_clicked.connect(func(_view: CardView) -> void: app.show_zoom(def, instance))
	card.clicked.connect(func(_view: CardView) -> void: app.show_zoom(def, instance))
	card_holder.add_child(card)
	var plaques := HBoxContainer.new()
	plaques.add_theme_constant_override("separation", 6)
	var prefix_box := UI.vbox(4)
	var suffix_box := UI.vbox(4)
	var prefixes: Array[Dictionary] = []
	var suffixes: Array[Dictionary] = []
	for mod in instance.mods:
		var mod_def: Dictionary = Content.mods.get(str(mod.get("id", "")), {})
		if str(mod_def.get("kind", "")) == "prefix":
			prefixes.append(mod)
		else:
			suffixes.append(mod)
	prefix_box.add_child(UI.small_caps("PREFIXES"))
	suffix_box.add_child(UI.small_caps("SUFFIXES"))
	_add_plaque(prefix_box, prefixes, 0, "P1")
	_add_plaque(prefix_box, prefixes, 1, "P2")
	_add_plaque(suffix_box, suffixes, 0, "S1")
	_add_plaque(suffix_box, suffixes, 1, "S2")
	plaques.add_child(prefix_box)
	plaques.add_child(UI.spacer())
	plaques.add_child(suffix_box)
	detail_box.add_child(plaques)
	var stats := CardResolver.effective_stats(instance, def, Content.mods)
	var power := CardResolver.power(instance, def, Content.mods)
	detail_box.add_child(UI.data_label("ATK %d · DEF %d · POWER %d · QUALITY %d%%" % [stats["atk"], stats["defense"], power, instance.quality], 12, Tokens.INK_SECONDARY))
	var gauge := GaugeBar.new()
	gauge.set_value(instance.quality, 20)
	gauge.color = Tokens.VERDIGRIS
	gauge.label = "Quality"
	detail_box.add_child(gauge)
	if instance.corrupted:
		detail_box.add_child(UI.label("CORRUPTED", 11, Tokens.VERDIGRIS))
	if not instance.fractured_mod.is_empty():
		detail_box.add_child(UI.label("FRACTURED: %s" % instance.fractured_mod, 11, Tokens.GOLD))

func _add_plaque(parent: VBoxContainer, mods: Array[Dictionary], index: int, label: String) -> void:
	var panel := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 6)
	panel.custom_minimum_size = Vector2(170, 42)
	var box := UI.vbox(1)
	panel.add_child(box)
	if index < mods.size():
		var mod: Dictionary = mods[index]
		var line := CardResolver.mod_name(mod, Content.mods)
		var tiers: Array[String] = ["", "I", "II", "III", "IV", "V"]
		var tier: String = tiers[clampi(int(mod.get("tier", 1)), 0, 5)]
		box.add_child(UI.small_caps("%s · %s %s" % [label, line, tier]))
		var effect := CardResolver.mod_text(mod, Content.mods)
		var effect_label := UI.label(effect, 9, Tokens.VERDIGRIS)
		effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(effect_label)
	else:
		box.add_child(UI.small_caps(label + " · EMPTY"))
		box.add_child(UI.label("—", 9, Tokens.INK_MUTED))
	parent.add_child(panel)

func _on_layout_changed(_size: Vector2) -> void:
	var next := Responsive.card_token_for_height(get_viewport_rect().size.y)
	if next == card_token:
		return
	card_token = next
	if card_holder != null:
		card_holder.custom_minimum_size = Vector2(0, Tokens.card_size(card_token).y + 4)
	if instance != null:
		_refresh_card()

func _set_tab(tab: String) -> void:
	selected_tab = tab
	_refresh_tabs()
	_refresh_vault()
	if tab == "history":
		selected_reagent = ""
		_refresh_rule()

func _apply() -> void:
	if selected_reagent.is_empty():
		return
	var reagent := Content.reagent(selected_reagent)
	var rare := str(reagent.get("rarity", "common")) in ["rare"]
	if rare:
		app.confirm("Apply %s?" % str(reagent.get("name", "")), "Rare reagents are permanent. %s" % str(reagent.get("rule", "")), func() -> void:
			_do_apply()
		, "Apply")
	else:
		_do_apply()

func _do_apply() -> void:
	var result: Dictionary = Session.apply_reagent(selected_reagent)
	if bool(result.get("ok", false)):
		app.toast(str(result.get("message", "Applied.")), "good")
		if int(Session.reagents.get(selected_reagent, 0)) <= 0:
			selected_reagent = ""
		_refresh_all()
	else:
		app.toast(str(result.get("message", "That did not work.")), "bad")

func _close() -> void:
	Session.close_bench()
	app.go_library(return_def)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				_close()
			KEY_ENTER, KEY_KP_ENTER:
				_apply()
			KEY_1:
				_set_tab("inks")
			KEY_2:
				_set_tab("solvents")
			KEY_3:
				_set_tab("seals")
			KEY_4:
				_set_tab("foul")
			KEY_5:
				_set_tab("rare")
			KEY_6:
				_set_tab("history")
			KEY_P:
				_select_hotkey("reagent.pale_ink")
			KEY_R:
				_select_hotkey("reagent.prism_ink")
			KEY_D:
				_select_hotkey("reagent.deep_ink")
			KEY_S:
				_select_hotkey("reagent.solvent")
			KEY_V:
				_select_hotkey("reagent.varnish")
			KEY_F:
				_select_hotkey("reagent.fracture")
			KEY_C:
				_select_hotkey("reagent.crucible")
			KEY_X:
				_select_hotkey("reagent.verdigris")
			KEY_E:
				_select_hotkey("reagent.echo")
			KEY_G:
				_select_hotkey("reagent.gold_leaf")

func _select_hotkey(reagent_id: String) -> void:
	var reagent := Content.reagent(reagent_id)
	if reagent.is_empty():
		return
	selected_tab = str(reagent.get("tab", "inks"))
	selected_reagent = reagent_id
	_refresh_all()
