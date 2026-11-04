class_name FolioScreen
extends UIScreen

## The Satchel Room: an envelope stack, a physical opening table, the Press,
## and a recent-pulls ledger. The wax is the only ceremony; the contents were
## rolled at acquisition and are committed when the seal cracks.

var mode: String = "satchel"
var pack_id: int = 0
var opened: bool = false
var reveal_data: Dictionary = {}
var revealed: Array[bool] = []
var before_owned: Dictionary = {}
var fan: FolioFan
var next_medallion: SealMedallion
var seal_button: SealMedallion
var stage_box: VBoxContainer
var status_label: Label
var summary_box: VBoxContainer
var press_box: VBoxContainer
var recent_box: VBoxContainer
var satchel_box: VBoxContainer
var marks_label: Label
var unopened_label: Label
var _busy: bool = false
var _current_cards: Array = []

func build() -> void:
	pack_id = int(payload.get("pack_id", 0))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root := UI.vbox(8)
	margin.add_child(root)
	root.add_child(_build_top())
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	content.add_child(_build_satchel())
	content.add_child(_build_stage())
	content.add_child(_build_press())
	if pack_id > 0:
		mode = "reveal"
	_refresh()

func _build_top() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var title := UI.vbox(0)
	title.add_child(UI.display("FOLIOS", 27))
	title.add_child(UI.small_caps("THE SATCHEL ROOM"))
	row.add_child(title)
	row.add_child(UI.spacer())
	# Chips keep their labels so values update without reconstructing the header.
	row.add_child(_chip_slot("MARKS", Tokens.BRASS_HI))
	row.add_child(_chip_slot("UNOPENED", Tokens.VERDIGRIS))
	row.add_child(UI.button("?", func() -> void: app._toggle_help(), Tokens.BRASS_LO))
	return panel

func _chip_slot(label_text: String, color: Color) -> Control:
	var chip := UI.panel(Tokens.BG_LACQUER, color.darkened(0.2), 6)
	var label := UI.data_label("0 %s" % label_text, 10, color)
	chip.add_child(label)
	if label_text == "MARKS":
		marks_label = label
	else:
		unopened_label = label
	return chip

func _build_satchel() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(5)
	panel.add_child(box)
	box.add_child(UI.small_caps("SATCHEL"))
	box.add_child(UI.hsep())
	var scroll := UI.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	satchel_box = UI.vbox(7)
	satchel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(satchel_box)
	return panel

func _build_stage() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(6)
	panel.add_child(box)
	box.add_child(UI.small_caps("THE TABLE"))
	box.add_child(UI.hsep())
	var stage_center := CenterContainer.new()
	stage_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(stage_center)
	stage_box = UI.vbox(8)
	stage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_box.custom_minimum_size = Vector2(520, 0)
	stage_center.add_child(stage_box)
	return panel

func _build_press() -> Control:
	var panel := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 8)
	panel.custom_minimum_size = Vector2(340, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := UI.vbox(5)
	panel.add_child(box)
	box.add_child(UI.small_caps("THE PRESS"))
	box.add_child(UI.hsep())
	press_box = UI.vbox(5)
	box.add_child(press_box)
	box.add_child(UI.hsep())
	box.add_child(UI.small_caps("RECENT PULLS"))
	recent_box = UI.vbox(2)
	box.add_child(recent_box)
	box.add_child(UI.hsep())
	box.add_child(UI.small_caps("SET PLATE"))
	box.add_child(UI.data_label("%d / %d DEFINITIONS" % [Session.total_definitions(), Content.cards.size()], 10, Tokens.INK_SECONDARY))
	var set_gauge := GaugeBar.new()
	set_gauge.set_value(Session.total_definitions(), maxi(1, Content.cards.size()))
	set_gauge.color = Tokens.BRASS
	set_gauge.show_numbers = false
	set_gauge.custom_minimum_size = Vector2(0, 8)
	box.add_child(set_gauge)
	var rarity_row := HBoxContainer.new()
	rarity_row.add_theme_constant_override("separation", 3)
	for rarity in ["common", "uncommon", "rare", "legendary"]:
		var count := 0
		for def in Content.card_list:
			if def.rarity == rarity and Session.codex.has(def.id):
				count += 1
		rarity_row.add_child(UI.chip("%s %d" % [GameConst.rarity_letter(rarity), count], Tokens.rarity_color(rarity)))
	box.add_child(rarity_row)
	return panel

func _refresh() -> void:
	var packs := Session.unopened_packs()
	if pack_id == 0 and not packs.is_empty():
		pack_id = int(packs[0].get("id", 0))
	if marks_label != null:
		marks_label.text = "%d MARKS" % int(Session.currency.get("marks", 0))
	if unopened_label != null:
		unopened_label.text = "%d UNOPENED" % Session.unopened_packs().size()
	_build_satchel_list()
	_build_stage_content()
	_refresh_press_list()
	_build_recent()

func _build_satchel_list() -> void:
	for child in satchel_box.get_children():
		satchel_box.remove_child(child)
		child.queue_free()
	var packs := Session.unopened_packs()
	if packs.is_empty():
		var empty := UI.panel(Tokens.BG_LACQUER, Tokens.BRASS_LO, 14)
		var box := UI.vbox(5)
		empty.add_child(box)
		box.add_child(UI.label("No sealed folios.", 13, Tokens.INK_SECONDARY))
		satchel_box.add_child(empty)
		return
	for pack in packs:
		satchel_box.add_child(_pack_row(pack))

func _pack_row(pack: Dictionary) -> Control:
	var folio := Content.folio(str(pack.get("kind", "")))
	var selected := int(pack.get("id", 0)) == pack_id
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.PAPER if not selected else Tokens.PAPER.lightened(0.04), Tokens.BRASS if selected else Tokens.BRASS_LO, 1, 5))
	panel.custom_minimum_size = Vector2(260, 128)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_pack_input.bind(int(pack.get("id", 0))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var seal := SealMedallion.new()
	seal.mode = "identity"
	seal.custom_minimum_size = Vector2(62, 72)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(seal)
	var box := UI.vbox(1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := UI.label(str(folio.get("name", "Folio")), 16, Tokens.PAPER_INK)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name)
	var meta := UI.label("%d cards · provenance %d" % [int(folio.get("cards", 3)), int(folio.get("provenance", 5))], 10, Color("#5A5144"))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meta)
	var sealed := UI.label("SEALED · %s" % str(pack.get("source", "drop")).capitalize(), 9, Color("#7A7060"))
	sealed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sealed)
	row.add_child(box)
	return panel

func _on_pack_input(event: InputEvent, selected_id: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		pack_id = selected_id
		mode = "reveal"
		opened = false
		reveal_data = {}
		revealed.clear()
		_refresh()

func _selected_pack() -> Dictionary:
	if pack_id > 0:
		return Session.pack_by_id(pack_id)
	var packs := Session.unopened_packs()
	return packs[0] if not packs.is_empty() else {}

func _build_stage_content() -> void:
	for child in stage_box.get_children():
		stage_box.remove_child(child)
		child.queue_free()
	var pack := _selected_pack()
	if pack.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.PAPER, Tokens.BRASS, 2, 8))
		empty.custom_minimum_size = Vector2(520, 300)
		empty.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stage_box.add_child(empty)
		var art := FolioEnvelopeArt.new()
		empty.add_child(art)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 28)
		margin.add_theme_constant_override("margin_right", 28)
		margin.add_theme_constant_override("margin_top", 22)
		margin.add_theme_constant_override("margin_bottom", 18)
		empty.add_child(margin)
		var box := UI.vbox(6)
		margin.add_child(box)
		box.add_child(UI.display("THE TABLE", 28, Tokens.PAPER_INK))
		box.add_child(UI.label("No sealed folios.", 12, Color("#5A5144")))
		box.add_child(UI.label("3 cards · uncommon guarantee · provenance 5", 10, Color("#7A7060")))
		box.add_child(UI.hsep(Color("#B9AE97")))
		box.add_child(UI.spacer())
		var buy_row := HBoxContainer.new()
		buy_row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(buy_row)
		var buy := SealMedallion.new()
		buy.caption = "BUY PAPER"
		buy.custom_minimum_size = Vector2(124, 140)
		buy.set_enabled(int(Session.currency.get("marks", 0)) >= 120)
		buy.pressed.connect(func() -> void: _buy_folio("folio.paper"))
		buy_row.add_child(buy)
		return
	stage_box.add_child(UI.spacer())
	if not opened:
		_build_sealed(pack)
		_build_sealed_details(pack)
	else:
		_build_reveal(pack)
	stage_box.add_child(UI.spacer())

func _build_sealed(pack: Dictionary) -> void:
	var folio := Content.folio(str(pack.get("kind", "")))
	var envelope := PanelContainer.new()
	envelope.add_theme_stylebox_override("panel", Tokens.panel_style(Tokens.PAPER, Tokens.BRASS, 2, 8))
	envelope.custom_minimum_size = Vector2(520, 300)
	envelope.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stage_box.add_child(envelope)
	var art := FolioEnvelopeArt.new()
	envelope.add_child(art)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	envelope.add_child(margin)
	var box := UI.vbox(6)
	margin.add_child(box)
	box.add_child(UI.display(str(folio.get("name", "Folio")), 28, Tokens.PAPER_INK))
	box.add_child(UI.label("%d cards · provenance %d · from %s" % [int(folio.get("cards", 3)), int(folio.get("provenance", 5)), str(pack.get("source", "drop"))], 11, Color("#5A5144")))
	box.add_child(UI.hsep(Color("#B9AE97")))
	box.add_child(UI.label("SEALED", 11, Color("#7A7060")))
	box.add_child(UI.spacer())
	var seal_row := HBoxContainer.new()
	seal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(seal_row)
	seal_button = SealMedallion.new()
	seal_button.caption = "CRACK"
	seal_button.custom_minimum_size = Vector2(124, 140)
	seal_button.pressed.connect(_crack)
	seal_row.add_child(seal_button)
	var hint := UI.label("Contents stored at acquisition.", 10, Color("#7A7060"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func _build_sealed_details(pack: Dictionary) -> void:
	var folio := Content.folio(str(pack.get("kind", "")))
	var details := UI.panel(Tokens.BG_PANEL, Tokens.BRASS_LO, 10)
	details.custom_minimum_size = Vector2(520, 0)
	stage_box.add_child(details)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	details.add_child(row)
	var contents := UI.vbox(2)
	contents.add_child(UI.small_caps("CONTENTS"))
	contents.add_child(UI.data_label("%d CARDS · PROVENANCE %d" % [int(folio.get("cards", 3)), int(folio.get("provenance", 5))], 11, Tokens.INK_SECONDARY))
	contents.add_child(UI.label("Guarantee: %s" % str(folio.get("guarantee", "uncommon")).capitalize(), 11, Tokens.VERDIGRIS))
	row.add_child(contents)
	var set_box := UI.vbox(2)
	set_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_box.add_child(UI.small_caps("SET PLATE"))
	set_box.add_child(UI.data_label("%d / %d DEFINITIONS" % [Session.total_definitions(), Content.cards.size()], 11, Tokens.INK_SECONDARY))
	var gauge := GaugeBar.new()
	gauge.set_value(Session.total_definitions(), maxi(1, Content.cards.size()))
	gauge.color = Tokens.BRASS
	gauge.show_numbers = false
	gauge.custom_minimum_size = Vector2(0, 8)
	set_box.add_child(gauge)
	row.add_child(set_box)
	var mode_box := UI.vbox(2)
	mode_box.add_child(UI.small_caps("OPEN MODE"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 3)
	for open_mode in ["ritual", "quick", "auto"]:
		var button := UI.button(open_mode.capitalize(), Callable(), Tokens.BRASS_LO)
		button.toggle_mode = true
		button.button_pressed = str(Session.settings.get("folio_mode", "ritual")) == open_mode
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func() -> void:
			Session.settings["folio_mode"] = open_mode
			Session.save_now()
			_refresh()
		)
		mode_row.add_child(button)
	mode_box.add_child(mode_row)
	row.add_child(mode_box)

func _build_reveal(pack: Dictionary) -> void:
	status_label = UI.label("Committed · 0 of %d revealed" % revealed.size(), 12, Tokens.INK_SECONDARY)
	stage_box.add_child(status_label)
	var cards: Array = reveal_data.get("cards", [])
	var reveal_token := "S" if cards.size() > 3 or get_viewport_rect().size.x < 1360 else "M"
	fan = FolioFan.new()
	fan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fan.custom_minimum_size = Vector2(0, fan.height_for_count(cards.size(), reveal_token))
	stage_box.add_child(fan)
	_current_cards.clear()
	revealed.resize(cards.size())
	for i in range(cards.size()):
		var drop: Dictionary = cards[i]
		var def: CardDef = Content.cards.get(str(drop.get("def_id", "")))
		if def == null:
			continue
		var temp := CardInstance.new(0, def.id, int(drop.get("provenance", 1)))
		temp.ink_id = str(drop.get("ink_id", "ink.iron"))
		temp.shimmer_id = str(drop.get("shimmer_id", "shimmer.none"))
		var before := int(before_owned.get(def.id, 0))
		var card_view := FolioRevealCard.new()
		card_view.setup(def, temp, before <= 0, before, reveal_token)
		card_view.pressed.connect(_on_reveal_card)
		_current_cards.append(card_view)
		if i < revealed.size() and revealed[i]:
			card_view.reveal_instant()
	fan.set_cards(_current_cards)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_box.add_child(controls)
	next_medallion = SealMedallion.new()
	next_medallion.caption = "NEXT"
	next_medallion.custom_minimum_size = Vector2(96, 112)
	next_medallion.pressed.connect(_reveal_next)
	controls.add_child(next_medallion)
	for pair in [["AUTO", _auto_reveal], ["REVEAL ALL", _reveal_all], ["SKIP", _skip]]:
		var button := UI.button(pair[0], pair[1], Tokens.BRASS_LO)
		button.custom_minimum_size = Vector2(90, 32)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		controls.add_child(button)
	summary_box = UI.vbox(4)
	stage_box.add_child(summary_box)
	_refresh_summary()

func _on_reveal_card(card: FolioRevealCard) -> void:
	if card == null:
		return
	if card.revealed:
		app.show_zoom(card.def, card.instance)
		return
	if _busy:
		return
	_busy = true
	await card.flip(0.22 if not bool(Session.settings.get("reduced_motion", false)) else 0.0)
	var index := _current_cards.find(card)
	if index >= 0 and index < revealed.size():
		revealed[index] = true
	_busy = false
	_refresh_summary()

func _reveal_next() -> void:
	if _busy:
		return
	for i in range(_current_cards.size()):
		if not revealed[i]:
			await _on_reveal_card(_current_cards[i])
			return

func _auto_reveal() -> void:
	if _busy:
		return
	for i in range(_current_cards.size()):
		if not revealed[i]:
			await _on_reveal_card(_current_cards[i])
			await get_tree().create_timer(0.25).timeout
			if not is_inside_tree():
				return

func _reveal_all() -> void:
	for i in range(_current_cards.size()):
		_current_cards[i].reveal_instant()
		if i < revealed.size():
			revealed[i] = true
	_refresh_summary()

func _skip() -> void:
	mode = "satchel"
	opened = false
	pack_id = 0
	reveal_data = {}
	revealed.clear()
	_refresh()

func _refresh_summary() -> void:
	if summary_box == null or not is_instance_valid(summary_box):
		return
	for child in summary_box.get_children():
		summary_box.remove_child(child)
		child.queue_free()
	var count := revealed.count(true) if revealed is Array else 0
	if status_label != null:
		status_label.text = "Committed · %d of %d revealed" % [count, revealed.size()]
	if next_medallion != null:
		next_medallion.set_enabled(count < revealed.size())
		next_medallion.caption = "ALL REVEALED" if count >= revealed.size() else "NEXT"
	if count < revealed.size():
		return
	var cards: Array = reveal_data.get("cards", [])
	var new_count := 0
	summary_box.add_child(UI.hsep())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UI.chip("%d CARDS" % cards.size(), Tokens.INK_SECONDARY))
	var reagents: Array = reveal_data.get("reagents", [])
	if not reagents.is_empty():
		row.add_child(UI.chip("%d REAGENTS" % reagents.size(), Tokens.VERDIGRIS))
	for card in _current_cards:
		if card.is_new:
			new_count += 1
	row.add_child(UI.chip("%d NEW" % new_count, Tokens.BRASS_HI))
	summary_box.add_child(row)
	summary_box.add_child(UI.label("Definitions %d / %d" % [Session.total_definitions(), Content.cards.size()], 10, Tokens.INK_MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	summary_box.add_child(actions)
	actions.add_child(UI.button("OPEN ANOTHER", func() -> void:
		mode = "satchel"
		opened = false
		pack_id = 0
		reveal_data = {}
		revealed.clear()
		_refresh()
	, Tokens.BRASS))
	actions.add_child(UI.button("SATCHEL", _skip, Tokens.BRASS_LO))

func _crack() -> void:
	var pack := Session.pack_by_id(pack_id)
	if pack.is_empty():
		app.toast("Folio not found.", "bad")
		return
	if seal_button != null:
		seal_button.pulse()
		if not bool(Session.settings.get("reduced_motion", false)):
			await get_tree().create_timer(0.14).timeout
			if not is_inside_tree():
				return
	# Snapshot ownership before the commit. The result's is_new is computed
	# after the add and answers a different question (first definition seen).
	before_owned.clear()
	for drop in pack.get("contents", {}).get("cards", []):
		var def_id := str(drop.get("def_id", ""))
		if not before_owned.has(def_id):
			before_owned[def_id] = Session.def_owned_count(def_id)
	var result := Session.open_pack(pack_id)
	if not bool(result.get("ok", false)):
		app.toast(str(result.get("reason", "Could not open.")), "bad")
		return
	reveal_data = result
	opened = true
	revealed.clear()
	for drop in result.get("cards", []):
		revealed.append(false)
	app.toast("Committed.", "good")
	_refresh()
	if str(Session.settings.get("folio_mode", "ritual")) in ["quick", "auto"]:
		_auto_reveal()

func _refresh_press_list() -> void:
	for child in press_box.get_children():
		press_box.remove_child(child)
		child.queue_free()
	for kind in ["folio.paper", "folio.brass", "folio.deep", "folio.set"]:
		var folio := Content.folio(kind)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		var box := UI.vbox(0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UI.label(str(folio.get("name", kind)), 12, Tokens.INK_PRIMARY))
		var guarantee := str(folio.get("guarantee", "uncommon")).capitalize()
		box.add_child(UI.label("%d cards · %s · prov %d" % [int(folio.get("cards", 3)), guarantee, int(folio.get("provenance", 5))], 9, Tokens.INK_MUTED))
		row.add_child(box)
		var price := int(folio.get("price", 0))
		row.add_child(UI.data_label("%d" % price, 11, Tokens.BRASS_HI))
		var buy := UI.button("BUY", _buy_folio.bind(kind), Tokens.BRASS)
		buy.disabled = int(Session.currency.get("marks", 0)) < price
		row.add_child(buy)
		press_box.add_child(row)

func _buy_folio(kind: String) -> void:
	var folio := Content.folio(kind)
	var price := int(folio.get("price", 0))
	var do_buy := func() -> void:
		var result := Session.buy_folio(kind)
		if bool(result.get("ok", false)):
			var pack: Dictionary = result.get("pack", {})
			pack_id = int(pack.get("id", 0))
			mode = "reveal"
			opened = false
			_refresh()
			app.toast("Acquired.", "good")
		else:
			app.toast(str(result.get("reason", "Not enough Marks.")), "bad")
	if price >= 400:
		app.confirm("Buy %s?" % str(folio.get("name", kind)), "%d Marks. The contents are committed when the wax cracks." % price, do_buy, "Buy")
	else:
		do_buy.call()

func _build_recent() -> void:
	for child in recent_box.get_children():
		recent_box.remove_child(child)
		child.queue_free()
	var lines := 0
	for pack in Session.packs:
		if int(pack.get("opened_at", 0)) == 0:
			continue
		for drop in pack.get("contents", {}).get("cards", []):
			var def: CardDef = Content.cards.get(str(drop.get("def_id", "")))
			if def == null:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.add_child(UI.chip(GameConst.rarity_letter(def.rarity), Tokens.rarity_color(def.rarity)))
			row.add_child(UI.label(def.name, 10, Tokens.INK_SECONDARY))
			recent_box.add_child(row)
			lines += 1
			if lines >= 10:
				return
	if lines == 0:
		recent_box.add_child(UI.label("No pulls.", 10, Tokens.INK_MUTED))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_ESCAPE:
				if mode == "reveal":
					_skip()
				else:
					app.go_library()
			KEY_SPACE:
				if opened:
					_reveal_next()
				else:
					_crack()
			KEY_A:
				if opened:
					_auto_reveal()
			KEY_R:
				if opened:
					_reveal_all()
			KEY_S:
				if opened:
					_skip()

func export_text() -> Array[String]:
	var lines: Array[String] = ["Folios · %d unopened · %d Marks" % [Session.unopened_packs().size(), int(Session.currency.get("marks", 0))]]
	for card in _current_cards:
		if card != null and card.def != null:
			lines.append("%s · %s" % [card.def.name, "revealed" if card.revealed else "sealed"])
	return lines
