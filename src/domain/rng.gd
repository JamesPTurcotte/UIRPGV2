class_name GameRng
extends RefCounted

## Deterministic random stream. Every duel / folio / craft derives its own
## stream from a root seed so replay does not depend on call order elsewhere.

var _rng := RandomNumberGenerator.new()

func _init(root_seed: int = 0, stream: int = 0) -> void:
	reseed(root_seed, stream)

func reseed(root_seed: int, stream: int = 0) -> void:
	# Split the stream id across the seed so adjacent streams do not correlate.
	var mixed := (root_seed & 0x7FFFFFFFFFFFFFFF) ^ ((stream * 0x9E3779B1) & 0x7FFFFFFFFFFFFFFF)
	_rng.seed = mixed

func next_int(max_exclusive: int) -> int:
	if max_exclusive <= 1:
		return 0
	return _rng.randi_range(0, max_exclusive - 1)

func range_int(min_value: int, max_value: int) -> int:
	if max_value <= min_value:
		return min_value
	return _rng.randi_range(min_value, max_value)

func chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() < probability

func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[next_int(items.size())]

func pick_weighted(entries: Array, weight_key: String = "weight") -> Variant:
	var total := 0.0
	for entry in entries:
		total += float(entry.get(weight_key, 1))
	if total <= 0.0:
		return null
	var roll := _rng.randf() * total
	var cursor := 0.0
	for entry in entries:
		cursor += float(entry.get(weight_key, 1))
		if roll <= cursor:
			return entry
	return entries.back()

func shuffle(items: Array) -> void:
	# Fisher-Yates with the domain RNG; Array.shuffle() uses the global RNG.
	for i in range(items.size() - 1, 0, -1):
		var j := next_int(i + 1)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp

func state_value() -> int:
	return _rng.state
