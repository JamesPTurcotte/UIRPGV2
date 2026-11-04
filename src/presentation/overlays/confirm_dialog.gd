class_name ConfirmDialog
extends Control

var on_confirm: Callable
var on_cancel: Callable
var _panel: PanelContainer

func open(title: String, message: String, confirm_text: String, on_yes: Callable, on_no: Callable = Callable()) -> void:
	on_confirm = on_yes
	on_cancel = on_no
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 220
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.PAPER, Tokens.WAX, 2, 6))
	_panel.custom_minimum_size = Vector2(520, 220)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)
	var box := UI.vbox(12)
	margin.add_child(box)
	var heading := UI.label(title.to_upper(), 20, Tokens.WAX)
	heading.add_theme_font_override("font", Tokens.font_display())
	box.add_child(heading)
	var body := UI.label(message, 14, Tokens.PAPER_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(460, 0)
	box.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var cancel := UI.button("Cancel", _cancel, Tokens.BRASS_LO)
	cancel.add_theme_stylebox_override("normal", Tokens.panel_style(Color("#D8CDB4"), Tokens.BRASS_LO, 1, 4))
	cancel.add_theme_color_override("font_color", Tokens.PAPER_INK)
	row.add_child(cancel)
	var confirm := UI.button(confirm_text, _confirm, Tokens.WAX)
	confirm.add_theme_stylebox_override("normal", Tokens.panel_style(Tokens.WAX, Tokens.WAX.darkened(0.3), 1, 4))
	row.add_child(confirm)

func _confirm() -> void:
	if on_confirm.is_valid():
		on_confirm.call()
	close()

func _cancel() -> void:
	if on_cancel.is_valid():
		on_cancel.call()
	close()

func close() -> void:
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
