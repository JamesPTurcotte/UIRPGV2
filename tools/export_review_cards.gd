extends Node

## Render review card faces with the shipping CardComposer. The review pages
## are static HTML, so they consume these PNGs instead of rebuilding a second
## card renderer in CSS. Output is 2x the L token for crisp downscaling.

const OUT_DIR := "res://review/assets/cards"
const CARDS := [
	"ember.cinder_hound",
	"verdant.bramble_wall",
	"ember.ash_moth",
	"ember.ember_scout",
	"neutral.ninefold_seal",
	"verdant.bone_orchard",
	"umbra.hollow_lantern",
	"tide.tidecall",
	"neutral.quiet_ledger",
]
const BACK_CARD := "ember.cinder_hound"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	for def_id in CARDS:
		var def: CardDef = Content.cards.get(def_id)
		if def == null:
			push_warning("Missing review card: %s" % def_id)
			continue
		var file_name: String = str(def_id).replace(".", "_") + ".png"
		await _render(def, false, OUT_DIR + "/" + file_name)
	await _render(Content.cards[BACK_CARD], true, OUT_DIR + "/back.png")
	print("review card renders written to %s" % OUT_DIR)
	get_tree().quit()

func _render(def: CardDef, face_down: bool, path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 840)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	add_child(viewport)

	var holder := Control.new()
	holder.size = Vector2(300, 420)
	holder.scale = Vector2(2.0, 2.0)
	viewport.add_child(holder)

	var view := CardView.new()
	view.set_card(def, null, "L")
	view.set_flag("face_down", face_down)
	holder.add_child(view)

	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Could not write %s: %s" % [path, error_string(err)])
	viewport.queue_free()
	await get_tree().process_frame
