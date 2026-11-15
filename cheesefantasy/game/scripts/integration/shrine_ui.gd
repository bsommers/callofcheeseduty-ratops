class_name ShrineUI
extends CanvasLayer
## Rainbow Orchard shrine: memory quest board + gallery of the Nine Lives Spirits (rotating 3D models).

signal closed

const ORDER: Array = ["jesse", "tripper", "samantha", "spooky"]

var _sel: String = "jesse"
var _list: VBoxContainer
var _info: VBoxContainer
var _stage: ModelStage
var _msg: Label
var _root: Control


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = MenuStyle.theme()
	add_child(_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.14, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 40)
	_root.add_child(m)
	var v: VBoxContainer = MenuStyle.vbox(14)
	m.add_child(v)
	v.add_child(MenuStyle.label("Rainbow Orchard Shrine  -  The Nine Lives Spirits", 36, Color(0.85, 0.7, 1.0)))
	var h: HBoxContainer = MenuStyle.hbox(24)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	_list = MenuStyle.vbox(10)
	_list.custom_minimum_size = Vector2(520, 0)
	h.add_child(_list)
	_stage = ModelStage.new()
	_stage.custom_minimum_size = Vector2(520, 480)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(_stage)
	_info = MenuStyle.vbox(10)
	_info.custom_minimum_size = Vector2(480, 0)
	h.add_child(_info)
	_msg = MenuStyle.label("", 20, MenuStyle.GOOD, true)
	v.add_child(_msg)
	var leave: Button = MenuStyle.button("Leave the shrine", 260)
	leave.pressed.connect(close)
	v.add_child(leave)
	_refresh()
	leave.grab_focus.call_deferred()
	Audio.play_music("shrine")


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (InputMap.has_action("cancel") and e.is_action_pressed("cancel")):
		get_viewport().set_input_as_handled()
		close()


func _state(sid: String) -> int:
	return Story.qstage(str(Data.SUMMONS[sid].unlock_quest))


func _refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	for c2: Node in _info.get_children():
		c2.queue_free()
	for sid: String in ORDER:
		var d: Dictionary = Data.SUMMONS[sid]
		var st: int = _state(sid)
		var tag: String = "Awakened" if st == 99 else ("Memory in progress" if st >= 0 else "Sleeping")
		var b: Button = MenuStyle.button("%s - %s   [%s]" % [d.name if st != -1 or sid == _sel else "???", d.title, tag], 500)
		b.pressed.connect(_select.bind(sid))
		_list.add_child(b)
	var d2: Dictionary = Data.SUMMONS[_sel]
	var st2: int = _state(_sel)
	var q: Dictionary = Data.QUESTS[str(d2.unlock_quest)]
	_info.add_child(MenuStyle.label(str(d2.name) + "  -  " + str(d2.title), 30, MenuStyle.GOLD))
	if st2 == 99:
		_stage.visible = true
		_stage.show_model(str(d2.model))
		_info.add_child(MenuStyle.label("Style: %s" % str(d2.cat), 18, MenuStyle.DIM))
		_info.add_child(MenuStyle.label(str(d2.desc), 20, MenuStyle.INK, true))
		_info.add_child(MenuStyle.label("\"" + str(d2.intro) + "\"", 18, MenuStyle.DIM, true))
	else:
		_stage.visible = false
		_info.add_child(MenuStyle.label(str(q.name), 24, MenuStyle.INK, true))
		if st2 < 0:
			_info.add_child(MenuStyle.label("A faint purring drifts from the stone. Listen, and a memory may return.", 20, MenuStyle.DIM, true))
			var bb: Button = MenuStyle.button("Listen to the memory", 360)
			bb.pressed.connect(_begin)
			_info.add_child(bb)
			bb.grab_focus.call_deferred()
		else:
			_info.add_child(MenuStyle.label("Objective: " + str(q.stages[clampi(st2, 0, q.stages.size() - 1)]), 22, MenuStyle.GOLD, true))
			if st2 >= 2:
				var need_yarn: bool = _sel == "spooky" and not GameState.has_item("memory_yarn")
				var rb: Button = MenuStyle.button("Return the memory" if not need_yarn else "Return the memory (needs Memory Yarn)", 460)
				rb.disabled = need_yarn
				rb.pressed.connect(_complete)
				_info.add_child(rb)
				rb.grab_focus.call_deferred()


func _select(sid: String) -> void:
	_sel = sid
	MenuStyle.sfx("ui_select")
	_msg.text = ""
	_refresh()


func _begin() -> void:
	var qid: String = str(Data.SUMMONS[_sel].unlock_quest)
	if _sel == "jesse":
		Story.setq(qid, 1)
		_msg.text = "You ring the Shrine Bell. A gray mist stirs. Find Jesse's favourite windowsill (the farmhouse)."
	else:
		Story.setq(qid, 0)
		_msg.text = "A memory returns: " + str(Data.QUESTS[qid].stages[0])
	Audio.play_sfx("ui_confirm")
	_refresh()


func _complete() -> void:
	var qid: String = str(Data.SUMMONS[_sel].unlock_quest)
	if _sel == "spooky":
		GameState.remove_item("memory_yarn", 1)
	Story.setq(qid, "done")
	Audio.play_sfx("summon_sting")
	var d: Dictionary = Data.SUMMONS[_sel]
	_msg.text = "%s awakens! %s" % [str(d.name), str(d.intro)]
	_refresh()
