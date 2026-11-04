class_name ResultCeremony
extends Control

## The post-duel ceremony. It is a ledger and a set of doors, not an instant
## modal. Auto mode gets a visible countdown; any input cancels it.

signal finished

var table: Node
var app: Node
var result: Dictionary = {}
var panel: PanelContainer
var countdown_label: Label
var failure_label: Label
var auto_left: float = 3.0
var auto_enabled: bool = false
var _done: bool = false
var _busy: bool = false
var _focus_index: int = -1
var focusables: Array[Control] = []
var doors: Array[DoorCard] = []

func setup(table_ref: Node, result_ref: Dictionary) -> void:
	table = table_ref
	app = table.get("app") if table != null else null
	result = result_ref
	focusables.clear()
	doors.clear()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 150
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = UI.panel(Tokens.BG_PANEL, Tokens.WAX if str(result.get("kind", "")) == "fall" else Tokens.BRASS, 18)
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)
	var win := str(result.get("kind", "")) == "win"
	var title_text := "FLOOR %d CLEARED" % int(result.get("floor", 0)) if win else "FALL"
	if bool(result.get("chapter_seal", false)):
		title_text = "CHAPTER SEAL"
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var seal := SealMedallion.new()
	seal.mode = "identity"
	seal.caption = ""
	seal.custom_minimum_size = Vector2(84, 84)
	head.add_child(seal)
	var title_box := UI.vbox(1)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_child(UI.display(title_text, 30))
	title_box.add_child(UI.label("Salvage ledger" if not win else "Depth %02d · Circuit %d" % [int(result.get("floor", 1)), int(ceil(float(int(result.get("floor", 1))) / 9.0))], 12, Tokens.INK_SECONDARY))
	head.add_child(title_box)
	if win:
		var marks_chip := UI.chip("+%d MARKS" % int(result.get("marks", 0)), Tokens.BRASS_HI)
		marks_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(marks_chip)
		var streak_chip := UI.chip("STREAK %d" % int(result.get("streak", 0)), Tokens.SELECTION)
		streak_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(streak_chip)
	else:
		var marks_chip := UI.chip("+%d MARKS" % int(result.get("marks", 0)), Tokens.BRASS_HI)
		marks_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(marks_chip)
	box.add_child(UI.hsep())
	if win:
		_build_win(box)
	else:
		_build_fall(box)
	failure_label = UI.label("", 10, Tokens.DANGER)
	failure_label.visible = false
	box.add_child(failure_label)
	auto_enabled = str(table.get("mode")) == "auto" and not bool(result.get("chapter_seal", false))
	if auto_enabled:
		countdown_label = UI.label("AUTO IN 3", 10, Tokens.INK_MUTED)
		box.add_child(countdown_label)
		set_process(true)
	else:
		set_process(false)
	_focus_first()
	_animate_in()

func _animate_in() -> void:
	if bool(Session.settings.get("reduced_motion", false)):
		return
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)

func _build_win(box: VBoxContainer) -> void:
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 8)
	for pair in [
		["%d CARDS" % result.get("cards", []).size(), Tokens.INK_SECONDARY],
		["%d FOLIOS" % result.get("folios", []).size(), Tokens.VERDIGRIS],
		["STREAK %d" % int(result.get("streak", 0)), Tokens.SELECTION],
	]:
		var chip := UI.chip(str(pair[0]), pair[1])
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rewards.add_child(chip)
	box.add_child(rewards)
	var drops: Array = result.get("cards", [])
	if not drops.is_empty():
		var drop_row := HBoxContainer.new()
		drop_row.add_theme_constant_override("separation", 6)
		for i in range(mini(drops.size(), 6)):
			var drop: Dictionary = drops[i]
			var def: CardDef = Content.cards.get(str(drop.get("def_id", "")))
			if def == null:
				continue
			var temp := CardInstance.new(0, def.id, int(drop.get("provenance", 1)))
			temp.ink_id = str(drop.get("ink_id", "ink.iron"))
			temp.shimmer_id = str(drop.get("shimmer_id", "shimmer.none"))
			var view := CardView.new()
			view.set_card(def, temp, "B-")
			view.double_clicked.connect(func(card_view: CardView) -> void: app.show_zoom(card_view.def, card_view.instance))
			drop_row.add_child(view)
		box.add_child(drop_row)
	if bool(result.get("chapter_seal", false)):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		var continue_button := UI.button("CONTINUE", _choose_continue, Tokens.BRASS)
		continue_button.custom_minimum_size = Vector2(150, 44)
		var recall_button := UI.button("RECALL", _recall, Tokens.VERDIGRIS)
		recall_button.custom_minimum_size = Vector2(150, 44)
		row.add_child(continue_button)
		row.add_child(recall_button)
		box.add_child(row)
		focusables.append(continue_button)
		focusables.append(recall_button)
		return
	box.add_child(UI.small_caps("DOORS"))
	var door_row := HBoxContainer.new()
	door_row.add_theme_constant_override("separation", 8)
	door_row.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(door_row)
	for door_data in [
		["warden", "WARDEN", "Standard stair\nnormal loot", Tokens.BRASS],
		["vault", "VAULT", "Elite Warden\nricher loot", Tokens.VERDIGRIS],
		["stair", "STAIR", "Skip a floor\nno skipped loot", Tokens.BRASS_LO],
	]:
		var door := DoorCard.new()
		door.setup(str(door_data[0]), str(door_data[1]), str(door_data[2]), door_data[3])
		door.pressed.connect(_choose)
		doors.append(door)
		focusables.append(door)
		door_row.add_child(door)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 8)
	lower.add_child(UI.label("Route policy: %s" % str(Session.settings.get("route_policy", "safe")).capitalize(), 10, Tokens.INK_MUTED))
	lower.add_child(UI.spacer())
	var recall_button := UI.button("RECALL", _recall, Tokens.VERDIGRIS)
	recall_button.custom_minimum_size = Vector2(110, 44)
	lower.add_child(recall_button)
	focusables.append(recall_button)
	box.add_child(lower)

func _build_fall(box: VBoxContainer) -> void:
	var perf: Dictionary = result.get("performance", {})
	box.add_child(UI.data_label("PERFORMANCE %d · SALVAGE +%d MARKS" % [int(perf.get("total", 0)), int(result.get("marks", 0))], 13, Tokens.BRASS_HI))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 1)
	for pair in [
		["Floors cleared", str(perf.get("floor_points", 0))],
		["Best streak", str(perf.get("streak_points", 0))],
		["Flawless duels", str(perf.get("flawless_points", 0))],
		["Damage dealt", str(perf.get("damage_points", 0))],
		["Damage healed", str(perf.get("heal_points", 0))],
		["Cards played", str(perf.get("cards_points", 0))],
	]:
		grid.add_child(UI.label(pair[0], 11, Tokens.INK_MUTED))
		grid.add_child(UI.data_label(pair[1], 11, Tokens.INK_SECONDARY))
	box.add_child(grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var salvage := UI.button("SALVAGE", _salvage, Tokens.WAX)
	salvage.custom_minimum_size = Vector2(150, 44)
	var library := UI.button("LIBRARY", _library, Tokens.BRASS_LO)
	library.custom_minimum_size = Vector2(150, 44)
	row.add_child(salvage)
	row.add_child(library)
	box.add_child(row)
	focusables.append(salvage)
	focusables.append(library)

func _process(delta: float) -> void:
	if not auto_enabled or _done:
		return
	auto_left = maxf(0.0, auto_left - delta)
	if countdown_label != null:
		countdown_label.text = "AUTO IN %d" % int(ceil(auto_left))
	if auto_left <= 0.0:
		auto_enabled = false
		set_process(false)
		if countdown_label != null:
			countdown_label.visible = false
		var policy := str(Session.settings.get("route_policy", "safe"))
		if str(result.get("kind", "")) == "win":
			_choose("stair" if policy == "fast" else ("vault" if policy == "greedy" else "warden"))
		else:
			_salvage()

func _input(event: InputEvent) -> void:
	if not auto_enabled:
		return
	if event is InputEventMouseButton or event is InputEventKey:
		_cancel_auto()

func _cancel_auto() -> void:
	if not auto_enabled:
		return
	auto_enabled = false
	set_process(false)
	if countdown_label != null:
		countdown_label.visible = false
	_focus_first()

func _try_action(action: Callable, failure_message: String = "") -> bool:
	if _done or _busy:
		return false
	_busy = true
	var ok := bool(action.call())
	_busy = false
	if not ok:
		_recover_failure(failure_message)
		return false
	_done = true
	return true

func _recover_failure(message: String = "") -> void:
	_done = false
	auto_enabled = false
	set_process(false)
	if countdown_label != null:
		countdown_label.visible = false
	if failure_label != null:
		failure_label.text = message
		failure_label.visible = not message.is_empty()
	_focus_first()

func _choose(choice: String) -> void:
	_try_action(func() -> bool:
		if table == null or not table.has_method("_choose_door"):
			return false
		return bool(table._choose_door(choice))
	, "Cannot open that door.")

func _choose_continue() -> void:
	_try_action(func() -> bool:
		if table == null or not table.has_method("_next_floor"):
			return false
		return bool(table._next_floor())
	, "The next floor is not available.")

func _recall() -> void:
	_try_action(func() -> bool:
		if table == null or not table.has_method("_recall_now"):
			return false
		return bool(table._recall_now())
	, "Recall is not available.")

func _salvage() -> void:
	if _done or _busy:
		return
	_busy = true
	_done = true
	app.go_salvage(result)
	_busy = false

func _library() -> void:
	if _done or _busy:
		return
	_done = true
	app.go_library()

func _focus_first() -> void:
	for i in range(focusables.size()):
		var control := focusables[i]
		if control != null and is_instance_valid(control) and not (control is BaseButton and (control as BaseButton).disabled):
			_focus_index = i
			control.grab_focus()
			return

func _move_focus(delta: int) -> void:
	if focusables.is_empty():
		return
	var start := _focus_index
	var index := start
	for _attempt in range(focusables.size()):
		index = (index + delta + focusables.size()) % focusables.size()
		var control := focusables[index]
		if index == start or control == null or not is_instance_valid(control):
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		_focus_index = index
		control.grab_focus()
		return

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT or key.keycode == KEY_UP:
			_move_focus(-1)
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_DOWN:
			_move_focus(1)
		elif key.keycode == KEY_R:
			_recall()
		elif key.keycode in [KEY_1, KEY_2, KEY_3] and str(result.get("kind", "")) == "win":
			_choose(["warden", "vault", "stair"][key.keycode - KEY_1])
		elif key.keycode == KEY_ESCAPE and str(result.get("kind", "")) != "win":
			_library()
