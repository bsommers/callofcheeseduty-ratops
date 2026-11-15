class_name DialogueBox
extends CanvasLayer
## Polished RPG dialogue box: portrait + name plate, typewriter text, choices, flags and quest hooks.
## Data: res://data/dialogue/<id>.json (see docs/swarm/reports/rpg-world.md for the format).

signal finished(npc_id: String)

const CPS := 55.0
const DIR := "res://data/dialogue/"

var active := false
var _data: Dictionary = {}
var _node: Dictionary = {}
var _npc: Node
var _npc_id := ""
var _speaker := ""
var _accent := Color(0.95, 0.72, 0.25)
var _typing := false
var _progress := 0.0
var _choices: Array = []
var _sel := 0
var _fallback_model := ""

var _root: Control
var _panel: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _choice_box: VBoxContainer
var _arrow: Label
var _portrait_vp: SubViewport
var _portrait_holder: Control
var _portrait_model: Node3D
var _plate: PanelContainer
var _t := 0.0

func _ready() -> void:
	layer = 20
	add_to_group("dialogue_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func _style(bg: Color, border: Color, radius := 14, bw := 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -520
	_panel.offset_right = 520
	_panel.offset_top = -210
	_panel.offset_bottom = -28
	_panel.add_theme_stylebox_override("panel", _style(Color(0.16, 0.10, 0.07, 0.94), _accent))
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_top", 26)
	_panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = false
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 80)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("bold_font_size", 22)
	_text.add_theme_color_override("default_color", Color(1.0, 0.96, 0.86))
	vb.add_child(_text)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 2)
	vb.add_child(_choice_box)
	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_color_override("font_color", _accent)
	_arrow.anchor_left = 1.0
	_arrow.anchor_right = 1.0
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = -50
	_arrow.offset_top = -40
	_arrow.offset_right = -20
	_arrow.offset_bottom = -12
	_panel.add_child(_arrow)
	# Name plate
	_plate = PanelContainer.new()
	_plate.anchor_left = 0.5
	_plate.anchor_right = 0.5
	_plate.anchor_top = 1.0
	_plate.anchor_bottom = 1.0
	_plate.offset_left = -340
	_plate.offset_top = -246
	_plate.offset_bottom = -206
	_plate.add_theme_stylebox_override("panel", _style(Color(0.35, 0.18, 0.08, 0.98), _accent, 10, 2))
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_plate.add_child(_name_label)
	_root.add_child(_plate)
	# Portrait frame
	_portrait_holder = PanelContainer.new()
	var pf := _portrait_holder as PanelContainer
	pf.anchor_left = 0.5
	pf.anchor_right = 0.5
	pf.anchor_top = 1.0
	pf.anchor_bottom = 1.0
	pf.offset_left = -500
	pf.offset_right = -352
	pf.offset_top = -244
	pf.offset_bottom = -52
	var psb := _style(Color(0.72, 0.84, 0.95, 1.0), _accent, 16, 4)
	psb.content_margin_left = 4
	psb.content_margin_right = 4
	psb.content_margin_top = 4
	psb.content_margin_bottom = 4
	pf.add_theme_stylebox_override("panel", psb)
	_root.add_child(pf)
	var cont := SubViewportContainer.new()
	cont.stretch = true
	pf.add_child(cont)
	_portrait_vp = SubViewport.new()
	_portrait_vp.size = Vector2i(140, 184)
	_portrait_vp.own_world_3d = true
	_portrait_vp.transparent_bg = false
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	cont.add_child(_portrait_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.86, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_portrait_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 35, 0)
	sun.light_energy = 1.3
	_portrait_vp.add_child(sun)
	var pc := Camera3D.new()
	pc.name = "PortraitCam"
	pc.fov = 32.0
	_portrait_vp.add_child(pc)

func _set_accent(c: Color) -> void:
	_accent = c
	_panel.add_theme_stylebox_override("panel", _style(Color(0.16, 0.10, 0.07, 0.94), c))
	_plate.add_theme_stylebox_override("panel", _style(Color(0.35, 0.18, 0.08, 0.98), c, 10, 2))
	_arrow.add_theme_color_override("font_color", c)

func _set_portrait(model_id: String) -> void:
	if _portrait_model != null:
		_portrait_model.queue_free()
		_portrait_model = null
	_portrait_holder.visible = model_id != ""
	if model_id == "":
		return
	var m := WorldModels.spawn_actor(model_id, 1.0)
	_portrait_vp.add_child(m)
	_portrait_model = m
	WorldModels.play(m, "idle")
	var bb := WorldModels._local_bounds(m)
	var h := maxf(bb.size.y, 0.5) if bb.size.y > 0.01 else 1.0
	var top := bb.position.y + h
	var cam := _portrait_vp.get_node("PortraitCam") as Camera3D
	var focus_y := top - minf(h * 0.18, 0.35)
	cam.position = Vector3(0.0, focus_y + 0.05, minf(h, 1.6) * 1.55 + 0.5)
	cam.look_at_from_position(cam.position, Vector3(0, focus_y, 0), Vector3.UP)
	m.rotation.y = 0.35
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

# ---------------------------------------------------------------- public API

func load_dialogue(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if FileAccess.file_exists(path):
		var txt := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			return parsed
		push_warning("dialogue_box: bad JSON in %s" % path)
	var d := WorldBus.autoload("Data")
	if d != null and d.get("DIALOGUE") is Dictionary and d.get("DIALOGUE").has(id):
		return d.get("DIALOGUE")[id]
	return {}

func start(dialogue_id: String, npc: Node = null) -> void:
	if active:
		return
	var d := load_dialogue(dialogue_id)
	if d.is_empty():
		d = {"speaker": dialogue_id.capitalize(), "start": "n", "nodes": {"n": {"text": "...", "end": true}}}
	_data = d
	_npc = npc
	_npc_id = str(d.get("id", dialogue_id))
	_speaker = str(d.get("speaker", "???"))
	var model_id := str(d.get("model", ""))
	if model_id == "" and npc != null and npc.get("model_id") != null:
		model_id = str(npc.get("model_id"))
	_set_accent(Color.from_string(str(d.get("accent", "#f2b84a")), Color(0.95, 0.72, 0.25)))
	_set_portrait(model_id)
	active = true
	WorldBus.locked = true
	_root.visible = true
	WorldBus.emit(&"dialogue_started", [_npc_id])
	_goto(_pick_start())

## One-off line (signposts, narration). No portrait.
func say(speaker: String, text: String) -> void:
	if active:
		return
	_data = {"speaker": speaker, "nodes": {"n": {"text": text, "end": true}}}
	_npc = null
	_npc_id = "sign"
	_speaker = speaker
	_set_accent(Color(0.8, 0.8, 0.7))
	_set_portrait("")
	active = true
	WorldBus.locked = true
	_root.visible = true
	WorldBus.emit(&"dialogue_started", [_npc_id])
	_goto("n")

# ---------------------------------------------------------------- flow

func _cond(c: Variant) -> bool:
	if c == null or c == "":
		return true
	if c is Array:
		for x in c:
			if not _cond(x):
				return false
		return true
	var s := str(c)
	if s.begins_with("!"):
		return not WorldBus.get_flag(s.substr(1), false)
	if s.begins_with("quest:"):
		var parts := s.substr(6).split("=")
		return WorldBus.quest_state(parts[0]) == (parts[1] if parts.size() > 1 else "active")
	return bool(WorldBus.get_flag(s, false))

func _pick_start() -> String:
	var s: Variant = _data.get("start", "n")
	if s is Array:
		for entry in s:
			if _cond(entry.get("if", null)):
				return str(entry.get("goto", "n"))
		return "n"
	return str(s)

func _apply_effects(src: Dictionary) -> void:
	var setf: Variant = src.get("set", null)
	if setf is String:
		WorldBus.set_flag(setf, true)
	elif setf is Dictionary:
		for k in setf.keys():
			WorldBus.set_flag(str(k), setf[k])
	elif setf is Array:
		for k in setf:
			WorldBus.set_flag(str(k), true)
	if src.has("quest"):
		WorldBus.set_quest(str(src["quest"][0]), str(src["quest"][1]))
	if src.has("item"):
		WorldBus.give_item(str(src["item"][0]), int(src["item"][1]) if src["item"].size() > 1 else 1)
	if src.has("gold"):
		WorldBus.give_gold(int(src["gold"]))
	if src.has("toast"):
		WorldBus.toast(str(src["toast"]))
	if src.has("heal"):
		WorldBus.emit(&"party_changed")

func _goto(node_id: String) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	if not nodes.has(node_id):
		_finish()
		return
	_node = nodes[node_id]
	_node["__id"] = node_id
	if not _cond(_node.get("if", null)) and _node.has("else"):
		_goto(str(_node["else"]))
		return
	_apply_effects(_node)
	var spk := str(_node.get("speaker", _speaker))
	_name_label.text = spk
	_text.text = str(_node.get("text", ""))
	_text.visible_characters = 0
	_progress = 0.0
	_typing = true
	_choices.clear()
	for c in _node.get("choices", []):
		if _cond(c.get("if", null)):
			_choices.append(c)
	_rebuild_choices()
	_arrow.visible = false
	_sel = 0

func _rebuild_choices() -> void:
	for ch in _choice_box.get_children():
		ch.queue_free()
	for i in range(_choices.size()):
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.set_meta("idx", i)
		_choice_box.add_child(l)
	_choice_box.visible = false
	_refresh_choice_labels()

func _refresh_choice_labels() -> void:
	for l: Label in _choice_box.get_children():
		var i: int = l.get_meta("idx")
		var on := i == _sel
		l.text = ("▶ " if on else "   ") + str(_choices[i].get("text", "..."))
		l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4) if on else Color(0.85, 0.8, 0.7))

func _finish() -> void:
	active = false
	_root.visible = false
	_portrait_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	WorldBus.locked = false
	var id := _npc_id
	_npc = null
	finished.emit(id)
	WorldBus.emit(&"dialogue_finished", [id])

func _advance() -> void:
	if _typing:
		_typing = false
		_text.visible_characters = -1
		_after_typing()
		return
	if _choices.size() > 0:
		var c: Dictionary = _choices[_sel]
		_apply_effects(c)
		if c.has("battle"):
			var enc := WorldBus.resolve_encounter(str(c["battle"]))
			_finish()
			WorldBus.locked = true
			WorldBus.emit(&"battle_requested", [enc])
			return
		if c.has("next"):
			_goto(str(c["next"]))
		else:
			_finish()
		return
	if _node.get("end", false) or not _node.has("next"):
		if _node.has("battle"):
			var enc2 := WorldBus.resolve_encounter(str(_node["battle"]))
			_finish()
			WorldBus.locked = true
			WorldBus.emit(&"battle_requested", [enc2])
			return
		_finish()
	else:
		_goto(str(_node["next"]))

func _after_typing() -> void:
	_choice_box.visible = _choices.size() > 0
	_arrow.visible = _choices.is_empty()

func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	if _typing:
		var before := int(_progress)
		_progress += CPS * delta
		var total := _text.get_total_character_count()
		_text.visible_characters = int(_progress)
		if int(_progress) != before and int(_progress) % 3 == 0:
			var au := WorldBus.autoload("Audio")
			if au != null and au.has_method("play_sfx"):
				au.call("play_sfx", "blip")
		if int(_progress) >= total:
			_typing = false
			_text.visible_characters = -1
			_after_typing()
	elif _arrow.visible:
		_arrow.modulate.a = 0.5 + 0.5 * sin(_t * 6.0)
	if _portrait_model != null:
		_portrait_model.rotation.y = 0.35 + sin(_t * 0.8) * 0.08

func _is_confirm(event: InputEvent) -> bool:
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		return true
	if InputMap.has_action("confirm") and event.is_action_pressed("confirm"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false

func _input(event: InputEvent) -> void:
	if not active:
		return
	if _is_confirm(event):
		get_viewport().set_input_as_handled()
		_advance()
		return
	if _choices.size() > 0 and not _typing:
		var up: bool = event.is_action_pressed("move_up") if InputMap.has_action("move_up") else (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_UP, KEY_W])
		var down: bool = event.is_action_pressed("move_down") if InputMap.has_action("move_down") else (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_DOWN, KEY_S])
		if up:
			_sel = (_sel - 1 + _choices.size()) % _choices.size()
			_refresh_choice_labels()
			get_viewport().set_input_as_handled()
		elif down:
			_sel = (_sel + 1) % _choices.size()
			_refresh_choice_labels()
			get_viewport().set_input_as_handled()
	if InputMap.has_action("cancel") and event.is_action_pressed("cancel") and _choices.is_empty():
		get_viewport().set_input_as_handled()
		_finish()
