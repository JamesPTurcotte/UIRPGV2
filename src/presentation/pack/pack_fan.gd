class_name PackFan
extends Control

## A fanned row of reveal cards. Cards overlap like physical paper; geometry is
## fixed and the layout only changes position.

var cards: Array[PackRevealCard] = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, Tokens.card_size("M").y)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)

func height_for_count(_count: int, size_token: String = "M") -> float:
	return Tokens.card_size(size_token).y + 12.0

func set_cards(list: Array) -> void:
	for child in cards:
		if is_instance_valid(child):
			child.queue_free()
	cards.clear()
	for card in list:
		if card is PackRevealCard:
			add_child(card)
			cards.append(card)
	_layout()

func deal_in() -> void:
	if cards.is_empty():
		return
	for i in range(cards.size()):
		var card := cards[i]
		var target := card.position
		card.position = target + Vector2(0, 34)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", target, 0.24).set_delay(float(i) * 0.055)
		tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(float(i) * 0.055)

func _layout() -> void:
	if cards.is_empty():
		return
	var card_w := cards[0].size.x
	var available := maxf(size.x, card_w + 80.0)
	var step := 120.0
	if cards.size() <= 3:
		step = card_w + 8.0
	elif cards.size() > 1:
		step = clampf((available - card_w - 8.0) / float(cards.size() - 1), 54.0, 168.0)
	var total := step * float(cards.size() - 1) + card_w
	var x := (available - total) * 0.5
	for i in range(cards.size()):
		var card := cards[i]
		card.position = Vector2(x + step * float(i), 4.0)
		card.z_index = 10 + i
