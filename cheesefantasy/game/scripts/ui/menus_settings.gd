class_name SettingsPanel
extends RefCounted
## Settings controls shared by the pause menu and the title screen. build() returns a Control bound to the Settings autoload.

const SLIDERS: Array = [["master", "Master volume", 0.0, 1.0, 0.05], ["music", "Music", 0.0, 1.0, 0.05], ["sfx", "Sound effects", 0.0, 1.0, 0.05],
	["text_speed", "Text speed (0 = instant)", 0.0, 120.0, 5.0], ["battle_speed", "Battle speed", 0.5, 3.0, 0.25], ["cam_sensitivity", "Camera sensitivity", 0.2, 3.0, 0.1]]
const TOGGLES: Array = [["fullscreen", "Fullscreen"], ["vsync", "VSync"], ["invert_cam", "Invert camera"]]
const QUALITY: Array = ["Low", "Medium", "High", "Ultra"]


static func build() -> Control:
	var st: Node = MenuStyle.auto("Settings")
	var v: VBoxContainer = MenuStyle.vbox(8)
	v.add_child(MenuStyle.label("Settings", 26, MenuStyle.GOLD))
	if st == null:
		v.add_child(MenuStyle.label("Settings unavailable."))
		return v
	for d: Array in SLIDERS:
		var row: HBoxContainer = MenuStyle.hbox(12)
		var l: Label = MenuStyle.label(str(d[1]), 20)
		l.custom_minimum_size.x = 280
		row.add_child(l)
		var s: HSlider = HSlider.new()
		s.min_value = d[2]
		s.max_value = d[3]
		s.step = d[4]
		s.value = float(st.get_value(d[0]))
		s.custom_minimum_size = Vector2(320, 30)
		s.focus_mode = Control.FOCUS_ALL
		var val: Label = MenuStyle.label("%.2f" % s.value, 18, MenuStyle.DIM)
		s.value_changed.connect(func(x: float) -> void:
			st.set_value(d[0], x)
			val.text = "%.2f" % x
			if d[0] != "master" or true:
				MenuStyle.sfx("ui_select"))
		row.add_child(s)
		row.add_child(val)
		v.add_child(row)
	for d: Array in TOGGLES:
		var cb: CheckButton = CheckButton.new()
		cb.text = str(d[1])
		cb.button_pressed = bool(st.get_value(d[0]))
		cb.toggled.connect(func(on: bool) -> void:
			st.set_value(d[0], on)
			MenuStyle.sfx("ui_confirm"))
		v.add_child(cb)
	var qb: Button = MenuStyle.button("Quality: %s" % QUALITY[clampi(int(st.get_value("quality")), 0, 3)])
	qb.pressed.connect(func() -> void:
		var q: int = (int(st.get_value("quality")) + 1) % 4
		st.set_value("quality", q)
		qb.text = "Quality: %s" % QUALITY[q]
		MenuStyle.sfx("ui_confirm"))
	v.add_child(qb)
	return MenuStyle.scroll(v)
