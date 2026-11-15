extends Control
## Screenshot/preview harness for the UI (owner: ui). User arg: --screen=title|hud|pause|settings|keys|intermission|gameover|victory
## Fakes Events/Game state; a dark gradient stands in for the 3D world.

func _ready() -> void:
	var screen: String = "title"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.trim_prefix("--screen=")
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([Color(0.30, 0.34, 0.40), Color(0.10, 0.09, 0.08)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	var tr: TextureRect = TextureRect.new()
	tr.texture = gt
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(tr)
	var ui: UIRoot = UIRoot.new()
	add_child(ui)
	await get_tree().process_frame
	Game.score = 12450
	Game.lives = 7
	match screen:
		"hud":
			ui.show_state(Game.State.PLAYING)
			Events.health_changed.emit(72, 7)
			Events.weapon_changed.emit("gatling")
			Events.ammo_changed.emit(14, 63)
			Events.score_changed.emit(12450)
			Events.key_taken.emit("gold")
			Events.pickup_taken.emit("tuna", 25)
			Events.pickup_taken.emit("gatling", 1)
			Events.message.emit("The door is locked. Need the silver key.")
			ui.hud.show_card("The Cheese Cellar", "LEVEL 1")
			ui.hud._card_t = 2.9
			ui.hud.crosshair.set_spread_rad(0.03)
			ui.hud.crosshair.hit(false)
			Events.player_hurt.emit(12)
		"pause": ui.show_state(Game.State.PAUSED)
		"settings":
			ui.show_state(Game.State.PAUSED)
			ui.pause.settings_requested.emit()
		"keys":
			ui.show_state(Game.State.PAUSED)
			ui.pause.settings_requested.emit()
			ui.settings._tabs.current_tab = 3
		"intermission":
			Game.level_id = "e1m1"
			Game.stats = {"kills": 18, "kills_total": 20, "secrets": 1, "secrets_total": 3, "treasure": 9, "treasure_total": 12, "time": 205.0, "par": 240, "bonus": 1200}
			ui.show_state(Game.State.INTERMISSION)
			await get_tree().create_timer(3.0).timeout
		"gameover": ui.show_state(Game.State.GAME_OVER)
		"victory": ui.show_state(Game.State.VICTORY)
		_: ui.show_state(Game.State.TITLE)
