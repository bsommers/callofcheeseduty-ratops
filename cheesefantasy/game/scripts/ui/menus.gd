class_name GameMenus
extends CanvasLayer
## Pause menu: Party (stats + equipment), Items, Bestiary, Summons, Save/Load, Settings.
## Add ONE instance (res://scenes/ui/menus.tscn) under the main scene; it opens on the `menu` action when `enabled`.
## API: open(tab := 0, allow_save := true), close(), toggle(). Signals: opened, closed, quit_to_title.
## Bestiary entries are recorded in GameState flags "seen_<enemy_id>" when Events.battle_finished arrives.

signal opened
signal closed
signal quit_to_title

const DB = preload("res://data/db.gd")
const TABS: Array = ["Party", "Items", "Bestiary", "Summons", "Save / Load", "Settings"]
const SLOTS: Array = [1, 2, 3]
const EQUIP_SLOTS: Array = ["weapon", "armor", "charm"]

var enabled: bool = true
var is_open: bool = false
var allow_save: bool = true
var _prev_pause: bool = false
var _tab: int = 0
var _root: Control
var _tab_row: HBoxContainer
var _page: Control
var _gold: Label
var _hint: Label
var _msg: Label
var _sel_member: String = "fennel"
var _sel_item: String = ""
var _sel_enemy: String = ""


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	var ev: Node = MenuStyle.auto("Events")
	if ev != null and ev.has_signal("battle_finished"):
		ev.battle_finished.connect(_on_battle_finished)


func _build() -> void:
	_root = Control.new()
	_root.theme = MenuStyle.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.04
	panel.anchor_right = 0.96
	panel.anchor_top = 0.04
	panel.anchor_bottom = 0.96
	_root.add_child(panel)
	var v: VBoxContainer = MenuStyle.vbox(8)
	panel.add_child(v)
	var head: HBoxContainer = MenuStyle.hbox(6)
	v.add_child(head)
	_tab_row = MenuStyle.hbox(6)
	_tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_tab_row)
	for i: int in TABS.size():
		var b: Button = MenuStyle.button(TABS[i])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_set_tab.bind(i))
		_tab_row.add_child(b)
	_gold = MenuStyle.label("", 22, MenuStyle.GOLD)
	head.add_child(_gold)
	_page = MarginContainer.new()
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_page)
	_msg = MenuStyle.label("", 18, MenuStyle.GOOD)
	v.add_child(_msg)
	_hint = MenuStyle.label("Arrows/stick: move   Confirm: select   Cancel / Menu: close   Q/E: switch tab", 20, MenuStyle.DIM)
	v.add_child(_hint)


# ------------------------------------------------------------------ open / close
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open(tab: int = 0, p_allow_save: bool = true) -> void:
	if is_open:
		return
	allow_save = p_allow_save
	is_open = true
	_prev_pause = get_tree().paused
	get_tree().paused = true
	visible = true
	MenuStyle.sfx("ui_open")
	_set_tab(tab, false)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = _prev_pause
	MenuStyle.sfx("ui_cancel")
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not is_open:
		if enabled and InputMap.has_action("menu") and e.is_action_pressed("menu") and not get_tree().paused:
			open()
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("ui_cancel") or (InputMap.has_action("menu") and e.is_action_pressed("menu")) \
			or (InputMap.has_action("cancel") and e.is_action_pressed("cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_Q:
			_set_tab((_tab + TABS.size() - 1) % TABS.size())
		elif e.keycode == KEY_E:
			_set_tab((_tab + 1) % TABS.size())


func _set_tab(i: int, sound: bool = true) -> void:
	_tab = i
	if sound:
		MenuStyle.sfx("ui_select")
	_refresh()


func _refresh() -> void:
	var gs: Node = MenuStyle.auto("GameState")
	_gold.text = "%d g" % (int(gs.gold) if gs != null else 0)
	for i: int in _tab_row.get_child_count():
		(_tab_row.get_child(i) as Button).disabled = (i == _tab)
	MenuStyle.clear(_page)
	_msg.text = ""
	var content: Control
	match _tab:
		0: content = _page_party()
		1: content = _page_items()
		2: content = _page_bestiary()
		3: content = _page_summons()
		4: content = _page_saves()
		_: content = _page_settings()
	_page.add_child(content)
	_focus_first.call_deferred(content)


func _focus_first(n: Node) -> void:
	if not is_instance_valid(n) or not n.is_inside_tree():
		return
	for c: Node in n.find_children("*", "BaseButton", true, false):
		if not (c as BaseButton).disabled and c.is_visible_in_tree():
			(c as Control).grab_focus()
			return
	for c: Node in n.find_children("*", "Slider", true, false):
		(c as Control).grab_focus()
		return


func _say(t: String, good: bool = true) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", MenuStyle.GOOD if good else MenuStyle.BAD)


func _two_col(left: Control, right: Control, left_w: float = 320.0) -> HBoxContainer:
	var h: HBoxContainer = MenuStyle.hbox(14)
	left.custom_minimum_size.x = left_w
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(right)
	return h


func _sep_panel(inner: Control) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", MenuStyle.box(Color(0.1, 0.07, 0.05, 0.8), Color(0.35, 0.23, 0.1), 10, 2))
	p.add_child(inner)
	return p


# ------------------------------------------------------------------ party
func _page_party() -> Control:
	var gs: Node = MenuStyle.auto("GameState")
	var left: VBoxContainer = MenuStyle.vbox(6)
	var right: VBoxContainer = MenuStyle.vbox(6)
	if gs == null:
		right.add_child(MenuStyle.label("No game state."))
		return _two_col(left, right)
	var order: Array = gs.active if not gs.active.is_empty() else DB.PARTY_ORDER
	if not _sel_member in gs.party:
		_sel_member = str(order[0])
	for cid: String in order:
		var m: Dictionary = gs.party[cid]
		var st: Dictionary = gs.member_stats(cid)
		var b: Button = MenuStyle.button("%s   Lv %d\nHP %d/%d   MP %d/%d" % [DB.CHARACTERS[cid].name, int(m.level), int(m.hp), int(st.hp), int(m.mp), int(st.mp)])
		b.custom_minimum_size.y = 64
		b.pressed.connect(func() -> void:
			_sel_member = cid
			_refresh())
		if cid == _sel_member:
			b.add_theme_color_override("font_color", MenuStyle.GOLD)
		left.add_child(b)
	var cid2: String = _sel_member
	var ch: Dictionary = DB.CHARACTERS[cid2]
	var m2: Dictionary = gs.party[cid2]
	var st2: Dictionary = gs.member_stats(cid2)
	right.add_child(MenuStyle.label("%s - %s" % [ch.name, ch.get("title", "")], 26, MenuStyle.GOLD))
	right.add_child(MenuStyle.label("%s   Role: %s   Element: %s" % [ch.get("species", ""), ch.get("role", ""), str(DB.ELEMENTS.get(ch.element, {}).get("name", ch.element))], 17, MenuStyle.DIM))
	var nxt: int = DB.xp_for_level(int(m2.level) + 1) if int(m2.level) < DB.MAX_LEVEL else int(m2.xp)
	right.add_child(MenuStyle.label("XP %d / %d" % [int(m2.xp), nxt], 17))
	right.add_child(MenuStyle.bar(float(m2.hp), float(st2.hp), MenuStyle.GOOD, 260))
	right.add_child(MenuStyle.bar(float(m2.mp), float(st2.mp), Color(0.4, 0.6, 0.95), 260))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	for k: String in ["atk", "def", "mag", "res", "spd", "lck"]:
		grid.add_child(MenuStyle.label(k.to_upper(), 18, MenuStyle.DIM))
		grid.add_child(MenuStyle.label(str(int(st2.get(k, 0))), 18))
	right.add_child(grid)
	var portrait: ModelStage = ModelStage.new()
	portrait.custom_minimum_size = Vector2(300, 300)
	portrait.show_model(str(ch.model))
	right.add_child(portrait)
	right.add_child(MenuStyle.label("Equipment", 20, MenuStyle.ACCENT))
	for slot: String in EQUIP_SLOTS:
		var cur: String = str(m2.equip.get(slot, ""))
		var eb: Button = MenuStyle.button("%s: %s" % [slot.capitalize(), DB.item_name(cur) if cur != "" else "(none)"])
		eb.pressed.connect(_equip_menu.bind(cid2, slot))
		right.add_child(eb)
	right.add_child(MenuStyle.label("Skills: " + ", ".join(gs.member_skills(cid2).map(func(s: Variant) -> String: return str(DB.skill(str(s)).get("name", s)))), 16, MenuStyle.DIM))
	return _two_col(left, MenuStyle.scroll(right), 300)


func _equip_menu(cid: String, slot: String) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	MenuStyle.clear(_page)
	var v: VBoxContainer = MenuStyle.vbox(6)
	v.add_child(MenuStyle.label("Equip %s - %s" % [slot, DB.CHARACTERS[cid].name], 24, MenuStyle.GOLD))
	var inner: VBoxContainer = MenuStyle.vbox(4)
	var any: bool = false
	for id: String in gs.inventory:
		var it: Dictionary = DB.item(id)
		if str(it.get("slot", "")) != slot or int(gs.inventory[id]) <= 0:
			continue
		if not it.get("who", []).is_empty() and not cid in it.who:
			continue
		any = true
		var b: Button = MenuStyle.button("%s x%d   %s" % [it.name, int(gs.inventory[id]), MenuStyle.item_blurb(id)])
		b.pressed.connect(func() -> void:
			if gs.equip(cid, id):
				MenuStyle.sfx("equip")
			_refresh())
		inner.add_child(b)
	if not any:
		inner.add_child(MenuStyle.label("Nothing in the pack fits this slot.", 18, MenuStyle.DIM))
	v.add_child(MenuStyle.scroll(inner))
	var back: Button = MenuStyle.button("Back")
	back.pressed.connect(_refresh)
	v.add_child(back)
	_page.add_child(v)
	_focus_first.call_deferred(v)


# ------------------------------------------------------------------ items
func _page_items() -> Control:
	var gs: Node = MenuStyle.auto("GameState")
	var list: VBoxContainer = MenuStyle.vbox(4)
	var detail: VBoxContainer = MenuStyle.vbox(6)
	if gs == null:
		return _two_col(list, detail)
	var groups: Array = [["Consumables & Dishes", ["consumable", "dish", "throwable"]], ["Equipment", ["weapon", "armor", "charm"]],
		["Ingredients", ["ingredient"]], ["Key Items", ["key"]]]
	var ids: Array = gs.inventory.keys().filter(func(k: Variant) -> bool: return int(gs.inventory[k]) > 0)
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return DB.item_name(str(a)) < DB.item_name(str(b)))
	for g: Array in groups:
		var first: bool = true
		for id: String in ids:
			if not str(DB.item(id).get("kind", "")) in g[1]:
				continue
			if first:
				list.add_child(MenuStyle.label(g[0], 17, MenuStyle.ACCENT))
				first = false
			var b: Button = MenuStyle.button("%s   x%d" % [DB.item_name(id), int(gs.inventory[id])])
			b.pressed.connect(func() -> void:
				_sel_item = id
				_refresh())
			list.add_child(b)
	if ids.is_empty():
		list.add_child(MenuStyle.label("The pack is empty.", 18, MenuStyle.DIM))
	if _sel_item != "" and gs.count(_sel_item) > 0:
		var it: Dictionary = DB.item(_sel_item)
		detail.add_child(MenuStyle.label(str(it.get("name", _sel_item)), 26, MenuStyle.GOLD))
		detail.add_child(MenuStyle.label(MenuStyle.item_blurb(_sel_item), 18, MenuStyle.INK, true))
		if _usable(it):
			detail.add_child(MenuStyle.label("Use on:", 18, MenuStyle.ACCENT))
			for cid: String in gs.active:
				var m: Dictionary = gs.party[cid]
				var st: Dictionary = gs.member_stats(cid)
				var ub: Button = MenuStyle.button("%s   HP %d/%d  MP %d/%d" % [DB.CHARACTERS[cid].name, int(m.hp), int(st.hp), int(m.mp), int(st.mp)])
				ub.pressed.connect(_use_item.bind(_sel_item, cid))
				detail.add_child(ub)
	return _two_col(MenuStyle.scroll(list), detail, 360)


func _usable(it: Dictionary) -> bool:
	return str(it.get("kind", "")) in ["consumable", "dish"] and (it.has("heal") or it.has("heal_pct") or it.has("mp") or it.has("mp_pct") or it.has("revive"))


func _use_item(id: String, cid: String) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	var it: Dictionary = DB.item(id)
	var m: Dictionary = gs.party[cid]
	var st: Dictionary = gs.member_stats(cid)
	var down: bool = int(m.hp) <= 0
	if it.has("revive"):
		if not down:
			_say("%s is not down." % DB.CHARACTERS[cid].name, false)
			MenuStyle.sfx("ui_error")
			return
		m.hp = maxi(1, int(float(st.hp) * float(it.revive)))
	elif down:
		_say("%s is down; revive first." % DB.CHARACTERS[cid].name, false)
		MenuStyle.sfx("ui_error")
		return
	else:
		var healed: bool = false
		var hp0: int = int(m.hp)
		var mp0: int = int(m.mp)
		m.hp = mini(int(st.hp), int(m.hp) + int(it.get("heal", 0)) + int(float(st.hp) * float(it.get("heal_pct", 0.0))))
		m.mp = mini(int(st.mp), int(m.mp) + int(it.get("mp", 0)) + int(float(st.mp) * float(it.get("mp_pct", 0.0))))
		healed = int(m.hp) != hp0 or int(m.mp) != mp0
		if not healed:
			_say("No effect.", false)
			MenuStyle.sfx("ui_error")
			return
	gs.remove_item(id, 1)
	MenuStyle.sfx("heal")
	var ev: Node = MenuStyle.auto("Events")
	if ev != null:
		ev.party_changed.emit()
	_refresh()
	_say("Used %s on %s." % [DB.item_name(id), DB.CHARACTERS[cid].name])


# ------------------------------------------------------------------ bestiary
func _on_battle_finished(result: Dictionary) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	if gs == null:
		return
	var enc: Dictionary = DB.ENCOUNTERS.get(str(result.get("encounter", "")), {})
	for eid: Variant in enc.get("enemies", []):
		gs.set_flag("seen_" + str(eid), true)


func _page_bestiary() -> Control:
	var gs: Node = MenuStyle.auto("GameState")
	var list: VBoxContainer = MenuStyle.vbox(4)
	var detail: VBoxContainer = MenuStyle.vbox(6)
	var seen: int = 0
	for eid: String in DB.ENEMIES:
		var known: bool = gs != null and bool(gs.flag("seen_" + eid))
		seen += int(known)
		var b: Button = MenuStyle.button(DB.ENEMIES[eid].name if known else "? ? ?")
		b.disabled = not known
		b.pressed.connect(func() -> void:
			_sel_enemy = eid
			_refresh())
		list.add_child(b)
	list.add_child(MenuStyle.label("Seen %d / %d" % [seen, DB.ENEMIES.size()], 16, MenuStyle.DIM))
	if _sel_enemy != "" and DB.ENEMIES.has(_sel_enemy) and gs != null and bool(gs.flag("seen_" + _sel_enemy)):
		var e: Dictionary = DB.ENEMIES[_sel_enemy]
		detail.add_child(MenuStyle.label("%s   Lv %d" % [e.name, int(e.get("level", 1))], 26, MenuStyle.GOLD))
		detail.add_child(MenuStyle.label("Family: %s   Element: %s" % [e.get("family", "?"), DB.ELEMENTS.get(e.get("element", "none"), {}).get("name", "?")], 17, MenuStyle.DIM))
		var es: ModelStage = ModelStage.new()
		es.custom_minimum_size = Vector2(300, 300)
		es.show_model(str(e.get("model", "")))
		detail.add_child(es)
		detail.add_child(MenuStyle.label("Weak: %s" % _elem_list(e.get("weak", [])), 18, MenuStyle.BAD))
		detail.add_child(MenuStyle.label("Resists: %s" % _elem_list(e.get("resist", [])), 18, MenuStyle.GOOD))
		detail.add_child(MenuStyle.label(str(e.get("desc", "")), 18, MenuStyle.INK, true))
		detail.add_child(MenuStyle.label("\"%s\"" % e.get("flavor", ""), 17, MenuStyle.DIM, true))
		var drops: Array = []
		for d: Variant in e.get("drops", []):
			drops.append(DB.item_name(str(d[0])))
		detail.add_child(MenuStyle.label("Drops: " + (", ".join(drops) if not drops.is_empty() else "none"), 17))
	else:
		detail.add_child(MenuStyle.label("Fight a monster to record it here.", 18, MenuStyle.DIM))
	return _two_col(MenuStyle.scroll(list), MenuStyle.scroll(detail), 300)


func _elem_list(a: Array) -> String:
	if a.is_empty():
		return "none"
	return ", ".join(a.map(func(x: Variant) -> String: return str(DB.ELEMENTS.get(str(x), {}).get("name", x))))


# ------------------------------------------------------------------ summons
func _page_summons() -> Control:
	var gs: Node = MenuStyle.auto("GameState")
	var v: VBoxContainer = MenuStyle.vbox(10)
	var n_have: int = 0
	var row: HBoxContainer = MenuStyle.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for sid: String in DB.SUMMONS:
		var s: Dictionary = DB.SUMMONS[sid]
		var have: bool = gs != null and sid in gs.summons
		n_have += int(have)
		var inner: VBoxContainer = MenuStyle.vbox(4)
		var stage: ModelStage = ModelStage.new()
		stage.custom_minimum_size = Vector2(300, 320)
		stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stage.show_model(str(s.model))
		if not have:
			stage.modulate = Color(0.03, 0.02, 0.05, 0.85)  # locked silhouette
		inner.add_child(stage)
		if have:
			inner.add_child(MenuStyle.label(str(s.name), 28, s.get("color", MenuStyle.INK)))
			inner.add_child(MenuStyle.label(str(s.title), 20, MenuStyle.GOLD))
			inner.add_child(MenuStyle.label("Skill: %s" % s.attack, 22, MenuStyle.ACCENT))
			inner.add_child(MenuStyle.label(_elem_list([s.element, s.get("element2", "none")].filter(func(x: Variant) -> bool: return x != "" and x != "none")), 18, MenuStyle.DIM))
			inner.add_child(MenuStyle.label(str(s.get("desc", "")), 18, MenuStyle.INK, true))
		else:
			var q: Dictionary = DB.QUESTS.get(str(s.get("unlock_quest", "")), {})
			inner.add_child(MenuStyle.label("? ? ?", 30, MenuStyle.DIM))
			inner.add_child(MenuStyle.label("Locked", 20, MenuStyle.BAD))
			inner.add_child(MenuStyle.label("Hint: %s at the Rainbow Orchard shrine." % str(q.get("name", "a lost memory")), 18, MenuStyle.DIM, true))
		row.add_child(_sep_panel(inner))
		(row.get_child(row.get_child_count() - 1) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(MenuStyle.label("Nine Lives Spirits   %d / %d awakened" % [n_have, DB.SUMMONS.size()], 26, MenuStyle.GOLD))
	v.add_child(row)
	return v


# ------------------------------------------------------------------ save / load
func _page_saves() -> Control:
	var gs: Node = MenuStyle.auto("GameState")
	var v: VBoxContainer = MenuStyle.vbox(8)
	v.add_child(MenuStyle.label("Save / Load" + ("" if allow_save else "   (saving is only possible at a campfire or the cauldron)"), 24, MenuStyle.GOLD))
	for s: int in SLOTS:
		var info: Dictionary = gs.save_info(s) if gs != null else {"exists": false}
		var row: HBoxContainer = MenuStyle.hbox(8)
		var txt: String = "Slot %d: empty" % s
		if info.exists:
			txt = "Slot %d: Lv %d   %s   %s\n%s" % [s, int(info.level), MenuStyle.fmt_time(float(info.play_time)), str(info.area).capitalize(), str(info.saved_at)]
		var lab: Label = MenuStyle.label(txt, 19)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_sep_panel(lab))
		(row.get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb: Button = MenuStyle.button("Save", 110)
		sb.disabled = not allow_save
		sb.pressed.connect(_do_save.bind(s))
		row.add_child(sb)
		var lb: Button = MenuStyle.button("Load", 110)
		lb.disabled = not info.exists
		lb.pressed.connect(_do_load.bind(s))
		row.add_child(lb)
		v.add_child(row)
	var q: Button = MenuStyle.button("Quit to title")
	q.pressed.connect(_quit_title)
	v.add_child(q)
	return v


func _do_save(s: int) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	if gs != null and gs.save_game(s):
		MenuStyle.sfx("ui_save")
		_refresh()
		_say("Saved to slot %d." % s)
	else:
		MenuStyle.sfx("ui_error")
		_say("Save failed.", false)


func _do_load(s: int) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	if gs != null and gs.load_game(s):
		MenuStyle.sfx("ui_confirm")
		close()
	else:
		MenuStyle.sfx("ui_error")
		_say("Load failed.", false)


func _quit_title() -> void:
	quit_to_title.emit()
	var tree: SceneTree = get_tree()
	close()
	if ResourceLoader.exists("res://scenes/main.tscn"):
		tree.change_scene_to_file("res://scenes/main.tscn")


# ------------------------------------------------------------------ settings
func _page_settings() -> Control:
	return SettingsPanel.build()
