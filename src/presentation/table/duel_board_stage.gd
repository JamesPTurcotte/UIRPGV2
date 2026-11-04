class_name DuelBoardStage
extends BattleStage

## The 900 × 900 Overlap Duel Board.
##
## One card token for every zone. The accessible table uses the 190px `A` token;
## each mat is one row of three lanes; the set card sits behind its monster and
## shows a 52px side tab. The smaller fallback keeps the same language at 145px.

const MAX_BOARD_W := 900.0

var access_scale: int = 150
var warden_mat_rect := Rect2()
var player_mat_rect := Rect2()
var target_lane: int = -1
var pad := 4.0
var score_h := 82.0
var gap := 4.0
var seam_h := 10.0
var action_h := 64.0
var lane_gap := 26.0
var slot_gap := 8.0

func _choose_tokens() -> void:
	# 960/1000 focus stages use the 190px accessible card. Only genuinely
	# short stages fall back to the old 145px token.
	if size.y > 0.0 and size.y < 900.0:
		board_token = "O" if size.y >= 760.0 else "B+"
	else:
		board_token = "A"
	hand_token = board_token
	back_token = board_token

func _apply_metrics() -> void:
	if board_token == "A":
		pad = 4.0
		score_h = 82.0 if access_scale >= 150 else 68.0
		action_h = 64.0 if access_scale >= 150 else 56.0
		gap = 4.0
		seam_h = 10.0
		lane_gap = 26.0
		slot_gap = 8.0
	else:
		pad = 10.0
		score_h = 56.0
		action_h = 46.0
		gap = 6.0
		seam_h = 8.0
		lane_gap = 22.0
		slot_gap = 8.0

func _compute_rects() -> void:
	zone_rects.clear()
	slot_rects.clear()
	lane_rects.clear()
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_choose_tokens()
	_apply_metrics()

	var card := Tokens.card_size(board_token)
	var board_w := minf(size.x - pad * 2.0, MAX_BOARD_W)
	var board_x := (size.x - board_w) * 0.5
	var action_y := size.y - pad - action_h
	var hand_h := card.y + (0.0 if board_token == "A" else 8.0)
	var hand_y := action_y - gap - hand_h
	var board_bottom := hand_y - gap
	var board_top := pad + score_h + gap
	var board_h := maxf(200.0, board_bottom - board_top)

	board_rect = Rect2(board_x, board_top, board_w, board_h)
	hand_zone_rect = Rect2(board_x, hand_y, board_w, hand_h)
	dock_rect = Rect2(board_x, action_y, board_w, action_h)
	deck_rect = Rect2(hand_zone_rect.position.x + 2.0, hand_y + 2.0, card.x, card.y)

	var mat_h := (board_h - seam_h) * 0.5
	warden_mat_rect = Rect2(board_x, board_top, board_w, mat_h)
	player_mat_rect = Rect2(board_x, board_top + mat_h + seam_h, board_w, mat_h)

	# Index Tab: the set card is the same token, shifted 52px to the right
	# behind the monster. The lane is card + 52 wide; the visible tab never eats
	# the next lane and the monster keeps its full face.
	var lane_w := card.x + Tokens.CARD_TAB
	var slot_h := card.y
	var row_w := lane_w * 3.0 + lane_gap * 2.0
	var row_x := board_x + (board_w - row_w) * 0.5
	for owner in [1, 0]:
		var mat_rect := warden_mat_rect if owner == 1 else player_mat_rect
		var slot_y := mat_rect.position.y + (mat_rect.size.y - slot_h) * 0.5
		for lane in range(3):
			var sx := row_x + float(lane) * (lane_w + lane_gap)
			var back_rect := Rect2(sx + Tokens.CARD_TAB, slot_y, card.x, card.y)
			var front_rect := Rect2(sx, slot_y, card.x, card.y)
			zone_rects["%d|backrow|%d" % [owner, lane]] = back_rect
			zone_rects["%d|monster|%d" % [owner, lane]] = front_rect
			# The visible tab is the set-card click target; the full card
			# remains behind it for the hover lift.
			slot_rects["%d|backrow|%d" % [owner, lane]] = Rect2(sx + card.x, slot_y, Tokens.CARD_TAB, card.y)
			slot_rects["%d|monster|%d" % [owner, lane]] = front_rect

	# Off-stage rest points for piles and the opponent hand. They are never
	# drawn; they only give actors a valid home when a pile transition starts.
	remains_rect = Rect2(-card.x - 24.0, hand_y, card.x, card.y)
	void_rect = Rect2(-card.x * 2.0 - 40.0, hand_y, card.x, card.y)
	opp_hand_rect = Rect2(-card.x * 3.0 - 56.0, 0.0, card.x, card.y)
	_compute_hand_rects()

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
	var start_x := deck_rect.end.x + slot_gap
	var available := maxf(120.0, hand_zone_rect.end.x - start_x - 4.0)
	var step := hand_size.x
	if count > 1:
		step = minf(hand_size.x, (available - hand_size.x) / float(count - 1))
	step = maxf(28.0, step)
	var total := step * float(count - 1) + hand_size.x
	var x := start_x + maxf(0.0, (available - total) * 0.5)
	var base_y := hand_zone_rect.position.y + (hand_zone_rect.size.y - hand_size.y) * 0.5
	for i in range(count):
		var card: DuelCard = hand[i]
		var lift := 6.0 if card.uid == selected_hand_uid else 0.0
		hand_rects[card.uid] = Rect2(Vector2(x + step * float(i), base_y - lift), hand_size)
		hand_angles[card.uid] = 0.0

func set_target_lane(lane: int) -> void:
	target_lane = lane
	queue_redraw()

func _draw() -> void:
	if duel == null or size.x <= 1.0:
		return
	_draw_score()
	_draw_mat(1, warden_mat_rect)
	_draw_board_seam()
	_draw_mat(0, player_mat_rect)
	_draw_hand()
	if auto_broadcast:
		draw_rect(Rect2(0, 0, size.x, 3), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(0, hand_zone_rect.position.y - 3, size.x, 3), Color(0, 0, 0, 0.55))

func _draw_score() -> void:
	var large := board_token == "A"
	var mode150 := large and access_scale >= 150
	var label_size := 12 if mode150 else (10 if large else 9)
	var score_size := 48 if mode150 else (40 if large else 36)
	var name_size_base := 12 if mode150 else (10 if large else 9)
	var name_size_min := 9 if mode150 else 7
	var pips_radius := 6.0 if mode150 else (5.0 if large else 4.0)
	var pips_step := 16.0 if mode150 else (13.0 if large else 11.0)
	var bar_h := 5.0 if mode150 else (4.0 if large else 3.0)
	var bar_w := 210.0 if mode150 else (190.0 if large else 156.0)
	var bar_y := 70.0 if mode150 else (58.0 if large else 49.0)
	var score_y := 62.0 if mode150 else (50.0 if large else 45.0)
	var label_y := 18.0 if mode150 else (15.0 if large else 13.0)
	var pips_y := 54.0 if mode150 else (44.0 if large else 40.0)
	var tick_w := 24.0 if mode150 else (22.0 if large else 17.0)
	var tick_h := 5.0 if mode150 else (4.0 if large else 3.0)
	var tick_gap := 6.0 if mode150 else (5.0 if large else 4.0)
	var tick_y := 40.0 if mode150 else (34.0 if large else 26.0)
	var diamond_y := 58.0 if mode150 else (48.0 if large else 40.0)
	var tool_gap := 112.0 if mode150 else (104.0 if large else 100.0)
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
	var diamond_radius := 4.0 if mode150 else (3.0 if large else 3.0)
	draw_colored_polygon(PackedVector2Array([
		center_diamond + Vector2(0, -diamond_radius), center_diamond + Vector2(diamond_radius, 0),
		center_diamond + Vector2(0, diamond_radius), center_diamond + Vector2(-diamond_radius, 0),
	]), Color(active_color.r, active_color.g, active_color.b, 0.55))

func _draw_mat(owner: int, rect: Rect2) -> void:
	var accent := Tokens.PINK if owner == 1 else Tokens.CYAN
	var fill := Color(Tokens.BG_RAISED.r, Tokens.BG_RAISED.g, Tokens.BG_RAISED.b, 0.50)
	if owner == 0:
		fill = Color(Tokens.BG_DEEP.r, Tokens.BG_DEEP.g, Tokens.BG_DEEP.b, 0.62)
	Chrome.draw_cut_rect(self, rect, 9.0, fill)
	Chrome.draw_cut_outline(self, rect, 9.0, Color(accent.r, accent.g, accent.b, 0.60 if board_token == "A" else 0.42), 2.0 if board_token == "A" else 1.0)
	Chrome.draw_grid(self, rect.grow(-1.0), Color(accent.r, accent.g, accent.b, 0.016), 64.0)
	draw_arc(rect.get_center(), rect.size.y * 0.36, 0.0, TAU, 64, Color(accent.r, accent.g, accent.b, 0.055), 1.0, true)
	var lane_w := Tokens.card_size(board_token).x + Tokens.CARD_TAB
	var row_w := lane_w * 3.0 + lane_gap * 2.0
	var row_left := rect.position.x + (rect.size.x - row_w) * 0.5
	for divider in range(2):
		var x := row_left + float(divider + 1) * lane_w + (float(divider) + 0.5) * lane_gap
		draw_line(Vector2(x, rect.position.y + 10.0), Vector2(x, rect.end.y - 10.0), Color(accent.r, accent.g, accent.b, 0.08), 1.0)
	if duel.active == owner:
		var edge_y := rect.end.y if owner == 1 else rect.position.y
		draw_line(Vector2(rect.position.x + 14.0, edge_y), Vector2(rect.end.x - 14.0, edge_y), Color(accent.r, accent.g, accent.b, 0.90), 3.0 if board_token == "A" else 2.0)

	for lane in range(3):
		var back_rect: Rect2 = zone_rects.get("%d|backrow|%d" % [owner, lane], Rect2())
		var front_rect: Rect2 = zone_rects.get("%d|monster|%d" % [owner, lane], Rect2())
		if back_rect.size.x <= 0.0:
			continue
		var back = duel.players[owner].backrow[lane]
		var monster = duel.players[owner].monsters[lane]
		var tab_rect := Rect2(front_rect.end.x, back_rect.position.y, Tokens.CARD_TAB, back_rect.size.y)
		if back == null:
			_draw_ghost(tab_rect, accent, true)
		if monster == null:
			_draw_ghost(front_rect, accent, true)
		_draw_legal(owner, lane, tab_rect, front_rect)
		if owner == 0 and (focus_lane == lane or target_lane == lane):
			Chrome.draw_corner_brackets(self, front_rect.grow(5.0), Tokens.PINK, 12.0 if board_token == "A" else 11.0, 2.0 if board_token == "A" else 1.0)
			draw_rect(front_rect.grow(2.0), Color(Tokens.PINK.r, Tokens.PINK.g, Tokens.PINK.b, 0.05 if board_token == "A" else 0.035))

func _draw_ghost(rect: Rect2, accent: Color, plus: bool) -> void:
	var strong := board_token == "A"
	_draw_dashed_rect(rect, Color(accent.r, accent.g, accent.b, 0.38 if strong else 0.22), 2.0 if strong else 1.0, 5.0)
	if plus:
		var center := rect.get_center()
		var arm := 14.0 if strong else 12.0
		var color := Color(accent.r, accent.g, accent.b, 0.62 if strong else 0.42)
		var width := 2.0 if strong else 1.0
		draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), color, width)
		draw_line(center - Vector2(0, arm), center + Vector2(0, arm), color, width)

func _draw_legal(owner: int, lane: int, tab_rect: Rect2, front_rect: Rect2) -> void:
	var back_key := "%d|backrow|%d" % [owner, lane]
	var front_key := "%d|monster|%d" % [owner, lane]
	var strong := board_token == "A"
	var width := 2.0 if strong else 1.0
	if bool(legal_zones.get(back_key, false)):
		Chrome.draw_corner_brackets(self, tab_rect.grow(4.0), Tokens.AMBER, 10.0 if strong else 9.0, width)
		draw_rect(tab_rect.grow(2.0), Color(Tokens.AMBER.r, Tokens.AMBER.g, Tokens.AMBER.b, 0.06))
	if bool(legal_zones.get(front_key, false)):
		Chrome.draw_corner_brackets(self, front_rect.grow(4.0), Tokens.AMBER, 10.0 if strong else 9.0, width)
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
	# The deck is the same card back token as the hand, not a separate doodle.
	if not Content.card_list.is_empty():
		var back_def: CardDef = Content.card_list[0]
		draw_set_transform(deck_rect.position, 0.0, Vector2.ONE)
		CardComposer.draw(self, back_def, null, board_token, {"face_down": true})
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		Chrome.draw_cut_rect(self, deck_rect, 4.0, Tokens.CARD_FACE_DEEP)
		Chrome.draw_cut_outline(self, deck_rect, 4.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.30), 1.0)
	for i in range(2):
		var offset := Vector2(float(2 - i) * 2.0, float(2 - i) * 2.0)
		Chrome.draw_cut_outline(self, Rect2(deck_rect.position + offset, deck_rect.size), 4.0, Color(Tokens.CYAN.r, Tokens.CYAN.g, Tokens.CYAN.b, 0.12), 1.0)
	var count_text := str(duel.players[0].deck.size())
	var count_width := Tokens.font_data().get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var count_rect := Rect2(deck_rect.end.x - count_width - 7.0, deck_rect.end.y - 20.0, count_width + 5.0, 17.0)
	Chrome.draw_cut_rect(self, count_rect, 2.0, Color(Tokens.BG_VOID.r, Tokens.BG_VOID.g, Tokens.BG_VOID.b, 0.82))
	draw_string(Tokens.font_data(), Vector2(count_rect.position.x + 2.0, count_rect.end.y - 4.0), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Tokens.INK_SECONDARY)
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
