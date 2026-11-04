class_name TopNav
extends PanelContainer

## The four doors. One bar, four nouns, one active state. The rooms fill below
## this bar; no screen owns a second primary navigation.

const DOORS := [
	["play", "PLAY"],
	["library", "LIBRARY"],
	["decks", "DECKS"],
	["packs", "PACKS"],
]

var app: Node
var active_door: String = "library"
var door_buttons: Dictionary = {}
var marks_label: Label
var folios_label: Label
var _built: bool = false

func setup(app_ref: Node) -> void:
	app = app_ref
	if _built:
		return
	_built = true
	_build()
	if not Session.currency_changed.is_connected(_on_resources_changed):
		Session.currency_changed.connect(_on_resources_changed)
	if not Session.folios_changed.is_connected(_on_resources_changed):
		Session.folios_changed.connect(_on_resources_changed)

func _build() -> void:
	custom_minimum_size = Vector2(0, 52)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.94)
	style.border_color = Tokens.PANEL_LINE
	style.border_width_bottom = 1
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 9)
	brand.custom_minimum_size = Vector2(286, 0)
	brand.add_child(_build_mark())
	var brand_copy := VBoxContainer.new()
	brand_copy.add_theme_constant_override("separation", 0)
	var word := Label.new()
	word.text = "RAZEAH"
	word.add_theme_font_override("font", Tokens.font_display())
	word.add_theme_font_size_override("font_size", 15)
	word.add_theme_color_override("font_color", Tokens.INK_PRIMARY)
	word.add_theme_constant_override("outline_size", 0)
	brand_copy.add_child(word)
	var sub := Label.new()
	sub.text = "NEON RELIQUARY"
	sub.add_theme_font_override("font", Tokens.font_label())
	sub.add_theme_font_size_override("font_size", 8)
	sub.add_theme_color_override("font_color", Tokens.INK_MUTED)
	brand_copy.add_child(sub)
	brand.add_child(brand_copy)
	row.add_child(brand)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override("separation", 2)
	for pair in DOORS:
		var door: String = pair[0]
		var button := _build_tab(pair[1], door)
		door_buttons[door] = button
		tabs.add_child(button)
	row.add_child(tabs)

	var resources := HBoxContainer.new()
	resources.alignment = BoxContainer.ALIGNMENT_END
	resources.add_theme_constant_override("separation", 6)
	resources.custom_minimum_size = Vector2(286, 0)
	marks_label = _build_resource("MARKS", Tokens.AMBER, resources)
	folios_label = _build_resource("FOLIOS", Tokens.GREEN, resources)
	var help := UI.button("?", func() -> void:
		if app != null and app.has_method("_toggle_help"):
			app._toggle_help()
	, Tokens.BRASS_LO)
	help.tooltip_text = "Controls and shortcuts (F1)"
	help.custom_minimum_size = Vector2(28, 30)
	help.add_theme_font_override("font", Tokens.font_data())
	help.add_theme_font_size_override("font_size", 14)
	resources.add_child(help)
	row.add_child(resources)

	update_resources()

func _build_mark() -> Control:
	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(30, 30)
	mark.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_VOID, Tokens.PINK, 1, 2))
	var label := Label.new()
	label.text = "R"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Tokens.font_display())
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Tokens.CYAN)
	mark.add_child(label)
	return mark

func _build_tab(label: String, door: String) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = label.capitalize()
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Tokens.font_display())
	button.add_theme_font_size_override("font_size", 10)
	button.custom_minimum_size = Vector2(98, 36)
	button.pressed.connect(_on_door.bind(door))
	_style_tab(button, false)
	return button

func _style_tab(button: Button, active: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.12)
	normal.border_width_bottom = 1
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.055)
	hover.border_color = Tokens.CYAN

	var active_style := normal.duplicate() as StyleBoxFlat
	active_style.bg_color = Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.07)
	active_style.border_color = Tokens.PINK
	active_style.border_width_bottom = 2

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Tokens.AMBER
	focus.set_border_width_all(2)
	focus.draw_center = false

	button.add_theme_stylebox_override("normal", active_style if active else normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", active_style)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_color_override("font_color", Tokens.CYAN if active else Tokens.INK_SECONDARY)
	button.add_theme_color_override("font_hover_color", Tokens.CYAN)
	button.add_theme_color_override("font_pressed_color", Tokens.PINK)
	button.add_theme_color_override("font_focus_color", Tokens.INK_PRIMARY)

func _build_resource(label_text: String, color: Color, parent: HBoxContainer) -> Label:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_RAISED, Tokens.PANEL_LINE, 1, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)
	var caption := Label.new()
	caption.text = label_text
	caption.add_theme_font_override("font", Tokens.font_label())
	caption.add_theme_font_size_override("font_size", 7)
	caption.add_theme_color_override("font_color", Tokens.INK_MUTED)
	row.add_child(caption)
	var value := Label.new()
	value.text = "0"
	value.add_theme_font_override("font", Tokens.font_data())
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", color)
	row.add_child(value)
	parent.add_child(chip)
	return value

func _on_door(door: String) -> void:
	if app != null and app.has_method("open_room"):
		app.open_room(door)

func _on_resources_changed() -> void:
	update_resources()

func update_resources() -> void:
	if marks_label != null:
		marks_label.text = "%d" % int(Session.currency.get("marks", 0))
	if folios_label != null:
		folios_label.text = "%d" % Session.unopened_packs().size()

func set_active(door: String) -> void:
	active_door = door
	for key in door_buttons.keys():
		var button: Button = door_buttons[key]
		_style_tab(button, key == door)
