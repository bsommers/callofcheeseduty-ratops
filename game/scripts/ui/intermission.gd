class_name Intermission
extends MenuScreen
## Level-complete card: kills / items / secrets / time vs par with count-up tally and bonus.

var _rows: Dictionary = {}
var _bonus: Label
var _total: Label
var _title: Label
var _btn: Button
var _tween: Tween


func build() -> void:
	_title = UITheme.label("", 40, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_title)
	body.add_child(UITheme.label("LEVEL COMPLETE", 18, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for k: String in ["Kills", "Items", "Secrets", "Time", "Par"]:
		grid.add_child(UITheme.label(k, 26, UITheme.TEXT_DIM))
		var v: Label = UITheme.label("-", 26, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(v)
		_rows[k] = v
	_bonus = UITheme.label("", 24, UITheme.OK, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_bonus)
	_total = UITheme.label("", 30, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_total)
	_btn = UITheme.button("Continue", _on_continue)
	body.add_child(_btn)
	set_focus_target(_btn)
	panel.custom_minimum_size = Vector2(520, 0)


func refresh() -> void:
	var st: Dictionary = Game.stats
	_title.text = Defs.level_name(Game.level_id)
	var par: float = float(st.get("par", 0))
	var time: float = float(st.get("time", 0.0))
	_rows["Par"].text = UITheme.fmt_time(par)
	_rows["Time"].text = UITheme.fmt_time(0.0)
	_rows["Time"].add_theme_color_override("font_color", UITheme.OK if time <= par else UITheme.TEXT)
	for k: String in ["Kills", "Items", "Secrets"]:
		_rows[k].text = "0%"
	_bonus.text = ""
	_total.text = ""
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var ratios: Dictionary = {
		"Kills": _pct(st, "kills", "kills_total"),
		"Items": _pct(st, "treasure", "treasure_total"),
		"Secrets": _pct(st, "secrets", "secrets_total"),
	}
	for k: String in ["Kills", "Items", "Secrets"]:
		var lbl: Label = _rows[k]
		var target: int = int(ratios[k])
		_tween.tween_method(func(v: float) -> void: lbl.text = "%d%%" % int(v), 0.0, float(target), 0.5)
		_tween.tween_callback(func() -> void: UITheme.ui_sfx("tally_tick"))
	var tl: Label = _rows["Time"]
	_tween.tween_method(func(v: float) -> void: tl.text = UITheme.fmt_time(v), 0.0, time, 0.6)
	_tween.tween_callback(func() -> void:
		_bonus.text = "Bonus  +%d" % int(st.get("bonus", 0))
		_total.text = "Score  %d" % Game.score
		UITheme.ui_sfx("tally_tick"))


static func _pct(st: Dictionary, a: String, b: String) -> int:
	var tot: int = int(st.get(b, 0))
	return 100 if tot <= 0 else int(round(100.0 * float(st.get(a, 0)) / float(tot)))


func _on_continue() -> void:
	UITheme.ui_sfx("menu_select")
	Game.next_level()


func _unhandled_input(_event: InputEvent) -> void:
	pass
