extends Control

func _ready() -> void:
	theme = ThemeBuilder.build()
	var backdrop := Backdrop.new()
	backdrop.screen_kind = "library"
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := UI.display("CARD GALLERY", 28)
	root.add_child(title)
	root.add_child(UI.label("5:7 at every size · procedural seals · no illustrations", 13, Tokens.INK_SECONDARY))

	var scroll := UI.scroll()
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)

	var index := 0
	for def in Content.card_list:
		var instance: CardInstance
		if index == 0:
			instance = CardInstance.new(1001, def.id, 42)
			instance.add_mod("mod.gilded", 3, 150)
			instance.add_mod("mod.of_embers", 4, 250)
			instance.quality = 14
		elif index == 1:
			instance = CardInstance.new(1002, def.id, 70)
			instance.custom_name = "Ash"
			instance.fractured_mod = "mod.stalwart"
			instance.add_mod("mod.stalwart", 5, 500)
			instance.shimmer_id = "shimmer.gilt"
		elif index == 2:
			instance = CardInstance.new(1003, def.id, 25)
			instance.corrupted = true
			instance.add_mod("mod.verdigris_open", 1, 0)
		var view := CardView.new()
		view.set_card(def, instance, "S")
		view.count = index + 1 if index < 3 else 0
		view.decked = index % 4 == 0
		view.set_flag("new", index % 5 == 0)
		grid.add_child(view)
		index += 1

	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 24)
	root.add_child(detail_row)
	for token in ["B", "M", "L"]:
		var holder := VBoxContainer.new()
		holder.add_child(UI.label(token, 11, Tokens.INK_MUTED, Tokens.font_data()))
		var view := CardView.new()
		view.set_card(Content.cards["ember.cinder_hound"], null, token)
		holder.add_child(view)
		detail_row.add_child(holder)

	await get_tree().create_timer(1.5).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://screenshots/card_gallery.png")
	print("screenshot saved")
	get_tree().quit(0)
