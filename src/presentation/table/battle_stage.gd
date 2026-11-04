class_name BattleStage
extends Control

## Stable table stage. Actors are keyed by DuelCard.uid and outlive zone changes.
## The stage owns geometry only; TableScreen owns rules, input, and timing.
##
## The composition is three vertical lanes. Each lane is an enemy backrow, an
## enemy front row, a seam, a player front row, and a player backrow. The hand
## fan and action dock share the bottom band.

signal zone_clicked(owner: int, zone_type: String, lane: int)

const LANE_NUMERALS := ["I", "II", "III"]
const LANE_UNITS := [0.46, 1.72, 0.16, 1.72, 0.46]

var duel: DuelState
var table: Node
var board_token: String = "B+"
var hand_token: String = "H"
var back_token: String = "T"
var actors: Dictionary = {}
var zone_rects: Dictionary = {}
var slot_rects: Dictionary = {}
var hand_rects: Dictionary = {}
var hand_angles: Dictionary = {}
var lane_rects: Array[Rect2] = []
var board_rect: Rect2 = Rect2()
var hand_zone_rect: Rect2 = Rect2()
var dock_rect: Rect2 = Rect2()
var deck_rect: Rect2 = Rect2()
var remains_rect: Rect2 = Rect2()
var void_rect: Rect2 = Rect2()
var opp_hand_rect: Rect2 = Rect2()
var legal_zones: Dictionary = {}
var selected_hand_uid: int = -1
var selected_board_uid: int = -1
var focus_lane: int = -1
var auto_broadcast: bool = false
var impact_lane: int = -1
var impact_owner: int = 1
var cue_text: String = ""
var cue_color: Color = Tokens.CYAN
var cue_alpha: float = 0.0
var _last_size: Vector2 = Vector2.ZERO

func setup(table_ref: Node) -> void:
	table = table_ref
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_on_resized)
	set_process(true)

func _ready() -> void:
	_choose_tokens()
	_on_resized()

func set_duel(state: DuelState) -> void:
	duel = state
	_choose_tokens()
	_on_resized()

func _choose_tokens() -> void:
	# Tokens are chosen in logical viewport space. The window size is physical
	# and changes with OS scaling and stretch aspect.
	var viewport_h := int(Responsive.viewport_size(self).y)
	if viewport_h < 820:
		board_token = "B-"
		hand_token = "H-"
	elif viewport_h < 1000:
		board_token = "B+"
		hand_token = "H-"
	else:
		board_token = "S"
		hand_token = "H"

func _on_resized() -> void:
	_compute_rects()
	queue_redraw()

func _process(delta: float) -> void:
	if size != _last_size:
		_last_size = size
		var previous_board := board_token
		_choose_tokens()
		_on_resized()
		if duel != null:
			if board_token != previous_board:
				sync_all(duel)
			apply_rest(duel)
	if cue_alpha > 0.0:
		cue_alpha = maxf(0.0, cue_alpha - delta * 0.62)
		queue_redraw()

func _compute_rects() -> void:
	zone_rects.clear()
	slot_rects.clear()
	lane_rects.clear()
	if size.x <= 1 or size.y <= 1:
		return
	var board := Tokens.card_size(board_token)
	var back := Tokens.card_size(back_token)
	var hand := Tokens.card_size(hand_token)
	var lane_gap := clampf(size.x * 0.012, 8.0, 14.0)
	var hand_height := hand.y + 40.0
	var dock_width := clampf(size.x * 0.27, 214.0, 272.0)
	var hand_top := size.y - hand_height
	hand_zone_rect = Rect2(0, hand_top, size.x - dock_width - 10.0, hand_height)
	dock_rect = Rect2(size.x - dock_width, hand_top + 4.0, dock_width, hand_height - 8.0)
	board_rect = Rect2(0, 0, size.x, hand_top - 6.0)
	deck_rect = Rect2(hand_zone_rect.position.x + 8.0, hand_zone_rect.end.y - 82.0, 42.0, 58.8)
	remains_rect = Rect2(-board.x - 12.0, hand_top + 8.0, board.x, board.y)
	void_rect = Rect2(size.x + 12.0, hand_top + 8.0, board.x, board.y)
	opp_hand_rect = Rect2(size.x - 86.0, 6.0, 56.0, 72.0)

	var lane_width := (size.x - lane_gap * 2.0) / 3.0
	var row_gap := 2.0
	var usable := maxf(40.0, board_rect.size.y - 4.0 - row_gap * 4.0)
	var unit_total := 0.0
	for unit in LANE_UNITS:
		unit_total += float(unit)
	for lane in range(3):
		var lane_x := float(lane) * (lane_width + lane_gap)
		var lane_rect := Rect2(lane_x, 2.0, lane_width, board_rect.size.y - 4.0)
		lane_rects.append(lane_rect)
		var row_y := lane_rect.position.y
		var row_rects: Array[Rect2] = []
		for unit in LANE_UNITS:
			var row_h := usable * float(unit) / unit_total
			row_rects.append(Rect2(lane_rect.position.x + 6.0, row_y, lane_width - 12.0, row_h))
			row_y += row_h + row_gap

		var enemy_back := row_rects[0]
		var enemy_front := row_rects[1]
		var seam := row_rects[2]
		var player_front := row_rects[3]
		var player_back := row_rects[4]

		slot_rects["1|backrow|%d" % lane] = enemy_back
		slot_rects["1|monster|%d" % lane] = enemy_front
		slot_rects["0|monster|%d" % lane] = player_front
		slot_rects["0|backrow|%d" % lane] = player_back

		zone_rects["1|monster|%d" % lane] = _centered(enemy_front, board)
		zone_rects["0|monster|%d" % lane] = _centered(player_front, board)
		zone_rects["1|backrow|%d" % lane] = _back_rect(enemy_back, back, lane_rect)
		zone_rects["0|backrow|%d" % lane] = _back_rect(player_back, back, lane_rect)
	_compute_hand_rects()

func _centered(row: Rect2, card_size: Vector2) -> Rect2:
	return Rect2(
		Vector2(row.get_center().x - card_size.x * 0.5, row.get_center().y - card_size.y * 0.5),
		card_size
	)

func _back_rect(row: Rect2, back_size: Vector2, lane_rect: Rect2) -> Rect2:
	var desired_y := row.get_center().y - back_size.y * 0.5
	var min_y := lane_rect.position.y + 2.0
	var max_y := lane_rect.end.y - back_size.y - 2.0
	return Rect2(
		Vector2(row.get_center().x - back_size.x * 0.5, clampf(desired_y, min_y, maxf(min_y, max_y))),
		back_size
	)

func _compute_hand_rects() -> void:
	hand_rects.clear()
	hand_angles.clear()
	if duel == null:
		return
	var hand := duel.players[0].hand
	var hand_size := Tokens.card_size(hand_token)
	var count := hand.size()
	if count == 0:
		return
	var start_x := deck_rect.end.x + 14.0
	var available := maxf(120.0, hand_zone_rect.end.x - start_x - 6.0)
	var step := hand_size.x * 0.72
	if count > 1:
		step = minf(step, (available - hand_size.x) / float(count - 1))
	step = maxf(48.0, step)
	var total := step * float(count - 1) + hand_size.x
	var x := start_x + maxf(0.0, (available - total) * 0.5)
	var base_y := hand_zone_rect.end.y - hand_size.y - 16.0
	var center := float(count - 1) * 0.5
	for i in range(count):
		var card: DuelCard = hand[i]
		var offset := float(i) - center
		var lift := 16.0 if card.uid == selected_hand_uid else 0.0
		var y := base_y + absf(offset) * 2.4 - lift
		hand_rects[card.uid] = Rect2(Vector2(x + step * float(i), y), hand_size)
		hand_angles[card.uid] = clampf(offset * 2.1, -8.0, 8.0)

func capture_layout(state: DuelState) -> Dictionary:
	duel = state
	_compute_rects()
	queue_redraw()
	var layout: Dictionary = {}
	for card in state.players[0].hand:
		layout[card.uid] = hand_rects.get(card.uid, deck_rect)
	for owner in [0, 1]:
		for lane in range(3):
			var monster: DuelCard = state.players[owner].monsters[lane]
			if monster != null:
				layout[monster.uid] = zone_rects.get("%d|monster|%d" % [owner, lane], deck_rect)
			var back: DuelCard = state.players[owner].backrow[lane]
			if back != null:
				layout[back.uid] = zone_rects.get("%d|backrow|%d" % [owner, lane], deck_rect)
	for card in state.players[1].hand:
		layout[card.uid] = opp_hand_rect
	for card in state.players[0].deck:
		layout[card.uid] = deck_rect
	for card in state.players[1].deck:
		layout[card.uid] = opp_hand_rect
	for card in state.players[0].remains:
		layout[card.uid] = remains_rect
	for card in state.players[0].banished:
		layout[card.uid] = void_rect
	return layout

func rest_rect_for(card: DuelCard, state: DuelState) -> Rect2:
	if card == null:
		return deck_rect
	duel = state
	_compute_rects()
	if card.owner == 0:
		if card.zone == GameConst.ZONE_HAND:
			return hand_rects.get(card.uid, deck_rect)
		if card.zone == GameConst.ZONE_MONSTER or card.zone == GameConst.ZONE_BACKROW:
			return zone_rects.get("%d|%s|%d" % [card.owner, card.zone, card.lane], deck_rect)
		if card.zone == GameConst.ZONE_REMAINS:
			return remains_rect
		if card.zone == GameConst.ZONE_VOID:
			return void_rect
	return opp_hand_rect

func ensure_actor(card: DuelCard, token: String = "") -> CardActor:
	if card == null:
		return null
	var actor: CardActor = actors.get(card.uid)
	if actor == null:
		actor = CardActor.new()
		actor.setup(card, token if not token.is_empty() else _token_for(card))
		actor.clicked.connect(_on_actor_clicked)
		actor.right_clicked.connect(_on_actor_right_clicked)
		add_child(actor)
		actors[card.uid] = actor
	elif not token.is_empty() and actor.token != token:
		actor.set_token(token)
	actor.card = card
	actor.z_index = _z_for(card)
	actor.refresh()
	return actor

func _token_for(card: DuelCard) -> String:
	if card != null and card.owner == 0 and card.zone == GameConst.ZONE_HAND:
		return hand_token
	if card != null and card.zone == GameConst.ZONE_BACKROW:
		return back_token
	return board_token

func _z_for(card: DuelCard) -> int:
	if card.owner == 0 and card.zone == GameConst.ZONE_HAND:
		return 20
	if card.zone == GameConst.ZONE_BACKROW:
		return 2
	if card.zone == GameConst.ZONE_MONSTER:
		return 4
	return 1

func sync_all(state: DuelState) -> void:
	duel = state
	_compute_rects()
	queue_redraw()
	var present: Dictionary = {}
	for card in state.players[0].hand:
		var actor := ensure_actor(card, hand_token)
		actor.set_ad("")
		actor.set_action_seal(card.uid == selected_hand_uid)
		actor.set_selected(card.uid == selected_hand_uid)
		present[card.uid] = true
	for owner in [0, 1]:
		for lane in range(3):
			var monster: DuelCard = state.players[owner].monsters[lane]
			if monster != null:
				var actor := ensure_actor(monster, board_token)
				actor.set_ad(_ad_for(monster))
				actor.set_action_seal(monster.uid == selected_board_uid and owner == 0)
				present[monster.uid] = true
			var back: DuelCard = state.players[owner].backrow[lane]
			if back != null:
				var actor := ensure_actor(back, back_token)
				actor.set_ad("SET" if back.face_down else "")
				present[back.uid] = true
	for uid in actors.keys():
		if not present.has(uid):
			(actors[uid] as CardActor).queue_free()
			actors.erase(uid)

func apply_rest(state: DuelState) -> void:
	sync_all(state)
	for card in state.players[0].hand:
		var actor: CardActor = actors.get(card.uid)
		if actor != null:
			actor.set_token(hand_token)
			actor.z_index = 20
			actor.set_rest(hand_rects.get(card.uid, deck_rect))
			actor.set_angle(float(hand_angles.get(card.uid, 0.0)))
	for owner in [0, 1]:
		for lane in range(3):
			for card in [state.players[owner].monsters[lane], state.players[owner].backrow[lane]]:
				if card == null:
					continue
				var actor: CardActor = actors.get(card.uid)
				if actor != null:
					actor.set_token(_token_for(card))
					actor.z_index = _z_for(card)
					actor.set_rest(zone_rects.get("%d|%s|%d" % [owner, card.zone, lane], deck_rect))
					actor.set_angle(0.0)
					actor.set_ad(_ad_for(card) if card.zone == GameConst.ZONE_MONSTER else ("SET" if card.face_down else ""))
					actor.set_action_seal(card.uid == selected_board_uid and owner == 0)
					actor.refresh()
	_update_focus_modulation()

func _ad_for(card: DuelCard) -> String:
	if card == null or not card.face_down or card.owner != 0 or not card.is_monster():
		return ""
	return "A" if card.is_attack_position() else "D"

func set_legal_zones(zones: Dictionary) -> void:
	legal_zones = zones
	queue_redraw()

func set_playable_hands(uids: Dictionary) -> void:
	for card_uid in actors.keys():
		var actor: CardActor = actors[card_uid]
		if actor == null or actor.card == null or actor.card.zone != GameConst.ZONE_HAND:
			continue
		if actor.view != null:
			actor.view.set_flag("playable", bool(uids.get(int(card_uid), false)))

func set_hand_selected(uid: int) -> void:
	selected_hand_uid = uid
	_compute_hand_rects()
	for card_uid in actors.keys():
		var actor: CardActor = actors[card_uid]
		var is_selected := int(card_uid) == uid
		actor.set_selected(is_selected)
		actor.set_action_seal(is_selected)
		if actor.card != null and actor.card.owner == 0 and actor.card.zone == GameConst.ZONE_HAND:
			actor.move_to(hand_rects.get(card_uid, actor.rest_rect), 0.10)
			actor.set_angle(float(hand_angles.get(card_uid, 0.0)))
	queue_redraw()

func set_board_selected(uid: int) -> void:
	selected_board_uid = uid
	for card_uid in actors.keys():
		var actor: CardActor = actors[card_uid]
		actor.set_action_seal(int(card_uid) == uid)

func set_focus_lane(lane: int) -> void:
	focus_lane = lane
	_update_focus_modulation()
	queue_redraw()

func set_auto_broadcast(value: bool) -> void:
	auto_broadcast = value
	queue_redraw()

func set_cue(text: String, color: Color = Tokens.CYAN) -> void:
	cue_text = text
	cue_color = color
	cue_alpha = 1.0
	queue_redraw()

func set_impact(owner: int, lane: int) -> void:
	impact_owner = owner
	impact_lane = lane

func _update_focus_modulation() -> void:
	for uid in actors.keys():
		var actor: CardActor = actors[uid]
		if actor == null or actor.card == null:
			continue
		var on_board := actor.card.zone == GameConst.ZONE_MONSTER or actor.card.zone == GameConst.ZONE_BACKROW
		if focus_lane >= 0 and on_board and actor.card.lane != focus_lane:
			actor.modulate = Color(0.62, 0.62, 0.74, 0.66)
		else:
			actor.modulate = Color.WHITE

func actor_for(uid: int) -> CardActor:
	return actors.get(uid)

func _on_actor_clicked(actor: CardActor) -> void:
	if actor == null or actor.card == null:
		return
	_on_card_clicked(actor)

func _on_actor_right_clicked(actor: CardActor, pos: Vector2) -> void:
	if table != null and table.has_method("_on_stage_card_right_clicked"):
		table._on_stage_card_right_clicked(actor.card, pos)

func _on_card_clicked(actor: CardActor) -> void:
	if table != null and table.has_method("_on_stage_card_clicked"):
		table._on_stage_card_clicked(actor.card)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			var zone := zone_at(mouse.position)
			if not zone.is_empty():
				zone_clicked.emit(int(zone["owner"]), str(zone["zone"]), int(zone["lane"]))
				accept_event()

func zone_at(pos: Vector2) -> Dictionary:
	for key in slot_rects.keys():
		var rect: Rect2 = slot_rects[key]
		if rect.has_point(pos):
			var parts: PackedStringArray = str(key).split("|")
			return {"owner": int(parts[0]), "zone": str(parts[1]), "lane": int(parts[2])}
	return {}

func _draw() -> void:
	if duel == null or size.x <= 1:
		return
	_draw_board()
	_draw_lanes()
	_draw_hand_zone()
	if auto_broadcast:
		# The broadcast letterbox is two quiet rails, never a cropped board.
		draw_rect(Rect2(0, 0, size.x, 3), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, hand_zone_rect.position.y - 3, size.x, 3), Color(0, 0, 0, 0.55))

func _draw_board() -> void:
	Chrome.draw_cut_rect(self, board_rect, 8.0, Color(Tokens.BG_DEEP.r, Tokens.BG_DEEP.g, Tokens.BG_DEEP.b, 0.46))
	Chrome.draw_cut_outline(self, board_rect, 8.0, Color(Tokens.PANEL_LINE.r, Tokens.PANEL_LINE.g, Tokens.PANEL_LINE.b, 0.35), 1.0)
	Chrome.draw_grid(self, board_rect.grow(-1.0), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.018), 72.0)

func _draw_lanes() -> void:
	var card := Tokens.card_size(board_token)
	var back := Tokens.card_size(back_token)
	var lane_font := Tokens.font_display()
	var numeral_size := clampi(int(board_rect.size.y * 0.20), 48, 104)
	for lane in range(3):
		if lane >= lane_rects.size():
			continue
		var lane_rect: Rect2 = lane_rects[lane]
		var focused := lane == focus_lane
		var guarded := duel.players[1].monsters[lane] != null
		var lane_fill := Color(Tokens.BG_RAISED.r, Tokens.BG_RAISED.g, Tokens.BG_RAISED.b, 0.46)
		if focused:
			lane_fill = Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.052)
		Chrome.draw_cut_rect(self, lane_rect, 7.0, lane_fill)
		Chrome.draw_cut_outline(self, lane_rect, 7.0, Tokens.CYAN if focused else Color(Tokens.PANEL_LINE.r, Tokens.PANEL_LINE.g, Tokens.PANEL_LINE.b, 0.72), 1.0)
		Chrome.draw_corner_brackets(self, lane_rect.grow(-8.0), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.16 if not focused else 0.32), 9.0)
		Chrome.draw_grid(self, lane_rect.grow(-10.0), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.013), 56.0)
		draw_line(Vector2(lane_rect.position.x + 1.0, lane_rect.position.y + lane_rect.size.y * 0.22), Vector2(lane_rect.position.x + 1.0, lane_rect.end.y - lane_rect.size.y * 0.22), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.10 if not focused else 0.26), 1.0)
		if focused:
			Chrome.draw_cut_outline(self, lane_rect.grow(-4.0), 5.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.22), 1.0)

		# The numeral sits behind the cards, not in front of them.
		var numeral: String = LANE_NUMERALS[lane]
		var numeral_width := lane_font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, numeral_size).x
		draw_string(lane_font, Vector2(lane_rect.get_center().x - numeral_width * 0.5, lane_rect.position.y + lane_rect.size.y * 0.57), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, numeral_size, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.11))

		var state_color := Tokens.PINK if guarded else Tokens.GREEN
		draw_string(Tokens.font_label(), lane_rect.position + Vector2(10, 14), "◆ %s" % ("GUARDED" if guarded else "OPEN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, state_color)
		var roman: String = LANE_NUMERALS[lane]
		var roman_width := Tokens.font_label().get_string_size(roman, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(Tokens.font_label(), Vector2(lane_rect.end.x - 10 - roman_width, lane_rect.position.y + 14), roman, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, 0.7))

		var enemy_back: Rect2 = slot_rects.get("1|backrow|%d" % lane, Rect2())
		var enemy_front: Rect2 = slot_rects.get("1|monster|%d" % lane, Rect2())
		var player_front: Rect2 = slot_rects.get("0|monster|%d" % lane, Rect2())
		var player_back: Rect2 = slot_rects.get("0|backrow|%d" % lane, Rect2())

		_draw_back_slot(enemy_back, back, duel.players[1].backrow[lane] != null, "ENEMY SET")
		_draw_front_slot(enemy_front, card, "1|monster|%d" % lane, duel.players[1].monsters[lane] != null, false, lane)
		_draw_seam(lane_rect, lane)

		# Enemy back is above its front card; player back is below its front card.
		_draw_back_slot(player_back, back, duel.players[0].backrow[lane] != null, "YOUR SET")
		_draw_front_slot(player_front, card, "0|monster|%d" % lane, duel.players[0].monsters[lane] != null, true, lane)

func _draw_front_slot(rect: Rect2, card_size: Vector2, key: String, occupied: bool, is_player: bool, lane: int) -> void:
	if occupied:
		return
	var card_rect := _centered(rect, card_size)
	var legal := bool(legal_zones.get(key, false))
	var target_color := Tokens.AMBER if legal else (Tokens.CYAN if is_player else Tokens.INK_MUTED)
	var alpha := 0.64 if legal else (0.24 if is_player else 0.18)
	_draw_dashed_rect(card_rect, Color(target_color.r, target_color.g, target_color.b, alpha), 1.0, 6.0)
	if legal:
		draw_rect(card_rect, Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.07))
		Chrome.draw_corner_brackets(self, card_rect.grow(4.0), Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.75), 8.0)
	var label := "CALL" if is_player else "OPEN"
	var font := Tokens.font_data()
	var font_size := 12 if is_player else 9
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(card_rect.get_center().x - width * 0.5, card_rect.get_center().y + font_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(target_color.r, target_color.g, target_color.b, alpha + 0.12))
	if is_player:
		draw_string(font, Vector2(card_rect.get_center().x - 4, card_rect.get_center().y - 14), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(target_color.r, target_color.g, target_color.b, alpha + 0.18))

func _draw_back_slot(rect: Rect2, back_size: Vector2, occupied: bool, label: String) -> void:
	if occupied:
		return
	var card_rect := Rect2(Vector2(rect.get_center().x - back_size.x * 0.5, rect.position.y), back_size)
	_draw_dashed_rect(card_rect, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.22), 1.0, 4.0)
	var text := label
	var width := Tokens.font_label().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	draw_string(Tokens.font_label(), Vector2(card_rect.get_center().x - width * 0.5, card_rect.end.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, 0.62))

func _draw_seam(lane_rect: Rect2, lane: int) -> void:
	var seam_y := lane_rect.position.y + lane_rect.size.y * 0.5
	draw_line(Vector2(lane_rect.position.x + 12, seam_y), Vector2(lane_rect.end.x - 12, seam_y), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.16), 1.0)
	var center := Vector2(lane_rect.get_center().x, seam_y)
	var radius := 4.0
	var points := PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0),
	])
	draw_colored_polygon(points, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.55))
	draw_string(Tokens.font_data(), center + Vector2(8, 4), LANE_NUMERALS[lane], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.45))

func _draw_hand_zone() -> void:
	var meta_font := Tokens.font_label()
	draw_string(meta_font, Vector2(deck_rect.end.x + 14, hand_zone_rect.position.y + 13), "HAND %d · CLICK TO CALL · SHIFT TO SET" % duel.players[0].hand.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Tokens.INK_MUTED)
	var hand_count := duel.players[0].hand.size()
	if hand_count == 0:
		var text := "NO CARDS IN HAND"
		var width := Tokens.font_data().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(Tokens.font_data(), Vector2(hand_zone_rect.get_center().x - width * 0.5, hand_zone_rect.end.y - 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Tokens.INK_MUTED)

	# Deck stack, bottom-left of the hand band.
	for i in range(3):
		var offset := Vector2(float(2 - i) * 2.0, float(2 - i) * 2.0)
		var rect := Rect2(deck_rect.position + offset, deck_rect.size)
		Chrome.draw_cut_rect(self, rect, 4.0, Tokens.CARD_FACE_DEEP)
		Chrome.draw_cut_outline(self, rect, 4.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.30), 1.0)
	draw_line(deck_rect.position + Vector2(7, deck_rect.size.y * 0.5), deck_rect.end - Vector2(7, deck_rect.size.y * 0.5), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.25), 1.0)
	draw_circle(deck_rect.get_center(), 2.2, Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.65))
	var count_text := str(duel.players[0].deck.size())
	var count_width := Tokens.font_data().get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(Tokens.font_data(), Vector2(deck_rect.get_center().x - count_width * 0.5, deck_rect.end.y + 13), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_SECONDARY)
	draw_string(meta_font, Vector2(deck_rect.position.x - 2, deck_rect.position.y - 7), "DECK", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Tokens.INK_MUTED)

func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash: float) -> void:
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, dash)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, dash)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, dash)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, dash)
