class_name ContextMenu
extends Control

## One app-level card action sheet. It is a Control, not a native PopupMenu, so
## opening/closing it can never participate in the room's layout or window
## lifecycle.

signal closed

var app: Node
var panel: PanelContainer
var scroll: ScrollContainer
var rows_box: VBoxContainer
var items: Array[Dictionary] = []
var buttons: Array[Button] = []
var on_choose: Callable
var source: Control
var anchor_rect: Rect2
var _closed: bool = false
var _focus_index: int = -1

func setup(app_ref: Node) -> void:
	app = app_ref

func open(menu_items: Array[Dictionary], anchor: Rect2, choose_callback: Callable, source_control: Control = null) -> void:
	items = menu_items.duplicate(true)
	on_choose = choose_callback
	source = source_control
	anchor_rect = anchor
	_closed = false
	_focus_index = -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 180
	set_process_input(true)
	_build()
	_position_panel()
	_focus_first()

func _build() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_PANEL, Tokens.BRASS, 1, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)
	rows_box = UI.vbox(1)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	var width := 264.0 if get_viewport_rect().size.x >= 1360 else 240.0
	var content_height := 0.0
	for item in items:
		if bool(item.get("separator_before", false)):
			var sep_wrap := UI.vbox(0)
			var top_space := Control.new()
			top_space.custom_minimum_size = Vector2(0, 4)
			sep_wrap.add_child(top_space)
			var sep := UI.hsep(Tokens.BRASS_LO * Color(1, 1, 1, 0.55))
			sep.custom_minimum_size = Vector2(0, 1)
			sep_wrap.add_child(sep)
			var bottom_space := Control.new()
			bottom_space.custom_minimum_size = Vector2(0, 4)
			sep_wrap.add_child(bottom_space)
			rows_box.add_child(sep_wrap)
			content_height += 9.0
		var button := UI.button(str(item.get("label", "")), Callable(), Tokens.BRASS_LO)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(width - 12.0, 44)
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = not bool(item.get("enabled", true))
		var reason := str(item.get("reason", ""))
		if not reason.is_empty():
			button.tooltip_text = reason
		if bool(item.get("separator_before", false)):
			button.add_theme_color_override("font_color", Tokens.BRASS_HI)
		var glyph := str(item.get("glyph", ""))
		if not glyph.is_empty():
			button.text = "%s   %s" % [glyph, str(item.get("label", ""))]
		var item_id = item.get("id", 0)
		button.pressed.connect(_choose.bind(item_id))
		rows_box.add_child(button)
		buttons.append(button)
		content_height += 44.0 + 1.0
	var max_height := get_viewport_rect().size.y - 16.0
	var body_height := minf(content_height + 12.0, max_height)
	scroll.custom_minimum_size = Vector2(0, body_height - 12.0)
	panel.custom_minimum_size = Vector2(width, body_height)

func _position_panel() -> void:
	if panel == null:
		return
	var viewport := get_viewport_rect().size
	var panel_size := panel.custom_minimum_size
	var x := anchor_rect.end.x + 8.0
	if x + panel_size.x > viewport.x - 8.0:
		x = anchor_rect.position.x - panel_size.x - 8.0
	x = clampf(x, 8.0, maxf(8.0, viewport.x - panel_size.x - 8.0))
	var y := anchor_rect.position.y
	if y + panel_size.y > viewport.y - 8.0:
		y = anchor_rect.end.y - panel_size.y
	y = clampf(y, 8.0, maxf(8.0, viewport.y - panel_size.y - 8.0))
	panel.position = Vector2(x, y)
	panel.size = panel_size

func _focus_first() -> void:
	for i in range(buttons.size()):
		if not buttons[i].disabled:
			_focus_index = i
			buttons[i].grab_focus()
			return

func _move_focus(delta: int) -> void:
	if buttons.is_empty():
		return
	var start := _focus_index
	var index := start
	for _attempt in range(buttons.size()):
		index = (index + delta + buttons.size()) % buttons.size()
		if index != start and not buttons[index].disabled:
			_focus_index = index
			buttons[index].grab_focus()
			return

func _choose(id) -> void:
	if _closed:
		return
	close(true)
	if on_choose.is_valid():
		on_choose.call(id)

func _gui_input(event: InputEvent) -> void:
	if _closed:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed:
			var panel_rect := panel.get_global_rect()
			if not panel_rect.has_point(get_global_mouse_position()):
				close()
				accept_event()

func _input(event: InputEvent) -> void:
	if _closed or not event is InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_DOWN:
		_move_focus(1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_UP:
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		_move_focus(-1 if key.shift_pressed else 1)
		get_viewport().set_input_as_handled()

func close(restore_focus: bool = true) -> void:
	if _closed:
		return
	_closed = true
	set_process_input(false)
	closed.emit()
	if restore_focus and source != null and is_instance_valid(source):
		source.grab_focus()
	queue_free()
