class_name FolioRevealCard
extends Control

signal pressed(card: FolioRevealCard)

var def: CardDef
var instance: CardInstance
var view: CardView
var revealed: bool = false
var is_new: bool = false
var duplicate_count: int = 0
var stamp: Label
var _flipping: bool = false

func setup(card_def: CardDef, card_instance: CardInstance, new_flag: bool, dupes: int, size_token: String = "M") -> void:
	def = card_def
	instance = card_instance
	is_new = new_flag
	duplicate_count = dupes
	custom_minimum_size = Tokens.card_size(size_token)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view = CardView.new()
	view.set_card(def, instance, size_token)
	view.set_flag("face_down", true)
	view.interactive = false
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.position = Vector2.ZERO
	view.size = custom_minimum_size
	add_child(view)
	stamp = UI.label("", 10, Tokens.BRASS_HI, Tokens.font_data())
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.position = Vector2(10, size.y - 28)
	stamp.size = Vector2(size.x - 20, 20)
	stamp.visible = false
	add_child(stamp)

func flip(duration: float = 0.22) -> void:
	if revealed or _flipping:
		return
	_flipping = true
	if duration <= 0.001:
		_finish_flip()
		return
	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.02, duration * 0.5)
	await tween.finished
	_finish_flip()
	var tween2 := create_tween()
	tween2.tween_property(self, "scale:x", 1.0, duration * 0.45)
	await tween2.finished

func reveal_instant() -> void:
	scale = Vector2.ONE
	_finish_flip()

func _finish_flip() -> void:
	if revealed:
		return
	revealed = true
	_flipping = false
	view.set_flag("face_down", false)
	if is_new:
		stamp.text = "NEW"
		stamp.visible = true
	elif duplicate_count > 0:
		stamp.text = "×%d" % (duplicate_count + 1)
		stamp.visible = true
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 2.0, 0.08)
	tween.tween_property(self, "position:y", position.y, 0.10)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			pressed.emit(self)
			accept_event()
