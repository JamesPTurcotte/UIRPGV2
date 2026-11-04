class_name UI
extends RefCounted

## Small construction helpers. Screens are code-built so procedural tokens stay
## the single source of visual truth.

static func label(text: String, size: int = 14, color: Color = Tokens.INK_PRIMARY, font: Font = null) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", font if font != null else Tokens.font_ui())
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

static func display(text: String, size: int = 28, color: Color = Tokens.INK_PRIMARY) -> Label:
	var node := label(text, size, color, Tokens.font_display())
	return node

static func data_label(text: String, size: int = 13, color: Color = Tokens.INK_SECONDARY) -> Label:
	return label(text, size, color, Tokens.font_data())

static func small_caps(text: String, color: Color = Tokens.INK_MUTED) -> Label:
	var node := label(text.to_upper(), 10, color, Tokens.font_label())
	node.add_theme_constant_override("outline_size", 0)
	return node

static func button(text: String, on_pressed: Callable = Callable(), accent: Color = Tokens.BRASS) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_ALL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if on_pressed.is_valid():
		node.pressed.connect(on_pressed)
	_style_button(node, accent)
	return node

static func toggle(text: String, on_toggled: Callable = Callable(), accent: Color = Tokens.BRASS) -> Button:
	var node := button(text, Callable(), accent)
	node.toggle_mode = true
	if on_toggled.is_valid():
		node.toggled.connect(on_toggled)
	return node

static func _style_button(node: Button, accent: Color) -> void:
	var normal := Tokens.panel_style(Tokens.BG_RAISED, accent.darkened(0.3), 1, 2)
	var hover := Tokens.panel_style(Tokens.BG_RAISED.lightened(0.06), accent, 1, 2)
	var pressed := Tokens.panel_style(Tokens.BG_PANEL, Tokens.PINK, 1, 2)
	var focus := Tokens.panel_style(Color(0, 0, 0, 0), Tokens.SELECTION, 2, 2)
	focus.draw_center = false
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("hover", hover)
	node.add_theme_stylebox_override("pressed", pressed)
	node.add_theme_stylebox_override("disabled", Tokens.panel_style(Tokens.BG_PANEL, Tokens.BRASS_LO.darkened(0.4), 1, 2))
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_color_override("font_color", Tokens.INK_PRIMARY)
	node.add_theme_color_override("font_hover_color", Tokens.CYAN)
	node.add_theme_color_override("font_pressed_color", Tokens.PINK)
	node.add_theme_color_override("font_disabled_color", Tokens.INK_MUTED)
	node.add_theme_font_size_override("font_size", 12)

static func panel(fill: Color = Tokens.BG_PANEL, border: Color = Tokens.BRASS_LO, padding: int = 12) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", Tokens.panel_style(fill, border, 1, 3))
	var margin := node.get_theme_stylebox("panel") as StyleBoxFlat
	if margin != null:
		margin.content_margin_left = padding
		margin.content_margin_right = padding
		margin.content_margin_top = padding
		margin.content_margin_bottom = padding
	return node

static func vbox(separation: int = 8) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func hbox(separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node

static func spacer(expand: bool = true) -> Control:
	var node := Control.new()
	if expand:
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node

static func hsep(color: Color = Tokens.BRASS_LO) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.custom_minimum_size = Vector2(0, 1)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func vsep(color: Color = Tokens.BRASS_LO) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.custom_minimum_size = Vector2(1, 0)
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node

static func scroll() -> ScrollContainer:
	var node := ScrollContainer.new()
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node

static func full_rect(node: Control) -> Control:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node

static func margins(node: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(node)
	return margin

static func chip(text: String, color: Color = Tokens.BRASS) -> PanelContainer:
	var chip_panel := panel(Tokens.BG_LACQUER, color.darkened(0.2), 6)
	var label_node := label(text, 11, color, Tokens.font_data())
	label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip_panel.add_child(label_node)
	chip_panel.custom_minimum_size = Vector2(0, 24)
	return chip_panel

static func title_block(title: String, subtitle: String = "") -> VBoxContainer:
	var box := vbox(2)
	box.add_child(display(title, 28))
	if not subtitle.is_empty():
		box.add_child(label(subtitle, 12, Tokens.INK_MUTED))
	return box

static func section_header(text: String, size: int = 20) -> Label:
	return display(text, size, Tokens.INK_PRIMARY)

static func wrap(font: Font, text: String, font_size: int, max_width: float, max_lines: int = 5) -> Array[String]:
	var lines: Array[String] = []
	var words := text.split(" ", false)
	var current := ""
	for word in words:
		var candidate := word if current.is_empty() else current + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			current = candidate
		else:
			if not current.is_empty():
				lines.append(current)
			current = word
			if lines.size() >= max_lines:
				break
	if lines.size() < max_lines and not current.is_empty():
		lines.append(current)
	if lines.size() > max_lines:
		lines = lines.slice(0, max_lines)
	return lines

static func fit_font_size(font: Font, text: String, max_width: float, start: int, minimum: int) -> int:
	var size := start
	while size > minimum and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width:
		size -= 1
	return size


static func format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return out
