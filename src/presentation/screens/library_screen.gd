class_name LibraryScreen
extends UIScreen

## The Library is the game: shelves, a reading desk, the Gate, the Bench, and
## the folio satchel are one continuous room. The second click on a selected
## card opens the card menu; the first click only reads it.

var entries_all: Array[Dictionary] = []
var entries_filtered: Array[Dictionary] = []
var view_entries: Dictionary = {}
var views: Array[CardView] = []
var selected_entry: Dictionary = {}
var selected_key: String = ""
var selected_def_id: String = ""
var desk_tab: String = "overview"
var query: Dictionary = CardQuery.empty_query()

var filter_bar: FilterBar
var cards_box: VBoxContainer
var desk_top: VBoxContainer
var desk_detail: VBoxContainer
var desk_actions: GridContainer
var shelf_caption: Label
var cards_count_label: Label
var defs_label: Label
var crafted_label: Label
var folios_label: Label
var marks_label: Label
var index_buttons: Array[Dictionary] = []
var desk_tab_buttons: Dictionary = {}
var context_entry: Dictionary = {}
var context_source: Control
var hint_label: Label
var shelf_scroll: ScrollContainer
var desk_scroll: ScrollContainer
var shelf_columns: int = 5

func build() -> void:
	shelf_columns = Responsive.library_shelf_columns(get_viewport_rect().size.x)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root := UI.vbox(8)
	margin.add_child(root)
	root.add_child(_build_top_bar())
	filter_bar = FilterBar.new()
	filter_bar.persist_key = "library_query"
	filter_bar.query_changed.connect(_on_query_changed)
	root.add_child(filter_bar)
	query = filter_bar.get_query()
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	content.add_child(_build_index())
	content.add_child(_build_shelves())
	content.add_child(_build_desk())
	root.add_child(_build_bottom_bar())
	layout_changed.connect(_on_layout_changed)
	_refresh_entries()
	var desired := str(payload.get("selected_def", ""))
	if not desired.is_empty():
		_select_def(desired)

func _build_top_bar() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title_box := UI.vbox(0)
	title_box.add_child(UI.display("THE LIBRARY", 28))
	title_box.add_child(UI.small_caps("READ · BUILD · BIND"))
	row.add_child(title_box)
	row.add_child(UI.spacer())
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 5)
	cards_count_label = _chip_label(chips, "0 CARDS")
	defs_label = _chip_label(chips, "0 DEFS")
	crafted_label = _chip_label(chips, "0 CRAFTED")
	folios_label = _chip_label(chips, "0 FOLIOS")
	marks_label = _chip_label(chips, "0 MARKS")
	row.add_child(chips)
	return panel

func _chip_label(parent: HBoxContainer, text: String) -> Label:
	var chip := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 6)
	var label := UI.data_label(text, 10, Tokens.BRASS_HI)
	chip.add_child(label)
	parent.add_child(chip)
	return label

func _build_index() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.custom_minimum_size = Vector2(168, 0)
	var box := UI.vbox(3)
	panel.add_child(box)
	box.add_child(UI.small_caps("INDEX"))
	box.add_child(UI.hsep())
	for pair in [["All cards", "all"], ["Monsters", "monster"], ["Spells", "spell"], ["Traps", "trap"]]:
		_add_index_button(box, pair[0], pair[1])
	box.add_child(UI.hsep())
	box.add_child(UI.small_caps("ATTRIBUTE"))
	for pair in [["Ember", "ember"], ["Tide", "tide"], ["Verdant", "verdant"], ["Umbra", "umbra"], ["Neutral", "neutral"]]:
		_add_index_button(box, pair[0], pair[1])
	box.add_child(UI.spacer())
	var satchel := UI.vbox(3)
	satchel.add_child(UI.small_caps("SATCHEL"))
	satchel.add_child(UI.button("Open folios", func() -> void: app.go_folio(), Tokens.VERDIGRIS))
	satchel.add_child(UI.button("Deck workshop", func() -> void: app.go_deck(), Tokens.BRASS_LO))
	box.add_child(satchel)
	return panel

func _add_index_button(parent: VBoxContainer, text: String, key: String) -> void:
	var button := UI.button(text, _set_index_filter.bind(key), Tokens.BRASS_LO)
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 27)
	button.add_theme_font_size_override("font_size", 12)
	index_buttons.append({"button": button, "key": key})
	parent.add_child(button)

func _build_shelves() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(5)
	panel.add_child(box)
	var header := HBoxContainer.new()
	header.add_child(UI.small_caps("SHELVES"))
	header.add_child(UI.spacer())
	shelf_caption = UI.data_label("", 10, Tokens.INK_MUTED)
	header.add_child(shelf_caption)
	box.add_child(header)
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shelf_scroll = scroll
	box.add_child(scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 14)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(gutter)
	cards_box = UI.vbox(10)
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(cards_box)
	return panel

func _build_desk() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(6)
	panel.add_child(box)
	box.add_child(UI.small_caps("READING DESK"))
	box.add_child(UI.hsep())
	desk_top = UI.vbox(5)
	box.add_child(desk_top)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	box.add_child(tabs)
	for pair in [["Overview", "overview"], ["Mods", "mods"], ["History", "history"], ["Passport", "passport"]]:
		var tab_key: String = pair[1]
		var button := UI.button(pair[0], _set_desk_tab.bind(tab_key), Tokens.BRASS_LO)
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 10)
		button.custom_minimum_size = Vector2(0, 26)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desk_tab_buttons[pair[1]] = button
		tabs.add_child(button)
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk_scroll = scroll
	box.add_child(scroll)
	desk_detail = UI.vbox(5)
	desk_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(desk_detail)
	desk_actions = GridContainer.new()
	desk_actions.columns = 2
	desk_actions.add_theme_constant_override("h_separation", 4)
	desk_actions.add_theme_constant_override("v_separation", 4)
	box.add_child(desk_actions)
	_refresh_desk_tabs()
	return panel

func _build_bottom_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	hint_label = UI.label("", 11, Tokens.INK_MUTED, Tokens.font_data_regular())
	row.add_child(hint_label)
	row.add_child(UI.spacer())
	return row

func _set_index_filter(value: String) -> void:
	var next_query := CardQuery.empty_query()
	next_query["sort"] = str(query.get("sort", "name"))
	next_query["desc"] = bool(query.get("desc", false))
	if value in ["monster", "spell", "trap"]:
		next_query["type"] = [value]
	elif value in ["ember", "tide", "verdant", "umbra", "neutral"]:
		next_query["attribute"] = [value]
	filter_bar.set_query(next_query)
	query = next_query
	_refresh_filter()

func _on_layout_changed(_size: Vector2) -> void:
	var next := Responsive.library_shelf_columns(get_viewport_rect().size.x)
	if next == shelf_columns:
		return
	shelf_columns = next
	var scroll := shelf_scroll.scroll_vertical if shelf_scroll != null else 0
	_rebuild_shelves()
	if shelf_scroll != null:
		_restore_shelf_scroll.call_deferred(scroll)

func _restore_shelf_scroll(value: int) -> void:
	if shelf_scroll != null and is_instance_valid(shelf_scroll):
		shelf_scroll.scroll_vertical = value

func _refresh_entries() -> void:
	entries_all = Session.collection_entries()
	if filter_bar != null:
		filter_bar.set_entries(entries_all)
	_refresh_filter()

func _on_query_changed(next_query: Dictionary) -> void:
	query = next_query
	_refresh_filter()

func _refresh_filter() -> void:
	entries_filtered = CardQuery.filter(entries_all, query)
	_rebuild_shelves()
	_refresh_chips()
	_refresh_index_styles()
	if not selected_key.is_empty():
		_select_key(selected_key, false)
	if selected_entry.is_empty() and not entries_filtered.is_empty():
		_select_entry(entries_filtered[0])
	elif entries_filtered.is_empty() and selected_entry.is_empty():
		_refresh_desk()

func _refresh_chips() -> void:
	cards_count_label.text = "%d CARDS" % Session.total_cards()
	defs_label.text = "%d DEFS" % Session.total_definitions()
	crafted_label.text = "%d CRAFTED" % Session.crafted_count()
	folios_label.text = "%d FOLIOS" % Session.unopened_packs().size()
	marks_label.text = "%d MARKS" % int(Session.currency.get("marks", 0))

func _refresh_index_styles() -> void:
	for item in index_buttons:
		var button: Button = item["button"]
		var key := str(item["key"])
		var active := false
		if key == "all":
			active = query["type"].is_empty() and query["attribute"].is_empty()
		elif key in ["monster", "spell", "trap"]:
			active = query["type"].has(key) and query["type"].size() == 1 and query["attribute"].is_empty()
		else:
			active = query["attribute"].has(key) and query["attribute"].size() == 1 and query["type"].is_empty()
		button.button_pressed = active

func _rebuild_shelves() -> void:
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	views.clear()
	view_entries.clear()
	var per_shelf := shelf_columns
	var card_h := Tokens.card_size("S").y
	var shelf_index := 0
	var row: HBoxContainer
	var shelf_box: VBoxContainer
	for i in range(entries_filtered.size()):
		if i % per_shelf == 0:
			shelf_index += 1
			shelf_box = UI.vbox(2)
			shelf_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var label_row := HBoxContainer.new()
			label_row.add_child(UI.small_caps("SHELF %02d" % shelf_index))
			label_row.add_child(UI.spacer())
			label_row.add_child(UI.data_label("%d" % mini(per_shelf, entries_filtered.size() - i), 9, Tokens.INK_MUTED))
			shelf_box.add_child(label_row)
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.custom_minimum_size = Vector2(0, card_h + 14)
			shelf_box.add_child(row)
			shelf_box.add_child(UI.hsep(Tokens.BRASS_LO * Color(1, 1, 1, 0.55)))
			cards_box.add_child(shelf_box)
		var entry: Dictionary = entries_filtered[i]
		var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
		var instance: CardInstance = entry.get("best_instance")
		var view := CardView.new()
		view.set_card(def, instance, "S")
		view.count = int(entry.get("count", 1)) if str(entry.get("kind", "")) == "stack" else 0
		view.decked = bool(entry.get("decked", false))
		view.set_flag("decked", view.decked)
		view.set_flag("action_seal", CardQuery.selection_key(entry) == selected_key)
		view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		view.clicked.connect(_on_card_clicked)
		view.double_clicked.connect(_on_card_double_clicked)
		view.right_clicked.connect(_on_card_right_clicked)
		row.add_child(view)
		views.append(view)
		view_entries[view] = entry
	if entries_filtered.is_empty():
		var empty := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 20)
		var box := UI.vbox(6)
		empty.add_child(box)
		box.add_child(UI.label("No cards match.", 14, Tokens.INK_SECONDARY))
		box.add_child(UI.button("CLEAR FILTERS", func() -> void: filter_bar._clear_filters(), Tokens.BRASS))
		cards_box.add_child(empty)
	shelf_caption.text = "%d entr%s · %d shelf%s" % [
		entries_filtered.size(),
		"y" if entries_filtered.size() == 1 else "ies",
		maxi(1, int(ceil(float(entries_filtered.size()) / float(per_shelf)))),
		"" if entries_filtered.size() <= per_shelf else "ves",
	]
	_apply_selection_highlights()

func _refresh_desk_tabs() -> void:
	for key in desk_tab_buttons.keys():
		var button: Button = desk_tab_buttons[key]
		button.button_pressed = str(key) == desk_tab

func _set_desk_tab(tab: String) -> void:
	desk_tab = tab
	_refresh_desk_tabs()
	_refresh_desk()

func _on_card_clicked(view: CardView) -> void:
	var entry: Dictionary = view_entries.get(view, {})
	if entry.is_empty():
		return
	var key := CardQuery.selection_key(entry)
	if key == selected_key:
		_open_card_menu(entry)
	else:
		_select_entry(entry)

func _on_card_double_clicked(view: CardView) -> void:
	var entry: Dictionary = view_entries.get(view, {})
	if not entry.is_empty():
		_open_card_menu(entry)

func _on_card_right_clicked(view: CardView, card_rect: Rect2) -> void:
	var entry: Dictionary = view_entries.get(view, {})
	if entry.is_empty():
		return
	context_entry = entry
	context_source = view
	var instance: CardInstance = entry.get("best_instance")
	var items: Array[Dictionary] = [
		{"id": 0, "label": "Open", "glyph": "↵"},
		{"id": 1, "label": "Craft on the Bench"},
		{"id": 2, "label": "Add to Deck", "glyph": "E"},
		{"id": 3, "label": "Add to Sideboard", "glyph": "S"},
		{"id": 4, "label": "Print a copy", "glyph": "P"},
		{"id": 5, "label": "Dissolve", "glyph": "X", "separator_before": true},
		{"id": 6, "label": "Lock / Unlock", "glyph": "L", "enabled": instance != null, "reason": "Pull a copy to lock it."},
		{"id": 7, "label": "Favorite", "glyph": "*", "enabled": instance != null, "reason": "Pull a copy to favorite it."},
		{"id": 8, "label": "Name", "glyph": "N", "enabled": instance != null, "reason": "Pull a copy to name it."},
	]
	app.open_context_menu(items, card_rect, _on_context_action, view)

func _on_context_action(id: int) -> void:
	match id:
		0:
			_open_card_menu(context_entry)
		1:
			_craft_entry(context_entry)
		2:
			_run_context_refresh(func() -> void: _add_entry_to_deck(context_entry))
		3:
			_run_context_refresh(func() -> void: _add_entry_to_deck(context_entry, "side"))
		4:
			_run_context_refresh(func() -> void: _print_entry(context_entry))
		5:
			_run_context_refresh(func() -> void: _dissolve_entry(context_entry))
		6:
			_run_context_refresh(func() -> void: _toggle_lock(context_entry))
		7:
			_run_context_refresh(func() -> void: _toggle_favorite(context_entry))
		8:
			_rename_entry(context_entry)

func _snapshot_view() -> Dictionary:
	var index := -1
	for i in range(entries_filtered.size()):
		if CardQuery.selection_key(entries_filtered[i]) == selected_key:
			index = i
			break
	return {
		"key": selected_key,
		"index": index,
		"shelf": shelf_scroll.scroll_vertical if shelf_scroll != null else 0,
		"desk": desk_scroll.scroll_vertical if desk_scroll != null else 0,
		"query": query.duplicate(true),
	}

func _run_context_refresh(action: Callable) -> void:
	var snapshot := _snapshot_view()
	action.call()
	_restore_after_refresh(snapshot)

func _restore_after_refresh(snapshot: Dictionary) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if shelf_scroll != null:
		shelf_scroll.scroll_vertical = int(snapshot.get("shelf", 0))
	if desk_scroll != null:
		desk_scroll.scroll_vertical = int(snapshot.get("desk", 0))
	var target: Dictionary = {}
	for entry in entries_filtered:
		if CardQuery.selection_key(entry) == str(snapshot.get("key", "")):
			target = entry
			break
	if target.is_empty() and not entries_filtered.is_empty():
		var index := clampi(int(snapshot.get("index", 0)), 0, entries_filtered.size() - 1)
		target = entries_filtered[index]
	if target.is_empty():
		selected_entry = {}
		selected_key = ""
		_apply_selection_highlights()
		_refresh_desk()
	else:
		_select_entry(target)

func _open_card_menu(entry: Dictionary) -> void:
	var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
	app.show_zoom(def, entry.get("best_instance"), entry)

func _select_def(def_id: String, scroll: bool = true) -> void:
	selected_def_id = def_id
	for entry in entries_filtered:
		if str(entry.get("def_id", "")) == def_id:
			_select_entry(entry)
			return

func _select_key(key: String, refresh: bool = true) -> void:
	for entry in entries_filtered:
		if CardQuery.selection_key(entry) == key:
			_select_entry(entry)
			return
	if refresh:
		_refresh_desk()

func _select_entry(entry: Dictionary) -> void:
	selected_entry = entry
	selected_def_id = str(entry.get("def_id", ""))
	selected_key = CardQuery.selection_key(entry)
	_apply_selection_highlights()
	_refresh_desk()

func _apply_selection_highlights() -> void:
	for view in views:
		var entry: Dictionary = view_entries.get(view, {})
		var is_selected := not selected_entry.is_empty() and CardQuery.selection_key(entry) == selected_key
		view.set_flag("selected", is_selected)
		view.set_flag("action_seal", is_selected)

func _refresh_desk() -> void:
	for child in desk_top.get_children():
		desk_top.remove_child(child)
		child.queue_free()
	for child in desk_detail.get_children():
		desk_detail.remove_child(child)
		child.queue_free()
	for child in desk_actions.get_children():
		desk_actions.remove_child(child)
		child.queue_free()
	if selected_entry.is_empty():
		desk_top.add_child(UI.label("No card selected.", 13, Tokens.INK_MUTED))
		hint_label.text = ""
		return
	var def: CardDef = Content.cards.get(str(selected_entry.get("def_id", "")))
	if def == null:
		return
	var instance: CardInstance = selected_entry.get("best_instance")
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Tokens.card_size("M")
	desk_top.add_child(holder)
	var card := CardView.new()
	card.set_card(def, instance, "M")
	card.clicked.connect(func(_view: CardView) -> void: _open_card_menu(selected_entry))
	card.double_clicked.connect(func(_view: CardView) -> void: _open_card_menu(selected_entry))
	holder.add_child(card)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 4)
	facts.add_child(UI.chip("POWER %d" % Session.entry_power(selected_entry), Tokens.BRASS_HI))
	facts.add_child(UI.chip("×%d" % int(selected_entry.get("count", 1)), Tokens.INK_SECONDARY))
	if instance != null:
		facts.add_child(UI.chip("F%d" % instance.provenance, Tokens.VERDIGRIS))
		if not instance.honours.is_empty():
			facts.add_child(UI.chip("HONOURS %d" % instance.honours.size(), Tokens.GOLD))
	desk_top.add_child(facts)
	desk_top.add_child(UI.hsep())
	match desk_tab:
		"mods":
			_refresh_desk_mods(instance)
		"history":
			_refresh_desk_history(instance)
		"passport":
			_refresh_desk_passport(def, instance)
		_:
			_refresh_desk_overview(def, instance)
	var visible := false
	for entry in entries_filtered:
		if CardQuery.selection_key(entry) == selected_key:
			visible = true
			break
	if not visible:
		var hidden := UI.label("Hidden by filters.", 11, Tokens.GOLD)
		desk_detail.add_child(hidden)
	_build_desk_actions(def, instance)
	hint_label.text = "Enter open · C craft · E deck · S sideboard"

func _refresh_desk_overview(def: CardDef, instance: CardInstance) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	for pair in [
		["Type", def.type.capitalize()],
		["Attribute", def.attribute.capitalize()],
		["Lineage", def.lineage.capitalize() if not def.lineage.is_empty() else "—"],
		["Offer", str(def.offer)],
		["Role", def.role.capitalize()],
		["Rarity", def.rarity.capitalize()],
	]:
		grid.add_child(UI.label(pair[0], 11, Tokens.INK_MUTED))
		grid.add_child(UI.label(pair[1], 11, Tokens.INK_SECONDARY))
	desk_detail.add_child(grid)
	var rules := UI.label(def.text, 12, Tokens.INK_PRIMARY)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(320, 0)
	desk_detail.add_child(rules)
	if not def.keywords.is_empty():
		var keyword_row := HBoxContainer.new()
		keyword_row.add_theme_constant_override("separation", 3)
		for keyword in def.keywords:
			keyword_row.add_child(UI.chip(str(keyword).to_upper(), Tokens.attribute_color(def.attribute)))
		desk_detail.add_child(keyword_row)
	if instance != null:
		var stats := CardResolver.effective_stats(instance, def, Content.mods)
		desk_detail.add_child(UI.data_label("ATK %d · DEF %d · OFFER %d" % [stats["atk"], stats["defense"], stats["offer"]], 11, Tokens.INK_SECONDARY))

func _refresh_desk_mods(instance: CardInstance) -> void:
	if instance == null or instance.mods.is_empty():
		desk_detail.add_child(UI.label("No mods.", 12, Tokens.INK_MUTED))
		return
	for line in CardResolver.mod_lines(instance, Content.mods):
		desk_detail.add_child(UI.label("· " + line, 12, Tokens.VERDIGRIS))
	desk_detail.add_child(UI.data_label("Quality %d%% · Mods %d / 4" % [instance.quality, instance.mods.size()], 11, Tokens.INK_SECONDARY))
	if not instance.fractured_mod.is_empty():
		desk_detail.add_child(UI.label("FRACTURED: %s" % instance.fractured_mod, 11, Tokens.GOLD))
	if instance.corrupted:
		desk_detail.add_child(UI.label("CORRUPTED: craft locked.", 11, Tokens.VERDIGRIS))

func _refresh_desk_history(instance: CardInstance) -> void:
	if instance == null or instance.history.is_empty():
		desk_detail.add_child(UI.label("No craft history.", 12, Tokens.INK_MUTED))
		return
	for entry in instance.history:
		desk_detail.add_child(UI.label("· " + str(entry.get("detail", "")), 11, Tokens.INK_SECONDARY))

func _refresh_desk_passport(def: CardDef, instance: CardInstance) -> void:
	if instance == null:
		desk_detail.add_child(UI.label("Plain stack.", 12, Tokens.INK_MUTED))
		return
	desk_detail.add_child(UI.data_label("COPY #%d" % instance.instance_id, 12, Tokens.BRASS_HI))
	desk_detail.add_child(UI.label("Found: F%d" % instance.provenance, 11, Tokens.INK_SECONDARY))
	desk_detail.add_child(UI.label("Origin: %s" % instance.origin, 11, Tokens.INK_SECONDARY))
	desk_detail.add_child(UI.label("Quality: %d%%" % instance.quality, 11, Tokens.INK_SECONDARY))
	var deck_names: Array[String] = []
	for deck in Session.decks.values():
		if deck.main.has(instance.instance_id) or deck.side.has(instance.instance_id):
			deck_names.append(deck.name)
	desk_detail.add_child(UI.label("Decks: %s" % (", ".join(deck_names) if not deck_names.is_empty() else "—"), 11, Tokens.INK_SECONDARY))
	var honours := "—"
	if not instance.honours.is_empty():
		var labels: Array[String] = []
		for honour in instance.honours:
			labels.append(str(honour.get("id", "")).replace("_", " ").capitalize())
		honours = ", ".join(labels)
	desk_detail.add_child(UI.label("Honours: %s" % honours, 11, Tokens.INK_SECONDARY))
	if not instance.custom_name.is_empty():
		desk_detail.add_child(UI.label("Name: \"%s\"" % instance.custom_name, 11, Tokens.SELECTION))

func _build_desk_actions(def: CardDef, instance: CardInstance) -> void:
	desk_actions.add_child(UI.button("Open  [Enter]", func() -> void: _open_card_menu(selected_entry), Tokens.BRASS))
	desk_actions.add_child(UI.button("Craft  [C]", func() -> void: _craft_entry(selected_entry), Tokens.BRASS_LO))
	desk_actions.add_child(UI.button("Deck  [E]", func() -> void: _add_entry_to_deck(selected_entry), Tokens.BRASS_LO))
	desk_actions.add_child(UI.button("Side  [S]", func() -> void: _add_entry_to_deck(selected_entry, "side"), Tokens.BRASS_LO))
	desk_actions.add_child(UI.button("Print  [P]", func() -> void: _print_entry(selected_entry), Tokens.BRASS_LO))
	desk_actions.add_child(UI.button("Dissolve  [X]", func() -> void: _dissolve_entry(selected_entry), Tokens.WAX))
	var has_instance := instance != null
	var lock := UI.button("Lock  [L]", func() -> void: _toggle_lock(selected_entry), Tokens.BRASS_LO)
	lock.disabled = not has_instance
	desk_actions.add_child(lock)
	var favorite := UI.button("Favorite  [*]", func() -> void: _toggle_favorite(selected_entry), Tokens.BRASS_LO)
	favorite.disabled = not has_instance
	desk_actions.add_child(favorite)
	var name := UI.button("Name  [N]", func() -> void: _rename_entry(selected_entry), Tokens.BRASS_LO)
	name.disabled = not has_instance
	desk_actions.add_child(name)

func _craft_entry(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var result: Dictionary = Session.pull_entry_to_bench(entry)
	if not bool(result.get("ok", false)):
		app.toast(str(result.get("reason", "Cannot pull that copy.")), "bad")
		return
	app.go_bench(result.get("instance"), str(entry.get("def_id", "")))

func _add_entry_to_deck(entry: Dictionary, zone: String = "main") -> void:
	if entry.is_empty():
		return
	var instance: CardInstance = entry.get("best_instance")
	var result: Dictionary
	if str(entry.get("kind", "")) == "instance" and instance != null and not instance.deck_bound:
		result = Session.add_instance_to_deck(instance.instance_id, zone)
	else:
		result = Session.add_def_to_deck(str(entry.get("def_id", "")), zone)
	if bool(result.get("ok", false)):
		app.toast("Added to %s." % ("deck" if zone == "main" else "sideboard"), "good")
		_refresh_entries()
		_refresh_desk()
	else:
		app.toast(str(result.get("reason", "Could not add.")), "bad")

func _print_entry(entry: Dictionary) -> void:
	var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
	if def != null and def.rarity == "legendary":
		app.confirm("Print a Legendary?", "This presses a Plain copy of %s for 2000 Marks." % def.name, func() -> void:
			_do_print(entry)
		, "Print")
	else:
		_do_print(entry)

func _do_print(entry: Dictionary) -> void:
	var snapshot := _snapshot_view()
	var result: Dictionary = Session.print_card(str(entry.get("def_id", "")))
	if bool(result.get("ok", false)):
		app.toast("Printed for %d Marks." % int(result.get("cost", 0)), "good")
		_refresh_entries()
		_restore_after_refresh(snapshot)
	else:
		app.toast(str(result.get("reason", "Could not print.")), "bad")

func _dissolve_entry(entry: Dictionary) -> void:
	var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
	var rare := def != null and def.rarity in ["rare", "legendary"]
	if rare:
		app.confirm("Dissolve this copy?", "This is a %s. The Marks are permanent; the copy is not." % def.rarity.capitalize(), func() -> void:
			_do_dissolve(entry)
		, "Dissolve")
	else:
		_do_dissolve(entry)

func _do_dissolve(entry: Dictionary) -> void:
	var snapshot := _snapshot_view()
	var result: Dictionary = Session.dissolve_entry(entry)
	if bool(result.get("ok", false)):
		app.toast("Dissolved for %d Marks." % int(result.get("marks", 0)), "good")
		_refresh_entries()
		_refresh_desk()
		_restore_after_refresh(snapshot)
	else:
		app.toast(str(result.get("reason", "Could not dissolve.")), "bad")

func _toggle_lock(entry: Dictionary) -> void:
	var instance: CardInstance = entry.get("best_instance")
	if instance == null:
		app.toast("Pull a copy to lock it.", "bad")
		return
	var snapshot := _snapshot_view()
	Session.toggle_lock(instance.instance_id)
	_refresh_entries()
	_refresh_desk()
	_restore_after_refresh(snapshot)

func _toggle_favorite(entry: Dictionary) -> void:
	var instance: CardInstance = entry.get("best_instance")
	if instance == null:
		app.toast("Pull a copy to favorite it.", "bad")
		return
	var snapshot := _snapshot_view()
	Session.toggle_favorite(instance.instance_id)
	_refresh_entries()
	_refresh_desk()
	_restore_after_refresh(snapshot)

func _rename_entry(entry: Dictionary) -> void:
	var instance: CardInstance = entry.get("best_instance")
	if instance == null:
		app.toast("Pull a copy to name it.", "bad")
		return
	_prompt_name(instance)

func _prompt_name(instance: CardInstance) -> void:
	var snapshot := _snapshot_view()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.z_index = 300
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS, 16)
	panel.custom_minimum_size = Vector2(420, 170)
	center.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.display("Name this copy", 20))
	var edit := LineEdit.new()
	edit.text = instance.custom_name
	edit.max_length = 24
	edit.placeholder_text = "24 characters"
	box.add_child(edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(row)
	row.add_child(UI.button("Cancel", func() -> void: root.queue_free(), Tokens.BRASS_LO))
	row.add_child(UI.button("Inscribe", func() -> void:
		var result: Dictionary = Session.rename_instance(instance.instance_id, edit.text)
		if bool(result.get("ok", false)):
			root.queue_free()
			_refresh_entries()
			_refresh_desk()
			_restore_after_refresh(snapshot)
		else:
			app.toast(str(result.get("reason", "Could not name.")), "bad")
	, Tokens.BRASS))
	edit.grab_focus()
	edit.select_all()

func export_text() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Library · %d cards · %d definitions · %d crafted" % [Session.total_cards(), Session.total_definitions(), Session.crafted_count()])
	for entry in entries_filtered:
		var def: CardDef = Content.cards.get(str(entry.get("def_id", "")))
		if def != null:
			lines.append("%s · %s · x%d" % [def.name, def.type_line, int(entry.get("count", 1))])
	return lines

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SLASH:
			filter_bar.search_edit.grab_focus()
			get_viewport().set_input_as_handled()
			return
		if filter_bar.search_edit.has_focus() and key.keycode != KEY_ESCAPE:
			return
		match key.keycode:
			KEY_ESCAPE:
				selected_entry = {}
				selected_key = ""
				_apply_selection_highlights()
				_refresh_desk()
			KEY_ENTER, KEY_KP_ENTER:
				if not selected_entry.is_empty():
					_open_card_menu(selected_entry)
			KEY_C:
				_craft_entry(selected_entry)
			KEY_E:
				_add_entry_to_deck(selected_entry)
			KEY_S:
				_add_entry_to_deck(selected_entry, "side")
			KEY_P:
				_print_entry(selected_entry)
			KEY_X:
				_dissolve_entry(selected_entry)
			KEY_L:
				_toggle_lock(selected_entry)
			KEY_N:
				_rename_entry(selected_entry)
			KEY_ASTERISK:
				_toggle_favorite(selected_entry)
