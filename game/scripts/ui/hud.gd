class_name Hud
extends CanvasLayer
## In-game HUD. Driven only by Events signals (plus a one-off read of Game on build / level load).
## Optional signals (connected only if Events declares them): hit_marker(kill: bool, head: bool),
## crosshair_spread(radians: float).

const MAX_TOASTS: int = 5

var health: int = 100
var max_health: int = 100
var lives: int = 9
var cur_ammo: int = 0
var reserve_ammo: int = 0
var weapon_id: String = "pistol"
var score: int = 0
var keys: Dictionary = {"gold": false, "silver": false}

var crosshair: Crosshair
var _root: Control
var _health_label: Label
var _health_bar: ProgressBar
var _lives_row: HBoxContainer
var _ammo_label: Label
var _reserve_label: Label
var _weapon_label: Label
var _weapon_icon: HudIcon
var _score_label: Label
var _key_gold: HudIcon
var _key_silver: HudIcon
var _toasts: VBoxContainer
var _card: Control
var _card_title: Label
var _card_sub: Label
var _vignette: ColorRect
var _vig_mat: ShaderMaterial
var _damage: float = 0.0
var _card_t: float = 0.0
var _pulse_t: float = 0.0
var _last_cur: int = -1

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.85, 0.05, 0.04);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = clamp(length(p * vec2(0.9, 1.0)) - 0.35, 0.0, 1.0);
	COLOR = vec4(tint, smoothstep(0.0, 1.0, d) * intensity * 0.9);
}
"""


func _init() -> void:
	layer = 5
	name = "Hud"


func _ready() -> void:
	_build()
	_connect_events()
	_sync_from_game()


# ───────────────────────── construction ─────────────────────────
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = Shader.new()
	sh.code = VIGNETTE_SHADER
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = sh
	_vignette.material = _vig_mat
	_root.add_child(_vignette)

	crosshair = Crosshair.new()
	_root.add_child(crosshair)

	# bottom-left: health + lives
	var bl: PanelContainer = PanelContainer.new()
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 32
	bl.offset_bottom = -32
	bl.offset_top = -150
	bl.offset_right = 380
	bl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(bl)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	bl.add_child(v)
	var hrow: HBoxContainer = HBoxContainer.new()
	hrow.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_child(hrow)
	hrow.add_child(UITheme.label("HP", 18, UITheme.TEXT_DIM))
	_health_label = UITheme.label("100", 56, UITheme.TEXT)
	hrow.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.min_value = 0
	_health_bar.max_value = 100
	_health_bar.custom_minimum_size = Vector2(0, 8)
	_health_bar.add_theme_stylebox_override("background", UITheme.box(Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 4, 0, Vector2.ZERO))
	_health_bar.add_theme_stylebox_override("fill", UITheme.box(UITheme.OK, Color(0, 0, 0, 0), 4, 0, Vector2.ZERO))
	v.add_child(_health_bar)
	_lives_row = HBoxContainer.new()
	_lives_row.add_theme_constant_override("separation", 3)
	v.add_child(_lives_row)

	# bottom-right: weapon + ammo
	var br: PanelContainer = PanelContainer.new()
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	br.offset_right = -32
	br.offset_bottom = -32
	br.offset_left = -380
	br.offset_top = -150
	br.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	br.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(br)
	var bv: VBoxContainer = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	br.add_child(bv)
	var wrow: HBoxContainer = HBoxContainer.new()
	bv.add_child(wrow)
	_weapon_icon = HudIcon.make(HudIcon.Kind.WEAPON, 1, Vector2(64, 32), UITheme.ACCENT)
	wrow.add_child(_weapon_icon)
	_weapon_label = UITheme.label("Hairball Pistol", 18, UITheme.TEXT_DIM)
	_weapon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrow.add_child(_weapon_label)
	var arow: HBoxContainer = HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_END
	arow.add_theme_constant_override("separation", 6)
	bv.add_child(arow)
	_ammo_label = UITheme.label("16", 56, UITheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	arow.add_child(_ammo_label)
	_reserve_label = UITheme.label("/ 0", 26, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	arow.add_child(_reserve_label)

	# top-right: score + keys
	var tr: PanelContainer = PanelContainer.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_right = -32
	tr.offset_top = 28
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_root.add_child(tr)
	var tv: HBoxContainer = HBoxContainer.new()
	tv.add_theme_constant_override("separation", 14)
	tr.add_child(tv)
	_key_gold = HudIcon.make(HudIcon.Kind.KEY, 0, Vector2(34, 24), Color(1.0, 0.82, 0.25))
	_key_silver = HudIcon.make(HudIcon.Kind.KEY, 0, Vector2(34, 24), Color(0.78, 0.86, 1.0))
	tv.add_child(_key_gold)
	tv.add_child(_key_silver)
	tv.add_child(UITheme.label("SCORE", 14, UITheme.TEXT_DIM))
	_score_label = UITheme.label("0", 30, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.custom_minimum_size = Vector2(110, 0)
	tv.add_child(_score_label)

	# toasts (left, above health)
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_toasts.offset_left = 32
	_toasts.offset_bottom = -200
	_toasts.offset_top = -450
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 6)
	_root.add_child(_toasts)

	# level name card
	_card = Control.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.offset_top = 120
	_card.modulate.a = 0.0
	_root.add_child(_card)
	var cv: VBoxContainer = VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(cv)
	_card_sub = UITheme.label("", 20, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	_card_title = UITheme.label("", 54, UITheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	cv.add_child(_card_sub)
	cv.add_child(_card_title)
	_rebuild_lives()


func _rebuild_lives() -> void:
	for c: Node in _lives_row.get_children():
		c.queue_free()
		_lives_row.remove_child(c)
	var total: int = maxi(lives, 9)
	for i: int in total:
		_lives_row.add_child(HudIcon.make(HudIcon.Kind.LIFE, 0 if i < lives else 1, Vector2(26, 26), UITheme.ACCENT))


# ───────────────────────── signals ─────────────────────────
func _connect_events() -> void:
	Events.health_changed.connect(set_health)
	Events.ammo_changed.connect(set_ammo)
	Events.weapon_changed.connect(set_weapon)
	Events.score_changed.connect(set_score)
	Events.key_taken.connect(func(c: String) -> void: set_key(c, true))
	Events.player_hurt.connect(on_hurt)
	Events.pickup_taken.connect(_on_pickup)
	Events.message.connect(toast)
	Events.enemy_killed.connect(func(_k: String, _p: Vector3) -> void: crosshair.hit(true))
	Events.secret_found.connect(func() -> void: toast("A secret!", UITheme.ACCENT))
	Events.level_loaded.connect(_on_level_loaded)
	if Events.has_signal("hit_marker"):
		Events.connect("hit_marker", func(kill: bool, head: bool) -> void: crosshair.hit(kill, head))
	if Events.has_signal("crosshair_spread"):
		Events.connect("crosshair_spread", func(rad: float) -> void: crosshair.set_spread_rad(rad))


func _sync_from_game() -> void:
	if not is_inside_tree():
		return
	score = Game.score
	lives = Game.lives
	var lo: Dictionary = Game.loadout
	if lo.has("health"):
		health = int(lo["health"])
	set_score(score)
	set_health(health, lives)
	set_weapon(weapon_id)


func set_health(hp: int, new_lives: int) -> void:
	if hp < health and hp > 0:
		_damage = maxf(_damage, 0.35)
	health = hp
	if new_lives != lives:
		lives = new_lives
		_rebuild_lives()
	_health_label.text = str(maxi(hp, 0))
	_health_bar.max_value = maxf(100.0, hp)
	_health_bar.value = hp
	var col: Color = UITheme.OK if hp > 60 else (UITheme.ACCENT if hp > 30 else UITheme.DANGER)
	_health_label.add_theme_color_override("font_color", col if hp <= 30 else UITheme.TEXT)
	(_health_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col


func set_ammo(cur: int, reserve: int) -> void:
	if _last_cur >= 0 and cur < _last_cur:
		crosshair.kick(9.0)
	_last_cur = cur
	cur_ammo = cur
	reserve_ammo = reserve
	_refresh_ammo()


func _refresh_ammo() -> void:
	var melee: bool = _weapon_def().get("ammo", "") == ""
	_ammo_label.text = "--" if melee else str(cur_ammo)
	_reserve_label.text = "" if melee else "/ %d" % reserve_ammo
	var low: bool = not melee and cur_ammo <= 3
	_ammo_label.add_theme_color_override("font_color", UITheme.DANGER if low else UITheme.TEXT)


func _weapon_def() -> Dictionary:
	for w: Dictionary in Defs.WEAPONS:
		if w["id"] == weapon_id:
			return w
	return {}


func set_weapon(id: String) -> void:
	weapon_id = id
	var slot: int = 0
	for i: int in Defs.WEAPONS.size():
		if Defs.WEAPONS[i]["id"] == id:
			slot = i
	_weapon_icon.set_slot(slot)
	_weapon_label.text = String(_weapon_def().get("name", id))
	_last_cur = -1
	_refresh_ammo()


func set_score(s: int) -> void:
	score = s
	_score_label.text = str(s)


func set_key(color: String, have: bool) -> void:
	keys[color] = have
	_key_gold.modulate.a = 1.0 if keys["gold"] else 0.18
	_key_silver.modulate.a = 1.0 if keys["silver"] else 0.18


func on_hurt(dmg: int) -> void:
	_damage = clampf(_damage + float(dmg) / 40.0, 0.0, 1.0)


func _on_pickup(kind: String, _amount: int) -> void:
	var item: Dictionary = Defs.ITEMS.get(kind, {})
	toast(String(item.get("msg", kind.capitalize())), UITheme.ACCENT)


func _on_level_loaded(id: String) -> void:
	set_key("gold", false)
	set_key("silver", false)
	_sync_from_game()
	show_card(Defs.level_name(id), "LEVEL %d" % (Defs.level_index(id) + 1))


func toast(text: String, color: Color = UITheme.TEXT) -> void:
	if _toasts == null:
		return
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.05, 0.07, 0.72), Color(color, 0.5), 8, 1, Vector2(14, 6)))
	p.add_child(UITheme.label(text, 20, color))
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toasts.add_child(p)
	while _toasts.get_child_count() > MAX_TOASTS:
		var old: Node = _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw: Tween = p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func show_card(title: String, sub: String = "") -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card_t = 3.4


# ───────────────────────── per-frame ─────────────────────────
func _process(dt: float) -> void:
	_damage = move_toward(_damage, 0.0, dt * 0.9)
	var low: float = 0.0
	if health > 0 and health <= 30:
		_pulse_t += dt * 4.0
		low = (0.22 + 0.12 * sin(_pulse_t)) * (1.0 - health / 30.0 * 0.5)
	_vig_mat.set_shader_parameter("intensity", clampf(_damage + low, 0.0, 1.0))
	if _card_t > 0.0:
		_card_t -= dt
		_card.modulate.a = clampf(minf(_card_t, 3.4 - _card_t) * 2.5, 0.0, 1.0)
