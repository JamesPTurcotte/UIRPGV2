class_name Tokens
extends RefCounted

## The visual contract. Colors, type, spacing, and card geometry live here so
## the room, furniture, and objects share one system.
##
## The legacy names (BRASS, PAPER, WAX, ...) are compatibility aliases for the
## Neon Reliquary values while the old screens are migrated. New code should use
## the semantic names (CYAN, PINK, AMBER, CARD_FACE, ...). Delete the aliases
## once the last screen is ported.

const CARD_ASPECT := 7.0 / 5.0
const CARD_TAB := 52.0
const REFERENCE_SIZE := Vector2(1440, 900)

# Neon Reliquary palette.
const BG_VOID := Color("#06030D")
const BG_DEEP := Color("#0A0518")
const BG_PANEL := Color("#0D071E")
const BG_RAISED := Color("#120A26")
const PANEL_LINE := Color("#1C5A64")
const LINE_HOT := Color("#46F0FF")
const INK_PRIMARY := Color("#F4ECFF")
const INK_SECONDARY := Color("#C9C0DE")
const INK_MUTED := Color("#6E638C")
const CYAN := Color("#46F0FF")
const PINK := Color("#FF3FA4")
const AMBER := Color("#FFCC55")
const GREEN := Color("#7DFFB2")
const PURPLE := Color("#B06BFF")
const RED := Color("#FF5B7F")
const CARD_FACE := Color("#0D0820")
const CARD_FACE_DEEP := Color("#070410")
const CARD_INK := Color("#F4ECFF")
const CARD_RULE := Color("#D9D0EF")
const CARD_MUTED := Color("#8E86A8")
const CARD_LINE := Color("#3B3559")
const SHADOW := Color(0.0, 0.0, 0.0, 0.48)
const SHADOW_DEEP := Color(0.0, 0.0, 0.0, 0.62)

# Compatibility aliases. Keep these until the screens stop using them.
const BG_LACQUER := BG_DEEP
const BRASS := CYAN
const BRASS_HI := PINK
const BRASS_LO := PANEL_LINE
const PAPER := CARD_FACE
const PAPER_INK := CARD_INK
const EMBER := Color("#FF5B7F")
const TIDE := CYAN
const VERDANT := GREEN
const UMBRA := PURPLE
const NEUTRAL := INK_PRIMARY
const VERDIGRIS := GREEN
const WAX := PINK
const DANGER := RED
const GOOD := GREEN
const SELECTION := AMBER
const GOLD := AMBER

## Card tokens are exactly 5:7. The Table swaps B/H for the compact/wide
## breakpoints; every other room reflows around the base S/M/L/XL tokens.
const CARD_SIZES := {
	"S": Vector2(150, 210),
	"M": Vector2(196, 274.4),
	"B": Vector2(105, 147),
	"H": Vector2(140, 196),
	"L": Vector2(300, 420),
	"XL": Vector2(432, 604.8),
	"B-": Vector2(80, 112),
	"H-": Vector2(112, 156.8),
	"B+": Vector2(120, 168),
	"H+": Vector2(180, 252),
	# Table backrow: a set card tucked behind its front row.
	"T": Vector2(80, 112),
	# Duel Board Overlap: one card token for hand, monsters, set cards, deck.
	"O": Vector2(145, 203),
	# Accessible Duel Board: 190px card for the 150% / 125% table.
	"A": Vector2(190, 266),
	# Legacy aliases kept so older call sites cannot silently use the tiny sizes.
	"BT": Vector2(105, 147),
	"HT": Vector2(140, 196),
}

const CARD_TEXT := {
	"S": {"name": 12, "type": 8, "rules": 8, "stat": 10, "label": 5, "footer": 6, "offer": 6},
	"B": {"name": 9, "type": 6, "rules": 5, "stat": 8, "label": 4, "footer": 4, "offer": 5},
	"B-": {"name": 7, "type": 5, "rules": 4, "stat": 7, "label": 3, "footer": 3, "offer": 4},
	"B+": {"name": 10, "type": 7, "rules": 6, "stat": 9, "label": 4, "footer": 4, "offer": 5},
	"H": {"name": 12, "type": 7, "rules": 7, "stat": 10, "label": 5, "footer": 6, "offer": 6},
	"H-": {"name": 10, "type": 6, "rules": 6, "stat": 9, "label": 4, "footer": 5, "offer": 5},
	"H+": {"name": 14, "type": 8, "rules": 9, "stat": 12, "label": 6, "footer": 7, "offer": 7},
	"T": {"name": 7, "type": 5, "rules": 4, "stat": 7, "label": 3, "footer": 3, "offer": 4},
	"O": {"name": 14, "type": 8, "rules": 8, "stat": 11, "label": 5, "footer": 6, "offer": 6},
	"A": {"name": 19, "type": 9, "rules": 11, "stat": 14, "label": 7, "footer": 8, "offer": 7},
	"M": {"name": 20, "type": 10, "rules": 12, "stat": 15, "label": 8, "footer": 9, "offer": 9},
	"L": {"name": 30, "type": 14, "rules": 18, "stat": 22, "label": 11, "footer": 13, "offer": 12},
	"XL": {"name": 34, "type": 17, "rules": 20, "stat": 28, "label": 13, "footer": 14, "offer": 14},
	# Legacy aliases.
	"BT": {"name": 9, "type": 6, "rules": 5, "stat": 8, "label": 4, "footer": 4, "offer": 5},
	"HT": {"name": 12, "type": 7, "rules": 7, "stat": 10, "label": 5, "footer": 6, "offer": 6},
}

const MOTION := {
	"instant": 0.0,
	"micro": 0.09,
	"select": 0.14,
	"move": 0.20,
	"act": 0.24,
	"impact": 0.06,
	"settle": 0.18,
	"panel": 0.20,
	"room": 0.45,
	"ceremony": 0.70,
}


const ATTRIBUTE_COLORS := {
	"ember": EMBER,
	"tide": TIDE,
	"verdant": VERDANT,
	"umbra": UMBRA,
	"neutral": NEUTRAL,
}

const RARITY_COLORS := {
	"common": Color("#9AA0B5"),
	"uncommon": Color("#7DFFB2"),
	"rare": Color("#FFCC55"),
	"legendary": Color("#FF3FA4"),
}

const INK_COLORS := {
	"ink.iron": Color("#9AA0B5"),
	"ink.verdigris": Color("#7DFFB2"),
	"ink.dusk": Color("#B06BFF"),
	"ink.ember": Color("#FF5B7F"),
	"ink.frost": Color("#46F0FF"),
	"ink.bone": Color("#F4ECFF"),
}

const SHIMMER_COLORS := {
	"shimmer.none": Color(0, 0, 0, 0),
	"shimmer.gilt": Color("#FFCC55"),
	"shimmer.iridescent": Color("#FF9AD5"),
	"shimmer.verdigris": Color("#7DFFB2"),
	"shimmer.moon": Color("#D9D0EF"),
}

static var _font_cache: Dictionary = {}

static func _load_font(path: String) -> Font:
	if not _font_cache.has(path):
		var resource = load(path)
		_font_cache[path] = resource
	return _font_cache[path]

static func _variation(path: String, weight: int) -> Font:
	var key := "%s#%d" % [path, weight]
	if _font_cache.has(key):
		return _font_cache[key]
	var base := load(path)
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {"wght": weight}
	_font_cache[key] = variation
	return variation

static func font_ui() -> Font:
	return _load_font("res://assets/fonts/Inter-Variable.ttf")

static func font_display() -> Font:
	return _variation("res://assets/fonts/Orbitron-Variable.ttf", 700)

static func font_display_regular() -> Font:
	return _variation("res://assets/fonts/Orbitron-Variable.ttf", 500)

static func font_data() -> Font:
	return _load_font("res://assets/fonts/VT323-Regular.ttf")

static func font_data_regular() -> Font:
	return _load_font("res://assets/fonts/IBMPlexMono-Regular.ttf")

static func font_label() -> Font:
	return _load_font("res://assets/fonts/IBMPlexMono-Medium.ttf")

static func card_size(token: String) -> Vector2:
	return CARD_SIZES.get(token, CARD_SIZES["M"])

static func card_text(token: String) -> Dictionary:
	return CARD_TEXT.get(token, CARD_TEXT["M"])

static func attribute_color(attribute: String) -> Color:
	return ATTRIBUTE_COLORS.get(attribute, NEUTRAL)

static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

static func ink_color(ink_id: String) -> Color:
	return INK_COLORS.get(ink_id, INK_COLORS["ink.iron"])

static func shimmer_color(shimmer_id: String) -> Color:
	return SHIMMER_COLORS.get(shimmer_id, Color(0, 0, 0, 0))

static func is_dark_face(_rarity: String) -> bool:
	return true

static func face_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Color("#0A0C1B")
		"rare":
			return Color("#0E0822")
		"legendary":
			return Color("#080410")
		_:
			return CARD_FACE

static func face_ink(_rarity: String) -> Color:
	return CARD_INK

static func face_ink_secondary(_rarity: String) -> Color:
	return CARD_RULE

static func face_ink_muted(_rarity: String) -> Color:
	return CARD_MUTED

static func frame_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return GREEN
		"rare":
			return AMBER
		"legendary":
			return PINK
		_:
			return CARD_LINE

static func panel_style(fill: Color = BG_PANEL, border: Color = PANEL_LINE, width: int = 1, radius: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
