class_name ViewportFrame
extends RefCounted

## The single source of screen geometry. Presentation code reads `safe_rect`
## and the logical viewport from here; only the window-mode owner reads the
## OS display rects.

const SAFE_MARGIN := 0.0

var viewport_size := Vector2.ZERO
var safe_rect := Rect2()
var window_size := Vector2i.ZERO
var screen_size := Vector2i.ZERO
var screen_position := Vector2i.ZERO
var dpr := 1.0
var mode: int = DisplayServer.WINDOW_MODE_WINDOWED

func refresh(host: Control) -> void:
	if host == null or not host.is_inside_tree():
		return
	viewport_size = host.get_viewport_rect().size
	window_size = DisplayServer.window_get_size()
	mode = DisplayServer.window_get_mode()
	var screen := DisplayServer.window_get_current_screen()
	screen_position = DisplayServer.screen_get_position(screen)
	screen_size = DisplayServer.screen_get_size(screen)
	dpr = maxf(1.0, DisplayServer.screen_get_scale(screen))
	safe_rect = Rect2(Vector2.ZERO, viewport_size)
	# Honor the platform safe area when the display exposes one. The OS returns
	# this in screen pixels; map it into the viewport's logical space.
	var display_safe := DisplayServer.get_display_safe_area()
	if display_safe.size.x > 0 and display_safe.size.y > 0 and screen_size.x > 0 and screen_size.y > 0:
		var scale := Vector2(
			viewport_size.x / float(screen_size.x),
			viewport_size.y / float(screen_size.y)
		)
		var local := Rect2(
			Vector2(display_safe.position - screen_position) * scale,
			Vector2(display_safe.size) * scale
		)
		var clipped := local.intersection(Rect2(Vector2.ZERO, viewport_size))
		if clipped.size.x > 64.0 and clipped.size.y > 64.0:
			safe_rect = clipped
	if SAFE_MARGIN > 0.0:
		safe_rect = safe_rect.grow(-SAFE_MARGIN)

func is_fullscreen() -> bool:
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func fit_scale(design: Vector2, margin: float = 16.0, max_scale: float = 1.0) -> float:
	if design.x <= 0.0 or design.y <= 0.0:
		return max_scale
	var available := safe_rect.size - Vector2(margin * 2.0, margin * 2.0)
	if available.x <= 0.0 or available.y <= 0.0:
		return 0.0
	return minf(max_scale, minf(available.x / design.x, available.y / design.y))

func centered_rect(design: Vector2, margin: float = 16.0, max_scale: float = 1.0) -> Rect2:
	var scale := fit_scale(design, margin, max_scale)
	var content := design * scale
	return Rect2(safe_rect.get_center() - content * 0.5, content)
