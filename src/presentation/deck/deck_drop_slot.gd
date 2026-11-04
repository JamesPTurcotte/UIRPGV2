class_name DeckDropSlot
extends PanelContainer

## An empty deck slot that accepts a drag. This is a belt-and-braces target:
## native drag can resolve the slot even if the panel root is not the topmost
## control under the pointer.

var screen: Node
var zone: String = "main"

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if screen == null or not data is Dictionary:
		return false
	return screen.can_drop_zone(zone, data)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if screen != null and data is Dictionary:
		screen.drop_payload(data, zone)
