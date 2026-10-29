class_name UIKit
## Shared look for all menus: chunky rounded panels, bold outlined text.

const BG := Color(0.08, 0.1, 0.12, 0.82)
const ACCENT := Color(0.45, 0.85, 0.35)
const WARN := Color(1.0, 0.45, 0.3)
const GOLD := Color(1.0, 0.82, 0.3)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Rounded MT Bold", "Futura", "Helvetica Neue", "Arial Black", "sans-serif"])
	font.font_weight = 800
	t.default_font = font
	t.set_stylebox("panel", "PanelContainer", box(BG, 14))
	t.set_stylebox("panel", "Panel", box(BG, 14))
	t.set_stylebox("normal", "Button", box(Color(0.62, 0.13, 0.1), 10, 2, Color(0.3, 0.05, 0.04)))
	t.set_stylebox("hover", "Button", box(Color(0.78, 0.2, 0.15), 10, 2, Color(0.3, 0.05, 0.04)))
	t.set_stylebox("pressed", "Button", box(Color(0.48, 0.09, 0.07), 10, 2, Color(0.3, 0.05, 0.04)))
	t.set_stylebox("disabled", "Button", box(Color(0.35, 0.35, 0.38), 10))
	t.set_stylebox("focus", "Button", box(Color(1, 1, 1, 0), 10, 3, Color(1, 1, 1, 0.8)))
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.7))
	t.set_constant("outline_size", "Button", 6)
	t.set_color("font_outline_color", "Button", Color(0.15, 0.02, 0.02))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_stylebox("normal", "LineEdit", box(Color(0.15, 0.17, 0.2), 8, 2, Color(0.4, 0.4, 0.45)))
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.55), 8))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, 8))
	_theme = t
	return t


static func box(color: Color, radius := 10, border := 0, border_color := Color.BLACK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func label(text: String, size := 22, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func bar(color: Color, w := 300.0, h := 22.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	p.max_value = 1.0
	p.step = 0.001
	p.add_theme_stylebox_override("fill", box(color, 8))
	return p
