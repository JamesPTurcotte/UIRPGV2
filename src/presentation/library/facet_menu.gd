class_name FacetMenu
extends MenuButton

## One multi-select facet. MenuButton + checkable PopupMenu keeps the primary
## filters visible without a modal or a second toolbar.

signal changed(key: String, selected: Array)

var key: String = ""
var title: String = ""
var entries: Array[Dictionary] = []
var selected: Array[String] = []
var counts: Dictionary = {}

func setup(facet_key: String, facet_title: String, values: Array) -> void:
	key = facet_key
	title = facet_title
	entries.clear()
	for value in values:
		entries.append({"id": str(value), "label": _label_for(str(value))})
	_build()
	_update_text()

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0, 32)

func _build() -> void:
	var popup := get_popup()
	popup.clear()
	for i in range(entries.size()):
		var row: Dictionary = entries[i]
		popup.add_check_item(str(row["label"]), i)
		popup.set_item_checked(i, selected.has(str(row["id"])))
	if not popup.id_pressed.is_connected(_on_id_pressed):
		popup.id_pressed.connect(_on_id_pressed)
	if not popup.about_to_popup.is_connected(_sync_checks):
		popup.about_to_popup.connect(_sync_checks)

func _sync_checks() -> void:
	var popup := get_popup()
	for i in range(entries.size()):
		if i < popup.item_count:
			popup.set_item_checked(i, selected.has(str(entries[i]["id"])))

func _on_id_pressed(id: int) -> void:
	if id < 0 or id >= entries.size():
		return
	var value := str(entries[id]["id"])
	if selected.has(value):
		selected.erase(value)
	else:
		selected.append(value)
	_sync_checks()
	_update_text()
	changed.emit(key, selected.duplicate())

func set_selected(values: Array) -> void:
	selected.clear()
	for value in values:
		selected.append(str(value))
	_sync_checks()
	_update_text()
	queue_redraw()

func set_counts(values: Dictionary) -> void:
	counts = values
	for i in range(entries.size()):
		var row: Dictionary = entries[i]
		var value := str(row["id"])
		var count := int(counts.get(value, 0))
		row["label"] = "%s  %d" % [_label_for(value), count]
	_update_text()
	_build()

func clear_selection() -> void:
	selected.clear()
	_sync_checks()
	_update_text()

func _update_text() -> void:
	if selected.is_empty():
		text = title
		tooltip_text = "All " + title.to_lower()
		return
	var labels: Array[String] = []
	for value in selected:
		labels.append(_label_for(value))
	text = "%s: %s" % [title, ", ".join(labels)]
	tooltip_text = "Filtering " + title.to_lower()

func _label_for(value: String) -> String:
	var clean := value.replace("_", " ").replace(".", " ")
	clean = clean.replace("ink ", "").replace("shimmer ", "")
	return clean.capitalize()
