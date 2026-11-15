class_name IntegModal
extends CanvasLayer
## Small centred choice panel (title, body, buttons). Emits chosen(index); -1 = cancelled.
## Does not pause the tree; callers lock WorldBus themselves.

signal chosen(index: int)

var _buttons: Array[Button] = []
var _box: PanelContainer
var _content: VBoxContainer
var body_label: Label


static func ask(parent: Node, title: String, body: String, options: Array, extra: Control = null) -> IntegModal:
	var m: IntegModal = IntegModal.new()
	parent.add_child(m)
	m.build(title, body, options, extra)
	return m


func build(title: String, body: String, options: Array, extra: Control = null) -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuStyle.theme()
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	_box = PanelContainer.new()
	_box.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.BG, MenuStyle.ACCENT, 14, 3))
	_box.custom_minimum_size = Vector2(620, 0)
	cc.add_child(_box)
	var m: MarginContainer = MarginContainer.new()
	for s: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	_box.add_child(m)
	_content = MenuStyle.vbox(12)
	m.add_child(_content)
	_content.add_child(MenuStyle.label(title, 30, MenuStyle.GOLD))
	if extra != null:
		_content.add_child(extra)
	body_label = MenuStyle.label(body, 20, MenuStyle.INK, true)
	_content.add_child(body_label)
	for i: int in options.size():
		var o: Variant = options[i]
		var txt: String = str(o) if not (o is Dictionary) else str(o.get("text", ""))
		var b: Button = MenuStyle.button(txt)
		b.disabled = o is Dictionary and bool(o.get("disabled", false))
		b.pressed.connect(_pick.bind(i))
		_content.add_child(b)
		_buttons.append(b)
	for b2: Button in _buttons:
		if not b2.disabled:
			b2.grab_focus.call_deferred()
			break


func _pick(i: int) -> void:
	MenuStyle.sfx("ui_confirm")
	chosen.emit(i)
	queue_free()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") or (InputMap.has_action("cancel") and e.is_action_pressed("cancel")):
		get_viewport().set_input_as_handled()
		MenuStyle.sfx("ui_cancel")
		chosen.emit(-1)
		queue_free()
