class_name PauseMenu
extends MenuScreen
## Pause menu (shown while Game.state == PAUSED).

signal settings_requested


func build() -> void:
	heading("PAUSED")
	var res: Button = UITheme.button("Resume", func() -> void: UITheme.ui_sfx("menu_select"); Game.toggle_pause())
	body.add_child(res)
	body.add_child(UITheme.button("Restart Level", func() -> void: Game.set_state(Game.State.PLAYING); Game.restart_level()))
	body.add_child(UITheme.button("Settings", func() -> void: UITheme.ui_sfx("menu_select"); settings_requested.emit()))
	body.add_child(UITheme.button("Quit to Title", func() -> void: Game.quit_to_title()))
	set_focus_target(res)
	back_requested.connect(func() -> void: Game.toggle_pause())
