class_name MenuScreen
extends Control
## Base for full-screen menus: dim backdrop, one centred panel, focus handling, `back` hook.

signal back_requested

var panel: PanelContainer
var body: VBoxContainer
var dim: float = 0.55
var _first_focus: Control = null


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UITheme.get_theme()
	visible = false


func _ready() -> void:
	var bd: ColorRect = ColorRect.new()
	bd.color = Color(0.01, 0.01, 0.02, dim)
	bd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bd)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	panel.add_child(body)
	build()


## Override: populate `body`.
func build() -> void:
	pass


## Override: refresh dynamic content before showing.
func refresh() -> void:
	pass


func open() -> void:
	refresh()
	visible = true
	call_deferred("_focus")


func close() -> void:
	visible = false


func set_focus_target(c: Control) -> void:
	_first_focus = c


func _focus() -> void:
	if _first_focus != null and is_instance_valid(_first_focus) and visible:
		_first_focus.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		UITheme.ui_sfx("menu_back")
		get_viewport().set_input_as_handled()
		back_requested.emit()


func heading(text: String, size: int = 40) -> Label:
	var l: Label = UITheme.label(text, size, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(l)
	return l
