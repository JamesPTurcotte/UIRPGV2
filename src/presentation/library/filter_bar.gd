class_name FilterBar
extends VBoxContainer

## Shared filter surface for the Library and the Deck Workshop. Primary facets
## are always visible; the advanced drawer is live and reversible.

signal query_changed(query: Dictionary)

const SORT_KEYS := ["name", "power", "rarity", "provenance", "count", "quality", "mods", "offer"]
const SORT_LABELS := ["Name", "Power", "Rarity", "Provenance", "Count", "Quality", "Mods", "Offer"]
const SECTION_LABELS := {
	"set": "Set",
	"lineage": "Lineage",
	"subtype": "Subtype",
	"role": "Role",
	"keyword": "Keyword",
	"craft": "Craft",
	"quality": "Quality",
	"provenance": "Provenance",
	"ink": "Ink",
	"shimmer": "Shimmer",
	"mod": "Mod",
	"deck": "Deck",
	"flags": "Flags",
}

var compact: bool = false
var persist_key: String = ""
var query: Dictionary = CardQuery.empty_query()
var search_edit: LineEdit
var facet_menus: Dictionary = {}
var advanced_checks: Dictionary = {}
var advanced_panel: PanelContainer
var chips_row: HBoxContainer
var sort_option: OptionButton
var dir_button: Button
var filters_button: Button
var views_menu: MenuButton
var _all_entries: Array = []
var _suppress: bool = false

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	if not persist_key.is_empty() and Session.settings.has(persist_key):
		var raw = Session.settings.get(persist_key, {})
		if raw is Dictionary:
			query = CardQuery.normalize(raw)
	_build()
	set_query(query)

func _build() -> void:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(panel)
	var box := UI.vbox(5)
	panel.add_child(box)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	box.add_child(row1)
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search cards, rules…"
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(func(_text: String) -> void:
		if _suppress:
			return
		query["search"] = search_edit.text.strip_edges()
		_emit()
	)
	search_edit.text_submitted.connect(func(_text: String) -> void: _persist())
	row1.add_child(search_edit)
	filters_button = UI.button("FILTERS", _toggle_advanced, Tokens.BRASS)
	filters_button.toggle_mode = true
	filters_button.custom_minimum_size = Vector2(86, 0)
	row1.add_child(filters_button)
	views_menu = MenuButton.new()
	views_menu.text = "VIEWS"
	views_menu.custom_minimum_size = Vector2(76, 0)
	views_menu.get_popup().id_pressed.connect(_on_view_menu)
	row1.add_child(views_menu)
	sort_option = OptionButton.new()
	for i in range(SORT_KEYS.size()):
		sort_option.add_item("Sort: " + SORT_LABELS[i], i)
	sort_option.item_selected.connect(func(index: int) -> void:
		if _suppress:
			return
		query["sort"] = SORT_KEYS[index]
		_emit()
	)
	row1.add_child(sort_option)
	dir_button = UI.button("↑", func() -> void:
		query["desc"] = not bool(query.get("desc", false))
		_refresh_dir()
		_emit()
	, Tokens.BRASS_LO)
	dir_button.custom_minimum_size = Vector2(34, 0)
	row1.add_child(dir_button)
	row1.add_child(UI.button("CLEAR", _clear_filters, Tokens.BRASS_LO))

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 5)
	box.add_child(row2)
	for pair in [["type", "TYPE"], ["attribute", "ATTRIBUTE"], ["rarity", "RARITY"], ["offer", "OFFER"]]:
		var key: String = pair[0]
		var menu := FacetMenu.new()
		menu.setup(key, pair[1], CardQuery.facet_values().get(key, []))
		menu.changed.connect(_on_primary_facet)
		facet_menus[key] = menu
		row2.add_child(menu)
	row2.add_child(UI.spacer())
	chips_row = HBoxContainer.new()
	chips_row.add_theme_constant_override("separation", 4)
	row2.add_child(chips_row)

	advanced_panel = UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 8)
	advanced_panel.visible = false
	add_child(advanced_panel)
	var adv_scroll := ScrollContainer.new()
	adv_scroll.custom_minimum_size = Vector2(0, 230)
	adv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	adv_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	advanced_panel.add_child(adv_scroll)
	var adv_grid := GridContainer.new()
	adv_grid.columns = 4
	adv_grid.add_theme_constant_override("h_separation", 12)
	adv_grid.add_theme_constant_override("v_separation", 8)
	adv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_scroll.add_child(adv_grid)
	var values := CardQuery.facet_values()
	values["set"] = _set_ids()
	values["mod"] = _mod_ids()
	for key in ["set", "lineage", "subtype", "role", "keyword", "craft", "quality", "provenance", "ink", "shimmer", "mod", "deck", "flags"]:
		adv_grid.add_child(_advanced_section(key, values.get(key, [])))
	_refresh_views_menu()
	_refresh_dir()

func _advanced_section(key: String, values: Array) -> Control:
	var section := UI.vbox(2)
	var title := UI.small_caps(str(SECTION_LABELS.get(key, key)))
	section.add_child(title)
	var checks: Array[Dictionary] = []
	for value in values:
		var check := CheckBox.new()
		check.text = _label_for(str(value))
		check.add_theme_font_size_override("font_size", 11)
		check.toggled.connect(_on_advanced_toggled.bind(key, str(value)))
		section.add_child(check)
		checks.append({"value": str(value), "check": check})
	advanced_checks[key] = checks
	return section

func _on_advanced_toggled(pressed: bool, key: String, value: String) -> void:
	if _suppress:
		return
	_toggle_advanced(key, value, pressed)

func _toggle_advanced(key: String, value: String, pressed: bool) -> void:
	var selected: Array = query.get(key, [])
	if pressed and not selected.has(value):
		selected.append(value)
	elif not pressed:
		selected.erase(value)
	query[key] = selected
	_emit()
	_persist()

func _on_primary_facet(key: String, selected: Array) -> void:
	if _suppress:
		return
	query[key] = selected.duplicate()
	_emit()
	_persist()

func _toggle_advanced_view() -> void:
	advanced_panel.visible = not advanced_panel.visible
	filters_button.button_pressed = advanced_panel.visible

func _clear_filters() -> void:
	var sort := str(query.get("sort", "name"))
	var desc := bool(query.get("desc", false))
	query = CardQuery.empty_query()
	query["sort"] = sort
	query["desc"] = desc
	set_query(query)
	_emit()
	_persist()

func _refresh_dir() -> void:
	dir_button.text = "↓" if bool(query.get("desc", false)) else "↑"

func _refresh_chips() -> void:
	for child in chips_row.get_children():
		chips_row.remove_child(child)
		child.queue_free()
	for key in ["type", "attribute", "rarity", "offer", "set", "lineage", "subtype", "role", "keyword", "craft", "quality", "provenance", "ink", "shimmer", "mod", "deck", "flags"]:
		var selected: Array = query.get(key, [])
		for value in selected:
			var chip := PanelContainer.new()
			chip.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_RAISED, Tokens.BRASS_LO, 1, 4))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			chip.add_child(row)
			var label := UI.label("%s: %s" % [str(SECTION_LABELS.get(key, key)), _label_for(str(value))], 10, Tokens.INK_SECONDARY)
			row.add_child(label)
			var close := UI.button("×", _remove_chip.bind(key, str(value)), Tokens.BRASS_LO)
			close.add_theme_font_size_override("font_size", 11)
			close.custom_minimum_size = Vector2(20, 20)
			row.add_child(close)
			chips_row.add_child(chip)

func _remove_chip(key: String, value: String) -> void:
	var selected: Array = query.get(key, [])
	selected.erase(value)
	query[key] = selected
	set_query(query)
	_emit()

func set_query(raw_query: Dictionary) -> void:
	_suppress = true
	query = CardQuery.normalize(raw_query)
	if search_edit != null:
		search_edit.text = str(query.get("search", ""))
	for key in facet_menus.keys():
		var menu: FacetMenu = facet_menus[key]
		menu.set_selected(query.get(key, []))
	for key in advanced_checks.keys():
		var selected: Array = query.get(key, [])
		for item in advanced_checks[key]:
			var check: CheckBox = item["check"]
			check.set_pressed_no_signal(selected.has(str(item["value"])))
	if sort_option != null:
		var index := SORT_KEYS.find(str(query.get("sort", "name")))
		sort_option.select(maxi(0, index))
	if dir_button != null:
		_refresh_dir()
	_refresh_chips()
	_suppress = false

func get_query() -> Dictionary:
	return query.duplicate(true)

func set_entries(entries: Array) -> void:
	_all_entries = entries
	var projected := CardQuery.project(entries)
	for key in ["type", "attribute", "rarity", "offer"]:
		var counts: Dictionary = {}
		for row in projected:
			var def: CardDef = row["def"]
			var value := ""
			match key:
				"type":
					value = def.type
				"attribute":
					value = def.attribute
				"rarity":
					value = def.rarity
				"offer":
					value = str(def.offer)
			counts[value] = int(counts.get(value, 0)) + 1
		if facet_menus.has(key):
			facet_menus[key].set_counts(counts)

func _emit() -> void:
	if _suppress:
		return
	query = CardQuery.normalize(query)
	_refresh_chips()
	_refresh_dir()
	if not persist_key.is_empty():
		Session.settings[persist_key] = query.duplicate(true)
	query_changed.emit(query.duplicate(true))

func _set_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in Content.sets.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func _mod_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in Content.mods.keys():
		ids.append(str(key))
	ids.sort()
	return ids

func _refresh_views_menu() -> void:
	var popup := views_menu.get_popup()
	popup.clear()
	popup.add_item("Save current view", 0)
	popup.add_separator()
	var views: Array = Session.settings.get("saved_views", [])
	for i in range(views.size()):
		var view: Dictionary = views[i]
		popup.add_item(str(view.get("name", "View %d" % (i + 1))), i + 1)
	if not views.is_empty():
		popup.add_separator()
		popup.add_item("Clear saved views", 999)

func _on_view_menu(id: int) -> void:
	if id == 0:
		var views: Array = Session.settings.get("saved_views", [])
		views.append({"name": "View %d" % (views.size() + 1), "query": query.duplicate(true)})
		Session.settings["saved_views"] = views
		Session.save_now()
		_refresh_views_menu()
		return
	if id == 999:
		Session.settings["saved_views"] = []
		Session.save_now()
		_refresh_views_menu()
		return
	var views: Array = Session.settings.get("saved_views", [])
	var index := id - 1
	if index >= 0 and index < views.size():
		var view: Dictionary = views[index]
		set_query(view.get("query", CardQuery.empty_query()))
		_emit()
		_persist()

func _persist() -> void:
	if persist_key.is_empty() or Session.test_mode:
		return
	Session.settings[persist_key] = query.duplicate(true)
	Session.save_now()

func _label_for(value: String) -> String:
	return value.replace("_", " ").replace(".", " ").replace("ink ", "").replace("shimmer ", "").capitalize()
