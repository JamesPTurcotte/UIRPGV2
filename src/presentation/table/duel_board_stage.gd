class_name DuelBoardStage
extends BattleStage

## The X2 table. The window is the budget: the board card grows with the table,
## the chrome stays at 150%, and the hand is a 30% shelf.
##
## At >=1280px the face-up backrow takes the full seat next to its monster (B1).
## Below that the face-up effects live in a 40px ribbon (B3). Set cards stay
## face-down; their effect is never exposed by the layout.

var access_scale: int = 150
var board_mode: String = "b1"
var card_w: float = 190.0
var card_scale: float = 1.0
var hand_shelf_h: float = 57.0
var ribbon_h: float = 0.0
var ribbon_rect := Rect2()
const CARD_SLICE := preload("res://src/presentation/table/card_slice.gd")

var deck_clip: Control
var deck_slice
var deck_count: Label
var warden_mat_rect := Rect2()
var player_mat_rect := Rect2()
var target_lane: int = -1
var pad := 4.0
var score_h := 82.0
var gap := 4.0
var seam_h := 10.0
var action_h := 64.0
var lane_gap := 8.0
var slot_gap := 8.0

func _choose_layout() -> void:
	board_mode = "b1" if size.x >= 1280.0 else "b3"
	var chrome := 202.0 if board_mode == "b1" else 246.0
	var height_limit := (size.y - chrome) / 3.1
	var width_limit := (size.x - 48.0) / 6.0 if board_mode == "b1" else (size.x - 232.0) / 3.0
	card_w = maxf(120.0, floor(minf(height_limit, width_limit)))
	card_scale = card_w / Tokens.card_size("A").x
	hand_shelf_h = card_w * 0.30
	ribbon_h = 0.0 if board_mode == "b1" else 40.0
	lane_gap = 8.0 if board_mode == "b1" else 26.0
	board_token = "A"
	hand_token = "A"
	back_token = "A"

func _compute_rects() -> void:
	zone_rects.clear()
	slot_rects.clear()
	lane_rects.clear()
	ribbon_rect = Rect2()
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_choose_layout()

	var card := Vector2(card_w, card_w * 1.4)
	var lane_w := (2.0 * card_w + 8.0) if board_mode == "b1" else (card_w + Tokens.CARD_TAB)
	var board_w := (3.0 * lane_w + 2.0 * lane_gap) + (8.0 if board_mode == "b1" else 0.0)
	var board_x := (size.x - board_w) * 0.5
	var action_y := size.y - pad - action_h
	var hand_y := action_y - gap - hand_shelf_h
	var board_bottom := hand_y - gap
	var board_top := pad + score_h + gap
	if board_mode == "b3":
		ribbon_rect = Rect2(board_x, board_top, board_w, ribbon_h)
		board_top += ribbon_h + gap
	var board_h := maxf(120.0, board_bottom - board_top)

	board_rect = Rect2(board_x, board_top, board_w, board_h)
	hand_zone_rect = Rect2(board_x, hand_y, board_w, hand_shelf_h)
	dock_rect = Rect2(pad, action_y, size.x - pad * 2.0, action_h)

	var mat_h := (board_h - seam_h) * 0.5
	warden_mat_rect = Rect2(board_x, board_top, board_w, mat_h)
	player_mat_rect = Rect2(board_x, board_top + mat_h + seam_h, board_w, mat_h)

	var row_w := lane_w * 3.0 + lane_gap * 2.0
	var row_x := board_x + (board_w - row_w) * 0.5
	for lane in range(3):
		var lane_x := row_x + float(lane) * (lane_w + lane_gap)
		lane_rects.append(Rect2(lane_x, board_top, lane_w, board_h))
	for owner in [1, 0]:
		var mat_rect := warden_mat_rect if owner == 1 else player_mat_rect
		var slot_y := mat_rect.position.y + (mat_rect.size.y - card.y) * 0.5
		for lane in range(3):
			var sx := row_x + float(lane) * (lane_w + lane_gap)
			var front_rect := Rect2(sx, slot_y, card.x, card.y)
			var back_rect: Rect2
			var back_slot: Rect2
			if board_mode == "b1":
				back_rect = Rect2(sx + card_w + 8.0, slot_y, card.x, card.y)
				back_slot = back_rect
			else:
				back_rect = Rect2(sx + Tokens.CARD_TAB, slot_y, card.x, card.y)
				var guarded := duel != null and duel.players[owner].monsters[lane] != null
				back_slot = Rect2(sx + card.x, slot_y, Tokens.CARD_TAB, card.y) if guarded else back_rect
			zone_rects["%d|backrow|%d" % [owner, lane]] = back_rect
			zone_rects["%d|monster|%d" % [owner, lane]] = front_rect
			slot_rects["%d|backrow|%d" % [owner, lane]] = back_slot
			slot_rects["%d|monster|%d" % [owner, lane]] = front_rect

	remains_rect = Rect2(-card.x - 24.0, hand_y, card.x, card.y)
	void_rect = Rect2(-card.x * 2.0 - 40.0, hand_y, card.x, card.y)
	opp_hand_rect = Rect2(-card.x * 3.0 - 56.0, 0.0, card.x, card.y)
	_compute_hand_rects()

func _ensure_deck_clip() -> void:
	if deck_clip != null:
		return
	deck_clip = Control.new()
	deck_clip.clip_contents = true
	deck_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(deck_clip)
	deck_slice = CARD_SLICE.new()
	deck_slice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_slice.face_down = true
	deck_clip.add_child(deck_slice)
	deck_count = UI.label("", 14, Tokens.INK_SECONDARY, Tokens.font_data())
	deck_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_count.position = Vector2(6, 2)
	deck_count.add_theme_constant_override("outline_size", 4)
	deck_count.add_theme_color_override("font_outline_color", Tokens.BG_VOID)
	deck_count.z_index = 2
	deck_clip.add_child(deck_count)

func _sync_deck_slice() -> void:
	_ensure_deck_clip()
	if deck_clip == null:
		return
	deck_clip.position = deck_rect.position
	deck_clip.size = Vector2(card_w, hand_shelf_h)
	deck_slice.position = Vector2.ZERO
	deck_slice.size = deck_clip.size
	deck_slice.token = board_token
	deck_slice.display_scale = card_scale
	deck_slice.def = Content.card_list[0] if not Content.card_list.is_empty() else null
	deck_slice.queue_redraw()
	if deck_count != null and duel != null:
		deck_count.text = str(duel.players[0].deck.size())
		deck_count.queue_redraw()

func _compute_hand_rects() -> void:
	hand_rects.clear()
	hand_angles.clear()
	if duel == null:
		return
	var hand := duel.players[0].hand
	var count := hand.size()
	var available := maxf(120.0, size.x - pad * 2.0 - 8.0)
	var step := card_w
	if count > 0:
		step = minf(card_w, (available - card_w) / float(count))
	step = maxf(28.0, step)
	var total := card_w + step * float(count)
	var x := pad + (size.x - pad * 2.0 - total) * 0.5
	var base_y := hand_zone_rect.position.y
	deck_rect = Rect2(x, base_y, card_w, card_w * 1.4)
	for i in range(count):
		var card: DuelCard = hand[i]
		hand_rects[card.uid] = Rect2(Vector2(x + step * float(i + 1), base_y), Vector2(card_w, card_w * 1.4))
		hand_angles[card.uid] = 0.0
	_sync_deck_slice()

func ensure_actor(card: DuelCard, token: String = "") -> CardActor:
	if card == null:
		return null
	var actor: CardActor = actors.get(card.uid)
	if actor == null:
		actor = CardActor.new()
		actor.setup(card, token if not token.is_empty() else _token_for(card), card_scale)
		actor.clicked.connect(_on_actor_clicked)
		actor.right_clicked.connect(_on_actor_right_clicked)
		add_child(actor)
		actors[card.uid] = actor
	else:
		actor.set_display_scale(card_scale)
		if not token.is_empty() and actor.token != token:
			actor.set_token(token)
	actor.card = card
	actor.backrow_tucked = board_mode == "b3"
	actor.z_index = _z_for(card)
	actor.refresh()
	return actor

func set_target_lane(lane: int) -> void:
	target_lane = lane
	queue_redraw()

func _draw() -> void:
	if duel == null or size.x <= 1.0:
		return
	_draw_score()
	_draw_ribbon()
	_draw_mat(1, warden_mat_rect)
	_draw_board_seam()
	_draw_mat(0, player_mat_rect)
	_draw_hand()
	if auto_broadcast:
		draw_rect(Rect2(0, 0, size.x, 3), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, hand_zone_rect.position.y - 3, size.x, 3), Color(0, 0, 0, 0.55))

func _draw_score() -> void:
	var mode150 := access_scale >= 150
	var label_size := 12 if mode150 else 10
	var score_size := 48 if mode150 else 40
	var name_size_base := 12 if mode150 else 10
	var name_size_min := 9 if mode150 else 7
	var pips_radius := 6.0 if mode150 else 5.0
	var pips_step := 16.0 if mode150 else 13.0
	var bar_h := 5.0 if mode150 else 4.0
	var bar_w := 210.0 if mode150 else 190.0
	var bar_y := 70.0 if mode150 else 58.0
	var score_y := 62.0 if mode150 else 50.0
	var label_y := 18.0 if mode150 else 15.0
	var pips_y := 54.0 if mode150 else 44.0
	var tick_w := 24.0 if mode150 else 22.0
	var tick_h := 5.0 if mode150 else 4.0
	var tick_gap := 6.0 if mode150 else 5.0
	var tick_y := 40.0 if mode150 else 34.0
	var diamond_y := 58.0 if mode150 else 48.0
	var tool_gap := 112.0 if mode150 else 104.0
	var left := board_rect.position.x
	var right := board_rect.end.x - tool_gap
	var top := pad
	var data_font := Tokens.font_data()
	var label_font := Tokens.font_label()
	var player = duel.players[0]
	var warden = duel.players[1]
	var p_ratio := float(player.resolve) / maxf(1.0, float(player.max_resolve))
	var p_color := Tokens.CYAN
	if p_ratio <= 0.25:
		p_color = Tokens.DANGER
	elif p_ratio <= 0.6:
		p_color = Tokens.AMBER
	var w_ratio := float(warden.resolve) / maxf(1.0, float(warden.max_resolve))
	var w_color := Tokens.PINK if w_ratio > 0.25 else Tokens.DANGER

	draw_string(label_font, Vector2(left, top + label_y), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Tokens.INK_MUTED)
	var p_text := _score_text(player.resolve)
	draw_string(data_font, Vector2(left, top + score_y), p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, p_color)
	Chrome.draw_gauge(self, Rect2(left, top + bar_y, bar_w, bar_h), player.resolve, player.max_resolve, p_color, Color(0, 0, 0, 0.35))

	var w_name := str(warden.name).to_upper()
	var center_x := (left + right) * 0.5
	var name_max := maxf(120.0, right - center_x - 90.0)
	var name_size := UI.fit_font_size(label_font, w_name, name_max, name_size_base, name_size_min)
	var name_w := label_font.get_string_size(w_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	draw_string(label_font, Vector2(right - name_w, top + label_y), w_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Tokens.INK_MUTED)
	var guards := _guard_count(warden)
	var w_text := _score_text(warden.resolve)
	var w_width := data_font.get_string_size(w_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size).x
	draw_string(data_font, Vector2(right - w_width, top + score_y), w_text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_size, w_color)
	Chrome.draw_gauge(self, Rect2(right - bar_w, top + bar_y, bar_w, bar_h), warden.resolve, warden.max_resolve, w_color, Color(0, 0, 0, 0.35))
	for i in range(3):
		var center := Vector2(right - w_width - 22.0 - float(i) * pips_step, top + pips_y)
		var points := PackedVector2Array([
			center + Vector2(0, -pips_radius), center + Vector2(pips_radius, 0),
			center + Vector2(0, pips_radius), center + Vector2(-pips_radius, 0),
		])
		draw_colored_polygon(points, Tokens.PINK if i < guards else Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, 0.30))

	var phases := GameConst.PHASES
	var phase_index := maxi(0, phases.find(duel.phase))
	var total_w := tick_w * float(phases.size()) + tick_gap * float(maxi(0, phases.size() - 1))
	var tick_x := (left + right) * 0.5 - total_w * 0.5
	var active_color := Tokens.CYAN if duel.active == 0 else Tokens.PINK
	for i in range(phases.size()):
		var rect := Rect2(tick_x + float(i) * (tick_w + tick_gap), top + tick_y, tick_w, tick_h)
		var fill := Color(active_color.r, active_color.g, active_color.b, 0.90) if i == phase_index else (Tokens.PANEL_LINE if i < phase_index else Color(Tokens.INK_MUTED.r, Tokens.INK_MUTED.g, Tokens.INK_MUTED.b, 0.22))
		draw_rect(rect, fill)
		if i == phase_index:
			draw_rect(Rect2(rect.position + Vector2(0, -2.0), Vector2(rect.size.x, 7.0)), Color(active_color.r, active_color.g, active_color.b, 0.10))
	var center_diamond := Vector2((left + right) * 0.5, top + diamond_y)
	var diamond_radius := 4.0 if mode150 else 3.0
	draw_colored_polygon(PackedVector2Array([
		center_diamond + Vector2(0, -diamond_radius), center_diamond + Vector2(diamond_radius, 0),
		center_diamond + Vector2(0, diamond_radius), center_diamond + Vector2(-diamond_radius, 0),
	]), Color(active_color.r, active_color.g, active_color.b, 0.55))

func _draw_ribbon() -> void:
	if board_mode != "b3" or ribbon_rect.size.y <= 0.0:
		return
	var accent := Tokens.CYAN
	Chrome.draw_cut_rect(self, ribbon_rect, 5.0, Color(Tokens.BG_PANEL.r, Tokens.BG_PANEL.g, Tokens.BG_PANEL.b, 0.78))
	Chrome.draw_cut_outline(self, ribbon_rect, 5.0, Color(accent.r, accent.g, accent.b, 0.28), 1.0)
	var font := Tokens.font_label()
	var font_size := 9 if ribbon_rect.size.x >= 800.0 else 8
	var line_h := 14.0 if font_size >= 9 else 12.0
	var left := ribbon_rect.position.x + 9.0
	var right := ribbon_rect.end.x - 8.0
	var effect_x := left + 58.0
	var x := effect_x
	var y := ribbon_rect.position.y + 16.0
	var line := 0
	draw_string(font, Vector2(left, y), "IN PLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.PINK)
	var effects: Array[DuelCard] = []
	for owner in [1, 0]:
		for lane in range(3):
			var back = duel.players[owner].backrow[lane]
			if back != null and not back.face_down:
				effects.append(back)
	if effects.is_empty():
		draw_string(font, Vector2(effect_x, y), "NO FACE-UP SPELL/TRAP", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.INK_MUTED)
		return
	for index in range(effects.size()):
		var back: DuelCard = effects[index]
		var text := "%s: %s" % [back.def.name.to_upper(), back.def.text]
		var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if x + text_w > right and x > effect_x:
			line += 1
			if line > 1:
				var more := "+%d MORE" % (effects.size() - index)
				var more_w := font.get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				draw_string(font, Vector2(right - more_w, y), more, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.AMBER)
				break
			x = effect_x
			y += line_h
		if text_w > right - effect_x:
			text = _fit_text(font, text, right - effect_x, font_size)
			text_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Tokens.INK_SECONDARY)
		x += text_w + 14.0

func _fit_text(font: Font, text: String, width: float, font_size: int) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var cut := text
	while cut.length() > 1 and font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		cut = cut.substr(0, cut.length() - 1)
	return cut + "…"

func _draw_mat(owner: int, rect: Rect2) -> void:
	var accent := Tokens.PINK if owner == 1 else Tokens.CYAN
	var fill := Color(Tokens.BG_RAISED.r, Tokens.BG_RAISED.g, Tokens.BG_RAISED.b, 0.50)
	if owner == 0:
		fill = Color(Tokens.BG_DEEP.r, Tokens.BG_DEEP.g, Tokens.BG_DEEP.b, 0.62)
	Chrome.draw_cut_rect(self, rect, 9.0, fill)
	Chrome.draw_cut_outline(self, rect, 9.0, Color(accent.r, accent.g, accent.b, 0.60), 2.0)
	Chrome.draw_grid(self, rect.grow(-1.0), Color(accent.r, accent.g, accent.b, 0.016), 64.0)
	draw_arc(rect.get_center(), rect.size.y * 0.36, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.055), 1.0, true)
	var lane_w := (2.0 * card_w + 8.0) if board_mode == "b1" else (card_w + Tokens.CARD_TAB)
	var row_w := lane_w * 3.0 + lane_gap * 2.0
	var row_left := rect.position.x + (rect.size.x - row_w) * 0.5
	for divider in range(2):
		var x := row_left + float(divider + 1) * lane_w + (float(divider) + 0.5) * lane_gap
		draw_line(Vector2(x, rect.position.y + 10.0), Vector2(x, rect.end.y - 10.0), Color(accent.r, accent.g, accent.b, 0.08), 1.0)
	if duel.active == owner:
		var edge_y := rect.end.y if owner == 1 else rect.position.y
		draw_line(Vector2(rect.position.x + 14.0, edge_y), Vector2(rect.end.x - 14.0, edge_y), Color(accent.r, accent.g, accent.b, 0.90), 3.0)

	for lane in range(3):
		var back_rect: Rect2 = zone_rects.get("%d|backrow|%d" % [owner, lane], Rect2())
		var front_rect: Rect2 = zone_rects.get("%d|monster|%d" % [owner, lane], Rect2())
		if back_rect.size.x <= 0.0:
			continue
		var back = duel.players[owner].backrow[lane]
		var monster = duel.players[owner].monsters[lane]
		var tab_rect := Rect2(front_rect.end.x, back_rect.position.y, Tokens.CARD_TAB, back_rect.size.y)
		var back_target := back_rect if board_mode == "b1" or monster == null else tab_rect
		if back == null:
			_draw_ghost(back_rect if board_mode == "b1" else tab_rect, accent, true)
		if monster == null:
			_draw_ghost(front_rect, accent, true)
		_draw_legal(owner, lane, back_target, front_rect)
		if owner == 0 and (focus_lane == lane or target_lane == lane):
			Chrome.draw_corner_brackets(self, front_rect.grow(5.0), Tokens.PINK, 12.0, 2.0)
			draw_rect(front_rect.grow(2.0), Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.05))

func _draw_ghost(rect: Rect2, accent: Color, plus: bool) -> void:
	_draw_dashed_rect(rect, Color(accent.r, accent.g, accent.b, 0.38), 2.0, 5.0)
	if plus:
		var center := rect.get_center()
		var arm := 14.0
		var color := Color(accent.r, accent.g, accent.b, 0.62)
		draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), color, 2.0)
		draw_line(center - Vector2(0, arm), center + Vector2(0, arm), color, 2.0)

func _draw_legal(owner: int, lane: int, tab_rect: Rect2, front_rect: Rect2) -> void:
	var back_key := "%d|backrow|%d" % [owner, lane]
	var front_key := "%d|monster|%d" % [owner, lane]
	if bool(legal_zones.get(back_key, false)):
		Chrome.draw_corner_brackets(self, tab_rect.grow(4.0), Tokens.AMBER, 10.0, 2.0)
		draw_rect(tab_rect.grow(2.0), Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.06))
	if bool(legal_zones.get(front_key, false)):
		Chrome.draw_corner_brackets(self, front_rect.grow(4.0), Tokens.AMBER, 10.0, 2.0)
		draw_rect(front_rect.grow(2.0), Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.06))

func _draw_board_seam() -> void:
	var y := warden_mat_rect.end.y + seam_h * 0.5
	draw_line(Vector2(board_rect.position.x + 16.0, y), Vector2(board_rect.end.x - 16.0, y), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.16), 1.0)
	var center := Vector2(board_rect.get_center().x, y)
	var radius := 4.0
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	]), Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.55))

func _draw_hand() -> void:
	if Content.card_list.is_empty():
		var shelf_rect := Rect2(deck_rect.position, Vector2(card_w, hand_shelf_h))
		Chrome.draw_cut_rect(self, shelf_rect, 4.0, Tokens.CARD_FACE_DEEP)
		Chrome.draw_cut_outline(self, shelf_rect, 4.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.30), 1.0)
	if duel.players[0].hand.is_empty():
		var text := "NO CARDS IN HAND"
		var width := Tokens.font_data().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(Tokens.font_data(), Vector2(hand_zone_rect.get_center().x - width * 0.5, hand_zone_rect.get_center().y + 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Tokens.INK_MUTED)

func _guard_count(warden) -> int:
	var count := 0
	for monster in warden.monsters:
		if monster != null:
			count += 1
	return count

func _score_text(value: int) -> String:
	var raw := str(absi(value))
	var out := ""
	var count := 0
	for i in range(raw.length() - 1, -1, -1):
		out = raw.substr(i, 1) + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if value < 0 else "") + out
