class_name SettingsMenu
extends MenuScreen
## Settings: graphics preset, resolution/fullscreen/vsync, FOV, sensitivity, volumes, key rebinding.
## All values live in `Settings` (ConfigFile). Display mode / resolution / key bindings are applied here
## (Settings.apply() does not cover them) via the static apply_display() / apply_bindings().

signal closed

const RESOLUTIONS: PackedStringArray = ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const BIND_ACTIONS: Array[Array] = [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["jump", "Jump"], ["crouch", "Crouch"], ["sprint", "Sprint"], ["fire", "Fire"], ["aim", "Aim"], ["reload", "Reload"],
	["use", "Use"], ["weapon_1", "Weapon 1"], ["weapon_2", "Weapon 2"], ["weapon_3", "Weapon 3"], ["weapon_4", "Weapon 4"],
	["weapon_5", "Weapon 5"], ["next_weapon", "Next weapon"], ["prev_weapon", "Previous weapon"], ["shoulder_swap", "Swap shoulder"],
	["map", "Map"], ["pause", "Pause"],
]

var _quality: OptionButton
var _res: OptionButton
var _full: CheckBox
var _vsync: CheckBox
var _fov: HSlider
var _fov_val: Label
var _sens: HSlider
var _sens_val: Label
var _invert: CheckBox
var _vols: Dictionary = {}
var _bind_btns: Dictionary = {}
var _tabs: TabContainer
var _listening: String = ""
var _building: bool = false


func _init() -> void:
	super()
	dim = 0.75


func build() -> void:
	panel.custom_minimum_size = Vector2(760, 560)
	_building = true
	heading("SETTINGS", 36)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.focus_mode = Control.FOCUS_ALL
	body.add_child(_tabs)

	var g: VBoxContainer = _tab("Graphics")
	_quality = OptionButton.new()
	for n: String in Settings.QUALITY_NAMES:
		_quality.add_item(n)
	_quality.item_selected.connect(func(i: int) -> void: Settings.quality = i)
	_row(g, "Quality preset", _quality)
	_res = OptionButton.new()
	for r: String in RESOLUTIONS:
		_res.add_item(r)
	_res.item_selected.connect(func(i: int) -> void:
		UIPrefs.set_pref("display", "resolution", RESOLUTIONS[i])
		apply_display())
	_row(g, "Resolution", _res)
	_full = CheckBox.new()
	_full.toggled.connect(func(on: bool) -> void:
		Settings.set_value("graphics", "fullscreen", on, false)
		apply_display())
	_row(g, "Fullscreen", _full)
	_vsync = CheckBox.new()
	_vsync.toggled.connect(func(on: bool) -> void: Settings.set_value("graphics", "vsync", on))
	_row(g, "VSync", _vsync)
	_fov = HSlider.new()
	_fov.min_value = 50
	_fov.max_value = 110
	_fov.step = 1
	_fov_val = UITheme.label("", 20, UITheme.ACCENT)
	_fov.value_changed.connect(func(v: float) -> void:
		_fov_val.text = "%d" % int(v)
		if not _building:
			Settings.set_value("graphics", "fov", v, false))
	_row(g, "Field of view", _slider_box(_fov, _fov_val))

	var c: VBoxContainer = _tab("Controls")
	_sens = HSlider.new()
	_sens.min_value = 0.5
	_sens.max_value = 10.0
	_sens.step = 0.1
	_sens_val = UITheme.label("", 20, UITheme.ACCENT)
	_sens.value_changed.connect(func(v: float) -> void:
		_sens_val.text = "%.1f" % v
		if not _building:
			Settings.mouse_sensitivity = v * 0.001)
	_row(c, "Mouse sensitivity", _slider_box(_sens, _sens_val))
	_invert = CheckBox.new()
	_invert.toggled.connect(func(on: bool) -> void: Settings.set_value("input", "invert_y", on, false))
	_row(c, "Invert Y", _invert)

	var a: VBoxContainer = _tab("Audio")
	for pair: Array in [["master", "Master volume"], ["music", "Music volume"], ["sfx", "Effects volume"]]:
		var s: HSlider = HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		var vl: Label = UITheme.label("", 20, UITheme.ACCENT)
		var key: String = pair[0]
		s.value_changed.connect(func(v: float) -> void:
			vl.text = "%d%%" % int(round(v * 100.0))
			if not _building:
				Settings.set_value("audio", key, v))
		_vols[key] = s
		_row(a, pair[1], _slider_box(s, vl))

	var k: VBoxContainer = _tab("Key bindings")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	k.add_child(scroll)
	var kv: VBoxContainer = VBoxContainer.new()
	kv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kv.add_theme_constant_override("separation", 6)
	scroll.add_child(kv)
	for pair: Array in BIND_ACTIONS:
		var act: String = pair[0]
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(220, 36)
		b.pressed.connect(func() -> void: _begin_listen(act))
		_bind_btns[act] = b
		_row(kv, pair[1], b)
	var reset: Button = UITheme.button("Reset bindings", _reset_bindings, 220)
	k.add_child(reset)

	var done: Button = UITheme.button("Done", _on_done)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(done)
	set_focus_target(_quality)
	back_requested.connect(_on_done)
	_building = false


func _tab(title: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = title
	v.add_theme_constant_override("separation", 14)
	_tabs.add_child(v)
	return v


func _row(parent: Control, text: String, ctl: Control) -> void:
	var h: HBoxContainer = HBoxContainer.new()
	var l: Label = UITheme.label(text, 20)
	l.custom_minimum_size = Vector2(240, 0)
	h.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if ctl is HSlider or ctl is HBoxContainer else Control.SIZE_SHRINK_BEGIN
	h.add_child(ctl)
	parent.add_child(h)


func _slider_box(s: HSlider, val: Label) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(260, 24)
	val.custom_minimum_size = Vector2(60, 0)
	h.add_child(s)
	h.add_child(val)
	return h


func refresh() -> void:
	_building = true
	_listening = ""
	_quality.select(Settings.quality)
	var res: String = str(UIPrefs.get_pref("display", "resolution"))
	_res.select(maxi(RESOLUTIONS.find(res), 2))
	_full.set_pressed_no_signal(bool(Settings.get_value("graphics", "fullscreen")))
	_vsync.set_pressed_no_signal(bool(Settings.get_value("graphics", "vsync")))
	_fov.value = float(Settings.get_value("graphics", "fov"))
	_fov_val.text = "%d" % int(_fov.value)
	_sens.value = Settings.mouse_sensitivity * 1000.0
	_sens_val.text = "%.1f" % _sens.value
	_invert.set_pressed_no_signal(bool(Settings.get_value("input", "invert_y")))
	for key: String in _vols:
		var s: HSlider = _vols[key]
		s.value = float(Settings.get_value("audio", key))
		(s.get_parent().get_child(1) as Label).text = "%d%%" % int(round(s.value * 100.0))
	_refresh_bindings()
	_tabs.current_tab = 0
	_building = false


func _on_done() -> void:
	if _listening != "":
		_listening = ""
		_refresh_bindings()
		return
	Settings.save()
	closed.emit()


# ───────────── key rebinding ─────────────
func _begin_listen(action: String) -> void:
	_listening = action
	_refresh_bindings()
	(_bind_btns[action] as Button).text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _listening == "" or not visible:
		return
	var code: String = ""
	if event is InputEventKey and event.pressed and not event.echo:
		var k: InputEventKey = event
		if k.physical_keycode == KEY_ESCAPE:
			_listening = ""
			_refresh_bindings()
			get_viewport().set_input_as_handled()
			return
		code = "k:%d" % int(k.physical_keycode)
	elif event is InputEventMouseButton and event.pressed:
		code = "m:%d" % int((event as InputEventMouseButton).button_index)
	if code == "":
		return
	get_viewport().set_input_as_handled()
	UIPrefs.set_pref("bindings", _listening, code)
	apply_bindings()
	_listening = ""
	_refresh_bindings()


func _reset_bindings() -> void:
	for pair: Array in BIND_ACTIONS:
		UIPrefs.set_pref("bindings", pair[0], "")
	InputMap.load_from_project_settings()
	_listening = ""
	_refresh_bindings()


func _refresh_bindings() -> void:
	for act: String in _bind_btns:
		(_bind_btns[act] as Button).text = binding_text(act)


static func binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "(unbound)"
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical((ev as InputEventKey).physical_keycode)) if DisplayServer.get_name() != "headless" else str((ev as InputEventKey).physical_keycode)
		if ev is InputEventMouseButton:
			return "Mouse %d" % int((ev as InputEventMouseButton).button_index)
	return "(unbound)"


## Re-apply saved overrides on top of the InputMap (keyboard/mouse events are replaced; joypad kept).
static func apply_bindings() -> void:
	for pair: Array in BIND_ACTIONS:
		var act: String = pair[0]
		var v: Variant = UIPrefs.get_pref("bindings", act)
		if v == null or str(v) == "" or not InputMap.has_action(act):
			continue
		var parts: PackedStringArray = str(v).split(":")
		if parts.size() != 2:
			continue
		for ev: InputEvent in InputMap.action_get_events(act):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(act, ev)
		if parts[0] == "k":
			var e: InputEventKey = InputEventKey.new()
			e.physical_keycode = int(parts[1]) as Key
			InputMap.action_add_event(act, e)
		else:
			var m: InputEventMouseButton = InputEventMouseButton.new()
			m.button_index = int(parts[1]) as MouseButton
			InputMap.action_add_event(act, m)


## Window mode + size from Settings (no-op headless).
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full: bool = bool(Settings.get_value("graphics", "fullscreen"))
	if full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var r: Variant = UIPrefs.get_pref("display", "resolution")
	if r != null and "x" in str(r):
		var wh: PackedStringArray = str(r).split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
