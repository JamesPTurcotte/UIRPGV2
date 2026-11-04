class_name CardActor
extends Control

## One stable node per DuelCard.uid. The actor outlives a zone change; the
## director moves it from its current rect to the new rest rect.

signal clicked(actor: CardActor)
signal right_clicked(actor: CardActor, position: Vector2)

var card: DuelCard
var view: CardView
var token: String = "B"
var rest_rect: Rect2 = Rect2()
var selected: bool = false
var action_seal: bool = false
var ad_label: String = ""
var ad_tab: Label
var hover_zone: Control

func setup(duel_card: DuelCard, size_token: String) -> void:
	card = duel_card
	token = size_token
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Tokens.card_size(token)
	size = custom_minimum_size
	view = CardView.new()
	view.set_card(card.def, card.instance, token)
	view.size = Tokens.card_size(token)
	view.position = Vector2.ZERO
	view.clicked.connect(func(_v: CardView) -> void: clicked.emit(self))
	view.double_clicked.connect(func(_v: CardView) -> void: clicked.emit(self))
	view.right_clicked.connect(func(_v: CardView, rect: Rect2) -> void: right_clicked.emit(self, rect.get_center()))
	view.hover_changed.connect(_on_hover_changed)
	add_child(view)
	# A backrow card slides; the hover target must not slide with it. This
	# transparent zone keeps the 52px tab under the pointer while the face
	# moves forward. It also owns the tab's click/right-click.
	hover_zone = Control.new()
	hover_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	hover_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hover_zone.mouse_entered.connect(func() -> void: _on_hover_changed(view, true))
	hover_zone.mouse_exited.connect(func() -> void: _on_hover_changed(view, false))
	hover_zone.gui_input.connect(_on_hover_zone_input)
	add_child(hover_zone)
	ad_tab = UI.label("", 12 if token == "A" else 8, Tokens.PAPER, Tokens.font_data())
	ad_tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ad_tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ad_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ad_tab.visible = false
	ad_tab.z_index = 5
	add_child(ad_tab)
	refresh()

func refresh() -> void:
	if card == null or view == null:
		return
	view.set_card(card.def, card.instance, token)
	view.set_flag("face_down", card.face_down)
	view.set_flag("selected", selected)
	view.set_flag("action_seal", action_seal)
	if card.is_monster() and not card.face_down:
		var owner_state := _owner_state()
		if owner_state != null:
			var stats: Dictionary = owner_state.stats_for(card)
			view.stats_override = {"atk": stats["atk"], "defense": stats["defense"], "offer": stats["offer"]}
	_sync_hover_zone()
	queue_redraw()

func _owner_state() -> DuelState:
	var node := get_parent()
	while node != null:
		if node is BattleStage:
			return (node as BattleStage).duel
		node = node.get_parent()
	return null

func set_token(size_token: String) -> void:
	if token == size_token:
		return
	token = size_token
	custom_minimum_size = Tokens.card_size(token)
	size = custom_minimum_size
	if view != null:
		view.set_size_token(token)
		view.size = Tokens.card_size(token)
		view.position = Vector2.ZERO
	set_angle(0.0)
	refresh()

func set_angle(degrees: float) -> void:
	if view == null:
		return
	var token_size := Tokens.card_size(token)
	view.pivot_offset = Vector2(token_size.x * 0.5, token_size.y)
	view.rotation = deg_to_rad(degrees)

func set_rest(rect: Rect2) -> void:
	rest_rect = rect
	position = rect.position
	# The rect is a position, not a size. Card geometry always comes from the
	# token so a source/target rect can never squash or invalidate the face.
	var token_size := Tokens.card_size(token)
	size = token_size
	if view != null:
		view.position = Vector2.ZERO
		view.size = token_size
		view.set_size_token(token)
		view.queue_redraw()
	_sync_hover_zone()

func move_to(rect: Rect2, duration: float = 0.2) -> void:
	rest_rect = rect
	if duration <= 0.001:
		set_rest(rect)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", rect.position, duration)
	await tween.finished
	set_rest(rect)

func exit_to(rect: Rect2, duration: float = 0.28, fade: bool = true) -> void:
	if duration <= 0.001:
		queue_free()
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", rect.position, duration)
	if fade:
		tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	await tween.finished
	queue_free()

func set_selected(value: bool) -> void:
	selected = value
	if view != null:
		view.set_flag("selected", selected)
	view.action_seal = selected
	queue_redraw()

func set_action_seal(value: bool) -> void:
	action_seal = value
	if view != null:
		view.set_flag("action_seal", value)
	queue_redraw()

func set_ad(value: String) -> void:
	ad_label = value
	if ad_tab == null:
		return
	ad_tab.text = value
	ad_tab.visible = not value.is_empty()
	var tab_size := Tokens.card_size(token)
	var badge_w := 24.0 if token == "A" else 20.0
	var badge_h := 16.0 if token == "A" else 12.0
	ad_tab.position = Vector2(tab_size.x * 0.5 - badge_w * 0.5, tab_size.y - badge_h - 3.0)
	ad_tab.size = Vector2(badge_w, badge_h)
	ad_tab.add_theme_constant_override("outline_size", 3)
	ad_tab.add_theme_color_override("font_outline_color", Tokens.BG_VOID)
	queue_redraw()

func pulse(color: Color = Tokens.BRASS_HI) -> void:
	if view == null:
		return
	view.modulate = color
	var tween := create_tween()
	tween.tween_property(view, "modulate", Color.WHITE, 0.25)

func _draw() -> void:
	pass

func _sync_hover_zone() -> void:
	if hover_zone == null or card == null:
		return
	var is_back := card.zone == GameConst.ZONE_BACKROW
	hover_zone.visible = is_back
	if is_back:
		hover_zone.position = Vector2.ZERO
		hover_zone.size = size
		hover_zone.tooltip_text = "Set card" if card.face_down else card.display_name()
		if view != null:
			view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif view != null:
		view.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_hover_zone_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(self, event.position + position)
		accept_event()

func _on_hover_changed(_view: CardView, hovered: bool) -> void:
	if card == null:
		return
	# Hovered hand cards rise above their neighbours so the face is readable.
	if card.zone == GameConst.ZONE_HAND:
		z_index = 40 if hovered else 20
		if view != null:
			view.position = Vector2(0, -7 if hovered else 0)
	elif card.zone == GameConst.ZONE_BACKROW:
		# The side tab is a full card. Hover slides it left over the monster so
		# the face (or its back) can be read without changing its size.
		z_index = 30 if hovered else 2
		if view != null:
			var slide := -Tokens.CARD_TAB if hovered else 0.0
			view.position = Vector2(slide, 0)
	# Action-state medallion only on the hovered/selected card.
	if not selected:
		set_action_seal(hovered)
