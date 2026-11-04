extends Control

## Visual QA driver. Not part of the game.
## godot --path . res://tests/screen_shot.tscn -- --screen=gate

var app: Control

func _ready() -> void:
	theme = ThemeBuilder.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app = load("res://src/presentation/app.gd").new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(app)
	await get_tree().create_timer(0.6).timeout
	var screen := "library"
	var wait_time := 1.4
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screen="):
			screen = arg.get_slice("=", 1)
		elif arg.begins_with("--wait="):
			wait_time = float(arg.get_slice("=", 1))
	match screen:
		"gate":
			app.show_screen("gate")
		"library_click":
			app.show_screen("library")
			await get_tree().create_timer(0.4).timeout
			if app.current_screen != null and not app.current_screen.views.is_empty():
				app.current_screen._on_card_clicked(app.current_screen.views[0])
				app.current_screen._on_card_clicked(app.current_screen.views[0])
		"library_filter":
			app.show_screen("library")
			await get_tree().create_timer(0.4).timeout
			if app.current_screen != null:
				app.current_screen.filter_bar._toggle_advanced_view()
				if app.current_screen.filter_bar.facet_menus.has("type"):
					app.current_screen.filter_bar.facet_menus["type"]._on_id_pressed(0)
		"library_context", "library_context_close":
			app.show_screen("library")
			await get_tree().create_timer(0.5).timeout
			if app.current_screen != null:
				var lib = app.current_screen
				lib.shelf_scroll.scroll_vertical = 0 if screen == "library_context" else 220
				await get_tree().process_frame
				var target_view: CardView = lib.views[mini(4, lib.views.size() - 1)]
				var before := {
					"screen": lib.size,
					"margin": lib.get_child(0).size,
					"cards": lib.cards_box.get_global_rect(),
					"shelf": lib.shelf_scroll.scroll_vertical,
					"desk": lib.desk_scroll.scroll_vertical,
					"key": lib.selected_key,
				}
				lib._on_card_right_clicked(target_view, target_view.get_global_rect())
				await get_tree().create_timer(0.25).timeout
				print("context open: before=%s after=%s menu=%s" % [str(before), str({"screen": lib.size, "margin": lib.get_child(0).size, "cards": lib.cards_box.get_global_rect(), "shelf": lib.shelf_scroll.scroll_vertical, "desk": lib.desk_scroll.scroll_vertical, "key": lib.selected_key}), str(app.context_menu != null)])
				if screen == "library_context_close":
					app.close_context_menu()
					await get_tree().create_timer(0.25).timeout
					print("context closed: %s" % str({"screen": lib.size, "margin": lib.get_child(0).size, "cards": lib.cards_box.get_global_rect(), "shelf": lib.shelf_scroll.scroll_vertical, "desk": lib.desk_scroll.scroll_vertical, "key": lib.selected_key}))
		"library_context_action":
			app.show_screen("library")
			await get_tree().create_timer(0.5).timeout
			if app.current_screen != null:
				var lib = app.current_screen
				var picked := {}
				for entry in lib.entries_filtered:
					if str(entry.get("kind", "")) == "instance" and entry.get("best_instance") != null:
						picked = entry
						break
				if not picked.is_empty():
					lib._select_entry(picked)
					lib.context_entry = picked
					lib.shelf_scroll.scroll_vertical = 200
					await get_tree().process_frame
					var before := {"key": lib.selected_key, "shelf": lib.shelf_scroll.scroll_vertical, "cards": lib.cards_box.get_global_rect()}
					lib._on_context_action(6)
					await get_tree().create_timer(0.3).timeout
					print("context action: before=%s after=%s" % [str(before), str({"key": lib.selected_key, "shelf": lib.shelf_scroll.scroll_vertical, "cards": lib.cards_box.get_global_rect()})])
		"deck":
			app.show_screen("deck")
		"deck_context":
			app.show_screen("deck")
			await get_tree().create_timer(0.5).timeout
			if app.current_screen != null:
				var deck_screen = app.current_screen
				deck_screen.library_scroll.scroll_vertical = 120
				deck_screen.deck_scroll.scroll_vertical = 180
				await get_tree().process_frame
				var view: CardView = deck_screen.library_grid.get_child(0).get_child(0)
				var before := {"library": deck_screen.library_scroll.scroll_vertical, "deck": deck_screen.deck_scroll.scroll_vertical, "panel": deck_screen.deck_panel.get_global_rect()}
				deck_screen._open_library_menu(str(view.def.id), view.get_global_rect(), view)
				await get_tree().create_timer(0.2).timeout
				print("deck context open: before=%s after=%s" % [str(before), str({"library": deck_screen.library_scroll.scroll_vertical, "deck": deck_screen.deck_scroll.scroll_vertical, "panel": deck_screen.deck_panel.get_global_rect()})])
				app.close_context_menu()
		"deck_drop_logic":
			app.show_screen("deck")
			await get_tree().create_timer(0.4).timeout
			if app.current_screen != null:
				var deck_screen = app.current_screen
				var deck = Session.active_deck()
				if deck != null and deck.main.size() >= 40:
					Session.remove_instance_from_deck(deck.main[0])
					deck_screen._refresh_all()
				var before: int = deck_screen.entries_all.size()
				var entry: Dictionary = {}
				for candidate in deck_screen.entries_all:
					var did := str(candidate.get("def_id", ""))
					if str(candidate.get("kind", "")) == "stack" and Session.count_def_in_deck(did, deck) < 3:
						entry = candidate
						break
				if entry.is_empty():
					entry = deck_screen.entries_all[0]
				var local_center: Vector2 = deck_screen.deck_panel.get_global_rect().get_center() - deck_screen.get_global_rect().position
				var payload := {"source": "library", "def_id": str(entry.get("def_id", "")), "entry_kind": "stack"}
				var accepted: bool = deck_screen._can_drop_data(local_center, payload)
				deck_screen._drop_data(local_center, payload)
				print("deck drop logic accepted=%s before=%d after=%d main=%d" % [str(accepted), before, deck_screen.entries_all.size(), Session.active_deck().main.size()])
				var lib_view: CardView = deck_screen.library_grid.get_child(0).get_child(0)
				var deck_id := int(Session.active_deck().main[0])
				var deck_payload := {"source": "deck", "instance_id": deck_id, "from_zone": "main"}
				var lib_accept := lib_view._can_drop_data(Vector2.ZERO, deck_payload)
				lib_view._drop_data(Vector2.ZERO, deck_payload)
				print("card drop library accepts=%s main_after=%d" % [str(lib_accept), Session.active_deck().main.size()])
				deck_screen._refresh_all()
				var deck_view: CardView = deck_screen.deck_grid.get_child(0).get_child(0)
				var lib_payload := {"source": "library", "def_id": str(entry.get("def_id", "")), "entry_kind": "stack"}
				var deck_accept := deck_view._can_drop_data(Vector2.ZERO, lib_payload)
				deck_view._drop_data(Vector2.ZERO, lib_payload)
				print("card drop deck accepts=%s main_after=%d" % [str(deck_accept), Session.active_deck().main.size()])
		"folio":
			app.show_screen("folio")
		"table":
			_fresh_descent("manual")
			app.show_screen("table")
		"table_focus_exit":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			print("focus exit before viewport=%s screen=%s scale=%s pinned=%s" % [str(get_viewport_rect().size), str(app.current_screen.size), str(app.current_screen.access_scale), str(get_window().get_flag(Window.FLAG_ALWAYS_ON_TOP))])
			var door: Button = null
			app.current_screen._toggle_drawer()
			await get_tree().create_timer(0.2).timeout
			for child in app.current_screen.drawer.find_children("*", "Button", true, false):
				if str((child as Button).text) == "LIBRARY":
					door = child
					break
			print("focus door library=%s" % str(door != null))
			if door != null:
				door.pressed.emit()
			await get_tree().create_timer(1.0).timeout
			print("focus exit after viewport=%s screen=%s pinned=%s window=%s" % [str(get_viewport_rect().size), str(app.current_screen.size), str(get_window().get_flag(Window.FLAG_ALWAYS_ON_TOP)), str(DisplayServer.window_get_position())])
		"table_focus_auto":
			Session.settings["table_speed"] = 4
			_fresh_descent("auto")
			app.show_screen("table")
			await get_tree().create_timer(4.0).timeout
		"table_focus_hover":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				var c = app.current_screen
				c.mode = "manual"
				c.paused = true
				c.timer.stop()
				var w = c.duel.players[1]
				var sdef: CardDef = Content.cards["neutral.ninefold_seal"]
				var sinst := CardInstance.new(9001, sdef.id, 1)
				var scard := DuelCard.new()
				scard.uid = 9001
				scard.instance = sinst
				scard.def = sdef
				scard.owner = 1
				scard.lane = 0
				scard.zone = GameConst.ZONE_BACKROW
				scard.face_down = true
				w.backrow[0] = scard
				var mdef: CardDef = Content.cards["verdant.bramble_wall"]
				var minst := CardInstance.new(9002, mdef.id, 1)
				var mcard := DuelCard.new()
				mcard.uid = 9002
				mcard.instance = minst
				mcard.def = mdef
				mcard.owner = 1
				mcard.lane = 0
				mcard.zone = GameConst.ZONE_MONSTER
				mcard.face_down = true
				w.monsters[0] = mcard
				c.stage.sync_all(c.duel)
				c.stage.apply_rest(c.duel)
				await get_tree().create_timer(0.2).timeout
				var actor = c.stage.actors.get(9001)
				if actor != null:
					actor._on_hover_changed(actor.view, true)
					print("index hover view=%s tab=%s" % [str(actor.view.position), str(actor.hover_zone.size)])
		"table_focus_drawer":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				app.current_screen._toggle_drawer()
				await get_tree().create_timer(0.5).timeout
				print("drawer rect=%s visible=%s scale=%s hand_label=%s hand=%d" % [str(app.current_screen.drawer.get_global_rect()), str(app.current_screen.drawer.visible), str(app.current_screen.access_scale), app.current_screen.player_hand_label.text, app.current_screen.duel.players[0].hand.size()])
		"table_focus_drawer_960":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				app.current_screen._toggle_drawer()
				await get_tree().create_timer(0.5).timeout
				print("drawer 960 rect=%s visible=%s scale=%s hand_label=%s hand=%d" % [str(app.current_screen.drawer.get_global_rect()), str(app.current_screen.drawer.visible), str(app.current_screen.access_scale), app.current_screen.player_hand_label.text, app.current_screen.duel.players[0].hand.size()])
		"table_focus_metrics":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			var st = app.current_screen.stage
			print("focus stage=%s board=%s hand=%s deck=%s hand_rects=%s" % [str(st.size), str(st.board_rect), str(st.hand_zone_rect), str(st.deck_rect), str(st.hand_rects)])
		"table_focus_960":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				var st = app.current_screen.stage
				print("focus 960 stage=%s scale=%d board=%s mat=%s card=%s" % [str(st.size), int(app.current_screen.access_scale), str(st.board_rect), str(st.warden_mat_rect), str(Tokens.card_size(st.board_token))])
		"table_focus":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				var st = app.current_screen.stage
				print("focus stage=%s scale=%d board=%s mat=%s card=%s tab=%s pinned=%s window=%s" % [str(st.size), int(app.current_screen.access_scale), str(st.board_rect), str(st.warden_mat_rect), str(Tokens.card_size(st.board_token)), str(Tokens.CARD_TAB), str(get_window().get_flag(Window.FLAG_ALWAYS_ON_TOP)), str(DisplayServer.window_get_position())])
		"result_win", "result_fall":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			var fake = {"kind": "win", "floor": 1, "marks": 120, "cards": [], "folios": [], "streak": 1, "chapter_seal": false, "performance": {"total": 0}, "underdog": 0.1, "reagents": {}}
			if screen == "result_fall":
				fake = {"kind": "fall", "floor": 1, "marks": 198, "cards": [], "performance": {"total": 140, "floor_points": 60, "streak_points": 20, "flawless_points": 50, "damage_points": 6, "heal_points": 2, "cards_points": 2}, "underdog": 0.2, "reagents": {}, "salvage_cache": true}
			if app.current_screen != null:
				app.current_screen._show_result(fake)
		"result_click":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.8).timeout
			var fake = {"kind": "win", "floor": 1, "marks": 120, "cards": [], "folios": [], "streak": 1, "chapter_seal": false, "performance": {"total": 0}, "underdog": 0.1, "reagents": {}}
			if app.current_screen != null:
				Session.descent["door_pending"] = false
				app.current_screen._show_result(fake)
				await get_tree().create_timer(0.2).timeout
				var ceremony = app.current_screen.result_overlay
				var door: DoorCard = ceremony.doors[0]
				var center := door.get_global_rect().get_center()
				Input.warp_mouse(center)
				var down := InputEventMouseButton.new()
				down.button_index = MOUSE_BUTTON_LEFT
				down.pressed = true
				down.position = center
				Input.parse_input_event(down)
				var up := InputEventMouseButton.new()
				up.button_index = MOUSE_BUTTON_LEFT
				up.pressed = false
				up.position = center
				Input.parse_input_event(up)
				await get_tree().create_timer(0.25).timeout
				print("door fail: overlay=%s failure=%s" % [str(app.current_screen.result_overlay != null), str(ceremony.failure_label.visible)])
				Session.descent["door_pending"] = true
				var center2 := door.get_global_rect().get_center()
				var down2 := InputEventMouseButton.new()
				down2.button_index = MOUSE_BUTTON_LEFT
				down2.pressed = true
				down2.position = center2
				Input.parse_input_event(down2)
				var up2 := InputEventMouseButton.new()
				up2.button_index = MOUSE_BUTTON_LEFT
				up2.pressed = false
				up2.position = center2
				Input.parse_input_event(up2)
				await get_tree().create_timer(0.3).timeout
				print("door success: overlay=%s" % str(app.current_screen.result_overlay != null))
		"layout_resize":
			app.show_screen("library")
			await get_tree().create_timer(0.5).timeout
			if app.current_screen != null:
				print("layout before: viewport=%s shelves=%d" % [str(get_viewport_rect().size), int(app.current_screen.shelf_columns)])
			get_window().size = Vector2i(1920, 1080)
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				print("layout after grow: viewport=%s shelves=%d" % [str(get_viewport_rect().size), int(app.current_screen.shelf_columns)])
			get_window().size = Vector2i(1440, 900)
			await get_tree().create_timer(0.8).timeout
			if app.current_screen != null:
				print("layout after shrink: viewport=%s shelves=%d" % [str(get_viewport_rect().size), int(app.current_screen.shelf_columns)])
		"zoom":
			app.show_zoom(Content.cards["ember.cinder_hound"], null)
		"zoom_trap":
			app.show_zoom(Content.cards["neutral.ninefold_seal"], null)
		"manual_action":
			_fresh_descent("manual")
			app.show_screen("table")
			await get_tree().create_timer(0.6).timeout
			for i in range(16):
				if app.current_screen != null and app.current_screen.duel != null and app.current_screen.duel.active == 0 and not app.current_screen.busy:
					break
				await get_tree().create_timer(0.5).timeout
			if app.current_screen != null and app.current_screen.duel != null and app.current_screen.duel.active == 0 and not app.current_screen.busy:
				var c_screen = app.current_screen
				var picked = {}
				for action in DuelRules.legal_actions(c_screen.duel):
					if str(action.get("type", "")) == "call" and not bool(action.get("face_down", false)):
						picked = action
						break
				if not picked.is_empty():
					c_screen._on_hand_card_clicked(int(picked.get("uid", -1)))
					c_screen._on_stage_zone_clicked(0, "monster", int(picked.get("lane", -1)))
					print("manual action applied: ", picked.get("label", ""))
					await get_tree().create_timer(1.2).timeout
					var hand_names: Array[String] = []
					for hand_card in c_screen.duel.players[0].hand:
						hand_names.append(hand_card.display_name())
					print("hand after: ", hand_names)
					for lane in range(3):
						var mon = c_screen.duel.players[0].monsters[lane]
						print("player lane %d: %s" % [lane, mon.display_name() if mon != null else "empty"])
					for uid in c_screen.stage.actors.keys():
						var actor = c_screen.stage.actors[uid]
						print("actor %s pos=%s size=%s zone=%s def=%s face_down=%s z=%d" % [uid, actor.position, actor.size, actor.card.zone, actor.card.def.id, str(actor.card.face_down), int(actor.z_index)])
					for uid in c_screen.stage.actors.keys():
						var hover_actor = c_screen.stage.actors[uid]
						if hover_actor.card.zone == GameConst.ZONE_BACKROW:
							hover_actor._on_hover_changed(hover_actor.view, true)
							print("hover backrow %s view_y=%.1f z=%d" % [hover_actor.card.def.id, hover_actor.view.position.y, int(hover_actor.z_index)])
							break
		"table_auto":
			Session.settings["table_speed"] = 4
			_fresh_descent("auto")
			app.show_screen("table")
			await get_tree().create_timer(1.0).timeout
			if app.current_screen != null:
				print("table_auto mode=%s rail=%s active=%d" % [str(app.current_screen.mode), str(app.current_screen.rail_tab), int(app.current_screen.duel.active)])
		"folio_reveal":
			var unopened = Session.unopened_packs()
			if unopened.is_empty():
				var bought: Dictionary = Session.buy_folio("folio.paper")
				unopened = Session.unopened_packs()
			if not unopened.is_empty():
				app.go_folio(int(unopened[0].get("id", 0)))
				await get_tree().create_timer(0.4).timeout
				if app.current_screen != null:
					app.current_screen._crack()
					await get_tree().create_timer(0.3).timeout
					if app.current_screen != null:
						app.current_screen._reveal_all()
		"folio_reveal5":
			Session.currency["marks"] = 1000
			var bought: Dictionary = Session.buy_folio("folio.brass")
			var pack_id := int(bought.get("pack", {}).get("id", 0)) if bool(bought.get("ok", false)) else 0
			if pack_id == 0:
				for pack in Session.unopened_packs():
					if str(pack.get("kind", "")) == "folio.brass":
						pack_id = int(pack.get("id", 0))
						break
			if pack_id > 0:
				app.go_folio(pack_id)
				await get_tree().create_timer(0.4).timeout
				if app.current_screen != null:
					app.current_screen._crack()
					await get_tree().create_timer(0.4).timeout
					if app.current_screen != null:
						app.current_screen._reveal_all()
		"bench", "bench_apply":
			var entries = Session.collection_entries()
			var picked = {}
			for entry in entries:
				if str(entry.get("kind", "")) == "stack":
					picked = entry
					break
			if not picked.is_empty():
				var pulled: Dictionary = Session.pull_entry_to_bench(picked)
				if bool(pulled.get("ok", false)):
					app.go_bench(pulled.get("instance"), str(picked.get("def_id", "")))
					if screen == "bench_apply":
						await get_tree().create_timer(0.4).timeout
						if app.current_screen != null:
							app.current_screen.selected_reagent = "reagent.pale_ink"
							app.current_screen._refresh_all()
							app.current_screen._apply()
		"salvage_cards":
			var drops: Array[Dictionary] = []
			for i in range(12):
				var def: CardDef = Content.card_list[i % Content.card_list.size()]
				drops.append({"def_id": def.id, "provenance": 5})
			app.go_salvage({
				"kind": "fall",
				"floor": 9,
				"marks": 406,
				"performance": {"total": 322},
				"reagents": {"reagent.pale_ink": 1},
				"cards": drops,
				"underdog": 0.17,
				"salvage_cache": true,
			}, false)
		"salvage":
			var last = Session.last_result
			if last.is_empty():
				last = {"kind": "fall", "floor": 3, "marks": 198, "performance": {"total": 140, "floor_points": 60, "streak_points": 20, "flawless_points": 50, "damage_points": 6, "heal_points": 2, "cards_points": 2}, "reagents": {"reagent.pale_ink": 1}, "cards": [], "underdog": 0.2, "salvage_cache": true}
			app.go_salvage(last, false)
	await get_tree().create_timer(wait_time).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/%s.png" % screen)
	print("screenshot saved: %s.png" % screen)
	if Session.has_active_descent():
		print("descent: floor=%d active=%s cleared=%d streak=%d" % [int(Session.descent.get("current_floor", 0)), str(Session.descent.get("active", false)), int(Session.descent.get("cleared", 0)), int(Session.descent.get("streak", 0))])
	get_tree().quit(0)

func _fresh_descent(play_mode: String) -> void:
	# Visual QA must reach the Table even when the developer's current deck is
	# mid-edit. Auto-fill is a no-op for a legal deck.
	var deck = Session.active_deck()
	if deck == null or not Session.deck_errors(deck).is_empty():
		Session.auto_fill_deck()
	if Session.has_active_descent():
		Session.abandon_descent()
	Session.start_descent(1, Session.active_deck_id, play_mode)
