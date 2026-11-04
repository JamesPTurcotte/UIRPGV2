class_name UIScreen
extends Control

signal layout_changed(size: Vector2)

var app: Node
var session: Node
var payload: Dictionary = {}
var _layout_ready: bool = false

func setup(app_ref: Node, payload_ref: Dictionary = {}) -> void:
	app = app_ref
	session = Session
	payload = payload_ref

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)
	build()
	_layout_ready = true
	layout_changed.emit(size)

func _on_resized() -> void:
	if _layout_ready:
		layout_changed.emit(size)

func build() -> void:
	pass

func refresh_all() -> void:
	pass
