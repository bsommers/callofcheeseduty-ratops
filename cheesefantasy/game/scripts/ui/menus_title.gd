class_name TitleMenu
extends Control
## Title screen: animated logo over a warm gradient, New Game / Continue / Settings / Quit.
## Signals: new_game_requested, continue_requested(slot). The owner of main.tscn connects them (and calls GameState.new_game()).
## Music id "title" is started on ready.

signal new_game_requested
signal continue_requested(slot: int)

var _logo: Label
var _menu: VBoxContainer
var _settings_box: PanelContainer
var _t: float = 0.0
var _slot_with_save: int = -1


func _ready() -> void:
	theme = MenuStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: TextureRect = TextureRect.new()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.78, 0.35), Color(0.95, 0.5, 0.2), Color(0.25, 0.12, 0.08)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(bg)
	var col: VBoxContainer = MenuStyle.vbox(10)
	col.set_anchors_preset(Control.PRESET_CENTER)
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.12
	col.anchor_bottom = 0.12
	col.offset_left = -300
	col.offset_right = 300
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(col)
	_logo = MenuStyle.label("CHEESE FANTASY", 72, Color(1, 0.95, 0.7))
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logo.add_theme_color_override("font_outline_color", Color(0.35, 0.15, 0.03))
	_logo.add_theme_constant_override("outline_size", 14)
	_logo.pivot_offset = Vector2(300, 40)
	col.add_child(_logo)
	var sub: Label = MenuStyle.label("The Last Wheel", 32, Color(1, 0.88, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color(0.35, 0.15, 0.03))
	sub.add_theme_constant_override("outline_size", 8)
	col.add_child(sub)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 150
	col.add_child(spacer)
	_menu = MenuStyle.vbox(8)
	col.add_child(_menu)
	_build_menu()
	var ver: Label = MenuStyle.label("v" + str(ProjectSettings.get_setting("application/config/version", "0.1")), 16, Color(0.2, 0.1, 0.05))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-120, -34)
	add_child(ver)
	var a: Node = MenuStyle.auto("Audio")
	if a != null:
		a.play_music("title")
	_focus_first.call_deferred()


func _build_menu() -> void:
	MenuStyle.clear(_menu)
	var gs: Node = MenuStyle.auto("GameState")
	_slot_with_save = -1
	var newest: String = ""
	for s: int in GameMenus.SLOTS:
		if gs != null and gs.has_save(s):
			var info: Dictionary = gs.save_info(s)
			if str(info.saved_at) >= newest:
				newest = str(info.saved_at)
				_slot_with_save = s
	var items: Array = []
	if _slot_with_save >= 0:
		items.append(["Continue", func() -> void:
			MenuStyle.sfx("ui_confirm")
			continue_requested.emit(_slot_with_save)])
	items.append(["New Game", func() -> void:
		MenuStyle.sfx("ui_confirm")
		new_game_requested.emit()])
	items.append(["Settings", _toggle_settings])
	items.append(["Quit", func() -> void: get_tree().quit()])
	for it: Array in items:
		var b: Button = MenuStyle.button(str(it[0]))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 26)
		b.custom_minimum_size = Vector2(320, 52)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(it[1])
		_menu.add_child(b)


func _toggle_settings() -> void:
	MenuStyle.sfx("ui_open")
	if _settings_box != null:
		_settings_box.queue_free()
		_settings_box = null
		_menu.visible = true
		_focus_first()
		return
	_menu.visible = false
	_settings_box = PanelContainer.new()
	var v: VBoxContainer = MenuStyle.vbox(8)
	var body: Control = SettingsPanel.build()
	body.custom_minimum_size = Vector2(760, 380)
	v.add_child(body)
	var back: Button = MenuStyle.button("Back")
	back.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back.pressed.connect(_toggle_settings)
	v.add_child(back)
	_settings_box.add_child(v)
	_menu.get_parent().add_child(_settings_box)
	for c: Node in _settings_box.find_children("*", "Slider", true, false):
		_focus.call_deferred(c)
		break


func _focus_first() -> void:
	for c: Node in _menu.get_children():
		(c as Control).grab_focus()
		return


func _unhandled_input(e: InputEvent) -> void:
	if _settings_box != null and e.is_action_pressed("ui_cancel"):
		_toggle_settings()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_logo.scale = Vector2.ONE * (1.0 + 0.025 * sin(_t * 1.6))
	_logo.rotation = 0.015 * sin(_t * 0.9)


func _focus(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree():
		c.grab_focus()
