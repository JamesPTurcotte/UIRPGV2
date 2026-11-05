class_name CardActor
extends Control

## One stable node per DuelCard.uid. The actor outlives a zone change; the
## director moves it from its current rect to the new rest rect.

signal clicked(actor: CardActor)
signal right_clicked(actor: CardActor, position: Vector2)
signal drag_started(actor: CardActor)
signal drag_moved(actor: CardActor)
signal drag_ended(actor: CardActor)

var card: DuelCard
var view: CardView
var card_clip: Control
var token: String = "B"
var card_scale: float = 1.0
var backrow_tucked: bool = false
var rest_rect: Rect2 = Rect2()
var selected: bool = false
var action_seal: bool = false
var ad_label: String = ""
var ad_tab: Label
var hover_zone: Control
var drag_zone: Control
var dragging: bool = false
var _drag_pending: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _hand_hovered: bool = false
var _hand_focused: bool = false

func setup(duel_card: DuelCard, size_token: String, scale: float = 1.0) -> void:
	card = duel_card
	token = size_token
	card_scale = maxf(0.01, scale)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)
	# The hand is a 30% shelf: only the title strip is visible until the card is
	# hovered, focused, or pinned. Clipping the view keeps the face at its true
	# 5:7 size instead of squashing or faking a short card.
	card_clip = Control.new()
	card_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_clip)
	view = CardView.new()
	view.set_card(card.def, card.instance, token)
	view.position = Vector2.ZERO
	card_clip.add_child(view)
	_apply_size()
	view.clicked.connect(func(_v: CardView) -> void: clicked.emit(self))
	view.double_clicked.connect(func(_v: CardView) -> void: clicked.emit(self))
	view.right_clicked.connect(func(_v: CardView, rect: Rect2) -> void: right_clicked.emit(self, rect.get_center()))
	view.hover_changed.connect(_on_hover_changed)
	view.focus_entered.connect(func() -> void:
		_hand_focused = true
		_update_hand_lift()
	)
	view.focus_exited.connect(func() -> void:
		_hand_focused = false
		_update_hand_lift()
	)
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
	# Player monsters get a transparent drag surface on top of the face. Hand
	# cards use their existing hover shelf; this zone keeps the click fallback.
	drag_zone = Control.new()
	drag_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	drag_zone.gui_input.connect(_on_drag_zone_input)
	drag_zone.mouse_entered.connect(func() -> void: _on_hover_changed(view, true))
	drag_zone.mouse_exited.connect(func() -> void: _on_hover_changed(view, false))
	drag_zone.visible = false
	drag_zone.z_index = 6
	add_child(drag_zone)
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
	_apply_size()
	if view != null:
		view.set_size_token(token)
	set_angle(0.0)
	refresh()

func set_display_scale(scale: float) -> void:
	var next := maxf(0.01, scale)
	if is_equal_approx(card_scale, next):
		return
	card_scale = next
	_apply_size()
	_sync_hover_zone()
	_update_hand_lift()
	queue_redraw()

func _full_size() -> Vector2:
	return Tokens.card_size(token) * card_scale

func _actor_size() -> Vector2:
	var full := _full_size()
	if card != null and card.zone == GameConst.ZONE_HAND:
		return Vector2(full.x, _hand_shelf_h())
	return full

func _apply_actor_size() -> void:
	custom_minimum_size = _actor_size()
	size = custom_minimum_size

func _apply_size() -> void:
	var base := Tokens.card_size(token)
	_apply_actor_size()
	if view != null:
		view.size = base
		view.pivot_offset = base * 0.5
		view.scale = Vector2(card_scale, card_scale)
		# Scale is centred on the pivot. Compensate so the visual top-left
		# stays on the slot rather than growing up and left out of it.
		view.position = view.pivot_offset * (card_scale - 1.0)
	_sync_card_clip()
	_sync_hover_zone()
	_update_hand_lift()

func set_angle(degrees: float) -> void:
	if view == null:
		return
	var token_size := Tokens.card_size(token)
	view.pivot_offset = Vector2(token_size.x * 0.5, token_size.y)
	# Re-anchor after the pivot moves; otherwise scaling around the bottom
	# centre shifts a shelf card upward and hides its nameplate.
	view.position = view.pivot_offset * (card_scale - 1.0)
	view.rotation = deg_to_rad(degrees)

func set_rest(rect: Rect2) -> void:
	rest_rect = rect
	position = rect.position
	# The rect is a position, not a size. Card geometry always comes from the
	# token and the display scale so a source/target rect can never squash the face.
	var base := Tokens.card_size(token)
	_apply_actor_size()
	if view != null:
		view.size = base
		view.pivot_offset = base * 0.5
		view.scale = Vector2(card_scale, card_scale)
		view.position = view.pivot_offset * (card_scale - 1.0)
		view.set_size_token(token)
		view.queue_redraw()
	_sync_hover_zone()
	_update_hand_lift()

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
	_update_hand_lift()
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
	var badge_w := 24.0 if token == "A" else 20.0
	var badge_h := 16.0 if token == "A" else 12.0
	ad_tab.position = Vector2(size.x * 0.5 - badge_w * 0.5, size.y - badge_h - 3.0)
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
	var is_hand := card.zone == GameConst.ZONE_HAND
	hover_zone.visible = is_back or is_hand
	if is_back:
		hover_zone.position = Vector2.ZERO
		hover_zone.size = _full_size()
		hover_zone.tooltip_text = "Set card" if card.face_down else card.display_name()
	elif is_hand:
		var full := _full_size()
		hover_zone.position = Vector2.ZERO
		hover_zone.size = Vector2(full.x, _hand_shelf_h())
		hover_zone.tooltip_text = card.display_name()
	if (is_back or is_hand) and view != null:
		# The visible strip stays under the pointer while the face lifts, so
		# hover does not flicker as the card rises out of the shelf.
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif view != null:
		view.mouse_filter = Control.MOUSE_FILTER_STOP
	if drag_zone != null:
		var is_draggable_monster := card.owner == 0 and card.zone == GameConst.ZONE_MONSTER
		drag_zone.visible = is_draggable_monster
		if is_draggable_monster:
			drag_zone.position = Vector2.ZERO
			drag_zone.size = _full_size()
			drag_zone.tooltip_text = "Drag to attack, or click to select."

func _on_hover_zone_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if card != null and card.zone == GameConst.ZONE_HAND and view != null:
			view.grab_focus()
		_begin_drag_pending()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(self, event.position + position)
		accept_event()

func _on_drag_zone_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_begin_drag_pending()
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		right_clicked.emit(self, event.position + position)
		accept_event()

func _begin_drag_pending() -> void:
	_drag_pending = true
	_drag_start = get_global_mouse_position()

func _process(_delta: float) -> void:
	if not _drag_pending:
		return
	var mouse := get_global_mouse_position()
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_pending = false
		if dragging:
			dragging = false
			drag_ended.emit(self)
		else:
			clicked.emit(self)
		_update_hand_lift()
		return
	if not dragging and mouse.distance_to(_drag_start) > 6.0:
		dragging = true
		z_index = 80
		drag_started.emit(self)
		_update_hand_lift()
	if dragging:
		var parent := get_parent()
		if parent is Control:
			var local := (parent as Control).get_local_mouse_position()
			var full := _full_size()
			var lift := _hand_lift_offset() if card != null and card.zone == GameConst.ZONE_HAND else 0.0
			position = local - Vector2(full.x * 0.5, full.y * 0.5 - lift)
		drag_moved.emit(self)

func finish_drag() -> void:
	_drag_pending = false
	dragging = false
	position = rest_rect.position
	z_index = _default_z()
	_update_hand_lift()
	queue_redraw()

func cancel_drag() -> void:
	finish_drag()

func _default_z() -> int:
	if card == null:
		return 1
	if card.owner == 0 and card.zone == GameConst.ZONE_HAND:
		return 20
	if card.zone == GameConst.ZONE_BACKROW:
		return 2
	if card.zone == GameConst.ZONE_MONSTER:
		return 4
	return 1

func _stage() -> BattleStage:
	var node := get_parent()
	while node != null:
		if node is BattleStage:
			return node as BattleStage
		node = node.get_parent()
	return null

func _hand_shelf_h() -> float:
	var stage := _stage()
	if stage is DuelBoardStage:
		return (stage as DuelBoardStage).hand_shelf_h
	return _full_size().x * 0.30

func _hand_full() -> bool:
	var stage := _stage()
	return stage is DuelBoardStage and (stage as DuelBoardStage).hand_full

func _hand_lift_offset() -> float:
	return maxf(0.0, _full_size().y - _hand_shelf_h())

func _hand_lifted() -> bool:
	if dragging:
		return true
	if _hand_full():
		return false
	return _hand_hovered or _hand_focused or selected

func _sync_card_clip() -> void:
	if card_clip == null or view == null:
		return
	var is_hand := card != null and card.zone == GameConst.ZONE_HAND
	var lifted := _hand_lifted()
	var full := _full_size()
	# The actor's footprint is the shelf strip while the face is stored at its
	# real 5:7 size inside. Only this control is clipped; the face never is.
	clip_contents = is_hand and not lifted
	if is_hand and not lifted:
		card_clip.clip_contents = true
		card_clip.position = Vector2.ZERO
		card_clip.size = full
	elif is_hand:
		card_clip.clip_contents = false
		card_clip.position = Vector2(0, -_hand_lift_offset())
		card_clip.size = full
	else:
		card_clip.clip_contents = false
		card_clip.position = Vector2.ZERO
		card_clip.size = full

func _update_hand_lift() -> void:
	if card == null or view == null:
		return
	_sync_card_clip()
	if card.zone != GameConst.ZONE_HAND:
		return
	var lifted := _hand_lifted()
	var full := _full_size()
	z_index = 40 if lifted else 20
	if hover_zone != null and hover_zone.visible:
		# The hover target covers the shelf strip and the lifted face, so the
		# pointer can move from the strip to the card without leaving hover.
		hover_zone.position = Vector2(0, -_hand_lift_offset()) if lifted else Vector2.ZERO
		hover_zone.size = full if lifted else Vector2(full.x, _hand_shelf_h())

func _on_hover_changed(_view: CardView, hovered: bool) -> void:
	if card == null:
		return
	# Hovered or selected hand cards rise out of the 30% shelf.
	if card.zone == GameConst.ZONE_HAND:
		_hand_hovered = hovered
		_update_hand_lift()
	elif card.zone == GameConst.ZONE_BACKROW:
		# In B3 the side tab is a full card tucked behind its monster; hover
		# slides it left so the face can be read without changing its size. In
		# B1 the card already has its own public seat, so it never slides.
		z_index = 30 if hovered and backrow_tucked else 2
		if view != null:
			var slide := -Tokens.CARD_TAB if hovered and backrow_tucked else 0.0
			view.position = Vector2(slide, 0)
	# Action-state medallion only on the hovered/selected card.
	if not selected:
		set_action_seal(hovered)
