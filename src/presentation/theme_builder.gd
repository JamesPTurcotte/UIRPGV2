class_name ThemeBuilder
extends RefCounted

## Standard Godot controls, skinned from Tokens. Custom-drawn objects (cards,
## chrome, table) must use Tokens directly; this file is only the fallback UI.

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = Tokens.font_ui()
	theme.default_font_size = 14

	theme.set_font("font", "Label", Tokens.font_ui())
	theme.set_font_size("font_size", "Label", 14)
	theme.set_color("font_color", "Label", Tokens.INK_PRIMARY)

	var button_normal := _style(Tokens.BG_RAISED, Tokens.BRASS_LO, 1, 2)
	var button_hover := _style(Tokens.BG_RAISED.lightened(0.06), Tokens.CYAN, 1, 2)
	var button_pressed := _style(Tokens.BG_PANEL, Tokens.PINK, 1, 2)
	var button_disabled := _style(Tokens.BG_PANEL, Tokens.BRASS_LO.darkened(0.35), 1, 2)
	button_disabled.bg_color.a = 0.45
	var button_focus := _style(Color(0, 0, 0, 0), Tokens.SELECTION, 2, 2)
	button_focus.draw_center = false
	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_disabled)
	theme.set_stylebox("focus", "Button", button_focus)
	theme.set_font("font", "Button", Tokens.font_ui())
	theme.set_font_size("font_size", "Button", 12)
	theme.set_color("font_color", "Button", Tokens.INK_PRIMARY)
	theme.set_color("font_hover_color", "Button", Tokens.CYAN)
	theme.set_color("font_pressed_color", "Button", Tokens.PINK)
	theme.set_color("font_disabled_color", "Button", Tokens.INK_MUTED)

	var panel := _style(Tokens.BG_PANEL, Tokens.BRASS_LO, 1, 3)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var line_edit := _style(Tokens.BG_VOID, Tokens.BRASS_LO, 1, 2)
	line_edit.content_margin_left = 9
	line_edit.content_margin_right = 9
	line_edit.content_margin_top = 7
	line_edit.content_margin_bottom = 7
	var line_focus := _style(Tokens.BG_VOID, Tokens.CYAN, 1, 2)
	line_focus.draw_center = false
	theme.set_stylebox("normal", "LineEdit", line_edit)
	theme.set_stylebox("focus", "LineEdit", line_focus)
	theme.set_color("font_color", "LineEdit", Tokens.INK_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", Tokens.INK_MUTED)
	theme.set_color("caret_color", "LineEdit", Tokens.PINK)
	theme.set_font("font", "LineEdit", Tokens.font_ui())
	theme.set_font_size("font_size", "LineEdit", 13)

	var option := _style(Tokens.BG_RAISED, Tokens.BRASS_LO, 1, 2)
	theme.set_stylebox("normal", "OptionButton", option)
	theme.set_stylebox("hover", "OptionButton", button_hover)
	theme.set_stylebox("pressed", "OptionButton", button_pressed)
	theme.set_stylebox("focus", "OptionButton", button_focus)
	theme.set_font("font", "OptionButton", Tokens.font_ui())
	theme.set_font_size("font_size", "OptionButton", 12)
	theme.set_color("font_color", "OptionButton", Tokens.INK_PRIMARY)

	var popup := _style(Tokens.BG_RAISED, Tokens.CYAN, 1, 2)
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_font("font", "PopupMenu", Tokens.font_ui())
	theme.set_font_size("font_size", "PopupMenu", 12)
	theme.set_color("font_color", "PopupMenu", Tokens.INK_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", Tokens.CYAN)
	theme.set_stylebox("hover", "PopupMenu", _style(Tokens.BG_PANEL, Tokens.PANEL_LINE, 1, 2))

	var scroll_track := _style(Tokens.BG_VOID.darkened(0.2), Color(0, 0, 0, 0), 0, 2)
	var scroll_grabber := _style(Tokens.BRASS_LO, Color(0, 0, 0, 0), 0, 2)
	theme.set_stylebox("scroll", "VScrollBar", scroll_track)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _style(Tokens.CYAN, Color(0, 0, 0, 0), 0, 2))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _style(Tokens.PINK, Color(0, 0, 0, 0), 0, 2))
	theme.set_stylebox("scroll", "HScrollBar", scroll_track)
	theme.set_stylebox("grabber", "HScrollBar", scroll_grabber)

	var tooltip := _style(Tokens.BG_RAISED, Tokens.CYAN, 1, 2)
	tooltip.content_margin_left = 9
	tooltip.content_margin_right = 9
	tooltip.content_margin_top = 7
	tooltip.content_margin_bottom = 7
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_font("font", "TooltipLabel", Tokens.font_ui())
	theme.set_font_size("font_size", "TooltipLabel", 12)
	theme.set_color("font_color", "TooltipLabel", Tokens.INK_PRIMARY)

	theme.set_color("font_color", "CheckBox", Tokens.INK_PRIMARY)
	theme.set_font("font", "CheckBox", Tokens.font_ui())
	theme.set_font_size("font_size", "CheckBox", 12)
	theme.set_stylebox("focus", "CheckBox", button_focus)

	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("margin_left", "MarginContainer", 0)
	return theme

static func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
