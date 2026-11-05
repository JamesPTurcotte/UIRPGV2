extends Control

## Visual layout audit. Run at a specific window size:
##   godot --path . --resolution 1440x900 res://tests/layout_audit.tscn
##   godot --path . --resolution 1920x1080 res://tests/layout_audit.tscn
## Exits non-zero if a visible control is laid out outside the logical viewport.
## ScrollContainer subtrees are skipped because their content is intentionally
## larger than the viewport and is clipped/scrolled.

var app: Control
var failures: Array[String] = []
var requested_size := Vector2i.ZERO
var requested_fullscreen := false

func _ready() -> void:
	theme = ThemeBuilder.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.get_slice("=", 1).split("x")
			if parts.size() == 2:
				requested_size = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--fullscreen":
			requested_fullscreen = true
	app = load("res://src/presentation/app.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(app)
	await get_tree().create_timer(0.7).timeout
	if requested_fullscreen:
		app.set_fullscreen(true)
		await get_tree().create_timer(0.8).timeout
	await _check_plain("library")
	await _check_plain("gate")
	await _check_plain("deck")
	await _check_bench()
	await _check_plain("folio")
	await _check_salvage()
	await _check_table()
	await _check_modals()
	print("layout audit: %d failure(s) at %s" % [failures.size(), str(get_viewport_rect().size)])
	for failure in failures:
		print("  FAIL: %s" % failure)
	get_tree().quit(1 if not failures.is_empty() else 0)

func _check_plain(screen_name: String) -> void:
	app.show_screen(screen_name)
	await get_tree().create_timer(0.5).timeout
	_audit(screen_name, app.current_screen)

func _check_salvage() -> void:
	var drops: Array[Dictionary] = []
	for i in range(12):
		var def: CardDef = Content.card_list[i % Content.card_list.size()]
		drops.append({"def_id": def.id, "provenance": 5})
	var fake := {
		"kind": "fall",
		"floor": 9,
		"marks": 406,
		"performance": {"total": 322},
		"reagents": {"reagent.pale_ink": 1},
		"cards": drops,
		"underdog": 0.17,
		"salvage_cache": true,
	}
	app.go_salvage(fake, false)
	await get_tree().create_timer(0.5).timeout
	_audit("salvage", app.current_screen)

func _check_bench() -> void:
	var instance = Session.bench_instance()
	if instance == null:
		for entry in Session.collection_entries():
			var pulled: Dictionary = Session.pull_entry_to_bench(entry)
			if bool(pulled.get("ok", false)):
				instance = pulled.get("instance")
				break
	if instance == null:
		failures.append("bench: no instance available")
		return
	app.go_bench(instance)
	await get_tree().create_timer(0.5).timeout
	_audit("bench", app.current_screen)
	Session.close_bench(false)

func _check_table() -> void:
	var deck = Session.active_deck()
	if deck == null or not Session.deck_errors(deck).is_empty():
		Session.auto_fill_deck()
	if Session.has_active_descent():
		Session.abandon_descent()
	Session.start_descent(1, Session.active_deck_id, "manual")
	app.show_screen("table")
	await get_tree().create_timer(0.8).timeout
	# The table is native-pixel and fills its window. Other rooms use the 1440
	# design canvas, so only the table is audited at each requested size.
	if requested_size.x > 0 and requested_size.y > 0 and not app.is_fullscreen():
		DisplayServer.window_set_size(requested_size)
		await get_tree().create_timer(0.35).timeout
	# Freeze the duel before auditing so a card caught mid-tween is not reported
	# as a layout failure; the audit is about rest geometry, not animation paths.
	app.current_screen.paused = true
	app.current_screen.timer.stop()
	await get_tree().create_timer(0.5).timeout
	_audit("table", app.current_screen)

func _audit(screen_name: String, screen: Control) -> void:
	if screen == null:
		failures.append("%s: screen is null" % screen_name)
		return
	var root := screen.get_child(0) as Control
	_audit_node(screen_name, root)

func _audit_node(screen_name: String, root: Control) -> void:
	var viewport := get_viewport_rect().size
	if root == null:
		failures.append("%s: no root control" % screen_name)
		return
	var root_rect := root.get_global_rect()
	if not _inside(root_rect, viewport):
		failures.append("%s: root %s outside %s" % [screen_name, str(root_rect), str(viewport)])
	_audit_children(root, viewport, screen_name)

func _check_modals() -> void:
	if app.current_screen == null or app.current_screen_name != "table":
		return
	var table = app.current_screen
	app.show_zoom(Content.cards.values()[0], null)
	await get_tree().create_timer(0.35).timeout
	_audit_node("zoom", app.overlay)
	app.close_zoom()
	app.confirm("Audit dialog", "A long confirmation message that must stay inside the viewport.", func() -> void: pass, "Confirm")
	await get_tree().create_timer(0.35).timeout
	_audit_node("confirm", app.overlay)
	if app.confirm_dialog != null:
		app.confirm_dialog.close()
	table._show_pile("DECK", table.duel.players[0].deck, true)
	await get_tree().create_timer(0.35).timeout
	if table.pile_overlay != null:
		_audit_node("pile", table.pile_overlay)
		table.pile_overlay.queue_free()
		table.pile_overlay = null
	app._toggle_help()
	await get_tree().create_timer(0.35).timeout
	_audit_node("help", app.overlay)
	app._toggle_help()

func _audit_children(node: Node, viewport: Vector2, screen_name: String, clipped: bool = false) -> void:
	if node is ScrollContainer:
		var scroll := node as ScrollContainer
		if scroll.is_visible_in_tree() and not _inside(scroll.get_global_rect(), viewport):
			failures.append("%s: scroll %s outside %s" % [screen_name, str(scroll.get_global_rect()), str(viewport)])
		if scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			_audit_scroll_width(scroll, scroll.get_global_rect(), screen_name)
		return
	var next_clipped := clipped
	if node is Control:
		var control := node as Control
		if not clipped and control.is_visible_in_tree():
			var rect := control.get_global_rect()
			if not _inside(rect, viewport):
				failures.append("%s: %s %s outside %s" % [screen_name, control.get_path(), str(rect), str(viewport)])
		next_clipped = clipped or control.clip_contents
	for child in node.get_children():
		_audit_children(child, viewport, screen_name, next_clipped)

func _audit_scroll_width(node: Node, bounds: Rect2, screen_name: String) -> void:
	for child in node.get_children():
		if child is ScrollContainer:
			continue
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree():
				var rect := control.get_global_rect()
				if rect.position.x < bounds.position.x - 1.0 or rect.end.x > bounds.end.x + 1.0:
					failures.append("%s: horizontal overflow in scroll: %s %s outside %s" % [screen_name, control.get_path(), str(rect), str(bounds)])
		_audit_scroll_width(child, bounds, screen_name)

func _inside(rect: Rect2, viewport: Vector2) -> bool:
	const EPSILON := 1.0
	return rect.position.x >= -EPSILON and rect.position.y >= -EPSILON \
		and rect.end.x <= viewport.x + EPSILON and rect.end.y <= viewport.y + EPSILON
