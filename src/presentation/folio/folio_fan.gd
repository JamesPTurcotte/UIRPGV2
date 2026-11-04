class_name FolioFan
extends Control

## A fanned row of reveal cards. Cards overlap like physical paper; geometry is
## fixed and the layout only changes position.

var cards: Array[FolioRevealCard] = []

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
		if card is FolioRevealCard:
			add_child(card)
			cards.append(card)
	_layout()

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
