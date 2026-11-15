class_name UIRoot
extends CanvasLayer
## Owns every 2D UI screen and shows the right one for Game.state. Instance once (scenes/ui/ui_root.tscn)
## from main.tscn. Reacts only to Events.state_changed / paused_changed; reads Game.state once on build.

var hud: Hud
var title: TitleMenu
var pause: PauseMenu
var settings: SettingsMenu
var intermission: Intermission
var game_over: EndScreen
var victory: EndScreen
var _settings_return: MenuScreen = null


func _init() -> void:
	layer = 20
	name = "UIRoot"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	SettingsMenu.apply_bindings()
	SettingsMenu.apply_display()
	hud = Hud.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	title = TitleMenu.new()
	pause = PauseMenu.new()
	settings = SettingsMenu.new()
	intermission = Intermission.new()
	game_over = EndScreen.new(EndScreen.Mode.GAME_OVER)
	victory = EndScreen.new(EndScreen.Mode.VICTORY)
	for s: MenuScreen in [title, pause, intermission, game_over, victory, settings]:
		add_child(s)
	title.settings_requested.connect(func() -> void: _open_settings(title))
	pause.settings_requested.connect(func() -> void: _open_settings(pause))
	settings.closed.connect(_close_settings)
	Events.state_changed.connect(func(n: int, _o: int) -> void: show_state(n))
	show_state(int(Game.state))


func show_state(s: int) -> void:
	for m: MenuScreen in [title, pause, intermission, game_over, victory, settings]:
		m.close()
	_settings_return = null
	var playing: bool = s == Game.State.PLAYING or s == Game.State.PAUSED
	hud.visible = playing
	match s:
		Game.State.TITLE: title.open()
		Game.State.PAUSED: pause.open()
		Game.State.INTERMISSION: intermission.open()
		Game.State.GAME_OVER: game_over.open()
		Game.State.VICTORY: victory.open()
	_set_mouse(s)


func _set_mouse(s: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if s == Game.State.PLAYING else Input.MOUSE_MODE_VISIBLE


func _open_settings(from: MenuScreen) -> void:
	_settings_return = from
	from.close()
	settings.open()


func _close_settings() -> void:
	settings.close()
	if _settings_return != null:
		_settings_return.open()
	_settings_return = null
