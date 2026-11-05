class_name FitPanel
extends Control

## Centers a fixed natural-size surface in the current viewport and scales it
## down until header, body, and actions fit. It never enlarges above 1:1 and
## never lets a child leave the viewport.

var content: Control
var design_size := Vector2.ZERO
var margin := 16.0
var max_scale := 1.0
var _fit_queued := false

func setup(content_ref: Control, design: Vector2, margin_px: float = 16.0) -> void:
	content = content_ref
	design_size = design
	margin = margin_px
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if content != null:
		content.custom_minimum_size = Vector2.ZERO
		add_child(content)
	resized.connect(_queue_fit)
	_queue_fit()

func refresh() -> void:
	_queue_fit()

func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	call_deferred("_fit")

func _fit() -> void:
	_fit_queued = false
	if content == null or not is_instance_valid(content) or size.x <= 1.0 or size.y <= 1.0:
		return
	var available := Rect2(
		Vector2(margin, margin),
		Vector2(maxf(1.0, size.x - margin * 2.0), maxf(1.0, size.y - margin * 2.0))
	)
	var natural := content.get_combined_minimum_size().max(design_size)
	if natural.x <= 0.0 or natural.y <= 0.0:
		return
	content.size = natural
	content.pivot_offset = Vector2.ZERO
	content.position = Vector2.ZERO
	var fit := minf(max_scale, minf(available.size.x / natural.x, available.size.y / natural.y))
	if fit <= 0.0:
		return
	content.scale = Vector2(fit, fit)
	content.position = available.position + (available.size - natural * fit) * 0.5
