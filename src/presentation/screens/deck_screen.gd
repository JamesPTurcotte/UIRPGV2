class_name DeckScreen
extends UIScreen

## The Deck Workshop: a card library and a binder of specific copies side by
## side. Click, keyboard, or drag; every mutation is snapshot-undoable.

var entries_all: Array[Dictionary] = []
var filter_bar: FilterBar
var query: Dictionary = CardQuery.empty_query()
var library_panel: PanelContainer
var library_grid: HFlowContainer
var library_scroll: ScrollContainer
var deck_panel: PanelContainer
var deck_grid: GridContainer
var side_grid: GridContainer
var deck_scroll: ScrollContainer
var header_box: VBoxContainer
var health_box: VBoxContainer
var drop_hint: DeckDropHint
var context_instance_id: int = 0
var context_zone: String = ""
var context_source: Control
var undo_stack: Array[Dictionary] = []
var _last_drop_zone: String = ""
var _drag_active: bool = false

func build() -> void:
	set_process(true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root := UI.vbox(8)
	margin.add_child(root)
	root.add_child(_build_top())
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	content.add_child(_build_library())
	content.add_child(_build_deck())
	drop_hint = DeckDropHint.new()
	add_child(drop_hint)
	entries_all = Session.collection_entries()
	query = filter_bar.get_query()
	_refresh_all()

func _build_top() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title := UI.vbox(0)
	title.add_child(UI.display("DECK WORKSHOP", 26))
	title.add_child(UI.small_caps("BIND · BALANCE · DESCEND"))
	row.add_child(title)
	row.add_child(UI.spacer())
	row.add_child(UI.button("AUTO-FILL", _auto_fill, Tokens.BRASS))
	row.add_child(UI.button("CLEAR DECK", _clear_deck, Tokens.WAX))
	row.add_child(UI.button("?", func() -> void: app._toggle_help(), Tokens.BRASS_LO))
	return panel

func _build_library() -> Control:
	library_panel = UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	library_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_panel.size_flags_stretch_ratio = 0.48
	var box := UI.vbox(5)
	library_panel.add_child(box)
	box.add_child(UI.small_caps("LIBRARY"))
	filter_bar = FilterBar.new()
	filter_bar.persist_key = "deck_query"
	filter_bar.compact = true
	filter_bar.query_changed.connect(_on_query_changed)
	box.add_child(filter_bar)
	library_scroll = UI.scroll()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(library_scroll)
	var gutter := MarginContainer.new()
	gutter.add_theme_constant_override("margin_right", 12)
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_scroll.add_child(gutter)
	library_grid = HFlowContainer.new()
	library_grid.add_theme_constant_override("h_separation", 6)
	library_grid.add_theme_constant_override("v_separation", 8)
	library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(library_grid)
	return library_panel

func _build_deck() -> Control:
	deck_panel = UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_stretch_ratio = 0.52
	var box := UI.vbox(5)
	deck_panel.add_child(box)
	header_box = UI.vbox(3)
	box.add_child(header_box)
	health_box = UI.vbox(2)
	box.add_child(health_box)
	box.add_child(UI.hsep())
	deck_scroll = UI.scroll()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(deck_scroll)
	var deck_content := UI.vbox(8)
	deck_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.add_child(deck_content)
	deck_content.add_child(UI.small_caps("MAIN DECK · 40"))
	deck_grid = GridContainer.new()
	deck_grid.columns = 4
	deck_grid.add_theme_constant_override("h_separation", 6)
	deck_grid.add_theme_constant_override("v_separation", 6)
	deck_content.add_child(deck_grid)
	deck_content.add_child(UI.small_caps("SIDEBOARD · 5"))
	side_grid = GridContainer.new()
	side_grid.columns = 4
	side_grid.add_theme_constant_override("h_separation", 6)
	side_grid.add_theme_constant_override("v_separation", 6)
	deck_content.add_child(side_grid)
	return deck_panel

func _refresh_all() -> void:
	entries_all = Session.collection_entries()
	filter_bar.set_entries(entries_all)
	_refresh_library()
	_refresh_deck()
	_refresh_header()
	_refresh_health()

func _on_query_changed(next_query: Dictionary) -> void:
	query = next_query
	_refresh_library()

func _refresh_library() -> void:
	for child in library_grid.get_children():
		library_grid.remove_child(child)
		child.queue_free()
	var filtered := CardQuery.filter(entries_all, query)
	var by_def: Dictionary = {}
	for entry in filtered:
		var def_id := str(entry.get("def_id", ""))
		var row: Dictionary = by_def.get(def_id, {"def_id": def_id, "count": 0, "entry": entry})
		row["count"] = int(row["count"]) + int(entry.get("count", 1))
		if entry.get("best_instance") != null:
			row["entry"] = entry
		by_def[def_id] = row
	var rows: Array = by_def.values()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ad: CardDef = Content.cards.get(str(a["def_id"]))
		var bd: CardDef = Content.cards.get(str(b["def_id"]))
		return (ad.name if ad != null else "") < (bd.name if bd != null else "")
	)
	if rows.is_empty():
		var empty := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 18)
		var empty_box := UI.vbox(4)
		empty.add_child(empty_box)
		empty_box.add_child(UI.label("No cards match.", 13, Tokens.INK_SECONDARY))
		empty_box.add_child(UI.button("CLEAR FILTERS", func() -> void: filter_bar._clear_filters(), Tokens.BRASS))
		library_grid.add_child(empty)
		return
	for row in rows:
		var def: CardDef = Content.cards.get(str(row["def_id"]))
		if def == null:
			continue
		var entry: Dictionary = row["entry"]
		var view := CardView.new()
		view.set_card(def, entry.get("best_instance"), "S")
		view.count = int(row["count"])
		view.decked = Session.count_def_in_deck(def.id, Session.active_deck()) > 0
		view.drag_payload = {"source": "library", "def_id": def.id, "entry_kind": str(entry.get("kind", "stack"))}
		view.drop_callback = _on_library_card_drop
		view.drop_action = _do_library_card_drop
		view.clicked.connect(func(_v: CardView) -> void: _add_def(def.id, "main"))
		view.right_clicked.connect(func(_v: CardView, rect: Rect2) -> void: _open_library_menu(def.id, rect, _v))
		var tile := UI.vbox(2)
		tile.custom_minimum_size = Vector2(Tokens.card_size("S").x, 0)
		tile.add_child(view)
		var in_deck := Session.count_def_in_deck(def.id, Session.active_deck())
		var count := UI.label("OWNED ×%d · DECK %d/3" % [int(row["count"]), in_deck], 9, Tokens.BRASS_HI if in_deck < 3 else Tokens.DANGER)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(count)
		library_grid.add_child(tile)

func _refresh_header() -> void:
	for child in header_box.get_children():
		header_box.remove_child(child)
		child.queue_free()
	var deck := Session.active_deck()
	if deck == null:
		header_box.add_child(UI.display("No deck.", 20))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.display(deck.name, 22))
	row.add_child(UI.spacer())
	row.add_child(UI.chip("%d / 40 MAIN" % deck.main.size(), Tokens.BRASS_HI if deck.main.size() == 40 else Tokens.DANGER))
	row.add_child(UI.chip("%d / 5 SIDE" % deck.side.size(), Tokens.INK_SECONDARY))
	row.add_child(UI.chip("POWER %d" % Session.deck_power(deck), Tokens.BRASS))
	var errors := Session.deck_errors(deck)
	row.add_child(UI.chip("LEGAL" if errors.is_empty() else "ILLEGAL", Tokens.GOOD if errors.is_empty() else Tokens.DANGER))
	header_box.add_child(row)
	var doctrine_row := HBoxContainer.new()
	doctrine_row.add_theme_constant_override("separation", 4)
	doctrine_row.add_child(UI.small_caps("DOCTRINE"))
	for doctrine in ["press", "hold", "read"]:
		var button := UI.button(doctrine.capitalize(), Callable(), Tokens.BRASS_LO)
		button.pressed.connect(_set_doctrine.bind(doctrine))
		button.toggle_mode = true
		button.button_pressed = deck.doctrine == doctrine
		button.add_theme_font_size_override("font_size", 11)
		doctrine_row.add_child(button)
	doctrine_row.add_child(UI.spacer())
	var last: Dictionary = Session.last_result
	if not last.is_empty():
		doctrine_row.add_child(UI.label("Last: %s · %d Marks" % [str(last.get("kind", "")).capitalize(), int(last.get("marks", 0))], 10, Tokens.INK_MUTED))
	header_box.add_child(doctrine_row)
	if not errors.is_empty():
		header_box.add_child(UI.label(errors[0], 11, Tokens.DANGER))

func _refresh_deck() -> void:
	for child in deck_grid.get_children():
		deck_grid.remove_child(child)
		child.queue_free()
	for child in side_grid.get_children():
		side_grid.remove_child(child)
		child.queue_free()
	var deck := Session.active_deck()
	if deck == null:
		return
	var index := 0
	for instance_id in deck.main:
		var instance: CardInstance = Session.instance_by_id(instance_id)
		deck_grid.add_child(_deck_tile(instance, "main"))
		index += 1
	while index < 40:
		deck_grid.add_child(_empty_slot("MAIN"))
		index += 1
	var side_index := 0
	for instance_id in deck.side:
		var instance: CardInstance = Session.instance_by_id(instance_id)
		side_grid.add_child(_deck_tile(instance, "side"))
		side_index += 1
	while side_index < 5:
		side_grid.add_child(_empty_slot("SIDE"))
		side_index += 1

func _deck_tile(instance: CardInstance, zone: String) -> Control:
	if instance == null:
		return _empty_slot("MAIN" if zone == "main" else "SIDE")
	var def: CardDef = Content.cards.get(instance.def_id)
	var view := CardView.new()
	view.set_card(def, instance, "S")
	view.drag_payload = {"source": "deck", "def_id": instance.def_id, "instance_id": instance.instance_id, "from_zone": zone}
	view.drop_callback = _on_deck_card_drop
	view.drop_action = _do_deck_card_drop
	view.clicked.connect(func(_v: CardView) -> void: _remove_instance(instance.instance_id))
	view.right_clicked.connect(func(_v: CardView, rect: Rect2) -> void: _open_deck_menu(instance.instance_id, zone, rect, _v))
	var holder := UI.vbox(1)
	holder.custom_minimum_size = Vector2(Tokens.card_size("S").x, 0)
	holder.add_child(view)
	var name := UI.label(def.name, 8, Tokens.INK_SECONDARY)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.clip_text = true
	holder.add_child(name)
	return holder

func _empty_slot(zone: String) -> Control:
	var panel := DeckDropSlot.new()
	panel.screen = self
	panel.zone = "main" if zone == "MAIN" else "side"
	panel.custom_minimum_size = Tokens.card_size("S") + Vector2(0, 11)
	panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_LACQUER * Color(1, 1, 1, 0.55), Tokens.BRASS_LO * Color(1, 1, 1, 0.4), 1, 4))
	var label := UI.label("EMPTY", 8, Tokens.INK_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.tooltip_text = "Drop a card into the %s." % ("main deck" if zone == "MAIN" else "sideboard")
	return panel

func _refresh_health() -> void:
	for child in health_box.get_children():
		health_box.remove_child(child)
		child.queue_free()
	var deck := Session.active_deck()
	if deck == null:
		return
	var type_counts := {"monster": 0, "spell": 0, "trap": 0}
	var attr_counts := {"ember": 0, "tide": 0, "verdant": 0, "umbra": 0, "neutral": 0}
	var offer_counts := {0: 0, 1: 0, 2: 0}
	for instance_id in deck.main:
		var instance: CardInstance = Session.instance_by_id(instance_id)
		if instance == null:
			continue
		var def: CardDef = Content.cards.get(instance.def_id)
		if def == null:
			continue
		type_counts[def.type] = int(type_counts.get(def.type, 0)) + 1
		attr_counts[def.attribute] = int(attr_counts.get(def.attribute, 0)) + 1
		offer_counts[def.offer] = int(offer_counts.get(def.offer, 0)) + 1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(UI.chip("M %d" % type_counts["monster"], Tokens.EMBER))
	row.add_child(UI.chip("S %d" % type_counts["spell"], Tokens.TIDE))
	row.add_child(UI.chip("T %d" % type_counts["trap"], Tokens.VERDANT))
	row.add_child(UI.chip("OFFER 0:%d 1:%d 2:%d" % [offer_counts[0], offer_counts[1], offer_counts[2]], Tokens.INK_SECONDARY))
	health_box.add_child(row)
	var attr_row := HBoxContainer.new()
	attr_row.add_theme_constant_override("separation", 4)
	for attribute in ["ember", "tide", "verdant", "umbra", "neutral"]:
		attr_row.add_child(UI.chip("%s %d" % [attribute.capitalize(), attr_counts[attribute]], Tokens.attribute_color(attribute)))
	health_box.add_child(attr_row)
	var power := Session.deck_power(deck)
	var recommended := Content.recommended_power(maxi(1, int(Session.unlocked_floor)))
	var underdog := Economy.underdog_bonus(power, recommended)
	health_box.add_child(UI.label("Power %d · Recommended %d · Underdog +%d%%" % [power, recommended, int(round(underdog * 100.0))], 11, Tokens.INK_SECONDARY))

func _add_def(def_id: String, zone: String) -> void:
	_push_undo()
	var result := Session.add_def_to_deck(def_id, zone)
	if bool(result.get("ok", false)):
		app.toast("Added to %s." % ("deck" if zone == "main" else "sideboard"), "good")
		_refresh_all()
	else:
		_undo_stack_pop_only()
		app.toast(str(result.get("reason", "Could not add.")), "bad")

func _remove_instance(instance_id: int) -> void:
	_push_undo()
	var result := Session.remove_instance_from_deck(instance_id)
	if bool(result.get("ok", false)):
		app.toast("Removed.", "info")
		_refresh_all()
	else:
		_undo_stack_pop_only()
		app.toast(str(result.get("reason", "Could not remove.")), "bad")

func _move_instance(instance_id: int, zone: String) -> void:
	_push_undo()
	var result := Session.move_instance_in_deck(instance_id, zone)
	if bool(result.get("ok", false)):
		app.toast("Moved to %s." % ("deck" if zone == "main" else "sideboard"), "info")
		_refresh_all()
	else:
		_undo_stack_pop_only()
		app.toast(str(result.get("reason", "Could not move.")), "bad")

func _open_library_menu(def_id: String, anchor: Rect2, source: Control) -> void:
	context_instance_id = 0
	context_zone = def_id
	context_source = source
	var items: Array[Dictionary] = [
		{"id": 0, "label": "Add to Main", "glyph": "E"},
		{"id": 1, "label": "Add to Sideboard", "glyph": "S"},
	]
	app.open_context_menu(items, anchor, _on_library_context, source)

func _open_deck_menu(instance_id: int, zone: String, anchor: Rect2, source: Control) -> void:
	context_instance_id = instance_id
	context_zone = zone
	context_source = source
	var items: Array[Dictionary] = [
		{"id": 2, "label": "Remove", "glyph": "X"},
		{"id": 3, "label": "Move to Sideboard" if zone == "main" else "Move to Main", "glyph": "↔"},
	]
	app.open_context_menu(items, anchor, _on_deck_context, source)

func _on_library_context(id: int) -> void:
	if id == 0 or id == 1:
		var def_id := str(context_zone)
		var zone := "main" if id == 0 else "side"
		_run_context_refresh(func() -> void: _add_def(def_id, zone))

func _on_deck_context(id: int) -> void:
	if id == 2:
		var instance_id := context_instance_id
		_run_context_refresh(func() -> void: _remove_instance(instance_id))
	elif id == 3:
		var instance_id := context_instance_id
		var zone := "side" if context_zone == "main" else "main"
		_run_context_refresh(func() -> void: _move_instance(instance_id, zone))

func _run_context_refresh(action: Callable) -> void:
	var snapshot := {
		"library": library_scroll.scroll_vertical if library_scroll != null else 0,
		"deck": deck_scroll.scroll_vertical if deck_scroll != null else 0,
	}
	action.call()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if library_scroll != null:
		library_scroll.scroll_vertical = int(snapshot.get("library", 0))
	if deck_scroll != null:
		deck_scroll.scroll_vertical = int(snapshot.get("deck", 0))

func _set_doctrine(value: String) -> void:
	Session.set_doctrine(value)
	_refresh_all()

func _auto_fill() -> void:
	_push_undo()
	var added := Session.auto_fill_deck()
	app.toast("Filled %d cards." % added, "good")
	_refresh_all()

func _clear_deck() -> void:
	app.confirm("Clear the deck?", "Copies return to the stacks.", func() -> void:
		_push_undo()
		var deck := Session.active_deck()
		if deck != null:
			while not deck.main.is_empty():
				Session.remove_instance_from_deck(deck.main[0])
			while not deck.side.is_empty():
				Session.remove_instance_from_deck(deck.side[0])
			_refresh_all()
	, "Clear")

func _snapshot() -> Dictionary:
	var deck := Session.active_deck()
	var snapshot := {
		"stacks": Session.stacks.duplicate(true),
		"instances": {},
		"main": deck.main.duplicate() if deck != null else [],
		"side": deck.side.duplicate() if deck != null else [],
	}
	for instance_id in Session.instances.keys():
		var instance: CardInstance = Session.instances[instance_id]
		snapshot["instances"][int(instance_id)] = instance.to_dict()
	return snapshot

func _push_undo() -> void:
	undo_stack.append(_snapshot())
	if undo_stack.size() > 20:
		undo_stack.pop_front()

func _undo_stack_pop_only() -> void:
	if not undo_stack.is_empty():
		undo_stack.pop_back()

func _undo() -> void:
	if undo_stack.is_empty():
		app.toast("Nothing to undo.", "info")
		return
	var snapshot: Dictionary = undo_stack.pop_back()
	Session.stacks.clear()
	for stack in snapshot["stacks"]:
		Session.stacks.append(stack.duplicate(true))
	Session.instances.clear()
	for raw_id in snapshot["instances"].keys():
		var instance := CardInstance.from_dict(snapshot["instances"][raw_id])
		Session.instances[int(raw_id)] = instance
	var deck := Session.active_deck()
	if deck != null:
		var main_ids: Array[int] = []
		for raw_id in snapshot["main"]:
			main_ids.append(int(raw_id))
		var side_ids: Array[int] = []
		for raw_id in snapshot["side"]:
			side_ids.append(int(raw_id))
		deck.main = main_ids
		deck.side = side_ids
	Session.save_now()
	Session.collection_changed.emit()
	Session.decks_changed.emit()
	_refresh_all()
	app.toast("Undone.", "info")

func _process(delta: float) -> void:
	if not _drag_active:
		return
	if deck_scroll == null or not is_instance_valid(deck_scroll):
		return
	var point := get_global_mouse_position()
	var rect := deck_scroll.get_global_rect()
	if not rect.has_point(point):
		return
	if point.y < rect.position.y + 40.0:
		deck_scroll.scroll_vertical = maxi(0, deck_scroll.scroll_vertical - int(340.0 * delta))
	elif point.y > rect.end.y - 40.0:
		deck_scroll.scroll_vertical += int(340.0 * delta)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("source"):
		return false
	_drag_active = true
	var pos := get_global_rect().position + at_position
	var zone := _drop_zone_at(pos)
	if not zone.is_empty():
		drop_hint.set_target(_zone_rect(zone), true)
		_last_drop_zone = zone
		return true
	if str(data.get("source", "")) == "deck" and library_panel.get_global_rect().has_point(pos):
		drop_hint.set_target(library_panel.get_global_rect(), true)
		_last_drop_zone = "remove"
		return true
	drop_hint.clear()
	_last_drop_zone = ""
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	drop_hint.clear()
	if not data is Dictionary:
		return
	var zone := _last_drop_zone
	_last_drop_zone = ""
	drop_payload(data, zone)

func can_drop_zone(zone: String, data: Dictionary) -> bool:
	if zone != "main" and zone != "side":
		return false
	if not data.has("source"):
		return false
	_drag_active = true
	drop_hint.set_target(_zone_rect(zone), true)
	_last_drop_zone = zone
	return true

func drop_payload(data: Dictionary, zone: String) -> void:
	var source := str(data.get("source", ""))
	if zone == "remove":
		if source == "deck":
			_remove_instance(int(data.get("instance_id", 0)))
		return
	if zone != "main" and zone != "side":
		return
	if source == "library":
		_add_def(str(data.get("def_id", "")), "main" if zone == "main" else "side")
	elif source == "deck":
		var instance_id := int(data.get("instance_id", 0))
		var from_zone := str(data.get("from_zone", ""))
		if from_zone != zone:
			_move_instance(instance_id, "main" if zone == "main" else "side")

func _on_library_card_drop(view: CardView, _at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or str(data.get("source", "")) != "deck":
		return false
	_drag_active = true
	drop_hint.set_target(view.get_global_rect(), true)
	_last_drop_zone = "remove"
	return true

func _on_deck_card_drop(view: CardView, _at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("source"):
		return false
	var zone := str(view.drag_payload.get("from_zone", "main"))
	if not can_drop_zone(zone, data):
		return false
	return true

func _do_library_card_drop(_view: CardView, _at_position: Vector2, data: Variant) -> void:
	drop_hint.clear()
	if data is Dictionary:
		drop_payload(data, "remove")

func _do_deck_card_drop(view: CardView, _at_position: Vector2, data: Variant) -> void:
	drop_hint.clear()
	if data is Dictionary:
		drop_payload(data, str(view.drag_payload.get("from_zone", "main")))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_drag_active = false
		if drop_hint != null:
			drop_hint.clear()

func _drop_zone_at(pos: Vector2) -> String:
	if side_grid.get_global_rect().has_point(pos):
		return "side"
	if deck_panel.get_global_rect().has_point(pos):
		return "main"
	return ""

func _zone_rect(zone: String) -> Rect2:
	if zone == "side":
		return side_grid.get_global_rect()
	return deck_panel.get_global_rect()

func export_text() -> Array[String]:
	var lines: Array[String] = []
	var deck := Session.active_deck()
	if deck != null:
		lines.append("%s · %d/40 main · %d/5 side · power %d" % [deck.name, deck.main.size(), deck.side.size(), Session.deck_power(deck)])
	if deck != null:
		for instance_id in deck.main:
			var instance: CardInstance = Session.instance_by_id(instance_id)
			var def: CardDef = Content.cards.get(instance.def_id) if instance != null else null
			if def != null:
				lines.append(def.name)
	return lines

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if (key.ctrl_pressed or key.meta_pressed) and key.keycode == KEY_Z:
			_undo()
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_ESCAPE:
			app.go_library()
