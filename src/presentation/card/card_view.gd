class_name CardView
extends Control

signal clicked(view: CardView)
signal double_clicked(view: CardView)
signal right_clicked(view: CardView, global_rect: Rect2)
signal hover_changed(view: CardView, hovered: bool)

var def: CardDef
var instance: CardInstance
var token: String = "M"
var face_down: bool = false
var selected: bool = false
var legal: bool = false
var playable: bool = false
var illegal: bool = false
var decked: bool = false
var is_new: bool = false
var locked: bool = false
var count: int = 0
var stats_override: Dictionary = {}
var interactive: bool = true
var action_seal: bool = false
var drag_payload: Dictionary = {}
var drop_callback: Callable
var drop_action: Callable

var _hovered: bool = false
var _lift: float = 0.0
var _last_lift: float = -1.0

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_size()

func _process(delta: float) -> void:
	var target := 6.0 if selected else (2.0 if _hovered else 0.0)
	if bool(Session.settings.get("reduced_motion", false)):
		if not is_equal_approx(_lift, target):
			_lift = target
			queue_redraw()
		return
	if not is_equal_approx(_lift, target):
		_lift = move_toward(_lift, target, maxf(0.5, delta * 90.0))
		if not is_equal_approx(_lift, _last_lift):
			_last_lift = _lift
			queue_redraw()

func set_card(card_def: CardDef, card_instance: CardInstance = null, size_token: String = "M") -> void:
	def = card_def
	instance = card_instance
	token = size_token
	tooltip_text = card_def.name if card_def != null and not face_down else ""
	_apply_size()
	queue_redraw()

func set_size_token(size_token: String) -> void:
	token = size_token
	_apply_size()
	queue_redraw()

func _apply_size() -> void:
	custom_minimum_size = Tokens.card_size(token)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	queue_redraw()

func set_flag(flag_name: String, value: bool) -> void:
	match flag_name:
		"selected":
			selected = value
		"legal":
			legal = value
		"playable":
			playable = value
		"illegal":
			illegal = value
		"decked":
			decked = value
		"new":
			is_new = value
		"locked":
			locked = value
		"face_down":
			face_down = value
			tooltip_text = def.name if def != null and not face_down else ""
		"action_seal":
			action_seal = value
		"interactive":
			interactive = value
			mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if def == null:
		return
	# The face is always 5:7. Containers may reflow the room; they never stretch a card.
	if absf(size.x / maxf(1.0, size.y) - 5.0 / 7.0) > 0.002:
		push_error("CardView aspect drift: %s (%s)" % [def.id, str(size)])
		return
	draw_set_transform(Vector2(0, -_lift), 0.0, Vector2.ONE)
	var state := {
		"face_down": face_down,
		"selected": selected,
		"legal": legal,
		"playable": playable,
		"illegal": illegal,
		"decked": decked,
		"new": is_new,
		"locked": locked,
		"count": count,
		"stats_override": stats_override,
		"action_seal": action_seal,
	}
	CardComposer.draw(self, def, instance, token, state)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selected:
		draw_rect(Rect2(Vector2(0, -_lift), size), Color(0, 0, 0, 0), false, 1.0)

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			if mouse.double_click:
				double_clicked.emit(self)
			else:
				clicked.emit(self)
			grab_focus()
			accept_event()
		elif mouse.button_index == MOUSE_BUTTON_RIGHT and mouse.pressed:
			right_clicked.emit(self, get_global_rect())
			accept_event()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				double_clicked.emit(self)
				accept_event()
			elif key.keycode == KEY_SPACE:
				clicked.emit(self)
				accept_event()
			elif key.keycode == KEY_MENU or (key.shift_pressed and key.keycode == KEY_F10):
				right_clicked.emit(self, get_global_rect())
				accept_event()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return drop_callback.is_valid() and bool(drop_callback.call(self, at_position, data))

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if drop_action.is_valid():
		drop_action.call(self, at_position, data)
	elif drop_callback.is_valid():
		drop_callback.call(self, at_position, data)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty() or not interactive:
		return null
	var preview := CardView.new()
	preview.set_card(def, instance, token)
	preview.face_down = face_down
	preview.action_seal = false
	preview.modulate = Color(1, 1, 1, 0.82)
	preview.custom_minimum_size = size
	preview.size = size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return drag_payload.duplicate(true)

func _on_mouse_entered() -> void:
	_hovered = true
	hover_changed.emit(self, true)

func _on_mouse_exited() -> void:
	_hovered = false
	hover_changed.emit(self, false)
