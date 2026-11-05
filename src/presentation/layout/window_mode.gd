class_name WindowMode
extends RefCounted

## Owns the windowed/fullscreen transition. It never changes layout; it only
## saves and restores the window state. Presentation reads the new viewport
## after `changed`.

signal changed(fullscreen: bool)

var _saved_mode := Window.MODE_WINDOWED
var _saved_size := Vector2i.ZERO
var _saved_position := Vector2i.ZERO
var _saved_min_size := Vector2i.ZERO
var _saved_on_top := false
var _active := false

func is_fullscreen(window: Window = null) -> bool:
	if window != null:
		return window.mode == Window.MODE_FULLSCREEN or window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
	return _active

func enter(window: Window) -> bool:
	if window == null:
		return false
	if is_fullscreen(window):
		_active = true
		return false
	_saved_mode = window.mode
	_saved_size = window.size
	_saved_position = window.position
	_saved_min_size = window.min_size
	_saved_on_top = window.get_flag(Window.FLAG_ALWAYS_ON_TOP)
	# Fullscreen ignores min-size constraints; keep the saved value for exit.
	window.min_size = Vector2i(1, 1)
	window.mode = Window.MODE_FULLSCREEN
	_active = true
	changed.emit(true)
	return true

func exit(window: Window) -> bool:
	if window == null:
		return false
	var was_fullscreen := is_fullscreen(window)
	if not was_fullscreen and not _active:
		return false
	window.mode = _saved_mode if _saved_mode != Window.MODE_FULLSCREEN and _saved_mode != Window.MODE_EXCLUSIVE_FULLSCREEN else Window.MODE_WINDOWED
	window.min_size = _saved_min_size if _saved_min_size.x > 0 and _saved_min_size.y > 0 else Vector2i(960, 720)
	if _saved_size.x > 0 and _saved_size.y > 0:
		window.size = _saved_size
		window.position = _saved_position
	window.set_flag(Window.FLAG_ALWAYS_ON_TOP, _saved_on_top)
	_active = false
	changed.emit(false)
	return true
