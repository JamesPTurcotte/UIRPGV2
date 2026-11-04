class_name TableScreen
extends UIScreen

## The Table: a stable stage of actors, an event-driven animation director,
## grouped legal actions, and a ceremony for win/fall/Recall.

var duel: DuelState
var mode: String = "auto"
var speed: int = 1
var paused: bool = false
var resolving: bool = false
var busy: bool = false
var recall_queued: bool = false
var timer: Timer
var result_overlay: Control
var pile_overlay: Control
var suggestion: Dictionary = {}
var legal_cache: Array[Dictionary] = []
var selected_hand_uid: int = -1
var selected_board_uid: int = -1
var inspected_card: DuelCard
var rail_tab: String = "log"

var access_scale: int = 150
var stage: DuelBoardStage
var fx: FxLayer
var player_resolve_bar: GaugeBar
var player_resolve_label: Label
var player_status_label: Label
var player_face_label: Label
var run_depth_label: Label
var run_streak_label: Label
var player_hand_label: Label
var marks_label: Label
var pause_button: Button
var mode_button: Button
var recall_button: Button
var speed_buttons: Dictionary = {}
var rail_content: VBoxContainer
var rail_scroll: ScrollContainer
var rail_tabs: Dictionary = {}
var deck_button: Button
var remains_button: Button
var void_button: Button
var intent_panel: PanelContainer
var intent_name_label: Label
var intent_value_label: Label
var warden_meta_label: Label
var intent_line_label: Label
var intent_lane_map: LaneMap
var current_intent: Dictionary = {}
var dock: PanelContainer
var strike_button: Button
var strike_sub: Label
var end_button: Button
var end_sub: Label
var reset_button: Button
var drawer: PanelContainer
var menu_button: Button
var pin_button: Button
var log_box: VBoxContainer
var log_tab_built: bool = false
var log_shown_count: int = 0

func build() -> void:
	duel = Session.make_duel()
	if duel == null:
		app.go_gate()
		return
	mode = str(Session.descent.get("mode", Session.settings.get("mode", "auto")))
	speed = int(Session.settings.get("table_speed", 1))
	# X2 fills the window it is given. The chrome stays at 150%; the card and
	# backrow budget respond to the actual table size.
	access_scale = 150
	get_window().min_size = Vector2i(960, 720)
	# Keep the window where the shell left it. The table is pinned above other
	# windows, but entering it must not teleport the window to a corner.
	get_window().set_flag(Window.FLAG_ALWAYS_ON_TOP, true)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	add_child(margin)
	var root := UI.vbox(0)
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)
	root.add_child(_build_stage())

	# The old dashboard rails become a drawer. The board keeps the full square;
	# the drawer is opened from the single menu button in the score rail.
	drawer = _build_drawer()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	drawer.offset_left = -420
	drawer.offset_right = 0
	drawer.visible = false
	drawer.z_index = 80
	add_child(drawer)

	timer = Timer.new()
	timer.wait_time = 0.55 / float(speed)
	timer.timeout.connect(_on_tick)
	add_child(timer)
	timer.start()
	if mode == "manual":
		rail_tab = "actions"
	_thicken_table_chrome(self)
	_refresh_all()
	call_deferred("_refresh_board")
	call_deferred("_layout_dock")
	call_deferred("_layout_menu_button")
	if duel.ended:
		_on_duel_end()

func _thicken_table_chrome(node: Node) -> void:
	# The accessible table draws 2px chrome; the shared UI styles stay 1px so
	# the 1440 rooms keep their hairline. Only this subtree is lifted.
	if access_scale < 125:
		return
	if node is Button:
		var button := node as Button
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style := button.get_theme_stylebox(state)
			if style is StyleBoxFlat:
				var copy := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
				copy.set_border_width_all(2)
				button.add_theme_stylebox_override(state, copy)
	elif node is PanelContainer:
		var panel := node as PanelContainer
		var style := panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var copy := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
			copy.set_border_width_all(2)
			panel.add_theme_stylebox_override("panel", copy)
	for child in node.get_children():
		_thicken_table_chrome(child)

func _build_compact_run_strip() -> Control:
	var caps_size := 12 if access_scale >= 150 else 10
	var body_size := 12 if access_scale >= 150 else 10
	var big_size := 14 if access_scale >= 150 else 12
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.PANEL_LINE, 8)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(6)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	run_depth_label = UI.data_label("DEPTH 01 · CIRCUIT 1", big_size, Tokens.CYAN)
	run_depth_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_streak_label = UI.label("STREAK 0 · CLEARED 0", body_size, Tokens.INK_MUTED, Tokens.font_label())
	head.add_child(run_depth_label)
	head.add_child(run_streak_label)
	box.add_child(head)

	marks_label = UI.label("0 MARKS", body_size + 1, Tokens.AMBER, Tokens.font_data())
	box.add_child(marks_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	for value in [1, 2, 4]:
		var button := UI.button("%d×" % value, Callable(), Tokens.PANEL_LINE)
		button.pressed.connect(_set_speed.bind(value))
		button.add_theme_font_size_override("font_size", body_size)
		button.custom_minimum_size = Vector2(44, btn_h)
		speed_buttons[value] = button
		controls.add_child(button)
	pause_button = UI.button("PAUSE", _toggle_pause, Tokens.PANEL_LINE)
	pause_button.custom_minimum_size = Vector2(0, btn_h)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.add_theme_font_size_override("font_size", body_size)
	controls.add_child(pause_button)
	mode_button = UI.button("AUTO", _cycle_mode, Tokens.CYAN)
	mode_button.custom_minimum_size = Vector2(0, btn_h)
	mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_button.add_theme_font_size_override("font_size", body_size)
	controls.add_child(mode_button)
	recall_button = UI.button("RECALL", _queue_recall, Tokens.PINK)
	recall_button.custom_minimum_size = Vector2(0, btn_h)
	recall_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recall_button.add_theme_font_size_override("font_size", body_size)
	controls.add_child(recall_button)
	box.add_child(controls)
	return panel

func _caps(text: String) -> Label:
	var node := UI.small_caps(text)
	node.add_theme_font_size_override("font_size", 12 if access_scale >= 150 else 10)
	return node

func _build_drawer() -> PanelContainer:
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	var body_size := 13 if access_scale >= 150 else 11
	var panel := UI.panel(Tokens.BG_VOID, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.40), 4)
	panel.custom_minimum_size = Vector2(420, 0)
	var box := UI.vbox(8)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(_caps("TABLE"))
	head.add_child(UI.spacer())
	var close := UI.button("×", _toggle_drawer, Tokens.PANEL_LINE)
	close.custom_minimum_size = Vector2(btn_h, btn_h)
	close.add_theme_font_size_override("font_size", 20)
	head.add_child(close)
	box.add_child(head)

	# The four doors live here while the top nav is hidden on the table.
	box.add_child(_caps("ROOMS"))
	var doors := HBoxContainer.new()
	doors.add_theme_constant_override("separation", 6)
	for pair in [["PLAY", "play"], ["LIBRARY", "library"], ["DECKS", "decks"], ["PACKS", "packs"]]:
		var door_id: String = pair[1]
		var door := UI.button(pair[0], func() -> void: app.open_room(door_id), Tokens.CYAN)
		door.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		door.custom_minimum_size = Vector2(0, btn_h)
		door.add_theme_font_size_override("font_size", body_size)
		doors.add_child(door)
	box.add_child(doors)

	box.add_child(_build_compact_run_strip())
	box.add_child(_build_left_rail())

	var right := _build_right_rail()
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(right)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	pin_button = UI.button("PIN", _toggle_pin, Tokens.PANEL_LINE)
	pin_button.custom_minimum_size = Vector2(0, btn_h)
	pin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_button.add_theme_font_size_override("font_size", body_size)
	pin_button.tooltip_text = "Keep the table above other windows."
	var pinned := get_window().get_flag(Window.FLAG_ALWAYS_ON_TOP)
	pin_button.text = "UNPIN" if pinned else "PIN"
	pin_button.modulate = Tokens.PINK if pinned else Color.WHITE
	tools.add_child(pin_button)
	var help := UI.button("HELP", func() -> void: app._toggle_help(), Tokens.PANEL_LINE)
	help.custom_minimum_size = Vector2(0, btn_h)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.add_theme_font_size_override("font_size", body_size)
	tools.add_child(help)
	box.add_child(tools)
	return panel

func _build_left_rail() -> Control:
	var body_size := 13 if access_scale >= 150 else 11
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.PANEL_LINE, 10)
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box := UI.vbox(7)
	panel.add_child(box)
	box.add_child(_caps("YOUR RESOLVE"))
	player_resolve_bar = GaugeBar.new()
	player_resolve_bar.color = Tokens.CYAN
	player_resolve_bar.show_numbers = false
	player_resolve_bar.compact = true
	player_resolve_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(player_resolve_bar)
	player_resolve_label = UI.data_label("4000", 40 if access_scale >= 150 else 34, Tokens.INK_PRIMARY)
	box.add_child(player_resolve_label)
	player_status_label = UI.label("", body_size, Tokens.GREEN, Tokens.font_label())
	player_status_label.visible = false
	box.add_child(player_status_label)
	player_face_label = UI.label("", body_size, Tokens.GREEN, Tokens.font_label())
	player_face_label.visible = false
	box.add_child(player_face_label)
	box.add_child(UI.hsep())
	box.add_child(_caps("PILES"))
	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation", 6)
	deck_button = _rail_button("DECK 40", func() -> void: _show_pile("Deck", duel.players[0].deck, true))
	remains_button = _rail_button("REMAINS 0", func() -> void: _show_pile("Remains", duel.players[0].remains, false))
	void_button = _rail_button("VOID 0", func() -> void: _show_pile("Void", duel.players[0].banished, false))
	for pile_button in [deck_button, remains_button, void_button]:
		pile_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pile_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		piles.add_child(pile_button)
	box.add_child(piles)
	box.add_child(UI.hsep())
	player_hand_label = UI.label("HAND 5", body_size, Tokens.INK_SECONDARY, Tokens.font_label())
	box.add_child(player_hand_label)
	var hint := UI.label("F2 BOARD · F3 CARD", 11 if access_scale >= 150 else 9, Tokens.INK_MUTED, Tokens.font_label())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	return panel

func _rail_button(text: String, callback: Callable) -> Button:
	var button := UI.button(text, callback, Tokens.PANEL_LINE)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 48 if access_scale >= 150 else 44)
	button.add_theme_font_size_override("font_size", 13 if access_scale >= 150 else 11)
	return button

func _build_stage() -> Control:
	stage = DuelBoardStage.new()
	stage.access_scale = access_scale
	stage.setup(self)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.zone_clicked.connect(_on_stage_zone_clicked)
	stage.set_duel(duel)
	dock = _build_dock()
	dock.z_index = 30
	stage.add_child(dock)
	menu_button = UI.button("≡", _toggle_drawer, Tokens.PANEL_LINE)
	var hud_size := 48.0 if access_scale >= 150 else 44.0
	menu_button.custom_minimum_size = Vector2(hud_size, hud_size)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.z_index = 40
	menu_button.tooltip_text = "Open the table drawer."
	stage.add_child(menu_button)
	var cue := CueStrip.new()
	cue.stage = stage
	cue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(cue)
	stage.resized.connect(_layout_dock)
	stage.resized.connect(_layout_menu_button)
	fx = FxLayer.new()
	fx.z_index = 50
	stage.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return stage

func _build_dock() -> PanelContainer:
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	var sub_h := 12.0 if access_scale >= 150 else 10.0
	var btn_font := 13 if access_scale >= 150 else 11
	var sub_font := 10 if access_scale >= 150 else 9
	var panel := PanelContainer.new()
	var style := Tokens.panel_style(Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.92), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.36), 1, 2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var live := UI.label("LIVE", 11 if access_scale >= 150 else 10, Tokens.GREEN, Tokens.font_label())
	row.add_child(live)
	row.add_child(UI.spacer())

	var strike_box := VBoxContainer.new()
	strike_box.add_theme_constant_override("separation", 0)
	strike_button = UI.button("STRIKE", _dock_strike, Tokens.PINK)
	strike_button.custom_minimum_size = Vector2(190, btn_h)
	strike_button.add_theme_font_size_override("font_size", btn_font)
	strike_box.add_child(strike_button)
	strike_sub = UI.label("NO LEGAL STRIKE", sub_font, Tokens.INK_MUTED, Tokens.font_label())
	strike_sub.custom_minimum_size = Vector2(190, sub_h)
	strike_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strike_sub.clip_text = true
	strike_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	strike_box.add_child(strike_sub)
	row.add_child(strike_box)

	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 0)
	end_button = UI.button("END PHASE", _dock_end, Tokens.CYAN)
	end_button.custom_minimum_size = Vector2(155, btn_h)
	end_button.add_theme_font_size_override("font_size", btn_font)
	end_box.add_child(end_button)
	end_sub = UI.label("NEXT · DRAW", sub_font, Tokens.INK_MUTED, Tokens.font_label())
	end_sub.custom_minimum_size = Vector2(155, sub_h)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_sub.clip_text = true
	end_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	end_box.add_child(end_sub)
	row.add_child(end_box)

	reset_button = UI.button("RESET", _dock_reset, Tokens.PANEL_LINE)
	reset_button.custom_minimum_size = Vector2(80, btn_h)
	reset_button.add_theme_font_size_override("font_size", btn_font)
	row.add_child(reset_button)
	return panel

func _layout_dock() -> void:
	if dock == null or stage == null or not is_instance_valid(dock):
		return
	dock.position = stage.dock_rect.position
	dock.size = stage.dock_rect.size

func _layout_menu_button() -> void:
	if menu_button == null or stage == null or not is_instance_valid(menu_button):
		return
	var hud_size := 48.0 if access_scale >= 150 else 44.0
	menu_button.position = Vector2(stage.board_rect.end.x - hud_size - 4.0, 8.0)
	menu_button.size = Vector2(hud_size, hud_size)

func _toggle_drawer() -> void:
	if drawer == null or not is_instance_valid(drawer):
		return
	drawer.visible = not drawer.visible
	if menu_button != null:
		menu_button.text = "×" if drawer.visible else "≡"
		menu_button.tooltip_text = "Close the table drawer." if drawer.visible else "Open the table drawer."
	if drawer.visible:
		_refresh_top()
		_refresh_rail()

func _toggle_pin() -> void:
	var window := get_window()
	var pinned := window.get_flag(Window.FLAG_ALWAYS_ON_TOP)
	window.set_flag(Window.FLAG_ALWAYS_ON_TOP, not pinned)
	if pin_button != null:
		pin_button.text = "UNPIN" if not pinned else "PIN"
		pin_button.modulate = Tokens.PINK if not pinned else Color.WHITE
	app.toast("Table pinned above other windows." if not pinned else "Table unpinned.", "info")

func _build_right_rail() -> Control:
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	var body_size := 13 if access_scale >= 150 else 11
	var small_size := 11 if access_scale >= 150 else 9
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.PANEL_LINE, 10)
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(8)
	panel.add_child(box)

	intent_panel = PanelContainer.new()
	var intent_style := Tokens.panel_style(Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.55), Color(Tokens.PURPLE.r, Tokens.PURPLE.g, Tokens.PURPLE.b, 0.34), 1, 2)
	intent_style.content_margin_left = 10
	intent_style.content_margin_right = 10
	intent_style.content_margin_top = 9
	intent_style.content_margin_bottom = 9
	intent_panel.add_theme_stylebox_override("panel", intent_style)
	intent_panel.custom_minimum_size = Vector2(0, 92 if access_scale >= 150 else 78)
	var intent_box := UI.vbox(4)
	intent_panel.add_child(intent_box)
	intent_box.add_child(_caps("THE WARDEN"))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	intent_name_label = UI.display("", 22 if access_scale >= 150 else 18, Tokens.PURPLE)
	intent_name_label.visible = false
	intent_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(intent_name_label)
	intent_value_label = UI.data_label("—", 34 if access_scale >= 150 else 28, Tokens.INK_PRIMARY)
	intent_value_label.visible = false
	head.add_child(intent_value_label)
	intent_box.add_child(head)
	warden_meta_label = UI.label("HAND 0 · DECK 0", small_size, Tokens.INK_MUTED, Tokens.font_label())
	intent_box.add_child(warden_meta_label)
	intent_lane_map = LaneMap.new()
	intent_lane_map.custom_minimum_size = Vector2(0, 20 if access_scale >= 150 else 15)
	intent_box.add_child(intent_lane_map)
	intent_line_label = UI.label("", body_size, Tokens.INK_SECONDARY)
	intent_line_label.visible = false
	intent_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_box.add_child(intent_line_label)
	box.add_child(intent_panel)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	box.add_child(tabs)
	for pair in [["Log", "log"], ["Inspect", "inspect"], ["Actions", "actions"], ["Descent", "descent"]]:
		var key: String = pair[1]
		var button := UI.button(pair[0], _set_rail_tab.bind(key), Tokens.PANEL_LINE)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12 if access_scale >= 150 else 10)
		button.custom_minimum_size = Vector2(0, btn_h)
		rail_tabs[key] = button
		tabs.add_child(button)
	box.add_child(UI.hsep())
	# A plain wrapper stops a freshly built ScrollContainer from briefly lending
	# its child's height to the whole table. The rail must fit the room at once.
	var scroll_wrap := Control.new()
	scroll_wrap.custom_minimum_size = Vector2(0, 0)
	scroll_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll_wrap)
	rail_scroll = UI.scroll()
	rail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_wrap.add_child(rail_scroll)
	rail_content = UI.vbox(7)
	rail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_scroll.add_child(rail_content)
	return panel

func _set_rail_tab(tab: String) -> void:
	rail_tab = tab
	_refresh_rail()

func _refresh_all() -> void:
	_refresh_top()
	_refresh_board()
	_refresh_rail()

func _refresh_top() -> void:
	var floor_number := int(Session.descent.get("current_floor", 1))
	var circuit := int(ceil(float(floor_number) / 9.0))
	run_depth_label.text = "DEPTH %02d · CIRCUIT %d" % [floor_number, circuit]
	run_streak_label.text = "STREAK %d · CLEARED %d" % [int(Session.descent.get("streak", 0)), int(Session.descent.get("cleared", 0))]
	marks_label.text = "%s MARKS" % _fmt_number(int(Session.currency.get("marks", 0)))
	pause_button.text = "RESUME" if paused else "PAUSE"
	mode_button.text = mode.to_upper()
	recall_button.text = "QUEUED" if recall_queued else "RECALL"
	for value in speed_buttons.keys():
		var button: Button = speed_buttons[value]
		button.button_pressed = int(value) == speed
		button.modulate = Tokens.PINK if int(value) == speed else Tokens.INK_SECONDARY
	var player = duel.players[0]
	var ratio := float(player.resolve) / maxf(1.0, float(player.max_resolve))
	player_resolve_bar.set_value(player.resolve, player.max_resolve)
	player_resolve_bar.color = Tokens.DANGER if ratio <= 0.25 else (Tokens.AMBER if ratio <= 0.6 else Tokens.CYAN)
	player_resolve_label.text = _fmt_number(player.resolve)
	var status := "STEADY"
	var status_color := Tokens.GREEN
	if ratio <= 0.25:
		status = "CRITICAL"
		status_color = Tokens.DANGER
	elif ratio <= 0.6:
		status = "STRAINED"
		status_color = Tokens.AMBER
	player_status_label.text = "%s · %d%%" % [status, int(round(ratio * 100.0))]
	player_status_label.add_theme_color_override("font_color", status_color)
	_refresh_face_contract()
	player_resolve_label.add_theme_color_override("font_color", status_color if ratio <= 0.25 else Tokens.INK_PRIMARY)
	deck_button.text = "DECK %d" % player.deck.size()
	remains_button.text = "REMAINS %d" % player.remains.size()
	void_button.text = "VOID %d" % player.banished.size()
	player_hand_label.text = "HAND %d" % player.hand.size()
	current_intent = _compute_intent()
	if warden_meta_label != null:
		var warden = duel.players[1]
		warden_meta_label.text = "HAND %d · DECK %d" % [warden.hand.size(), warden.deck.size()]
	_refresh_intent()
	_refresh_dock()
	stage.set_auto_broadcast(mode == "auto")
	stage.set_target_lane(int(current_intent.get("lane", -1)))
	stage.queue_redraw()
	for key in rail_tabs.keys():
		var button: Button = rail_tabs[key]
		button.button_pressed = str(key) == rail_tab

func _compute_intent() -> Dictionary:
	var opponent_meta := Session.current_opponent()
	var raw_line = opponent_meta.get("tell", null)
	if raw_line == null:
		raw_line = opponent_meta.get("plan", "")
	var dry_line := "" if raw_line == null else str(raw_line).strip_edges()
	if dry_line.is_empty():
		dry_line = "The Warden keeps its own counsel."
	var data := {"title": "HOLD", "chip": "HOLD", "lane": -1, "value": "—", "line": dry_line, "color": Tokens.PURPLE}
	if duel == null or duel.ended:
		data["title"] = "SILENT"
		data["chip"] = "SILENT"
		data["line"] = "The table is still."
		return data
	var warden = duel.players[1]
	if duel.active == 1:
		match duel.phase:
			"clash":
				var strike := _forecast_strike(warden)
				if not strike.is_empty():
					return strike
				data["title"] = "HOLD"
				data["chip"] = "HOLD · GUARD"
				data["value"] = str(warden.monster_count())
				data["line"] = "The Warden has no face-up attacker. The guards hold the line."
			"call":
				data["title"] = "MUSTER"
				data["chip"] = "MUSTER"
				data["value"] = str(warden.hand.size())
				data["line"] = "%d cards held. The call stays hidden until it lands." % warden.hand.size()
			"actions":
				data["title"] = "PLOT"
				data["chip"] = "PLOT · BACKROW"
				data["value"] = str(warden.hand.size())
				data["line"] = "Spells and traps gather behind the guard."
			"dusk":
				data["title"] = "DUSK"
				data["chip"] = "DUSK"
				data["value"] = "—"
				data["line"] = "The turn closes. The Warden counts what remains."
			"dawn":
				data["title"] = "WAKE"
				data["chip"] = "WAKE"
				data["value"] = "—"
				data["line"] = "The Warden draws breath before the first phase."
			"draw":
				data["title"] = "DRAW"
				data["chip"] = "DRAW"
				data["value"] = "—"
				data["line"] = "A card leaves the Warden's deck."
		return data
	if warden.monster_count() <= 0:
		data["title"] = "OPEN"
		data["chip"] = "OPEN · FACE"
		data["value"] = "0"
		data["line"] = "No guard remains. The face can be struck directly."
		data["color"] = Tokens.GREEN
		return data
	var threat = _strongest_attacker(warden)
	var guards := warden.monster_count()
	if threat != null:
		var stats: Dictionary = duel.stats_for(threat)
		data["title"] = "THREAT"
		data["chip"] = "THREAT · LANE %s" % _roman(threat.lane)
		data["lane"] = threat.lane
		data["value"] = _fmt_number(int(stats["atk"]))
		data["line"] = "%s holds Lane %s. The face is sealed while %d guard%s %s." % [threat.display_name(), _roman(threat.lane), guards, "" if guards == 1 else "s", "stands" if guards == 1 else "stand"]
		data["color"] = Tokens.PINK
	else:
		data["title"] = "GUARD"
		data["chip"] = "GUARDS · FACE SEALED"
		data["value"] = str(guards)
		data["line"] = "%d guard%s %s the monster zones. Strike a lane before the face." % [guards, "" if guards == 1 else "s", "holds" if guards == 1 else "hold"]
		data["color"] = Tokens.PINK
	return data

func _forecast_strike(warden) -> Dictionary:
	var best: DuelCard = null
	var best_atk := -1
	for monster in warden.monsters:
		if monster == null or monster.face_down or not monster.is_attack_position():
			continue
		var stats: Dictionary = duel.stats_for(monster)
		if int(stats["atk"]) > best_atk:
			best = monster
			best_atk = int(stats["atk"])
	if best == null:
		return {}
	var target_lane := best.lane
	var lowest_def := 999999
	for lane in range(3):
		var target = duel.players[0].monsters[lane]
		if target == null:
			continue
		var stats: Dictionary = duel.stats_for(target)
		if int(stats["defense"]) < lowest_def:
			lowest_def = int(stats["defense"])
			target_lane = lane
	return {
		"title": "STRIKE",
		"chip": "STRIKE · LANE %s" % _roman(target_lane),
		"lane": target_lane,
		"value": _fmt_number(best_atk),
		"line": "%s is committed. Lane %s is the open wound." % [best.display_name(), _roman(target_lane)],
		"color": Tokens.PINK,
	}

func _strongest_attacker(player) -> DuelCard:
	var best: DuelCard = null
	var best_atk := -1
	for monster in player.monsters:
		if monster == null or monster.face_down or not monster.is_attack_position():
			continue
		var stats: Dictionary = duel.stats_for(monster)
		if int(stats["atk"]) > best_atk:
			best = monster
			best_atk = int(stats["atk"])
	return best

func _refresh_face_contract() -> void:
	if player_face_label == null:
		return
	var guards := _guard_count(0)
	if guards > 0:
		player_face_label.text = "◆ FACE SEALED · %d" % guards
		player_face_label.add_theme_color_override("font_color", Tokens.PINK)
	else:
		player_face_label.text = "◇ FACE OPEN"
		player_face_label.add_theme_color_override("font_color", Tokens.GREEN)

func _refresh_intent() -> void:
	if current_intent.is_empty():
		return
	var color: Color = current_intent.get("color", Tokens.PURPLE)
	intent_name_label.text = str(current_intent.get("title", "HOLD")).to_upper()
	intent_name_label.add_theme_color_override("font_color", color)
	intent_value_label.text = str(current_intent.get("value", "—"))
	intent_value_label.add_theme_color_override("font_color", color if color != Tokens.INK_PRIMARY else Tokens.INK_PRIMARY)
	intent_lane_map.set_lane(int(current_intent.get("lane", -1)), color)
	intent_line_label.text = str(current_intent.get("line", ""))
	var style := intent_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = Color(color.r, color.g, color.b, 0.36)

func _refresh_dock() -> void:
	if strike_button == null or duel == null:
		return
	var attacks := _legal_attacks()
	var chosen := _dock_attack_action(attacks)
	var can_act := mode == "manual" and duel.active == 0 and not duel.ended and not busy
	strike_button.disabled = not can_act or chosen.is_empty()
	if not can_act:
		if busy:
			strike_sub.text = "RESOLVING…"
		elif mode == "auto":
			strike_sub.text = "AUTO IS PILOTING"
		elif mode == "suggest":
			strike_sub.text = "SUGGEST MODE"
		elif duel.ended:
			strike_sub.text = "DUEL ENDED"
		else:
			strike_sub.text = "WARDEN ACTING"
	elif chosen.is_empty():
		if _guard_count(1) > 0:
			strike_sub.text = "STRIKE A GUARD LANE"
		else:
			strike_sub.text = "SELECT A MONSTER"
	else:
		var attacker: DuelCard = null
		for card in duel.players[0].monsters:
			if card != null and card.uid == int(chosen.get("uid", -1)):
				attacker = card
				break
		var lane := int(chosen.get("target_lane", -1))
		strike_sub.text = "%s → LANE %s" % [attacker.display_name() if attacker != null else "STRIKE", _roman(lane)]
	if strike_sub.text.length() > 30:
		strike_sub.text = strike_sub.text.substr(0, 29) + "…"
	end_button.disabled = not can_act
	end_sub.text = "NEXT STEP"
	reset_button.disabled = duel.ended

func _dock_attack_action(attacks: Array[Dictionary]) -> Dictionary:
	if selected_board_uid != -1:
		for action in attacks:
			if int(action.get("uid", -1)) == selected_board_uid:
				return action
		return {}
	var uids: Dictionary = {}
	for action in attacks:
		uids[int(action.get("uid", -1))] = true
	if uids.size() == 1:
		return attacks[0]
	return {}

func _legal_attacks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if duel == null or duel.ended:
		return out
	for action in DuelRules.legal_actions(duel):
		if str(action.get("type", "")) == "attack":
			out.append(action)
	return out

func _guard_count(owner: int) -> int:
	if duel == null:
		return 0
	var count := 0
	for monster in duel.players[owner].monsters:
		if monster != null:
			count += 1
	return count

func _dock_strike() -> void:
	if busy:
		return
	var chosen := _dock_attack_action(_legal_attacks())
	if chosen.is_empty():
		app.toast("Select a monster, then strike a guard lane.", "info")
		return
	_apply_player_action(chosen)

func _dock_end() -> void:
	if busy or mode != "manual" or duel.active != 0 or duel.ended:
		return
	_apply_player_action({"type": "end_phase"})

func _dock_reset() -> void:
	selected_hand_uid = -1
	selected_board_uid = -1
	inspected_card = null
	suggestion = {}
	rail_tab = "log"
	stage.set_hand_selected(-1)
	stage.set_board_selected(-1)
	stage.set_focus_lane(-1)
	log_tab_built = false
	log_shown_count = 0
	_refresh_all()

static func _fmt_number(value: int) -> String:
	return UI.format_number(value)

static func _roman(lane: int) -> String:
	match lane:
		0:
			return "I"
		1:
			return "II"
		2:
			return "III"
		_:
			return "—"

func _refresh_board() -> void:
	legal_cache = DuelRules.legal_actions(duel)
	stage.set_duel(duel)
	stage.set_hand_selected(selected_hand_uid)
	stage.set_board_selected(selected_board_uid)
	stage.sync_all(duel)
	stage.apply_rest(duel)
	var zones: Dictionary = {}
	if mode == "manual" and duel.active == 0 and not duel.ended:
		if selected_hand_uid != -1:
			for action in legal_cache:
				if int(action.get("uid", -1)) != selected_hand_uid:
					continue
				var type := str(action.get("type", ""))
				if type == "call":
					zones["0|monster|%d" % int(action.get("lane", -1))] = true
				elif type == "play" or type == "set_card":
					zones["0|backrow|%d" % int(action.get("lane", -1))] = true
		elif selected_board_uid != -1:
			for action in legal_cache:
				if str(action.get("type", "")) == "attack" and int(action.get("uid", -1)) == selected_board_uid:
					zones["1|monster|%d" % int(action.get("target_lane", -1))] = true
	stage.set_legal_zones(zones)
	var playable: Dictionary = {}
	if mode == "manual" and duel.active == 0 and not duel.ended:
		for action in legal_cache:
			var action_type := str(action.get("type", ""))
			if action_type in ["call", "play", "set_card", "activate"]:
				playable[int(action.get("uid", -1))] = true
	stage.set_playable_hands(playable)
	_refresh_dock()

func _refresh_rail() -> void:
	# The log appends while it is visible; switching tabs rebuilds that tab only.
	if rail_tab == "log" and log_tab_built and log_box != null and is_instance_valid(log_box):
		_append_log_entries()
		return
	for child in rail_content.get_children():
		rail_content.remove_child(child)
		child.queue_free()
	log_tab_built = false
	log_box = null
	log_shown_count = 0
	match rail_tab:
		"inspect":
			_build_inspect()
		"actions":
			_build_actions()
		"descent":
			_build_descent()
		_:
			_build_log()

func _build_log() -> void:
	rail_content.add_child(_caps("TABLE LOG"))
	rail_content.add_child(UI.hsep())
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 5)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_content.add_child(log_box)
	log_tab_built = true
	log_shown_count = 0
	_append_log_entries()

func _append_log_entries() -> void:
	if log_box == null or not is_instance_valid(log_box):
		return
	log_shown_count = mini(log_shown_count, duel.log.size())
	for i in range(log_shown_count, duel.log.size()):
		var entry: Dictionary = duel.log[i]
		var text := str(entry.get("text", ""))
		var kind := str(entry.get("kind", "info"))
		var color := Tokens.INK_SECONDARY
		match kind:
			"turn":
				color = Tokens.PINK
			"phase":
				color = Tokens.INK_MUTED
			"damage", "direct":
				color = Tokens.DANGER
			"heal":
				color = Tokens.GREEN
			"attack", "battle":
				color = Tokens.PINK
			"destroy", "end":
				color = Tokens.PINK
			"call", "play", "set":
				color = Tokens.INK_PRIMARY
		var label_node := UI.label(text, 13 if access_scale >= 150 else 11, color, Tokens.font_data_regular())
		label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		log_box.add_child(label_node)
	log_shown_count = duel.log.size()
	call_deferred("_scroll_rail")

func _scroll_rail() -> void:
	if rail_scroll != null and is_instance_valid(rail_scroll):
		var bar := rail_scroll.get_v_scroll_bar()
		if bar.value >= bar.max_value - 40.0:
			rail_scroll.scroll_vertical = int(bar.max_value)

func _build_inspect() -> void:
	var body_size := 14 if access_scale >= 150 else 12
	var small_size := 12 if access_scale >= 150 else 10
	rail_content.add_child(_caps("INSPECT"))
	rail_content.add_child(UI.hsep())
	if inspected_card == null:
		rail_content.add_child(UI.label("No card inspected.", body_size, Tokens.INK_MUTED))
		return
	var hidden := inspected_card.owner == 1 and inspected_card.face_down
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Tokens.card_size("M")
	rail_content.add_child(holder)
	var view := CardView.new()
	view.set_card(inspected_card.def, inspected_card.instance, "M")
	view.set_flag("face_down", hidden)
	if not hidden:
		view.double_clicked.connect(func(_view: CardView) -> void: app.show_zoom(inspected_card.def, inspected_card.instance))
	holder.add_child(view)
	if hidden:
		rail_content.add_child(UI.label("Set card. Position hidden.", body_size, Tokens.INK_MUTED))
		return
	rail_content.add_child(UI.display(inspected_card.display_name(), 20 if access_scale >= 150 else 17))
	rail_content.add_child(UI.label(inspected_card.def.type_line, small_size, Tokens.INK_SECONDARY))
	var stats := duel.stats_for(inspected_card) if inspected_card.is_monster() else {}
	if inspected_card.is_monster():
		rail_content.add_child(UI.data_label("ATK %d · DEF %d · OFFER %d" % [stats["atk"], stats["defense"], stats["offer"]], small_size, Tokens.INK_PRIMARY))
		var keywords := duel.keywords_for(inspected_card)
		if not keywords.is_empty():
			rail_content.add_child(UI.label("KEYWORDS: " + ", ".join(keywords.keys()).to_upper(), small_size, Tokens.attribute_color(inspected_card.def.attribute)))
	var rules := UI.label(inspected_card.def.text, body_size, Tokens.INK_SECONDARY)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rail_content.add_child(rules)
	if inspected_card.instance != null and not inspected_card.instance.mods.is_empty():
		for line in CardResolver.mod_lines(inspected_card.instance, Content.mods):
			rail_content.add_child(UI.label("· " + line, small_size, Tokens.VERDIGRIS))
	if not inspected_card.buffs.is_empty():
		for buff in inspected_card.buffs:
			rail_content.add_child(UI.label("%s%+d %s" % [str(buff.get("stat", "")).to_upper(), int(buff.get("amount", 0)), str(buff.get("duration", ""))], small_size, Tokens.GOLD))

func _build_actions() -> void:
	var body_size := 14 if access_scale >= 150 else 12
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	rail_content.add_child(_caps("LEGAL ACTIONS"))
	rail_content.add_child(UI.hsep())
	if duel.ended:
		rail_content.add_child(UI.label("Duel over.", body_size, Tokens.INK_MUTED))
		return
	if duel.active != 0:
		rail_content.add_child(UI.label("Warden acting.", body_size, Tokens.INK_MUTED))
		return
	if mode == "auto":
		rail_content.add_child(UI.label("Auto is piloting.", body_size, Tokens.INK_SECONDARY))
		var take := UI.button("TAKE CONTROL", func() -> void:
			mode = "manual"
			Session.settings["mode"] = "manual"
			_refresh_all()
		, Tokens.BRASS)
		take.custom_minimum_size = Vector2(0, btn_h)
		take.add_theme_font_size_override("font_size", body_size)
		rail_content.add_child(take)
		return
	if mode == "suggest":
		if suggestion.is_empty():
			suggestion = DuelAI.choose_action(duel, 70)
		rail_content.add_child(UI.label("SUGGESTED", 11 if access_scale >= 150 else 9, Tokens.VERDIGRIS))
		rail_content.add_child(UI.label(str(suggestion.get("label", "End the phase.")), body_size, Tokens.INK_PRIMARY))
		var confirm := UI.button("CONFIRM", func() -> void:
			var chosen := suggestion
			suggestion = {}
			_apply_player_action(chosen)
		, Tokens.GOOD)
		confirm.custom_minimum_size = Vector2(0, btn_h)
		confirm.add_theme_font_size_override("font_size", body_size)
		rail_content.add_child(confirm)
		var override := UI.button("OVERRIDE", func() -> void:
			mode = "manual"
			Session.settings["mode"] = "manual"
			suggestion = {}
			_refresh_all()
		, Tokens.BRASS_LO)
		override.custom_minimum_size = Vector2(0, btn_h)
		override.add_theme_font_size_override("font_size", body_size)
		rail_content.add_child(override)
		return
	var end_phase := UI.button("END PHASE  [E]", func() -> void: _apply_player_action({"type": "end_phase"}), Tokens.BRASS)
	end_phase.custom_minimum_size = Vector2(0, btn_h)
	end_phase.add_theme_font_size_override("font_size", body_size)
	rail_content.add_child(end_phase)
	rail_content.add_child(UI.hsep())
	var actions := legal_cache
	var filtered: Array[Dictionary] = []
	if selected_hand_uid != -1:
		for action in actions:
			if int(action.get("uid", -1)) == selected_hand_uid:
				filtered.append(action)
	elif selected_board_uid != -1:
		for action in actions:
			if int(action.get("uid", -1)) == selected_board_uid and str(action.get("type", "")) == "attack":
				filtered.append(action)
	if selected_hand_uid == -1 and selected_board_uid == -1:
		rail_content.add_child(UI.label("No card selected.", body_size, Tokens.INK_MUTED))
	else:
		for action in filtered:
			if str(action.get("type", "")) in ["resign", "end_phase"]:
				continue
			var button := UI.button(str(action.get("label", str(action.get("type", "")))), _apply_player_action.bind(action), Tokens.BRASS_LO)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(0, btn_h)
			button.add_theme_font_size_override("font_size", body_size)
			rail_content.add_child(button)
		if filtered.is_empty() and selected_board_uid != -1 and _guard_count(1) > 0:
			var sealed := UI.label("The face is sealed. Strike a guard lane.", body_size, Tokens.PINK)
			sealed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rail_content.add_child(sealed)
	if duel.turn >= 50:
		var resign := UI.button("RESIGN", _resign, Tokens.WAX)
		resign.custom_minimum_size = Vector2(0, btn_h)
		resign.add_theme_font_size_override("font_size", body_size)
		rail_content.add_child(resign)

func _build_descent() -> void:
	var body_size := 13 if access_scale >= 150 else 11
	var btn_h := 48.0 if access_scale >= 150 else 44.0
	rail_content.add_child(_caps("DESCENT"))
	rail_content.add_child(UI.hsep())
	var grid := GridContainer.new()
	grid.columns = 2
	for pair in [
		["Depth", str(int(Session.descent.get("current_floor", 1)))],
		["Cleared", str(int(Session.descent.get("cleared", 0)))],
		["Best", str(maxi(int(Session.descent.get("deepest", 1)), int(Session.deepest_floor)))],
		["Streak", str(int(Session.descent.get("streak", 0)))],
		["Marks won", str(int(Session.descent.get("marks_won", 0)))],
		["Underdog", "+%d%%" % int(round(float(Session.descent.get("underdog", 0.0)) * 100.0))],
	]:
		grid.add_child(UI.label(pair[0], body_size, Tokens.INK_MUTED))
		grid.add_child(UI.data_label(pair[1], body_size, Tokens.INK_SECONDARY))
	rail_content.add_child(grid)
	rail_content.add_child(UI.hsep())
	var recall := UI.button("RECALL AFTER THIS DUEL", _queue_recall, Tokens.VERDIGRIS)
	recall.custom_minimum_size = Vector2(0, btn_h)
	recall.add_theme_font_size_override("font_size", body_size)
	rail_content.add_child(recall)

func _on_tick() -> void:
	if duel == null or duel.ended or paused or resolving or busy or result_overlay != null:
		return
	if mode == "manual" and duel.active == 0:
		return
	if mode == "suggest" and duel.active == 0:
		if suggestion.is_empty():
			suggestion = DuelAI.choose_action(duel, 70)
			if rail_tab == "actions":
				_refresh_rail()
		return
	var action := DuelAI.choose_action(duel, 70)
	if action.is_empty():
		action = {"type": "end_phase"}
	await _apply_and_animate(action, duel.active)
	if mode == "manual":
		rail_tab = "actions"

func _apply_player_action(action: Dictionary) -> void:
	if action.is_empty() or duel.ended or busy:
		return
	await _apply_and_animate(action, 0)

func _apply_and_animate(action: Dictionary, player: int) -> void:
	if busy or duel == null or duel.ended:
		return
	busy = true
	var before := stage.capture_layout(duel)
	var result := DuelRules.apply(duel, player, action)
	if not bool(result.get("ok", false)):
		busy = false
		app.toast(str(result.get("reason", "Illegal action.")), "bad")
		return
	# The guard contract updates on the same frame as the board, not after the
	# whole animation, so the score pips never contradict a lane state.
	stage.queue_redraw()
	_refresh_face_contract()
	var after := stage.capture_layout(duel)
	var events := duel.drain_events()
	await _play_events(events, before, after)
	if not is_inside_tree():
		return
	stage.sync_all(duel)
	stage.apply_rest(duel)
	selected_hand_uid = -1
	selected_board_uid = -1
	stage.set_hand_selected(-1)
	stage.set_board_selected(-1)
	if mode != "auto":
		stage.set_focus_lane(-1)
	if mode == "manual":
		rail_tab = "actions"
	busy = false
	_refresh_top()
	_refresh_board()
	_refresh_rail()
	if duel.ended:
		_on_duel_end()

func _play_events(events: Array[Dictionary], before: Dictionary, after: Dictionary) -> void:
	for event in events:
		if not is_inside_tree():
			return
		var kind := str(event.get("type", ""))
		var uid := int(event.get("card_uid", -1))
		var card := _find_card(uid) if uid > 0 else null
		stage.set_cue(_cue_for(event), _cue_color(event))
		match kind:
			"turn":
				stage.set_focus_lane(-1)
				stage.set_impact(-1, -1)
				await _wait(_dur(0.08))
			"phase":
				stage.set_focus_lane(-1)
				await _wait(_dur(0.08))
			"draw":
				if card == null:
					continue
				if card.owner == 1:
					# The opponent hand is a small stack, not a card-sized object.
					fx.ring(stage.opp_hand_rect.get_center(), Tokens.PINK, 12.0, _dur(0.22))
					await _wait(_dur(0.12))
					continue
				var actor := stage.ensure_actor(card, stage.hand_token)
				var hand_size := Tokens.card_size(stage.hand_token)
				var draw_start := Rect2(Vector2(stage.deck_rect.position.x, stage.deck_rect.end.y - hand_size.y), hand_size)
				actor.set_rest(draw_start)
				actor.set_token(stage.hand_token)
				actor.set_angle(0.0)
				actor.refresh()
				var target: Rect2 = after.get(uid, stage.rest_rect_for(card, duel))
				await actor.move_to(target, _dur(0.18))
				fx.ring(target.get_center(), Tokens.CYAN, 12.0, _dur(0.22))
			"call":
				if card == null:
					continue
				var lane := int(event.get("lane", 0))
				stage.set_focus_lane(lane)
				var actor := stage.ensure_actor(card, stage.board_token)
				var source: Rect2 = before.get(uid, stage.opp_hand_rect if card.owner == 1 else stage.hand_rects.get(uid, stage.deck_rect))
				actor.set_rest(source)
				actor.set_token(stage.board_token)
				actor.set_angle(0.0)
				actor.refresh()
				var target: Rect2 = after.get(uid, stage.rest_rect_for(card, duel))
				await actor.move_to(target, _dur(0.22))
				fx.ring(target.get_center(), Tokens.PINK, 24.0, _dur(0.24))
			"set":
				if card == null:
					continue
				var lane := int(event.get("lane", 0))
				stage.set_focus_lane(lane)
				var actor := stage.ensure_actor(card, stage.back_token)
				var source: Rect2 = before.get(uid, stage.opp_hand_rect if card.owner == 1 else stage.deck_rect)
				actor.set_rest(source)
				actor.set_token(stage.back_token)
				actor.set_angle(0.0)
				actor.view.face_down = false
				actor.refresh()
				var target: Rect2 = after.get(uid, stage.rest_rect_for(card, duel))
				await actor.move_to(target, _dur(0.20))
				actor.view.face_down = true
				actor.view.queue_redraw()
				actor.set_ad("A" if card.is_monster() and card.is_attack_position() else "D")
				fx.ring(target.get_center(), Tokens.GREEN, 18.0, _dur(0.20))
			"play":
				if card == null:
					continue
				var actor := stage.ensure_actor(card, stage.back_token)
				actor.set_angle(0.0)
				var home := actor.rest_rect
				await actor.move_to(Rect2(home.position - Vector2(0, 22), home.size), _dur(0.12))
				fx.ring(home.get_center(), Tokens.CYAN, 28.0, _dur(0.24))
				await actor.exit_to(after.get(uid, stage.remains_rect), _dur(0.26), true)
				stage.actors.erase(uid)
			"discard":
				if card == null:
					continue
				var actor := stage.ensure_actor(card, stage.hand_token)
				actor.set_angle(0.0)
				actor.set_rest(before.get(uid, stage.hand_rects.get(uid, stage.deck_rect)))
				await actor.exit_to(after.get(uid, stage.remains_rect), _dur(0.22), true)
				stage.actors.erase(uid)
			"attack":
				if card == null:
					continue
				var actor := stage.ensure_actor(card, stage.board_token)
				var home := actor.rest_rect
				var target_lane := int(event.get("target_lane", 0))
				var target_owner := 1 - int(event.get("player", 0))
				stage.set_focus_lane(target_lane)
				stage.set_impact(target_owner, target_lane)
				var target_rect: Rect2 = stage.zone_rects.get("%d|monster|%d" % [target_owner, target_lane], home)
				var direction := (target_rect.get_center() - home.get_center()).normalized()
				fx.arrow(home.get_center(), target_rect.get_center(), Tokens.PINK, 2.0, _dur(0.26))
				await actor.move_to(Rect2(home.position + direction * 8.0, home.size), _dur(0.10))
				await _wait(_dur(0.05))
				fx.spark(target_rect.get_center(), Tokens.PINK, _dur(0.28))
				await actor.move_to(home, _dur(0.14))
			"damage":
				var target_owner := int(event.get("player", 1))
				var amount := int(event.get("amount", 0))
				var pos := _impact_position(target_owner)
				fx.plate(pos, "-%s" % _fmt_number(amount), "RESOLVE", Tokens.DANGER, _dur(0.95))
				stage.set_impact(-1, -1)
				await _wait(_dur(0.18))
			"heal":
				var target_owner := int(event.get("player", 0))
				var amount := int(event.get("amount", 0))
				var pos := _impact_position(target_owner)
				fx.plate(pos, "+%s" % _fmt_number(amount), "RESOLVE", Tokens.GREEN, _dur(0.85))
				fx.ring(pos, Tokens.GREEN, 18.0, _dur(0.30))
				await _wait(_dur(0.16))
			"destroy":
				var actor := stage.actor_for(uid)
				if actor == null:
					continue
				stage.set_focus_lane(actor.card.lane)
				var target: Rect2 = after.get(uid, stage.remains_rect)
				fx.spark(actor.rest_rect.get_center(), Tokens.PINK, _dur(0.28))
				await actor.exit_to(target, _dur(0.28), true)
				stage.actors.erase(uid)
			"banish":
				var actor := stage.actor_for(uid)
				if actor == null:
					continue
				stage.set_focus_lane(actor.card.lane)
				var target: Rect2 = after.get(uid, stage.void_rect)
				fx.ring(actor.rest_rect.get_center(), Tokens.PURPLE, 22.0, _dur(0.28))
				await actor.exit_to(target, _dur(0.28), true)
				stage.actors.erase(uid)
			"flip":
				var actor := stage.actor_for(uid)
				if actor != null:
					actor.view.face_down = false
					actor.refresh()
					actor.pulse(Tokens.PINK)
					await _wait(_dur(0.12))
			"activate":
				var actor := stage.actor_for(uid)
				if actor != null:
					actor.pulse(Tokens.CYAN)
					fx.ring(actor.rest_rect.get_center(), Tokens.CYAN, 20.0, _dur(0.24))
					await _wait(_dur(0.12))
			"negate":
				fx.ring(_impact_position(int(event.get("player", 1))), Tokens.PINK, 30.0, _dur(0.24))
				await _wait(_dur(0.10))
			"offer":
				var actor := stage.actor_for(uid)
				if actor != null:
					await actor.exit_to(after.get(uid, stage.remains_rect), _dur(0.22), true)
					stage.actors.erase(uid)
			"buff":
				var actor := stage.actor_for(uid)
				if actor != null:
					actor.pulse(Tokens.AMBER)
					await _wait(_dur(0.10))
			"return":
				if card == null:
					continue
				var actor := stage.ensure_actor(card, stage.hand_token)
				actor.set_angle(0.0)
				actor.set_rest(stage.remains_rect)
				var target: Rect2 = after.get(uid, stage.rest_rect_for(card, duel))
				await actor.move_to(target, _dur(0.22))
			"token":
				if card == null:
					continue
				var lane := int(event.get("lane", 0))
				stage.set_focus_lane(lane)
				var actor := stage.ensure_actor(card, stage.board_token)
				var target: Rect2 = after.get(uid, stage.rest_rect_for(card, duel))
				actor.set_rest(target)
				fx.ring(target.get_center(), Tokens.PINK, 26.0, _dur(0.30))
				await _wait(_dur(0.12))
			"end":
				stage.set_focus_lane(-1)
				await _wait(_dur(0.12))
			_:
				pass

func _impact_position(owner: int) -> Vector2:
	var lane := stage.impact_lane if stage.impact_owner == owner else 1
	var key := "%d|monster|%d" % [owner, maxi(0, lane)]
	var rect: Rect2 = stage.slot_rects.get(key, Rect2())
	if rect.size.x > 0:
		return rect.get_center()
	return Vector2(stage.size.x * 0.5, stage.board_rect.get_center().y)

func _cue_for(event: Dictionary) -> String:
	var kind := str(event.get("type", ""))
	match kind:
		"turn":
			return "TURN %d · %s" % [int(event.get("turn", 0)), "YOU" if int(event.get("player", 0)) == 0 else "WARDEN"]
		"phase":
			# Phase is carried by the six ticks in the score rail; no phase name
			# belongs on the felt.
			return ""
		"draw":
			return "DRAW · %s" % ("YOU" if int(event.get("player", 0)) == 0 else "WARDEN")
		"call":
			return "CALL · %s · LANE %s" % [str(event.get("name", "MONSTER")).to_upper(), _roman(int(event.get("lane", 0)))]
		"set":
			return "SET · LANE %s" % _roman(int(event.get("lane", 0)))
		"play":
			return "SPELL · %s" % str(event.get("name", "SPELL")).to_upper()
		"attack":
			return "STRIKE · LANE %s" % _roman(int(event.get("target_lane", 0)))
		"damage":
			return "-%s · %s RESOLVE" % [_fmt_number(int(event.get("amount", 0))), "YOU" if int(event.get("player", 1)) == 0 else "WARDEN"]
		"heal":
			return "+%s · %s RESOLVE" % [_fmt_number(int(event.get("amount", 0))), "YOU" if int(event.get("player", 0)) == 0 else "WARDEN"]
		"destroy":
			return "DESTROYED · %s" % str(event.get("name", "CARD")).to_upper()
		"banish":
			return "BANISHED · %s" % str(event.get("name", "CARD")).to_upper()
		"flip":
			return "FLIP · %s" % str(event.get("name", "CARD")).to_upper()
		"activate":
			return "ACTIVATE · %s" % str(event.get("name", "CARD")).to_upper()
		"negate":
			return "NEGATED · LANE %s" % _roman(int(event.get("target_lane", 0)))
		"offer":
			return "OFFER · %s" % str(event.get("name", "CARD")).to_upper()
		"buff":
			return "BUFF · %s" % str(event.get("stat", "")).to_upper()
		"token":
			return "TOKEN · LANE %s" % _roman(int(event.get("lane", 0)))
		"end":
			return "THE DUEL ENDS"
		_:
			return kind.replace("_", " ").to_upper()

func _cue_color(event: Dictionary) -> Color:
	match str(event.get("type", "")):
		"damage", "destroy", "attack", "negate":
			return Tokens.PINK
		"heal":
			return Tokens.GREEN
		"call", "play", "set", "draw", "activate", "token":
			return Tokens.CYAN
		"end":
			return Tokens.AMBER
		_:
			return Tokens.INK_SECONDARY

func _dur(base: float) -> float:
	if bool(Session.settings.get("reduced_motion", false)):
		return 0.001
	if speed >= 4:
		return 0.04
	if speed >= 2:
		return base * 0.65
	return base

func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.001, seconds)).timeout

func _find_card(uid: int) -> DuelCard:
	if duel == null or uid <= 0:
		return null
	for player in duel.players:
		for card in player.hand:
			if card.uid == uid:
				return card
		for card in player.monsters:
			if card != null and card.uid == uid:
				return card
		for card in player.backrow:
			if card != null and card.uid == uid:
				return card
		for card in player.remains:
			if card.uid == uid:
				return card
		for card in player.banished:
			if card.uid == uid:
				return card
		for card in player.deck:
			if card.uid == uid:
				return card
	return null

func _on_stage_card_clicked(card: DuelCard) -> void:
	if card == null:
		return
	inspected_card = card
	if card.owner == 0 and card.zone == GameConst.ZONE_HAND:
		_on_hand_card_clicked(card.uid)
		return
	if mode == "manual" and duel.active == 0 and not duel.ended:
		if card.owner == 1 and selected_board_uid != -1 and card.is_monster():
			var action := _attack_action(selected_board_uid, card.lane)
			if not action.is_empty():
				_apply_player_action(action)
				return
		if card.owner == 0 and card.is_monster():
			selected_board_uid = card.uid if selected_board_uid != card.uid else -1
			selected_hand_uid = -1
			stage.set_board_selected(selected_board_uid)
			_refresh_board()
			rail_tab = "actions"
			_refresh_rail()
			return
		if selected_hand_uid != -1:
			var action := _action_for_zone(card.zone, card.owner, card.lane, Input.is_key_pressed(KEY_SHIFT))
			if not action.is_empty():
				_apply_player_action(action)
				return
	rail_tab = "inspect"
	_refresh_rail()

func _on_stage_card_right_clicked(card: DuelCard, _pos: Vector2) -> void:
	if card != null:
		inspected_card = card
		rail_tab = "inspect"
		_refresh_rail()

func _on_stage_zone_clicked(owner: int, zone: String, lane: int) -> void:
	if mode != "manual" or duel.active != 0 or duel.ended:
		return
	if selected_hand_uid != -1:
		var action := _action_for_zone(zone, owner, lane, Input.is_key_pressed(KEY_SHIFT))
		if not action.is_empty():
			_apply_player_action(action)
		return
	if selected_board_uid != -1 and owner == 1 and zone == "monster":
		var action := _attack_action(selected_board_uid, lane)
		if not action.is_empty():
			_apply_player_action(action)

func _on_hand_card_clicked(uid: int) -> void:
	selected_hand_uid = uid if selected_hand_uid != uid else -1
	selected_board_uid = -1
	var card: DuelCard = null
	for hand_card in duel.players[0].hand:
		if hand_card.uid == uid:
			card = hand_card
			break
	if card != null:
		inspected_card = card
		if mode == "manual" and duel.active == 0 and rail_tab == "log":
			rail_tab = "actions"
	stage.set_hand_selected(selected_hand_uid)
	stage.set_board_selected(-1)
	_refresh_board()
	_refresh_rail()

func _action_for_zone(zone_type: String, owner: int, lane: int, shift: bool) -> Dictionary:
	if owner != 0:
		return {}
	for action in DuelRules.legal_actions(duel):
		var type := str(action.get("type", ""))
		if int(action.get("uid", -1)) != selected_hand_uid:
			continue
		if zone_type == "monster" and type == "call" and int(action.get("lane", -1)) == lane:
			if shift:
				if bool(action.get("face_down", false)) and str(action.get("position", "")) == GameConst.POSITION_DEFENSE:
					return action
			elif not bool(action.get("face_down", false)):
				return action
		if zone_type == "backrow" and int(action.get("lane", -1)) == lane:
			if shift and type == "set_card":
				return action
			if not shift and type == "play":
				return action
			if not shift and type == "set_card":
				var card: DuelCard = null
				for hand_card in duel.players[0].hand:
					if hand_card.uid == selected_hand_uid:
						card = hand_card
						break
				if card != null and card.is_trap():
					return action
	return {}

func _attack_action(attacker_uid: int, target_lane: int) -> Dictionary:
	for action in DuelRules.legal_actions(duel):
		if str(action.get("type", "")) == "attack" and int(action.get("uid", -1)) == attacker_uid and int(action.get("target_lane", -1)) == target_lane:
			return action
	return {}

func _on_duel_end() -> void:
	if resolving:
		return
	resolving = true
	paused = true
	var result := Session.finish_duel(duel)
	if not bool(result.get("ok", false)):
		app.toast(str(result.get("reason", "The duel ended.")), "bad")
		app.go_gate()
		resolving = false
		return
	if recall_queued and str(result.get("kind", "")) == "win":
		if _recall_now():
			return
	# Aftermath: let the last impact land before the ledger takes the screen.
	await _wait(_dur(0.28))
	if not is_inside_tree():
		return
	_show_result(result)
	resolving = false

func _show_result(result: Dictionary) -> void:
	if result_overlay != null and is_instance_valid(result_overlay):
		result_overlay.queue_free()
	var ceremony := ResultCeremony.new()
	add_child(ceremony)
	ceremony.setup(self, result)
	result_overlay = ceremony

func _choose_door(choice: String) -> bool:
	var result: Dictionary = Session.apply_door(choice)
	if not bool(result.get("ok", false)):
		app.toast(str(result.get("reason", "Cannot open that door.")), "bad")
		return false
	return _next_floor()

func _next_floor() -> bool:
	var next_duel := Session.make_duel()
	if next_duel == null:
		app.go_gate()
		return false
	if result_overlay != null and is_instance_valid(result_overlay):
		result_overlay.queue_free()
		result_overlay = null
	duel = next_duel
	selected_hand_uid = -1
	selected_board_uid = -1
	inspected_card = null
	suggestion = {}
	recall_queued = false
	paused = false
	busy = false
	rail_tab = "actions" if mode == "manual" else "log"
	log_tab_built = false
	log_shown_count = 0
	stage.set_duel(duel)
	stage.set_focus_lane(-1)
	stage.set_impact(-1, -1)
	stage.actors.clear()
	for child in stage.get_children():
		if child is CardActor:
			child.queue_free()
	_refresh_all()
	if timer != null:
		timer.start()
	return true

func _recall_now() -> bool:
	var returned := Session.recall()
	if not bool(returned.get("ok", false)):
		app.toast(str(returned.get("reason", "Recall is not available.")), "bad")
		return false
	app.go_salvage(returned, true)
	return true

func _queue_recall() -> void:
	recall_queued = true
	app.toast("Recall queued. The duel resolves first.", "info")
	_refresh_top()

func _resign() -> void:
	if duel.turn < 50:
		app.toast("You can Resign after turn 50.", "bad")
		return
	app.confirm("Resign this duel?", "It counts as a fall. Salvage is paid. The Descent ends.", func() -> void:
		var result := DuelRules.apply(duel, 0, {"type": "resign"})
		if bool(result.get("ok", false)):
			duel.drain_events()
			_refresh_all()
			_on_duel_end()
	, "Resign")

func _leave_to_library() -> void:
	app.go_library()

func _toggle_pause() -> void:
	paused = not paused
	_refresh_top()

func _cycle_mode() -> void:
	var order := ["auto", "suggest", "manual"]
	mode = order[(order.find(mode) + 1) % order.size()]
	Session.settings["mode"] = mode
	if not Session.descent.is_empty():
		Session.descent["mode"] = mode
	Session.save_now()
	suggestion = {}
	stage.set_auto_broadcast(mode == "auto")
	if mode != "auto":
		stage.set_focus_lane(-1)
	_refresh_all()

func _set_speed(value: int) -> void:
	speed = value
	Session.settings["table_speed"] = value
	if timer != null:
		timer.wait_time = 0.55 / float(speed)
	_refresh_top()

func _show_pile(title: String, cards: Array, hidden: bool) -> void:
	if pile_overlay != null and is_instance_valid(pile_overlay):
		pile_overlay.queue_free()
	pile_overlay = Control.new()
	pile_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pile_overlay.z_index = 140
	add_child(pile_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pile_overlay.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			pile_overlay.queue_free()
			pile_overlay = null
	)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pile_overlay.add_child(center)
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS, 16)
	panel.custom_minimum_size = Vector2(860, 600)
	center.add_child(panel)
	var box := UI.vbox(6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_child(UI.display("%s · %d" % [title.to_upper(), cards.size()], 24))
	head.add_child(UI.spacer())
	head.add_child(UI.button("CLOSE", func() -> void:
		pile_overlay.queue_free()
		pile_overlay = null
	, Tokens.BRASS_LO))
	box.add_child(head)
	var scroll := UI.scroll()
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for card in cards:
		var view := CardView.new()
		view.set_card(card.def, card.instance, "S")
		view.set_flag("face_down", hidden or card.face_down)
		if not hidden and not card.face_down:
			view.double_clicked.connect(func(pile_view: CardView) -> void: app.show_zoom(pile_view.def, pile_view.instance))
		grid.add_child(view)

func _announce(text: String) -> void:
	var voices := DisplayServer.tts_get_voices()
	if not voices.is_empty():
		DisplayServer.tts_speak(text, str(voices[0].get("id", "")), 50, 1.0, 1.0, 0, true)
	else:
		app.toast(text, "info")

func _read_board() -> void:
	var lines: Array[String] = []
	lines.append("Depth %d. Resolve %d to %d. Phase %s. Turn %d." % [int(Session.descent.get("current_floor", 1)), duel.players[0].resolve, duel.players[1].resolve, duel.phase, duel.turn])
	var hand_names: Array[String] = []
	for card in duel.players[0].hand:
		hand_names.append(card.display_name())
	lines.append("Your hand: " + ", ".join(hand_names) + ".")
	lines.append("Your monsters: " + _board_text(0))
	lines.append("Opponent monsters: " + _board_text(1))
	_announce("\n".join(lines))

func _board_text(owner: int) -> String:
	var bits: Array[String] = []
	for lane in range(3):
		var card: DuelCard = duel.players[owner].monsters[lane]
		if card == null:
			bits.append("lane %d empty" % (lane + 1))
		elif owner == 1 and card.face_down:
			bits.append("lane %d set" % (lane + 1))
		else:
			var stats := duel.stats_for(card)
			bits.append("lane %d %s %d over %d" % [lane + 1, card.display_name(), stats["atk"], stats["defense"]])
	return "; ".join(bits)

func _read_focused_card() -> void:
	if inspected_card == null:
		_announce("No card selected.")
		return
	if inspected_card.owner == 1 and inspected_card.face_down:
		_announce("A set card. Position hidden.")
		return
	var bits := [inspected_card.display_name(), inspected_card.def.type_line, inspected_card.def.text]
	if inspected_card.is_monster():
		var stats := duel.stats_for(inspected_card)
		bits.append("Attack %d, Defense %d." % [stats["atk"], stats["defense"]])
	_announce(". ".join(bits))

func _read_log() -> void:
	var lines: Array[String] = []
	var start := maxi(0, duel.log.size() - 10)
	for i in range(start, duel.log.size()):
		lines.append(str(duel.log[i].get("text", "")))
	_announce("\n".join(lines) if not lines.is_empty() else "The log is empty.")

func _read_legal() -> void:
	if duel.active != 0:
		_announce("The Warden is acting.")
		return
	var labels: Array[String] = []
	for action in DuelRules.legal_actions(duel):
		labels.append(str(action.get("label", action.get("type", ""))))
	_announce("\n".join(labels) if not labels.is_empty() else "No legal actions.")

func export_text() -> Array[String]:
	var lines: Array[String] = []
	lines.append("Depth %d · Resolve %d to %d · Phase %s · Turn %d" % [int(Session.descent.get("current_floor", 1)), duel.players[0].resolve, duel.players[1].resolve, duel.phase, duel.turn])
	lines.append("Your hand: " + ", ".join(_hand_names()))
	lines.append("Your monsters: " + _board_text(0))
	lines.append("Opponent monsters: " + _board_text(1))
	lines.append("Log:")
	for i in range(maxi(0, duel.log.size() - 10), duel.log.size()):
		lines.append("  " + str(duel.log[i].get("text", "")))
	return lines

func _hand_names() -> Array[String]:
	var names: Array[String] = []
	for card in duel.players[0].hand:
		names.append(card.display_name())
	return names

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_SPACE:
				_toggle_pause()
			KEY_1:
				_set_speed(1)
			KEY_2:
				_set_speed(2)
			KEY_4:
				_set_speed(4)
			KEY_M:
				_cycle_mode()
			KEY_L:
				rail_tab = "log"
				_refresh_rail()
			KEY_D:
				rail_tab = "descent"
				_refresh_rail()
			KEY_I:
				rail_tab = "inspect"
				_refresh_rail()
			KEY_E:
				if mode == "manual" and duel.active == 0 and not duel.ended:
					_apply_player_action({"type": "end_phase"})
			KEY_R:
				if duel.turn >= 50 and mode == "manual" and duel.active == 0:
					_resign()
				else:
					_queue_recall()
			KEY_F2:
				_read_board()
			KEY_F3:
				_read_focused_card()
			KEY_F4:
				_read_log()
			KEY_F5:
				_read_legal()
			KEY_ESCAPE:
				if result_overlay != null and is_instance_valid(result_overlay):
					pass
				elif selected_hand_uid != -1 or selected_board_uid != -1 or inspected_card != null:
					selected_hand_uid = -1
					selected_board_uid = -1
					inspected_card = null
					rail_tab = "log"
					_refresh_all()
				else:
					_leave_to_library()
