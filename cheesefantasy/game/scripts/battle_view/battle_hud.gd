class_name BattleHud
extends CanvasLayer
## Battle UI built in code (owner battle-presentation): turn-order bar, Fondue Gauge + flavor chain, party panel
## (HP/MP bars, status icons, active highlight), command menu with Skill/Item/Summon/target submenus, banner,
## enemy nameplates, letterbox + summon name card, screen flash, victory / level-up and defeat screens.
## The scene drives it: open_menu(...) then `await chosen` -> {type, id, target_type} or {} on back at root.

signal chosen(choice: Dictionary)
signal target_chosen(uid: String)        ## "" = cancelled
signal target_hovered(uid: String)
signal screen_closed

const GOLD: Color = Color(1.0, 0.82, 0.3)
const INK: Color = Color(0.13, 0.09, 0.06, 0.88)
const STATUS_COL: Dictionary = {
	"melted": Color(1.0, 0.5, 0.15), "frozen": Color(0.5, 0.85, 1.0), "chilled": Color(0.65, 0.8, 1.0),
	"aerated": Color(0.85, 1.0, 0.65), "rinded": Color(0.8, 0.55, 0.25), "moldy": Color(0.3, 0.75, 0.6),
	"sated": Color(0.55, 1.0, 0.5), "spicy": Color(1.0, 0.35, 0.3), "stinky": Color(0.65, 0.7, 0.25),
	"taunting": Color(1.0, 0.7, 0.9),
}
const ELEM_GLYPH: Dictionary = {"fire": "F", "ice": "I", "wind": "W", "earth": "E", "rot": "R", "light": "L", "shade": "S", "none": ""}

var root: Control
var _order_box: HBoxContainer
var _gauge_bar: ProgressBar
var _gauge_label: Label
var _chain_label: Label
var _party_box: VBoxContainer
var _party_rows: Dictionary = {}          ## uid -> {panel, hp, mp, hpl, mpl, status, name}
var _menu_panel: PanelContainer
var _menu_box: VBoxContainer
var _sub_panel: PanelContainer
var _sub_box: VBoxContainer
var _desc: Label
var _banner: Label
var _banner_tw: Tween
var _message: Label
var _plates: Dictionary = {}              ## uid -> {ctrl, bar, label}
var _letter_top: ColorRect
var _letter_bot: ColorRect
var _flash: ColorRect
var _vignette: ColorRect
var _card: Control
var _screen: PanelContainer
var _commands: Array = []
var _skills: Array = []
var _items: Array = []
var _summons: Array = []
var _level: String = "root"


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_top()
	_build_party()
	_build_menu()
	_build_overlays()


## Anchor a control to (ax, ay) of the screen with a pixel offset + size (size 0 = shrink to content).
func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + h
	c.custom_minimum_size = Vector2(w, h)


# ------------------------------------------------------------------ theme
func _box(bg: Color, border: Color, radius: int = 10, bw: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


func _make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", _box(INK, Color(GOLD, 0.8)))
	t.set_stylebox("normal", "Button", _box(Color(0.25, 0.17, 0.1, 0.9), Color(0.5, 0.38, 0.2), 8, 1))
	t.set_stylebox("hover", "Button", _box(Color(0.45, 0.3, 0.12, 0.95), GOLD, 8, 2))
	t.set_stylebox("focus", "Button", _box(Color(0.55, 0.38, 0.12, 0.95), Color(1, 0.95, 0.6), 8, 3))
	t.set_stylebox("pressed", "Button", _box(Color(0.7, 0.5, 0.15, 1.0), Color(1, 0.95, 0.6), 8, 3))
	t.set_stylebox("disabled", "Button", _box(Color(0.15, 0.12, 0.1, 0.7), Color(0.3, 0.25, 0.2), 8, 1))
	t.set_color("font_color", "Button", Color(1, 0.96, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.45))
	t.set_color("font_focus_color", "Button", Color(1, 1, 0.9))
	t.set_color("font_color", "Label", Color(1, 0.96, 0.88))
	t.set_color("font_outline_color", "Label", Color(0.1, 0.05, 0.0))
	t.set_constant("outline_size", "Label", 4)
	var bg: StyleBoxFlat = _box(Color(0.08, 0.06, 0.05, 0.9), Color(0, 0, 0, 0.6), 5, 1)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	t.set_stylebox("background", "ProgressBar", bg)
	return t


func _bar(c: Color, h: float) -> ProgressBar:
	var b: ProgressBar = ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	var f: StyleBoxFlat = StyleBoxFlat.new()
	f.bg_color = c
	f.set_corner_radius_all(5)
	f.border_color = c.lightened(0.4)
	f.border_width_top = 2
	b.add_theme_stylebox_override("fill", f)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _label(text: String, size: int = 22, col: Color = Color(1, 0.96, 0.88)) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


# ------------------------------------------------------------------ top: turn order + gauge + banner
func _build_top() -> void:
	var tp: PanelContainer = PanelContainer.new()
	tp.position = Vector2(24, 20)
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(_label("TURN", 16, GOLD))
	_order_box = HBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 6)
	hb.add_child(_order_box)
	tp.add_child(hb)
	root.add_child(tp)

	var gp: PanelContainer = PanelContainer.new()
	_place(gp, 1, 0, -24 - 420, 20, 420, 0)
	var vb: VBoxContainer = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_label("FONDUE GAUGE", 18, GOLD))
	_gauge_label = _label("0 / 100", 18)
	_gauge_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gauge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_gauge_label)
	vb.add_child(row)
	_gauge_bar = _bar(Color(1.0, 0.78, 0.2), 22)
	_gauge_bar.max_value = 100
	vb.add_child(_gauge_bar)
	_chain_label = _label("", 18, Color(1, 0.7, 0.4))
	vb.add_child(_chain_label)
	gp.add_child(vb)
	root.add_child(gp)

	_banner = _label("", 40, Color(1, 0.95, 0.75))
	_place(_banner, 0.5, 0, -500, 96, 1000, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_message = _label("", 24)
	_place(_message, 0.5, 0, -600, 156, 1200, 0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message)


func set_turn_order(entries: Array, current: String) -> void:
	for c: Node in _order_box.get_children():
		c.queue_free()
	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var chip: PanelContainer = PanelContainer.new()
		var party: bool = e.get("side", "") == "party"
		var col: Color = Color(0.25, 0.45, 0.8, 0.95) if party else Color(0.7, 0.22, 0.2, 0.95)
		var hl: bool = i == 0 and str(e.get("uid", "")) == current
		chip.add_theme_stylebox_override("panel", _box(col if not hl else col.lightened(0.25), GOLD if hl else col.lightened(0.4), 14, 3 if hl else 1))
		var nm: String = str(e.get("name", "?"))
		var l: Label = _label(nm.substr(0, 7) if i > 0 else nm, 18 if i > 0 else 22)
		chip.add_child(l)
		if i > 0:
			chip.modulate.a = clampf(1.0 - 0.08 * i, 0.5, 1.0)
		_order_box.add_child(chip)


func set_gauge(v: int, chain_text: String = "") -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_gauge_bar, "value", float(v), 0.4).set_trans(Tween.TRANS_CUBIC)
	_gauge_label.text = "%d / 100%s" % [v, "  READY!" if v >= 100 else ""]
	var f: StyleBoxFlat = _gauge_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if f != null:
		f.bg_color = Color(1.0, 0.92, 0.45) if v >= 100 else Color(1.0, 0.72, 0.18)
	if v >= 100:
		var p: Tween = create_tween().set_loops(3)
		p.tween_property(_gauge_bar, "modulate", Color(1.6, 1.4, 0.9), 0.25)
		p.tween_property(_gauge_bar, "modulate", Color.WHITE, 0.25)
	if chain_text != "":
		_chain_label.text = chain_text


func banner(text: String, col: Color = Color(1, 0.95, 0.75), hold: float = 1.0) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(1, 1)
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.3)


func message(text: String) -> void:
	_message.text = text


# ------------------------------------------------------------------ party panel
func _build_party() -> void:
	var pp: PanelContainer = PanelContainer.new()
	_place(pp, 1, 1, -24 - 760, -24 - 250, 760, 250)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 4)
	pp.add_child(_party_box)
	root.add_child(pp)


func add_party_member(uid: String, name: String, element: String) -> void:
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0), 8, 0))
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var nl: Label = _label(name, 24)
	nl.custom_minimum_size = Vector2(170, 0)
	var ec: Color = BattleVfx.COL.get(element, Color.WHITE)
	nl.add_theme_color_override("font_color", ec.lightened(0.35))
	hb.add_child(nl)
	var hpv: VBoxContainer = VBoxContainer.new()
	hpv.custom_minimum_size = Vector2(230, 0)
	hpv.add_theme_constant_override("separation", 0)
	var hpl: Label = _label("HP", 18)
	var hp: ProgressBar = _bar(Color(0.35, 0.85, 0.35), 12)
	hpv.add_child(hpl)
	hpv.add_child(hp)
	hb.add_child(hpv)
	var mpv: VBoxContainer = VBoxContainer.new()
	mpv.custom_minimum_size = Vector2(150, 0)
	mpv.add_theme_constant_override("separation", 0)
	var mpl: Label = _label("MP", 18)
	var mp: ProgressBar = _bar(Color(0.35, 0.6, 1.0), 12)
	mpv.add_child(mpl)
	mpv.add_child(mp)
	hb.add_child(mpv)
	var st: HBoxContainer = HBoxContainer.new()
	st.add_theme_constant_override("separation", 3)
	st.custom_minimum_size = Vector2(120, 0)
	hb.add_child(st)
	row.add_child(hb)
	_party_box.add_child(row)
	_party_rows[uid] = {"panel": row, "hp": hp, "mp": mp, "hpl": hpl, "mpl": mpl, "status": st, "name": nl}


func update_member(a: Dictionary) -> void:
	var uid: String = str(a.get("uid", ""))
	if not _party_rows.has(uid):
		return
	var r: Dictionary = _party_rows[uid]
	var hp: ProgressBar = r.hp
	var mp: ProgressBar = r.mp
	hp.max_value = maxf(1.0, float(a.get("max_hp", 1)))
	mp.max_value = maxf(1.0, float(a.get("max_mp", 1)))
	create_tween().tween_property(hp, "value", float(a.get("hp", 0)), 0.35)
	create_tween().tween_property(mp, "value", float(a.get("mp", 0)), 0.35)
	var frac: float = float(a.get("hp", 0)) / hp.max_value
	var fs: StyleBoxFlat = hp.get_theme_stylebox("fill") as StyleBoxFlat
	fs.bg_color = Color(0.35, 0.85, 0.35) if frac > 0.5 else (Color(0.95, 0.8, 0.25) if frac > 0.25 else Color(0.95, 0.3, 0.25))
	(r.hpl as Label).text = "HP %d/%d" % [int(a.get("hp", 0)), int(a.get("max_hp", 0))]
	(r.mpl as Label).text = "MP %d/%d" % [int(a.get("mp", 0)), int(a.get("max_mp", 0))]
	(r.name as Label).modulate = Color(0.55, 0.45, 0.45) if not bool(a.get("alive", true)) else Color.WHITE
	set_status_icons(r.status as HBoxContainer, a.get("statuses", {}) as Dictionary)


func set_status_icons(box: HBoxContainer, statuses: Dictionary) -> void:
	for c: Node in box.get_children():
		c.queue_free()
	for sid: String in statuses:
		var chip: PanelContainer = PanelContainer.new()
		var c: Color = STATUS_COL.get(sid, Color(0.8, 0.8, 0.8))
		var sb: StyleBoxFlat = _box(c.darkened(0.35), c.lightened(0.3), 6, 1)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		sb.shadow_size = 0
		chip.add_theme_stylebox_override("panel", sb)
		var turns: Variant = statuses[sid]
		var t: int = int(turns.get("turns", 0)) if turns is Dictionary else int(turns)
		chip.add_child(_label("%s%s" % [sid.substr(0, 3).capitalize(), str(t) if t > 0 else ""], 15))
		chip.tooltip_text = str(Data.STATUSES.get(sid, {}).get("desc", sid)) if Data != null else sid
		box.add_child(chip)


func highlight_member(uid: String) -> void:
	for k: String in _party_rows:
		var p: PanelContainer = _party_rows[k].panel
		var on: bool = k == uid
		p.add_theme_stylebox_override("panel", _box(Color(0.6, 0.42, 0.12, 0.45) if on else Color(0, 0, 0, 0), GOLD if on else Color(0, 0, 0, 0), 8, 2 if on else 0))


# ------------------------------------------------------------------ enemy nameplates (projected from 3D each frame)
func add_plate(uid: String, name: String) -> void:
	var c: VBoxContainer = VBoxContainer.new()
	c.custom_minimum_size = Vector2(150, 0)
	c.add_theme_constant_override("separation", 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = _label(name, 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	var b: ProgressBar = _bar(Color(0.9, 0.3, 0.25), 8)
	b.max_value = 1.0
	b.value = 1.0
	c.add_child(b)
	var st: HBoxContainer = HBoxContainer.new()
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(st)
	root.add_child(c)
	_plates[uid] = {"ctrl": c, "bar": b, "label": l, "status": st}


func update_plate(uid: String, screen_pos: Vector2, visible_: bool, hp_frac: float, statuses: Dictionary) -> void:
	if not _plates.has(uid):
		return
	var p: Dictionary = _plates[uid]
	var c: Control = p.ctrl
	c.visible = visible_
	c.position = screen_pos - Vector2(75, 40)
	var b: ProgressBar = p.bar
	if absf(b.value - hp_frac) > 0.001:
		create_tween().tween_property(b, "value", hp_frac, 0.3)
	if statuses.hash() != int(c.get_meta("sh", 0)):
		c.set_meta("sh", statuses.hash())
		set_status_icons(p.status as HBoxContainer, statuses)


func show_plates(v: bool) -> void:
	for k: String in _plates:
		(_plates[k].ctrl as Control).modulate.a = 1.0 if v else 0.0


# ------------------------------------------------------------------ command menu
func _build_menu() -> void:
	_menu_panel = PanelContainer.new()
	_place(_menu_panel, 0, 1, 24, -24 - 380, 230, 380)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 4)
	_menu_panel.add_child(_menu_box)
	_menu_panel.visible = false
	root.add_child(_menu_panel)
	_sub_panel = PanelContainer.new()
	_place(_sub_panel, 0, 1, 270, -24 - 380, 440, 380)
	var vb: VBoxContainer = VBoxContainer.new()
	var sc: ScrollContainer = ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 290)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sub_box = VBoxContainer.new()
	_sub_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_box.add_theme_constant_override("separation", 3)
	sc.add_child(_sub_box)
	vb.add_child(sc)
	_desc = _label("", 17, Color(0.95, 0.88, 0.7))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(400, 60)
	vb.add_child(_desc)
	_sub_panel.add_child(vb)
	_sub_panel.visible = false
	root.add_child(_sub_panel)


## commands: engine.available_commands(); skills: engine.skill_list(); items: [{id,name,count,target,desc}];
## summons: [{id,name,title,enabled,desc}].
func open_menu(actor_name: String, commands: Array, skills: Array, items: Array, summons: Array) -> void:
	_commands = commands
	_skills = skills
	_items = items
	_summons = summons
	_show_root(actor_name)


func _show_root(actor_name: String = "") -> void:
	_level = "root"
	_sub_panel.visible = false
	_menu_panel.visible = true
	for c: Node in _menu_box.get_children():
		_menu_box.remove_child(c)
		c.queue_free()
	if actor_name != "":
		_menu_panel.set_meta("actor", actor_name)
	var title: Label = _label(str(_menu_panel.get_meta("actor", "")), 22, GOLD)
	_menu_box.add_child(title)
	var first: Button = null
	for c: Dictionary in _commands:
		var b: Button = Button.new()
		b.text = str(c.get("label", c.get("type", "?")))
		b.disabled = not bool(c.get("enabled", true))
		b.tooltip_text = str(c.get("reason", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if c.get("type", "") == "summon" and not b.disabled:
			b.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		var t: String = str(c.get("type", ""))
		b.pressed.connect(func() -> void: _root_pick(t))
		_menu_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first != null:
		first.call_deferred("grab_focus")


func _root_pick(t: String) -> void:
	match t:
		"skill": _show_sub("skill", _skills.map(func(s: Dictionary) -> Dictionary: return {"id": s.id,
			"label": "%s%s" % [s.name, "  %d MP" % int(s.mp) if int(s.mp) > 0 else ""], "enabled": s.get("enabled", true),
			"target": s.get("target", "enemy"), "desc": str(Data.skill(str(s.id)).get("desc", "")), "element": s.get("element", "none")}))
		"item": _show_sub("item", _items.map(func(s: Dictionary) -> Dictionary: return {"id": s.id,
			"label": "%s  x%d" % [s.name, int(s.count)], "enabled": true, "target": s.get("target", "ally"), "desc": s.get("desc", "")}))
		"summon": _show_sub("summon", _summons.map(func(s: Dictionary) -> Dictionary: return {"id": s.id,
			"label": "%s, %s" % [s.name, s.title], "enabled": s.get("enabled", true), "target": s.get("target", "all_enemies"), "desc": s.get("desc", "")}))
		"attack": _emit({"type": "attack", "target_type": "enemy"})
		"cook": _emit({"type": "cook", "target_type": "ally"})
		_: _emit({"type": t, "target_type": "none"})


func _show_sub(kind: String, entries: Array) -> void:
	_level = kind
	_sub_panel.visible = true
	for c: Node in _sub_box.get_children():
		_sub_box.remove_child(c)
		c.queue_free()
	var first: Button = null
	for e: Dictionary in entries:
		var b: Button = Button.new()
		b.text = str(e.label)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(e.enabled)
		var el: String = str(e.get("element", "none"))
		if el != "none" and BattleVfx.COL.has(el) and not b.disabled:
			b.add_theme_color_override("font_color", (BattleVfx.COL[el] as Color).lightened(0.35))
		var d: String = str(e.desc)
		b.focus_entered.connect(func() -> void: _desc.text = d)
		b.mouse_entered.connect(func() -> void: _desc.text = d)
		var choice: Dictionary = {"type": kind, "id": e.id, "target_type": e.target}
		b.pressed.connect(func() -> void: _emit(choice))
		_sub_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first != null:
		first.call_deferred("grab_focus")
	else:
		_desc.text = "Nothing usable."


func _emit(choice: Dictionary) -> void:
	close_menu()
	chosen.emit(choice)


func close_menu() -> void:
	_menu_panel.visible = false
	_sub_panel.visible = false
	_level = "closed"


## Re-open the menu where it was (after a cancelled target pick).
func reopen() -> void:
	_show_root()


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("cancel")):
		return
	if _level == "target":
		_level = "closed"
		_sub_panel.visible = false
		target_chosen.emit("")
		get_viewport().set_input_as_handled()
	elif _level in ["skill", "item", "summon"]:
		_show_root()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ target picker (list mirrors the 3D cursor)
func pick_target(entries: Array, title: String) -> void:
	_level = "target"
	_menu_panel.visible = false
	_sub_panel.visible = true
	for c: Node in _sub_box.get_children():
		_sub_box.remove_child(c)
		c.queue_free()
	_desc.text = title + "   (Esc: back)"
	var first: Button = null
	for e: Dictionary in entries:
		var b: Button = Button.new()
		b.text = str(e.name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var u: String = str(e.uid)
		b.focus_entered.connect(func() -> void: target_hovered.emit(u))
		b.mouse_entered.connect(func() -> void: target_hovered.emit(u))
		b.pressed.connect(func() -> void:
			_level = "closed"
			_sub_panel.visible = false
			target_chosen.emit(u))
		_sub_box.add_child(b)
		if first == null:
			first = b
	if first != null:
		first.call_deferred("grab_focus")


# ------------------------------------------------------------------ overlays: flash, letterbox, name card
func _build_overlays() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs: ShaderMaterial = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = "shader_type canvas_item; uniform float amount = 0.0; uniform vec4 tint : source_color = vec4(0.0,0.0,0.0,1.0);\n" \
		+ "void fragment(){ float d = distance(UV, vec2(0.5)); COLOR = vec4(tint.rgb, smoothstep(0.35, 0.85, d) * amount); }"
	vs.shader = sh
	_vignette.material = vs
	root.add_child(_vignette)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	root.add_child(_flash)
	_letter_top = ColorRect.new()
	_letter_top.color = Color.BLACK
	_letter_top.anchor_right = 1.0
	_letter_top.offset_bottom = 0.0
	_letter_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_letter_top)
	_letter_bot = ColorRect.new()
	_letter_bot.color = Color.BLACK
	_letter_bot.anchor_right = 1.0
	_letter_bot.anchor_top = 1.0
	_letter_bot.anchor_bottom = 1.0
	_letter_bot.offset_top = 0.0
	_letter_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_letter_bot)


func flash(c: Color, strength: float, dur: float = 0.35) -> void:
	_flash.color = Color(c.r, c.g, c.b, clampf(strength, 0.0, 1.0))
	create_tween().tween_property(_flash, "color:a", 0.0, dur)


func vignette(amount: float, tint: Color = Color.BLACK, dur: float = 0.4) -> void:
	var m: ShaderMaterial = _vignette.material as ShaderMaterial
	m.set_shader_parameter("tint", tint)
	var cur: Variant = m.get_shader_parameter("amount")
	var from: float = float(cur) if cur != null else 0.0
	create_tween().tween_method(func(v: float) -> void: m.set_shader_parameter("amount", v), from, amount, dur)


func letterbox(on: bool, dur: float = 0.4) -> void:
	var h: float = 110.0 if on else 0.0
	var tw: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_letter_top, "offset_bottom", h, dur)
	tw.tween_property(_letter_bot, "offset_top", -h, dur)


## Set every normal HUD panel visible/hidden (cinematics hide them).
func set_chrome(v: bool) -> void:
	for c: Node in root.get_children():
		if c is Control and c != _flash and c != _letter_top and c != _letter_bot and c != _vignette and c != _card and c != _screen:
			var ctl: Control = c as Control
			create_tween().tween_property(ctl, "modulate:a", 1.0 if v else 0.0, 0.25)


## Summon name card: slides in a ribbon with big name, title and attack.
func name_card(name: String, title: String, attack: String, col: Color, hold: float = 1.6) -> void:
	if _card != null:
		_card.queue_free()
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	var ribbon: ColorRect = ColorRect.new()
	ribbon.color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.82)
	ribbon.size = Vector2(2400, 230)
	ribbon.position = Vector2(-2600, 150)
	ribbon.rotation = -0.06
	_card.add_child(ribbon)
	var stripe: ColorRect = ColorRect.new()
	stripe.color = col.lightened(0.3)
	stripe.size = Vector2(2400, 8)
	stripe.position = Vector2(0, 0)
	ribbon.add_child(stripe)
	var stripe2: ColorRect = ColorRect.new()
	stripe2.color = col.lightened(0.3)
	stripe2.size = Vector2(2400, 8)
	stripe2.position = Vector2(0, 222)
	ribbon.add_child(stripe2)
	var big: Label = _label(name.to_upper(), 120, Color(1, 1, 1))
	big.add_theme_constant_override("outline_size", 18)
	big.add_theme_color_override("font_outline_color", col.darkened(0.6))
	big.position = Vector2(900, 10)
	ribbon.add_child(big)
	var sub: Label = _label("%s   ~   %s" % [title, attack], 38, col.lightened(0.5))
	sub.position = Vector2(910, 160)
	ribbon.add_child(sub)
	var paws: Label = _label("NINE LIVES SPIRIT", 24, Color(1, 0.95, 0.8, 0.85))
	paws.position = Vector2(915, -2)
	ribbon.add_child(paws)
	var tw: Tween = create_tween()
	tw.tween_property(ribbon, "position:x", -560.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon, "position:x", -500.0, hold)
	tw.tween_property(ribbon, "position:x", 2400.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(_card.queue_free)


# ------------------------------------------------------------------ result screens
## party: [{name, xp, level_from, level_to, stats_gain: {hp:..}}]
func victory_screen(xp: int, gold: int, drops: Array, party: Array) -> void:
	_screen_base("VICTORY!", GOLD)
	var vb: VBoxContainer = _screen.get_child(0) as VBoxContainer
	vb.add_child(_label("+%d XP      +%d gold" % [xp, gold], 30, Color(1, 0.95, 0.75)))
	for p: Dictionary in party:
		var row: HBoxContainer = HBoxContainer.new()
		var nl: Label = _label(str(p.name), 26)
		nl.custom_minimum_size = Vector2(220, 0)
		row.add_child(nl)
		var bar: ProgressBar = _bar(Color(0.5, 0.75, 1.0), 14)
		bar.custom_minimum_size = Vector2(300, 14)
		bar.max_value = 1.0
		bar.value = float(p.get("frac_from", 0.0))
		row.add_child(bar)
		create_tween().tween_property(bar, "value", float(p.get("frac_to", 1.0)), 1.2).set_delay(0.4)
		var lv: Label = _label("  Lv %d" % int(p.get("level_to", 1)), 26)
		row.add_child(lv)
		if int(p.get("level_to", 1)) > int(p.get("level_from", 1)):
			var up: Label = _label("  LEVEL UP!", 28, Color(1, 0.85, 0.3))
			row.add_child(up)
			var tw: Tween = create_tween().set_loops(4)
			tw.tween_property(up, "modulate", Color(1.5, 1.3, 0.8), 0.3)
			tw.tween_property(up, "modulate", Color.WHITE, 0.3)
			var g: Dictionary = p.get("gains", {})
			var gl: Label = _label("     " + "  ".join(g.keys().map(func(k: String) -> String: return "%s +%d" % [k.to_upper(), int(g[k])])), 18, Color(0.8, 1.0, 0.8))
			vb.add_child(row)
			vb.add_child(gl)
			continue
		vb.add_child(row)
	if not drops.is_empty():
		var names: Array = drops.map(func(d: Variant) -> String: return Data.item_name(str(d)))
		vb.add_child(_label("Spoils: " + ", ".join(names), 22, Color(0.9, 1.0, 0.8)))
	_screen_button(vb, "Continue")


func defeat_screen(fled: bool) -> void:
	_screen_base("Got away!" if fled else "The party has fallen...", Color(0.85, 0.85, 1.0) if fled else Color(0.9, 0.4, 0.4))
	var vb: VBoxContainer = _screen.get_child(0) as VBoxContainer
	vb.add_child(_label("" if fled else "The Rot creeps a little further over Curdlewick.", 22))
	_screen_button(vb, "Continue")


func _screen_base(title: String, col: Color) -> void:
	close_menu()
	if _screen != null:
		_screen.queue_free()
	_screen = PanelContainer.new()
	_place(_screen, 0.5, 0.5, -450, -280, 900, 0)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var t: Label = _label(title, 64, col)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 12)
	vb.add_child(t)
	_screen.add_child(vb)
	root.add_child(_screen)
	_screen.modulate.a = 0.0
	_screen.scale = Vector2(0.9, 0.9)
	_screen.pivot_offset = Vector2(450, 200)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_screen, "modulate:a", 1.0, 0.3)
	tw.tween_property(_screen, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _screen_button(vb: VBoxContainer, text: String) -> void:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 50)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: screen_closed.emit())
	vb.add_child(b)
	b.call_deferred("grab_focus")
