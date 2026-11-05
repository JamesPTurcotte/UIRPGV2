class_name ZoomOverlay
extends Control

## The card menu. Not just a bigger picture: the face is the reading object and
## the rail carries the exact-copy actions and the passport.

var app: Node
var session: Node
var def: CardDef
var instance: CardInstance
var entry: Dictionary = {}
var tab: String = "overview"
var tab_buttons: Dictionary = {}
var detail_box: VBoxContainer
var panel: PanelContainer
var fit_panel: FitPanel

func setup(app_ref: Node) -> void:
	app = app_ref
	session = Session

func open(card_def: CardDef, card_instance: CardInstance, card_entry: Dictionary = {}) -> void:
	def = card_def
	instance = card_instance
	entry = card_entry
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	fit_panel = FitPanel.new()
	add_child(fit_panel)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_PANEL, Tokens.BRASS, 1, 8))
	var viewport := get_viewport_rect().size
	var design := Vector2(1024, 720) if viewport.y >= 820 else Vector2(920, 660)
	fit_panel.setup(panel, design, 16.0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)
	var card_holder := CenterContainer.new()
	card_holder.custom_minimum_size = Tokens.card_size("XL")
	row.add_child(card_holder)
	var card := CardView.new()
	card.set_card(def, instance, "XL")
	card_holder.add_child(card)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 7)
	rail.custom_minimum_size = Vector2(500 if viewport.y >= 820 else 420, 0)
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(rail)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	rail.add_child(head)
	var name_box := UI.vbox(0)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(UI.display(def.name, 28))
	name_box.add_child(UI.label(def.type_line, 12, Tokens.INK_SECONDARY))
	head.add_child(name_box)
	head.add_child(UI.chip(def.rarity.to_upper(), Tokens.rarity_color(def.rarity)))
	head.add_child(UI.chip("POWER %d" % CardResolver.power(instance if instance != null else CardInstance.new(0, def.id, 1), def, Content.mods), Tokens.BRASS_HI))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	rail.add_child(tabs)
	for pair in [["Overview", "overview"], ["Mods", "mods"], ["History", "history"], ["Passport", "passport"]]:
		var key: String = pair[1]
		var button := UI.button(pair[0], _set_tab.bind(key), Tokens.BRASS_LO)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 28)
		button.add_theme_font_size_override("font_size", 11)
		tab_buttons[key] = button
		tabs.add_child(button)
	rail.add_child(UI.hsep())
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(scroll)
	detail_box = UI.vbox(6)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	rail.add_child(actions)
	var craft_text := "Craft a copy" if str(entry.get("kind", "")) == "stack" or instance == null else "Open on Bench"
	var craft := UI.button(craft_text, _craft, Tokens.BRASS)
	craft.disabled = instance == null and str(entry.get("kind", "")) != "stack"
	actions.add_child(craft)
	actions.add_child(UI.button("Add to Deck", _add_to_deck, Tokens.BRASS_LO))
	actions.add_child(UI.button("Print", _print, Tokens.BRASS_LO))
	var dissolve_button := UI.button("Dissolve", _dissolve, Tokens.WAX)
	dissolve_button.disabled = instance == null and entry.is_empty()
	actions.add_child(dissolve_button)
	var more := MenuButton.new()
	more.text = "More"
	more.get_popup().add_item("Lock / Unlock", 0)
	more.get_popup().add_item("Favorite", 1)
	more.get_popup().add_item("Name", 2)
	more.get_popup().id_pressed.connect(_more_action)
	actions.add_child(more)
	actions.add_child(UI.spacer())
	actions.add_child(UI.button("Close", close, Tokens.BRASS_LO))
	_refresh_tabs()
	_refresh_detail()
	fit_panel.refresh()

func _set_tab(next_tab: String) -> void:
	tab = next_tab
	_refresh_tabs()
	_refresh_detail()
	fit_panel.refresh()

func _refresh_tabs() -> void:
	for key in tab_buttons.keys():
		var button: Button = tab_buttons[key]
		button.button_pressed = str(key) == tab

func _refresh_detail() -> void:
	for child in detail_box.get_children():
		detail_box.remove_child(child)
		child.queue_free()
	match tab:
		"mods":
			_refresh_mods()
		"history":
			_refresh_history()
		"passport":
			_refresh_passport()
		_:
			_refresh_overview()
	if fit_panel != null:
		fit_panel.refresh()

func _refresh_overview() -> void:
	var facts := GridContainer.new()
	facts.columns = 2
	facts.add_theme_constant_override("h_separation", 14)
	facts.add_theme_constant_override("v_separation", 2)
	for pair in [
		["Type", def.type.capitalize()],
		["Attribute", def.attribute.capitalize()],
		["Lineage", def.lineage.capitalize() if not def.lineage.is_empty() else "—"],
		["Offer", str(def.offer)],
		["Role", def.role.capitalize()],
		["Rarity", def.rarity.capitalize()],
	]:
		facts.add_child(UI.label(pair[0], 11, Tokens.INK_MUTED))
		facts.add_child(UI.label(pair[1], 11, Tokens.INK_SECONDARY))
	detail_box.add_child(facts)
	var rules := UI.label(def.text, 15, Tokens.INK_PRIMARY)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(470 if get_viewport_rect().size.y >= 820 else 400, 0)
	detail_box.add_child(rules)
	if not def.keywords.is_empty():
		var keyword_row := HBoxContainer.new()
		keyword_row.add_theme_constant_override("separation", 4)
		for keyword in def.keywords:
			keyword_row.add_child(UI.chip(str(keyword).to_upper(), Tokens.attribute_color(def.attribute)))
		detail_box.add_child(keyword_row)
	if instance != null:
		var stats := CardResolver.effective_stats(instance, def, Content.mods)
		detail_box.add_child(UI.data_label("ATK %d · DEF %d · OFFER %d" % [stats["atk"], stats["defense"], stats["offer"]], 12, Tokens.INK_SECONDARY))
		detail_box.add_child(UI.data_label("FOUND F%d · %s · QUALITY %d%%" % [instance.provenance, instance.origin.to_upper(), instance.quality], 11, Tokens.INK_SECONDARY))
	else:
		detail_box.add_child(UI.label("Plain stack.", 12, Tokens.INK_MUTED))

func _refresh_mods() -> void:
	if instance == null or instance.mods.is_empty():
		detail_box.add_child(UI.label("No mods.", 13, Tokens.INK_MUTED))
		return
	for line in CardResolver.mod_lines(instance, Content.mods):
		detail_box.add_child(UI.label("· " + line, 13, Tokens.VERDIGRIS))
	detail_box.add_child(UI.data_label("Quality %d%% · Mods %d / 4" % [instance.quality, instance.mods.size()], 11, Tokens.INK_SECONDARY))
	if not instance.fractured_mod.is_empty():
		detail_box.add_child(UI.label("FRACTURED: %s" % instance.fractured_mod, 11, Tokens.GOLD))
	if instance.corrupted:
		detail_box.add_child(UI.label("CORRUPTED: further crafting is locked.", 11, Tokens.VERDIGRIS))

func _refresh_history() -> void:
	if instance == null or instance.history.is_empty():
		detail_box.add_child(UI.label("No craft history.", 12, Tokens.INK_MUTED))
		return
	for history_entry in instance.history:
		detail_box.add_child(UI.label("· " + str(history_entry.get("detail", "")), 11, Tokens.INK_SECONDARY))

func _refresh_passport() -> void:
	if instance == null:
		detail_box.add_child(UI.label("Plain stack.", 12, Tokens.INK_MUTED))
		return
	detail_box.add_child(UI.data_label("COPY #%d" % instance.instance_id, 12, Tokens.BRASS_HI))
	detail_box.add_child(UI.label("Found: F%d" % instance.provenance, 11, Tokens.INK_SECONDARY))
	detail_box.add_child(UI.label("Origin: %s" % instance.origin, 11, Tokens.INK_SECONDARY))
	detail_box.add_child(UI.label("Quality: %d%%" % instance.quality, 11, Tokens.INK_SECONDARY))
	var deck_names: Array[String] = []
	for deck in session.decks.values():
		if deck.main.has(instance.instance_id) or deck.side.has(instance.instance_id):
			deck_names.append(deck.name)
	detail_box.add_child(UI.label("Decks: %s" % (", ".join(deck_names) if not deck_names.is_empty() else "—"), 11, Tokens.INK_SECONDARY))
	var honours := "—"
	if not instance.honours.is_empty():
		var labels: Array[String] = []
		for honour in instance.honours:
			labels.append(str(honour.get("id", "")).replace("_", " ").capitalize())
		honours = ", ".join(labels)
	detail_box.add_child(UI.label("Honours: %s" % honours, 11, Tokens.INK_SECONDARY))
	if not instance.custom_name.is_empty():
		detail_box.add_child(UI.label("Name: \"%s\"" % instance.custom_name, 11, Tokens.SELECTION))

func _craft() -> void:
	var result: Dictionary
	if str(entry.get("kind", "")) == "stack":
		result = session.pull_entry_to_bench(entry)
	elif instance != null:
		result = session.pull_to_bench({"kind": "instance", "instance_id": instance.instance_id})
	else:
		result = {"ok": false, "reason": "No copy to pull."}
	if bool(result.get("ok", false)):
		close()
		app.go_bench(result.get("instance"), def.id)
	else:
		app.toast(str(result.get("reason", "Cannot craft.")), "bad")

func _add_to_deck() -> void:
	var result: Dictionary
	if str(entry.get("kind", "")) == "instance" and instance != null and not instance.deck_bound:
		result = session.add_instance_to_deck(instance.instance_id, "main")
	else:
		result = session.add_def_to_deck(def.id, "main")
	app.toast("Added to deck." if bool(result.get("ok", false)) else str(result.get("reason", "Could not add.")), "good" if bool(result.get("ok", false)) else "bad")

func _print() -> void:
	if def.rarity == "legendary":
		app.confirm("Print a Legendary?", "This presses a Plain copy of %s for 2000 Marks." % def.name, _do_print, "Print")
	else:
		_do_print()

func _do_print() -> void:
	var result: Dictionary = session.print_card(def.id)
	app.toast("Printed for %d Marks." % int(result.get("cost", 0)) if bool(result.get("ok", false)) else str(result.get("reason", "Could not print.")), "good" if bool(result.get("ok", false)) else "bad")

func _dissolve() -> void:
	if def.rarity in ["rare", "legendary"]:
		app.confirm("Dissolve this copy?", "This is a %s. The Marks are permanent; the copy is not." % def.rarity.capitalize(), _do_dissolve, "Dissolve")
	else:
		_do_dissolve()

func _do_dissolve() -> void:
	var result: Dictionary
	if not entry.is_empty():
		result = session.dissolve_entry(entry)
	elif instance != null:
		result = session.dissolve_instance(instance.instance_id)
	else:
		result = {"ok": false, "reason": "No copy to dissolve."}
	app.toast("Dissolved for %d Marks." % int(result.get("marks", 0)) if bool(result.get("ok", false)) else str(result.get("reason", "Could not dissolve.")), "good" if bool(result.get("ok", false)) else "bad")

func _more_action(id: int) -> void:
	if instance == null:
		app.toast("Pull a copy first.", "bad")
		return
	if id == 0:
		session.toggle_lock(instance.instance_id)
		app.toast("Lock toggled.", "info")
	elif id == 1:
		session.toggle_favorite(instance.instance_id)
		app.toast("Favorite toggled.", "info")
	elif id == 2:
		_prompt_name()
	_refresh_detail()

func _prompt_name() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 300
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var name_panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS, 14)
	name_panel.custom_minimum_size = Vector2(390, 150)
	center.add_child(name_panel)
	var box := UI.vbox(7)
	name_panel.add_child(box)
	box.add_child(UI.display("Name this copy", 18))
	var edit := LineEdit.new()
	edit.text = instance.custom_name
	edit.max_length = 24
	box.add_child(edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	row.add_child(UI.button("Cancel", func() -> void: root.queue_free(), Tokens.BRASS_LO))
	row.add_child(UI.button("Inscribe", func() -> void:
		var result: Dictionary = session.rename_instance(instance.instance_id, edit.text)
		if bool(result.get("ok", false)):
			root.queue_free()
			_refresh_detail()
		else:
			app.toast(str(result.get("reason", "Could not name.")), "bad")
	, Tokens.BRASS))
	edit.grab_focus()
	edit.select_all()

func close() -> void:
	if app != null:
		app.close_zoom()
	else:
		queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
