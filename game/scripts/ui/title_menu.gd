class_name TitleMenu
extends MenuScreen
## Title screen: emblem, KÄSEKRIEG: RAT OPS, New Game / Settings / Quit, skill selector.

signal settings_requested

var _skill: OptionButton


func _init() -> void:
	super()
	dim = 0.35


func build() -> void:
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.04, 0.06, 0.72), UITheme.PANEL_EDGE, 16, 1, Vector2(56, 36)))
	var em: CheeseEmblem = CheeseEmblem.new()
	em.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(em)
	var ti: Label = UITheme.label("KÄSEKRIEG", 84, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	ti.add_theme_constant_override("outline_size", 8)
	ti.add_theme_color_override("font_outline_color", Color(0.25, 0.14, 0.0))
	body.add_child(ti)
	body.add_child(UITheme.label("R A T   O P S", 30, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(Control.new())
	var start: Button = UITheme.button("New Game", _on_new)
	body.add_child(start)
	_skill = OptionButton.new()
	_skill.custom_minimum_size = Vector2(280, 40)
	for s: Dictionary in Defs.SKILLS:
		_skill.add_item("Skill: %s" % s["name"], int(s["id"]))
	_skill.select(clampi(Settings.skill, 0, Defs.SKILLS.size() - 1))
	_skill.item_selected.connect(func(i: int) -> void: Settings.skill = i)
	body.add_child(_skill)
	body.add_child(UITheme.button("Settings", func() -> void: UITheme.ui_sfx("menu_select"); settings_requested.emit()))
	body.add_child(UITheme.button("Quit", func() -> void: get_tree().quit()))
	set_focus_target(start)


func refresh() -> void:
	_skill.select(clampi(Settings.skill, 0, Defs.SKILLS.size() - 1))


func _on_new() -> void:
	UITheme.ui_sfx("menu_select")
	Game.new_game("", _skill.selected)


func _unhandled_input(_event: InputEvent) -> void:
	pass   # no "back" on the title
