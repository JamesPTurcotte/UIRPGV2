class_name WardenStrip
extends PanelContainer

## The Warden's strip: seal, identity, resolve, the guard contract, and the
## hidden hand count. The guard chip is the rule made visible.

var table: Node
var seal: WardenSeal
var kicker_label: Label
var name_label: Label
var meta_label: Label
var resolve_bar: GaugeBar
var resolve_label: Label
var resolve_max_label: Label
var guard_chip: PanelContainer
var guard_label: Label
var intent_chip: PanelContainer
var intent_label: Label
var hand_label: Label
var deck_label: Label
var mini_hand: MiniHand
var _guard_style: StyleBoxFlat

func setup(table_ref: Node) -> void:
	table = table_ref
	custom_minimum_size = Vector2(0, 70)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Tokens.BG_PANEL.r, Tokens.BG_PANEL.g, Tokens.BG_PANEL.b, 0.88)
	style.border_color = Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.30)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	seal = WardenSeal.new()
	seal.custom_minimum_size = Vector2(56, 56)
	row.add_child(seal)

	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 0)
	identity.custom_minimum_size = Vector2(242, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_stretch_ratio = 0.9
	kicker_label = UI.small_caps("WARDEN · FLOOR 01")
	identity.add_child(kicker_label)
	name_label = UI.display("The Warden", 18)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(name_label)
	meta_label = UI.label("doctrine", 9, Tokens.INK_MUTED, Tokens.font_label())
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(meta_label)
	row.add_child(identity)

	var resolve := VBoxContainer.new()
	resolve.add_theme_constant_override("separation", 2)
	resolve.custom_minimum_size = Vector2(360, 0)
	resolve.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resolve.size_flags_stretch_ratio = 1.4
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UI.small_caps("RESOLVE"))
	resolve_label = UI.data_label("4000", 24, Tokens.INK_PRIMARY)
	head.add_child(resolve_label)
	resolve_max_label = UI.label("/ 4000", 10, Tokens.INK_MUTED, Tokens.font_label())
	head.add_child(resolve_max_label)
	head.add_child(UI.spacer())
	resolve.add_child(head)
	resolve_bar = GaugeBar.new()
	resolve_bar.color = Tokens.PINK
	resolve_bar.show_numbers = false
	resolve_bar.compact = true
	resolve_bar.custom_minimum_size = Vector2(0, 10)
	resolve.add_child(resolve_bar)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	guard_chip = PanelContainer.new()
	_guard_style = Tokens.panel_style(Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.55), Tokens.PINK, 1, 2)
	_guard_style.content_margin_left = 7
	_guard_style.content_margin_right = 7
	_guard_style.content_margin_top = 2
	_guard_style.content_margin_bottom = 2
	guard_chip.add_theme_stylebox_override("panel", _guard_style)
	guard_label = UI.label("◆ 0 GUARDS · FACE OPEN", 8, Tokens.GREEN, Tokens.font_label())
	guard_chip.add_child(guard_label)
	foot.add_child(guard_chip)
	intent_chip = PanelContainer.new()
	var intent_style := Tokens.panel_style(Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.55), Tokens.PANEL_LINE, 1, 2)
	intent_style.content_margin_left = 7
	intent_style.content_margin_right = 7
	intent_style.content_margin_top = 2
	intent_style.content_margin_bottom = 2
	intent_chip.add_theme_stylebox_override("panel", intent_style)
	intent_label = UI.label("NEXT · HOLD", 8, Tokens.INK_SECONDARY, Tokens.font_label())
	intent_chip.add_child(intent_label)
	foot.add_child(intent_chip)
	resolve.add_child(foot)
	row.add_child(resolve)

	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 0)
	hand_box.custom_minimum_size = Vector2(150, 0)
	var hand_head := HBoxContainer.new()
	hand_head.add_theme_constant_override("separation", 6)
	hand_label = UI.label("HAND 0", 9, Tokens.INK_SECONDARY, Tokens.font_label())
	hand_head.add_child(hand_label)
	hand_head.add_child(UI.spacer())
	deck_label = UI.label("DECK 0", 9, Tokens.INK_MUTED, Tokens.font_label())
	hand_head.add_child(deck_label)
	hand_box.add_child(hand_head)
	mini_hand = MiniHand.new()
	mini_hand.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mini_hand.custom_minimum_size = Vector2(62, 38)
	hand_box.add_child(mini_hand)
	row.add_child(hand_box)

func _draw() -> void:
	# A pink event seam under the cyan frame: the Warden is the wound.
	draw_rect(Rect2(1.0, size.y - 2.0, size.x - 2.0, 1.0), Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.45))
	draw_line(Vector2(size.x * 0.22, size.y - 1.0), Vector2(size.x * 0.78, size.y - 1.0), Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.28), 1.0)

func refresh(state, opponent: Dictionary, intent: Dictionary) -> void:
	if state == null:
		return
	var warden = state.players[1]
	var floor_number := int(Session.descent.get("current_floor", 1))
	kicker_label.text = "WARDEN · FLOOR %02d" % floor_number
	name_label.text = str(warden.name)
	var doctrine := str(warden.doctrine).to_upper()
	var modifier := "NO RITUAL"
	if not opponent.is_empty():
		var raw = opponent.get("modifier", null)
		if raw != null and not str(raw).is_empty():
			modifier = str(raw).replace("_", " ").to_upper()
	meta_label.text = "%s · %s" % [doctrine, modifier]
	resolve_bar.set_value(warden.resolve, warden.max_resolve)
	resolve_label.text = _fmt(warden.resolve)
	resolve_max_label.text = "/ %s" % _fmt(warden.max_resolve)
	resolve_bar.color = Tokens.DANGER if warden.resolve <= 1000 else Tokens.PINK
	resolve_label.add_theme_color_override("font_color", Tokens.DANGER if warden.resolve <= 1000 else Tokens.INK_PRIMARY)

	sync_guards(state)
	var guards := _guard_count(warden)
	intent_label.text = "NEXT · %s" % str(intent.get("chip", "HOLD"))
	intent_label.add_theme_color_override("font_color", Tokens.PURPLE if guards > 0 else Tokens.INK_SECONDARY)
	hand_label.text = "HAND %d" % warden.hand.size()
	deck_label.text = "DECK %d" % warden.deck.size()
	mini_hand.set_count(warden.hand.size())
	seal.set_tone(Tokens.RED if warden.resolve <= 1000 else Tokens.PURPLE)
	queue_redraw()

func sync_guards(state) -> void:
	if state == null or guard_label == null:
		return
	var warden = state.players[1]
	var guards := _guard_count(warden)
	if guards > 0:
		guard_label.text = "◆ %d GUARD%s · FACE SEALED" % [guards, "" if guards == 1 else "S"]
		guard_label.add_theme_color_override("font_color", Tokens.PINK)
		_guard_style.border_color = Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.55)
		_guard_style.bg_color = Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.055)
	else:
		guard_label.text = "◇ NO GUARDS · FACE OPEN"
		guard_label.add_theme_color_override("font_color", Tokens.GREEN)
		_guard_style.border_color = Color(Tokens.GREEN.r, Tokens.GREEN.g, Tokens.GREEN.b, 0.40)
		_guard_style.bg_color = Color(Tokens.GREEN.r, Tokens.GREEN.g, Tokens.GREEN.b, 0.045)
	guard_chip.queue_redraw()

func _guard_count(warden) -> int:
	var count := 0
	for monster in warden.monsters:
		if monster != null:
			count += 1
	return count

static func _fmt(value: int) -> String:
	return UI.format_number(value)
