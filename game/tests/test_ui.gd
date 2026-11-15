extends "res://tests/test_case.gd"
## UI: theme, HUD reacting to Events, screen routing by Game.state, settings widgets + key rebinding.

var _nodes: Array[Node] = []
var _saved_persist: bool


func before_each() -> void:
	_saved_persist = Settings.persist
	Settings.persist = false
	UIPrefs.reset_cache()


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Game.set_state(Game.State.TITLE)
	InputMap.load_from_project_settings()
	UIPrefs.reset_cache()
	Settings.persist = _saved_persist


func _add(n: Node) -> Node:
	tree.root.add_child(n)
	_nodes.append(n)
	return n


func test_theme_loads() -> void:
	var t: Theme = UITheme.get_theme()
	check(t != null and t.default_font != null, "theme with font")
	check(t.has_stylebox("normal", "Button"), "button style")
	check(ResourceLoader.exists(UITheme.THEME_PATH), "theme.tres exists")


func test_hud_follows_events() -> void:
	var h: Hud = _add(Hud.new()) as Hud
	Events.health_changed.emit(64, 5)
	eq(h.health, 64, "health")
	eq(h.lives, 5, "lives")
	eq(h._health_label.text, "64", "health label")
	eq(h._lives_row.get_child_count(), 9, "life pips")
	Events.weapon_changed.emit("gatling")
	Events.ammo_changed.emit(12, 40)
	eq(h._ammo_label.text, "12", "ammo")
	eq(h._reserve_label.text, "/ 40", "reserve")
	Events.weapon_changed.emit("claws")
	eq(h._ammo_label.text, "--", "melee shows no ammo")
	Events.score_changed.emit(777)
	eq(h._score_label.text, "777", "score")
	Events.key_taken.emit("gold")
	check(h.keys["gold"] and not h.keys["silver"], "keys")
	eq(h._key_gold.modulate.a, 1.0, "gold key lit")
	Events.player_hurt.emit(20)
	check(h._damage >= 0.5, "damage vignette")
	Events.pickup_taken.emit("tuna", 25)
	eq(h._toasts.get_child_count(), 1, "toast")
	for i: int in 8:
		Events.message.emit("m%d" % i)
	check(h._toasts.get_child_count() <= Hud.MAX_TOASTS, "toast cap")


func test_crosshair_spread_and_markers() -> void:
	var h: Hud = _add(Hud.new()) as Hud
	h.crosshair.set_spread_rad(0.0)
	var a: float = h.crosshair._target_px
	h.crosshair.set_spread_rad(0.05)
	check(h.crosshair._target_px > a, "spread widens")
	h.crosshair.hit(true)
	check(h.crosshair._kill_t > 0.0, "kill marker")
	h.crosshair.kick()
	check(h.crosshair._bloom > 0.0, "bloom")


func test_screen_routing() -> void:
	var ui: UIRoot = _add(UIRoot.new()) as UIRoot
	eq(ui.title.visible, true, "title visible at start")
	ui.show_state(Game.State.PAUSED)
	check(ui.pause.visible and not ui.title.visible, "pause only")
	check(ui.hud.visible, "hud under pause")
	ui.show_state(Game.State.INTERMISSION)
	check(ui.intermission.visible and not ui.hud.visible, "intermission")
	ui.show_state(Game.State.GAME_OVER)
	check(ui.game_over.visible, "game over")
	ui.show_state(Game.State.VICTORY)
	check(ui.victory.visible, "victory")
	ui.show_state(Game.State.PLAYING)
	check(ui.hud.visible and not ui.pause.visible, "playing")


func test_state_signal_drives_ui() -> void:
	var ui: UIRoot = _add(UIRoot.new()) as UIRoot
	Events.state_changed.emit(int(Game.State.VICTORY), 0)
	check(ui.victory.visible, "state_changed shows victory")
	Events.state_changed.emit(int(Game.State.TITLE), 0)
	check(ui.title.visible and not ui.victory.visible, "back to title")


func test_intermission_percentages() -> void:
	eq(Intermission._pct({"kills": 5, "kills_total": 10}, "kills", "kills_total"), 50, "half")
	eq(Intermission._pct({}, "kills", "kills_total"), 100, "none to kill counts as 100")


func test_settings_widgets_bind_to_settings() -> void:
	var m: SettingsMenu = _add(SettingsMenu.new()) as SettingsMenu
	m.open()
	var saved_q: int = Settings.quality
	m._quality.select(0)
	m._quality.item_selected.emit(0)
	eq(Settings.quality, 0, "quality set to Low")
	Settings.quality = saved_q
	eq(m._quality.item_count, 4, "four presets")
	m._sens.value = 4.0
	eq(Settings.mouse_sensitivity, 0.004, "sensitivity")
	m._vols["music"].value = 0.3
	eq(float(Settings.get_value("audio", "music")), 0.3, "music volume")
	m._fov.value = 90.0
	eq(float(Settings.get_value("graphics", "fov")), 90.0, "fov")
	Settings.reset_to_defaults()


func test_key_rebinding() -> void:
	var m: SettingsMenu = _add(SettingsMenu.new()) as SettingsMenu
	m.open()
	m._begin_listen("reload")
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_T
	ev.pressed = true
	m._input(ev)
	var found: bool = false
	for e: InputEvent in InputMap.action_get_events("reload"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_T:
			found = true
	check(found, "reload rebound to T")
	eq(m._listening, "", "listening ended")
	m._reset_bindings()
	found = false
	for e: InputEvent in InputMap.action_get_events("reload"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_T:
			found = true
	check(not found, "reset restores default")
