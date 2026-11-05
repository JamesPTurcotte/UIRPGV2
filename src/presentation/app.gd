extends Control

## Screen host and global furniture: backdrop, overlays, toasts, zoom, confirm,
## and the top-level navigation between the Library, Gate, Table, and Bench.

const SCREEN_PATHS := {
	"library": "res://src/presentation/screens/library_screen.gd",
	"gate": "res://src/presentation/screens/gate_screen.gd",
	"table": "res://src/presentation/screens/table_screen.gd",
	"bench": "res://src/presentation/screens/bench_screen.gd",
	"salvage": "res://src/presentation/screens/salvage_screen.gd",
	"pack": "res://src/presentation/screens/pack_screen.gd",
	"deck": "res://src/presentation/screens/deck_screen.gd",
}

var backdrop: Backdrop
var top_nav: TopNav
var host: Control
var overlay: Control
var toast_layer: Control
var current_screen: UIScreen
var current_screen_name: String = ""
var zoom_overlay: ZoomOverlay
var confirm_dialog: ConfirmDialog
var context_menu: ContextMenu
var _help_overlay: Control
var _shell_window_position := Vector2i.ZERO
var _shell_window_size := Vector2i.ZERO
var _shell_window_min_size := Vector2i.ZERO
var _shell_window_saved := false
var viewport_frame: ViewportFrame
var window_mode: WindowMode
var _viewport_debug: Control
var _viewport_debug_label: Label
var _metrics_refresh_queued := false

func _ready() -> void:
	theme = ThemeBuilder.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_mode = WindowMode.new()
	viewport_frame = ViewportFrame.new()
	viewport_frame.refresh(self)
	if not is_fullscreen():
		get_window().min_size = Vector2i(1280, 720)
	_set_runtime_icon()
	backdrop = Backdrop.new()
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	top_nav = TopNav.new()
	add_child(top_nav)
	top_nav.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_nav.offset_bottom = 52
	top_nav.setup(self)

	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.offset_top = 52
	host.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(host)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	toast_layer = Control.new()
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_layer)

	Session.toast.connect(_on_toast)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	get_window().dpi_changed.connect(_on_viewport_size_changed)
	if not Session.loaded:
		_fatal("Content failed to load. Run tools/build_content.py and relaunch.")
		return
	go_library()
	if OS.get_cmdline_user_args().has("--shot"):
		await get_tree().create_timer(1.4).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://screenshots/app.png")
		print("screenshot saved: app.png")
		get_tree().quit(0)

func _set_runtime_icon() -> void:
	# The window icon is generated from the seal grammar, never shipped as art.
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(32, 32)
	for y in range(64):
		for x in range(64):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d >= 25.0 and d <= 29.0:
				image.set_pixel(x, y, Tokens.BRASS)
			elif d <= 3.0:
				image.set_pixel(x, y, Tokens.PAPER)
			elif d <= 10.0:
				image.set_pixel(x, y, Tokens.WAX)
			elif d >= 17.0 and d <= 18.5:
				image.set_pixel(x, y, Tokens.INK_PRIMARY)
	DisplayServer.set_icon(image)

func _fatal(message: String) -> void:
	var panel := CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := UI.panel(Tokens.BG_PANEL, Tokens.DANGER, 24)
	panel.add_child(box)
	box.add_child(UI.display(message, 18))

func show_screen(screen_name: String, payload_data: Dictionary = {}) -> void:
	close_context_menu()
	_apply_screen_scale(screen_name)
	var is_table := screen_name == "table"
	if is_table and not _shell_window_saved and not is_fullscreen():
		viewport_frame.refresh(self)
		_shell_window_position = DisplayServer.window_get_position()
		_shell_window_size = viewport_frame.window_size
		_shell_window_min_size = Vector2i(1280, 720)
		_shell_window_saved = true
	if top_nav != null:
		top_nav.visible = not is_table
	if host != null:
		host.offset_top = 0 if is_table else 52
	if not is_table:
		get_window().set_flag(Window.FLAG_ALWAYS_ON_TOP, false)
		if not is_fullscreen():
			get_window().min_size = Vector2i(1280, 720)
	var path: String = SCREEN_PATHS.get(screen_name, "")
	if path.is_empty():
		return
	var script = load(path)
	if script == null:
		toast("That room is not built yet.", "bad")
		return
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.queue_free()
	current_screen = script.new()
	if not (current_screen is UIScreen):
		toast("That room has no screen script.", "bad")
		return
	current_screen.setup(self, payload_data)
	host.add_child(current_screen)
	if bool(Session.settings.get("reduced_motion", false)):
		current_screen.modulate.a = 1.0
	else:
		current_screen.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(current_screen, "modulate:a", 1.0, 0.22)
	current_screen_name = screen_name
	if not is_table and not is_fullscreen():
		_restore_shell_window_if_needed()
	backdrop.screen_kind = _backdrop_kind(screen_name)
	backdrop.queue_redraw()
	if top_nav != null:
		top_nav.set_active(_door_for_screen(screen_name))
		top_nav.update_resources()
	_flash_transition()
	call_deferred("_refresh_viewport_frame")

func _refresh_viewport_frame() -> void:
	if viewport_frame == null:
		return
	viewport_frame.refresh(self)
	update_viewport_debug()

func _queue_metrics_refresh() -> void:
	if _metrics_refresh_queued:
		return
	_metrics_refresh_queued = true
	call_deferred("_flush_metrics_refresh")

func _flush_metrics_refresh() -> void:
	_metrics_refresh_queued = false
	_refresh_viewport_frame()

func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func set_fullscreen(value: bool) -> void:
	var window := get_window()
	if window == null:
		return
	if value:
		if not window_mode.enter(window):
			_refresh_viewport_frame()
			return
	else:
		if not window_mode.exit(window):
			_refresh_viewport_frame()
			return
	_apply_screen_scale(current_screen_name)
	if not value and current_screen_name != "table":
		_restore_shell_window_if_needed()
	call_deferred("_refresh_viewport_frame")

func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

func _restore_shell_window_if_needed() -> void:
	if not _shell_window_saved or is_fullscreen() or current_screen_name == "table":
		return
	var window := get_window()
	window.min_size = Vector2i(1280, 720)
	if _shell_window_size.x > 0 and _shell_window_size.y > 0:
		DisplayServer.window_set_size(_shell_window_size)
		DisplayServer.window_set_position(_shell_window_position)
	_shell_window_saved = false

func _apply_screen_scale(screen_name: String) -> void:
	# Rooms use the 1440×900 design canvas. The table switches to native pixels
	# so its stage can scale the 5:7 board to the actual window.
	var window := get_window()
	if window == null:
		return
	if screen_name == "table":
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	else:
		# The shell is a 1440×900 design canvas. Contain it so fullscreen and
		# unusual aspect ratios never crop or push a rail past the screen.
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_size = Vector2i(1440, 900)
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func _flash_transition() -> void:
	if bool(Session.settings.get("reduced_motion", false)):
		return
	var fade := ColorRect.new()
	fade.color = Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.62)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.z_index = 500
	host.add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.38).set_ease(Tween.EASE_OUT)
	tween.tween_callback(fade.queue_free)

func _backdrop_kind(screen_name: String) -> String:
	match screen_name:
		"table":
			return "table"
		"gate":
			return "gate"
		"pack":
			return "pack"
		"salvage":
			return "salvage"
		_:
			return "library"

func _door_for_screen(screen_name: String) -> String:
	match screen_name:
		"gate", "table", "salvage":
			return "play"
		"deck":
			return "decks"
		"pack":
			return "packs"
		_:
			return "library"

## The four doors. Play is the Gate until a descent is live, then the Table.
func open_room(door: String) -> void:
	match door:
		"play":
			if Session.has_active_descent():
				go_table()
			else:
				go_gate()
		"library":
			go_library()
		"decks":
			go_deck()
		"packs":
			go_packs()
		_:
			go_library()

func go_library(selected_def: String = "") -> void:
	show_screen("library", {"selected_def": selected_def})

func go_gate() -> void:
	show_screen("gate")

func go_table(payload_data: Dictionary = {}) -> void:
	show_screen("table", payload_data)

func go_bench(instance: CardInstance, return_def: String = "") -> void:
	show_screen("bench", {"instance": instance, "return_def": return_def})

func go_salvage(result: Dictionary, returned: bool = false) -> void:
	show_screen("salvage", {"result": result, "returned": returned})

func go_packs(pack_id: int = 0) -> void:
	show_screen("pack", {"pack_id": pack_id})

## Legacy alias; remove after the one-version compatibility window.
func go_folio(pack_id: int = 0) -> void:
	go_packs(pack_id)

func go_deck() -> void:
	show_screen("deck")

func show_zoom(def: CardDef, instance: CardInstance, entry: Dictionary = {}) -> void:
	if def == null:
		return
	close_context_menu()
	close_zoom()
	zoom_overlay = ZoomOverlay.new()
	overlay.add_child(zoom_overlay)
	zoom_overlay.setup(self)
	zoom_overlay.open(def, instance, entry)

func close_zoom() -> void:
	if zoom_overlay != null and is_instance_valid(zoom_overlay):
		zoom_overlay.queue_free()
	zoom_overlay = null

func confirm(title: String, message: String, on_confirm: Callable, confirm_text: String = "Confirm") -> void:
	close_context_menu()
	if confirm_dialog != null and is_instance_valid(confirm_dialog):
		confirm_dialog.queue_free()
	confirm_dialog = ConfirmDialog.new()
	overlay.add_child(confirm_dialog)
	confirm_dialog.open(title, message, confirm_text, on_confirm)
	confirm_dialog.tree_exited.connect(func() -> void: confirm_dialog = null)

func open_context_menu(items: Array[Dictionary], anchor: Rect2, on_choose: Callable, source: Control = null) -> void:
	close_context_menu()
	context_menu = ContextMenu.new()
	overlay.add_child(context_menu)
	context_menu.setup(self)
	context_menu.closed.connect(func() -> void: context_menu = null)
	context_menu.open(items, anchor, on_choose, source)

func close_context_menu(restore_focus: bool = true) -> void:
	if context_menu != null and is_instance_valid(context_menu):
		context_menu.close(restore_focus)
	context_menu = null

func _on_viewport_size_changed() -> void:
	close_context_menu(false)
	_queue_metrics_refresh()

func toast(message: String, kind: String = "info") -> void:
	if toast_layer == null:
		return
	var panel := PanelContainer.new()
	var border := Tokens.BRASS
	if kind == "bad":
		border = Tokens.DANGER
	elif kind == "good":
		border = Tokens.GOOD
	panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.BG_RAISED, border, 1, 4))
	var label := UI.label(message, 13, Tokens.INK_PRIMARY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	toast_layer.add_child(panel)
	panel.modulate.a = 0.0
	panel.position = Vector2(0, 0)
	var safe: Rect2 = viewport_frame.safe_rect if viewport_frame != null else Rect2(Vector2.ZERO, get_viewport_rect().size)
	panel.reset_size()
	panel.position = Vector2(safe.position.x + (safe.size.x - panel.size.x) * 0.5, safe.position.y + 74.0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.tween_callback(panel.queue_free)

func _on_toast(message: String, kind: String) -> void:
	toast(message, kind)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.ctrl_pressed and key.keycode == KEY_S:
			Session.save_now()
			toast("Saved.", "good")
			get_viewport().set_input_as_handled()
		elif key.ctrl_pressed and key.keycode == KEY_E:
			_export_screen_text()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F1 or (key.keycode == KEY_SLASH and key.shift_pressed):
			_toggle_help()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ESCAPE and _help_overlay != null and is_instance_valid(_help_overlay):
			_help_overlay.queue_free()
			_help_overlay = null
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F11:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_F10 and OS.is_debug_build():
			_toggle_viewport_debug()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_Q and not key.ctrl_pressed:
			confirm("Leave the Library?", "Your collection is saved. Quit UIRPG?", func() -> void:
				Session.save_now()
				get_tree().quit()
			, "Quit")
			get_viewport().set_input_as_handled()

func _export_screen_text() -> void:
	var lines: Array[String] = []
	lines.append("UIRPG — %s" % current_screen_name.to_upper())
	lines.append("Marks %d · Cards %d · Definitions %d · Crafted %d · Packs %d" % [
		int(Session.currency.get("marks", 0)),
		Session.total_cards(),
		Session.total_definitions(),
		Session.crafted_count(),
		Session.unopened_packs().size(),
	])
	if current_screen != null and current_screen.has_method("export_text"):
		lines.append_array(current_screen.export_text())
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	toast("Screen exported to clipboard.", "good")

func _toggle_viewport_debug() -> void:
	if _viewport_debug != null and is_instance_valid(_viewport_debug):
		_viewport_debug.queue_free()
		_viewport_debug = null
		_viewport_debug_label = null
		return
	_viewport_debug = UI.panel(Tokens.BG_VOID, Tokens.CYAN, 10)
	_viewport_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_debug.z_index = 900
	_viewport_debug.position = Vector2(12, 12)
	overlay.add_child(_viewport_debug)
	_viewport_debug_label = UI.data_label("", 12, Tokens.INK_PRIMARY)
	_viewport_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_debug.add_child(_viewport_debug_label)
	update_viewport_debug()

func update_viewport_debug() -> void:
	if _viewport_debug_label == null or viewport_frame == null:
		return
	var mode := "FULLSCREEN" if is_fullscreen() else "WINDOWED"
	var safe: Rect2 = viewport_frame.safe_rect
	var lines := [
		"MODE      %s" % mode,
		"WINDOW    %s" % str(viewport_frame.window_size),
		"VIEWPORT  %s" % str(viewport_frame.viewport_size),
		"SAFE      %s" % str(safe),
		"DPR       %.2f" % viewport_frame.dpr,
		"SCREEN    %s" % current_screen_name.to_upper(),
	]
	if current_screen_name == "table" and current_screen != null:
		var stage = current_screen.get("stage")
		if stage != null:
			lines.append("TABLE     %s · card %.0f · shelf %.1f" % [str(stage.board_mode), float(stage.card_w), float(stage.hand_shelf_h)])
	_viewport_debug_label.text = "\n".join(lines)
	var minimum := _viewport_debug_label.get_combined_minimum_size()
	_viewport_debug.size = minimum + Vector2(20, 20)
	_viewport_debug_label.position = Vector2(10, 10)

func _toggle_help() -> void:
	close_context_menu()
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.queue_free()
		_help_overlay = null
		return
	_help_overlay = Control.new()
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_help_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)
	var fit := FitPanel.new()
	_help_overlay.add_child(fit)
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS, 24)
	fit.setup(panel, Vector2(720, 520), 16.0)
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.display("KEYS", 26))
	box.add_child(UI.hsep())
	var text := """Esc        back / close / deselect
Enter      confirm / zoom
Space      select / pause / reveal
1 2 4      speed
M          Auto -> Suggest -> Manual
H          HUD mode
C          Craft (Library)
E          Add to deck
P          Print
X          Dissolve
L          Lock
N          Name
*          Favorite
F2-F5      read board / card / log / actions
Ctrl+S     save now
Ctrl+E     export screen text
F1 / ?     this help

THE TABLE
Click a hand card, then a zone. Shift-click a monster zone to set.
Click your monster, then an enemy lane to attack.
E ends the phase. R recalls between duels. Q quits.
"""
	var label := UI.label(text, 13, Tokens.INK_SECONDARY, Tokens.font_data_regular())
	box.add_child(label)
	box.add_child(UI.button("Close", func() -> void:
		_help_overlay.queue_free()
		_help_overlay = null
	))
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_help_overlay.queue_free()
			_help_overlay = null
	)
