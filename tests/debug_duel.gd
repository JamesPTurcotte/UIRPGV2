extends Node

func _ready() -> void:
	await get_tree().process_frame
	var player_deck := _make_instances(Content.starter("starter.ember").get("deck", []))
	var opponent_deck := _make_instances(Content.opponent("warden.damp").get("deck", []))
	var state := DuelState.new()
	state.setup({
		"seed": 4019,
		"def_db": Content.cards,
		"mod_db": Content.mods,
		"player": {"name": "You", "doctrine": "press", "instances": player_deck},
		"opponent": {"name": "The Damp Warden", "doctrine": "hold", "instances": opponent_deck, "skill": 55},
	})
	DuelAI.simulate(state, 65)
	var summary := state.summary()
	print("SUMMARY: ", summary)
	print("LOG:")
	for entry in state.log:
		print("T%02d %-8s %s" % [int(entry["turn"]), str(entry["phase"]), str(entry["text"])])
	get_tree().quit(0)

func _make_instances(deck_entries: Array) -> Array:
	var result: Array = []
	var counter := 1
	for entry in deck_entries:
		for i in range(int(entry.get("count", 0))):
			var instance := CardInstance.new(counter, str(entry.get("def", "")), 1)
			counter += 1
			result.append(instance)
	return result
