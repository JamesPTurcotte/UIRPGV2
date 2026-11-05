class_name DoorCard
extends PanelContainer

## One full-card door target. The title, detail, chips, and border all belong to
## the same click/focus surface; no decorative label can swallow the click.

signal pressed(choice: String)

var choice: String = ""
var accent: Color = Tokens.BRASS
var title_text: String = ""
var detail_text: String = ""
var _hovered: bool = false
var _down: bool = false

func setup(choice_id: String, title: String, detail: String, color: Color) -> void:
	choice = choice_id
	title_text = title
	detail_text = detail
	accent = color

func _ready() -> void:
	custom_minimum_size = Vector2(0, 96)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hovered = true
		_apply_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_down = false
		_apply_style()
	)
	focus_entered.connect(func() -> void:
		_hovered = true
		_apply_style()
	)
	focus_exited.connect(func() -> void:
		_hovered = false
		_apply_style()
	)
	_build()
	_apply_style()

func _build() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var box := UI.vbox(3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	var title := UI.label(title_text, 16, Tokens.INK_PRIMARY, Tokens.font_display())
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var detail := UI.label(detail_text, 10, Tokens.INK_SECONDARY)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Give the wrap a real column width; otherwise its minimum height is one
	# word per line and a FitPanel overestimates the modal.
	detail.custom_minimum_size = Vector2(150, 0)
	box.add_child(detail)

func _apply_style() -> void:
	var border := accent
	var fill := Tokens.BG_LACQUER
	if _down:
		fill = Tokens.BG_VOID
	elif _hovered:
		fill = Tokens.BG_PANEL
		border = accent.lightened(0.25)
	if has_focus():
		border = Tokens.SELECTION
	add_theme_stylebox_override("panel", Tokens.panel_style(fill, border, 1, 6))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_down = true
				_apply_style()
			else:
				if _down:
					_down = false
					_apply_style()
					pressed.emit(choice)
			accept_event()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			pressed.emit(choice)
			accept_event()
