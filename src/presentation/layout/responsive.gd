class_name Responsive
extends RefCounted

## Layout math in logical viewport coordinates.
##
## The project stretches with canvas_items/expand. DisplayServer window sizes are
## physical pixels and do not match the coordinates Controls are laid out in, so
## presentation code must never use them for breakpoints. These helpers are the
## single place where "how wide is the room" becomes "how many columns fit".

const DEFAULT_GAP := 8.0
const MAX_COLUMNS := 16

static func columns(available_width: float, tile_width: float, gap: float = DEFAULT_GAP, max_columns: int = MAX_COLUMNS) -> int:
	if tile_width <= 0.0 or available_width <= 0.0:
		return 1
	var count := int(floor((available_width + gap) / (tile_width + gap)))
	return clampi(count, 1, maxi(1, max_columns))

static func library_shelf_columns(viewport_width: float) -> int:
	# Library margins (44) + two content separations (24) + index (168) +
	# reading desk (360) + shelf panel padding (16) + scrollbar gutter (14).
	const RESERVED := 626.0
	return columns(viewport_width - RESERVED, Tokens.card_size("S").x, 8.0, MAX_COLUMNS)

static func card_token_for_height(viewport_height: float) -> String:
	# L is 300x420 and needs the extra headroom. M keeps the Bench apply rail
	# on screen at the reference 900 px logical height.
	return "L" if viewport_height >= 980.0 else "M"

static func viewport_size(control: Control) -> Vector2:
	if control == null or not control.is_inside_tree():
		return Tokens.REFERENCE_SIZE
	return control.get_viewport_rect().size
