class_name ShopMenu
extends CanvasLayer
## Shop screen. ShopMenu.open_shop("cheesemonger_shop"); emits closed. Stock comes from DB.SHOPS via GameState.shop_stock().
## Buy price = price * buy_mult, sell = price * sell_mult (min 1g). Key items and price-0 items cannot be sold.

signal closed

const DB = preload("res://data/db.gd")

var is_open: bool = false
var _shop_id: String = ""
var _mode: int = 0  ## 0 buy, 1 sell
var _prev_pause: bool = false
var _root: Control
var _body: Control
var _title: Label
var _gold: Label
var _msg: Label
var _tabs: Array = []


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = MenuStyle.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	_root.add_child(panel)
	var v: VBoxContainer = MenuStyle.vbox(8)
	panel.add_child(v)
	var head: HBoxContainer = MenuStyle.hbox(10)
	v.add_child(head)
	_title = MenuStyle.label("Shop", 28, MenuStyle.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	for i: int in 2:
		var b: Button = MenuStyle.button(["Buy", "Sell"][i], 100)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(_set_mode.bind(i))
		head.add_child(b)
		_tabs.append(b)
	var leave: Button = MenuStyle.button("Leave", 100)
	leave.alignment = HORIZONTAL_ALIGNMENT_CENTER
	leave.pressed.connect(close)
	head.add_child(leave)
	_gold = MenuStyle.label("", 22, MenuStyle.GOLD)
	head.add_child(_gold)
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_msg = MenuStyle.label("", 18, MenuStyle.GOOD)
	v.add_child(_msg)
	visible = false


func open_shop(shop_id: String) -> void:
	if is_open or not DB.SHOPS.has(shop_id):
		return
	_shop_id = shop_id
	_mode = 0
	is_open = true
	_prev_pause = get_tree().paused
	get_tree().paused = true
	visible = true
	MenuStyle.sfx("ui_open")
	_title.text = str(DB.SHOPS[shop_id].name)
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = _prev_pause
	MenuStyle.sfx("ui_cancel")
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if is_open and (e.is_action_pressed("ui_cancel") or (InputMap.has_action("cancel") and e.is_action_pressed("cancel"))):
		close()
		get_viewport().set_input_as_handled()


func _set_mode(m: int) -> void:
	_mode = m
	MenuStyle.sfx("ui_select")
	_refresh()


func _price(id: String, buying: bool) -> int:
	var sh: Dictionary = DB.SHOPS[_shop_id]
	var base: int = int(DB.item(id).get("price", 0))
	if buying:
		return maxi(1, int(round(base * float(sh.get("buy_mult", 1.0)))))
	return maxi(1, int(round(base * float(sh.get("sell_mult", 0.5)))))


func _refresh() -> void:
	var gs: Node = MenuStyle.auto("GameState")
	_gold.text = "%d g" % int(gs.gold)
	for i: int in _tabs.size():
		(_tabs[i] as Button).disabled = (i == _mode)
	MenuStyle.clear(_body)
	var list: VBoxContainer = MenuStyle.vbox(4)
	var ids: Array = gs.shop_stock(_shop_id) if _mode == 0 else gs.inventory.keys().filter(
		func(k: Variant) -> bool: return int(gs.inventory[k]) > 0 and str(DB.item(str(k)).get("kind", "")) != "key" and int(DB.item(str(k)).get("price", 0)) > 0)
	if _mode == 1:
		ids.sort_custom(func(a: Variant, b: Variant) -> bool: return DB.item_name(str(a)) < DB.item_name(str(b)))
	for id: String in ids:
		var owned: int = gs.count(id)
		var pr: int = _price(id, _mode == 0)
		var b: Button = MenuStyle.button("%s   %dg   (own %d)\n%s" % [DB.item_name(id), pr, owned, MenuStyle.item_blurb(id).left(110)])
		b.custom_minimum_size.y = 58
		b.disabled = _mode == 0 and int(gs.gold) < pr
		b.pressed.connect(_transact.bind(id))
		list.add_child(b)
	if ids.is_empty():
		list.add_child(MenuStyle.label("Nothing here.", 20, MenuStyle.DIM))
	_body.add_child(MenuStyle.scroll(list))
	for c: Node in list.find_children("*", "Button", true, false):
		if not (c as Button).disabled:
			_focus.call_deferred(c)
			break


func _transact(id: String) -> void:
	var gs: Node = MenuStyle.auto("GameState")
	var pr: int = _price(id, _mode == 0)
	if _mode == 0:
		if gs.spend_gold(pr):
			gs.add_item(id, 1)
			MenuStyle.sfx("ui_buy")
			_say("Bought %s." % DB.item_name(id), true)
		else:
			MenuStyle.sfx("ui_error")
			_say("Not enough gold.", false)
	else:
		if gs.remove_item(id, 1):
			gs.add_gold(pr)
			MenuStyle.sfx("coin")
			_say("Sold %s for %dg." % [DB.item_name(id), pr], true)
	var keep: int = -1
	var fo: Control = _root.get_viewport().gui_get_focus_owner()
	if fo != null and fo.get_parent() != null:
		keep = fo.get_index()
	_refresh()
	if keep >= 0:
		var btns: Array = _body.find_children("*", "Button", true, false)
		if not btns.is_empty():
			_focus.call_deferred(btns[mini(keep, btns.size() - 1)])


func _say(t: String, good: bool) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", MenuStyle.GOOD if good else MenuStyle.BAD)


func _focus(c: Control) -> void:
	if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
		c.grab_focus()
