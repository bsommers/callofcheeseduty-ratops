class_name MenuStyle
extends RefCounted
## Shared look + helpers for the menus-audio screens. Autoloads are fetched by name at runtime so these scripts
## parse even when an autoload is not registered yet.

const DB = preload("res://data/db.gd")
const INK := Color(0.98, 0.93, 0.78)
const DIM := Color(0.72, 0.65, 0.5)
const GOLD := Color(1.0, 0.82, 0.3)
const BG := Color(0.24, 0.15, 0.08, 0.97)
const BG2 := Color(0.36, 0.23, 0.12, 1.0)
const ACCENT := Color(0.95, 0.6, 0.15)
const GOOD := Color(0.55, 0.85, 0.4)
const BAD := Color(0.9, 0.35, 0.3)
static var _theme: Theme


static func auto(name: String) -> Node:
	var ml: SceneTree = Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(name) if ml != null else null


static func sfx(id: String) -> void:
	var a: Node = auto("Audio")
	if a != null:
		a.play_sfx(id)


static func box(color: Color, border: Color = Color(0.5, 0.33, 0.15), radius: int = 10, bw: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font_size = 24
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "RichTextLabel", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("panel", "PanelContainer", box(BG, Color(0.95, 0.72, 0.25), 16, 5))
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var c: Color = BG2
		var bc: Color = Color(0.4, 0.27, 0.12)
		match st:
			"hover":
				c = Color(0.32, 0.21, 0.1)
				bc = ACCENT
			"pressed":
				c = Color(0.45, 0.28, 0.1)
				bc = GOLD
			"focus":
				c = Color(0.36, 0.23, 0.08)
				bc = GOLD
			"disabled":
				c = Color(0.16, 0.12, 0.09)
				bc = Color(0.25, 0.2, 0.15)
		var sb: StyleBoxFlat = box(c, bc, 8, 3 if st == "focus" else 2)
		t.set_stylebox(st, "Button", sb)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.38))
	t.set_stylebox("slider", "HSlider", box(Color(0.25, 0.17, 0.1), Color(0.4, 0.27, 0.12), 4, 1))
	t.set_stylebox("grabber_area", "HSlider", box(ACCENT, ACCENT, 4, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 4, 0))
	_theme = t
	return t


static func label(text: String, size: int = 20, color: Color = INK, wrap: bool = false) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(22, int(size * 1.2)))
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 200
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, min_w: float = 0.0) -> Button:
	var b: Button = Button.new()
	b.add_theme_font_size_override("font_size", 24)
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(min_w, 52)
	b.focus_entered.connect(sfx.bind("ui_select"))
	return b


static func clear(n: Node) -> void:
	for c: Node in n.get_children():
		n.remove_child(c)
		c.queue_free()


static func vbox(sep: int = 6) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func scroll(content: Control) -> ScrollContainer:
	var s: ScrollContainer = ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func bar(cur: float, mx: float, color: Color, w: float = 160.0) -> ProgressBar:
	var p: ProgressBar = ProgressBar.new()
	p.max_value = maxf(1.0, mx)
	p.value = cur
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, 12)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_theme_stylebox_override("background", box(Color(0.1, 0.07, 0.05), Color(0.3, 0.2, 0.1), 4, 1))
	p.custom_minimum_size.y = 18
	p.add_theme_stylebox_override("fill", box(color, color, 4, 0))
	return p


static func fmt_time(sec: float) -> String:
	var s: int = int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


static func item_blurb(id: String) -> String:
	var it: Dictionary = DB.item(id)
	var parts: Array = []
	if it.has("desc"):
		parts.append(str(it.desc))
	if it.has("stats"):
		var st: Array = []
		for k: String in it.stats:
			st.append("%s %+d" % [k.to_upper(), int(it.stats[k])])
		parts.append(", ".join(st))
	if it.has("price"):
		parts.append("%dg" % int(it.price))
	return "  ".join(parts)
