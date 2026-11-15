class_name EndingScreen
extends CanvasLayer
## Ending: the party and the four spirit-cats pose in front of the barn at sunset while the story plays out,
## then "The Last Wheel returns" and a scrolling credits roll, then a summary and a way back to the title.

signal finished

const PAGES: Array = [
	"The Rat King falls, and with him the throne of stolen rinds.\n\nBehind it, wrapped in cobwebs and one very smug rat's laundry, sits the Last Wheel: a hundred years old and still perfectly ripe.",
	"Fennel, Madame Brie, Clover and Maple carry it down the hill between them.\n\nThe Rot fades from the wheat field by field. Blue-green turns to gold. The mould blobs wander off, embarrassed.",
	"Farmer Gouda cuts the first slice. One taste heals the whole valley.\n\nOn the hill behind the Rainbow Orchard, four old cats purr in the long grass: Jesse, Tripper, Samantha and Spooky, who would have wanted a slice too.",
]
const CREDITS: String = "CHEESE FANTASY\nThe Last Wheel\n\n\nHeroes\nFennel, Apprentice Cheesemonger\nMadame Brie\nClover\nMaple\n\n\nThe Nine Lives Spirits\nJesse, Silver Stalker\nTripper, Stripe Quake\nSamantha, Snow Angel\nSpooky, Midnight Walker\n\n\nCurdlewick Farm\nFarmer Gouda and the whole herd\nThe Cheesemonger, the Cook, Granny and the Kid\n\n\nBuilt with Godot Engine\nMade with way too much cheese\n\n\nIn loving memory of four good cats\n\n\nThank you for playing"
const HEROES: Array = ["hero_fennel", "hero_brie", "hero_clover", "hero_maple"]
const SPIRITS: Array = ["summon_jesse", "summon_tripper", "summon_samantha", "summon_spooky"]

var _page: int = 0
var _label: Label
var _btn: Button
var _root: Control
var _chars: float = 0.0
var _panel: PanelContainer
var _title: Label
var _credits: Label
var _credits_tween: Tween
var _cam: Camera3D
var _t: float = 0.0
var _phase: String = "story"  # story | credits | summary


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = MenuStyle.theme()
	add_child(_root)
	_root.add_child(_build_scene())
	var shade: ColorRect = ColorRect.new()  # vignette strip under the text
	shade.color = Color(0.1, 0.04, 0.02, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	_title = MenuStyle.label("", 64, Color(1.0, 0.86, 0.35))
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.offset_top = 50
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.02))
	_title.modulate.a = 0.0
	_root.add_child(_title)

	_credits = MenuStyle.label(CREDITS, 38, Color(1.0, 0.95, 0.8))
	_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.add_theme_constant_override("outline_size", 10)
	_credits.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.02))
	_credits.anchor_left = 0.62
	_credits.anchor_right = 0.95
	_credits.visible = false
	_root.add_child(_credits)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.12
	_panel.anchor_right = 0.88
	_panel.anchor_top = 0.7
	_panel.anchor_bottom = 0.97
	_root.add_child(_panel)
	var v: VBoxContainer = MenuStyle.vbox(16)
	_panel.add_child(v)
	_label = MenuStyle.label("", 30, MenuStyle.INK, true)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(_label)
	_btn = MenuStyle.button("Continue", 300)
	_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn.pressed.connect(_next)
	v.add_child(_btn)
	_btn.grab_focus.call_deferred()
	var audio: Node = MenuStyle.auto("Audio")
	if audio != null:
		audio.play_music("victory")
	_set_page()


# ------------------------------------------------------------------ 3D diorama
func _build_scene() -> SubViewportContainer:
	var svc: SubViewportContainer = SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp: SubViewport = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)

	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.12, 0.4)
	sky_mat.sky_horizon_color = Color(1.0, 0.55, 0.25)
	sky_mat.ground_horizon_color = Color(0.95, 0.5, 0.25)
	sky_mat.ground_bottom_color = Color(0.3, 0.2, 0.15)
	sky_mat.sun_angle_max = 25.0
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.6, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.65, 0.4)
	env.fog_density = 0.003
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, -150, 0)  # low sun, behind the barn side, rim-lighting the cast
	sun.light_color = Color(1.0, 0.6, 0.3)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	vp.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 20, 0)
	fill.light_color = Color(0.7, 0.75, 1.0)
	fill.light_energy = 0.55
	vp.add_child(fill)

	var ground: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.62, 0.25)
	ground.material_override = gm
	vp.add_child(ground)

	_place(vp, "world_barn", Vector3(-1, 0, -13), 8.5, 0.0)
	_place(vp, "world_silo", Vector3(-10, 0, -15), 10.0, 0.0)
	_place(vp, "world_windmill", Vector3(15, 0, -22), 11.0, 0.0)
	_place(vp, "world_tree_oak", Vector3(9, 0, -9), 6.0, 0.0)
	_place(vp, "world_tree_oak", Vector3(-14, 0, -6), 5.5, 90.0)
	_place(vp, "world_haybale", Vector3(5, 0, -6), 1.1, 20.0)
	_place(vp, "world_wheel_cheese", Vector3(0, 0, 2.4), 0.8, 0.0)  # the Last Wheel, front and centre
	_place(vp, "world_fence", Vector3(-6, 0, -4), 1.2, 90.0)
	for i: int in 4:
		var x: float = -3.6 + 2.4 * float(i)
		var rig: Node3D = _place(vp, HEROES[i], Vector3(x, 0, 0.0 + (0.5 if i == 1 or i == 2 else 0.0)), 1.5, 180.0 + (12.0 - 8.0 * float(i)))
		if rig != null and rig.has_method("play"):
			rig.call("play", "victory")
	for i: int in 4:
		var x2: float = -5.4 + 3.6 * float(i)
		var rig2: Node3D = _place(vp, SPIRITS[i], Vector3(x2, 0, -3.8), 3.0, 180.0 + (10.0 - 6.0 * float(i)))
		if rig2 != null and rig2.has_method("play"):
			rig2.call("play", "idle")
	_cam = Camera3D.new()
	_cam.fov = 52.0
	_cam.far = 300.0
	vp.add_child(_cam)
	_cam.position = Vector3(0, 1.6, 8.5)
	_cam.look_at(Vector3(0, 1.5, -4))
	_cam.current = true
	return svc


func _place(parent: Node, model_id: String, pos: Vector3, height: float, yaw_deg: float) -> Node3D:
	if not ActorFactory.has_model(model_id) and not model_id.begins_with("hero_") and not model_id.begins_with("summon_"):
		return null
	var rig: Node3D = ActorFactory.spawn(model_id, height)
	parent.add_child(rig)
	rig.position = pos
	rig.rotation_degrees.y = yaw_deg
	return rig


# ------------------------------------------------------------------ flow
func _set_page() -> void:
	if _page < PAGES.size():
		_phase = "story"
		_label.text = PAGES[_page]
		_label.visible_ratio = 0.0
		_chars = 0.0
	else:
		_start_credits()


func _start_credits() -> void:
	_phase = "credits"
	_panel.visible = false
	_title.text = "The Last Wheel returns"
	var tw: Tween = create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 2.0)
	_credits.visible = true
	_credits.position.y = 1080.0
	var end_y: float = -_credits.get_minimum_size().y - 100.0
	_credits_tween = create_tween()
	_credits_tween.tween_interval(2.5)
	_credits_tween.tween_property(_credits, "position:y", end_y, 38.0)
	_credits_tween.tween_callback(_show_summary)
	# Skip button stays reachable at the bottom while the credits roll.
	_btn.get_parent().remove_child(_btn)
	_root.add_child(_btn)
	_btn.text = "Skip credits"
	_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_btn.offset_left = -340
	_btn.offset_right = -40
	_btn.offset_top = -100
	_btn.offset_bottom = -40
	_btn.grab_focus.call_deferred()


func _show_summary() -> void:
	if _phase == "summary":
		return
	_phase = "summary"
	if _credits_tween != null:
		_credits_tween.kill()
	_credits.visible = false
	_title.text = "The Last Wheel is home."
	_title.modulate.a = 1.0
	var secs: int = int(GameState.play_time)
	_panel.visible = true
	_panel.anchor_top = 0.74
	_label.text = "Play time  %d:%02d:%02d      Party level  %d\nSpirits awakened  %d / 4      Dishes mastered  %d" % [
		secs / 3600, (secs / 60) % 60, secs % 60, Story.party_level(), GameState.summons.size(), _dishes()]
	_label.visible_ratio = 1.0
	_btn.get_parent().remove_child(_btn)
	_panel.get_child(0).add_child(_btn)
	_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_btn.text = "Return to title"
	_btn.grab_focus.call_deferred()


func _dishes() -> int:
	var n: int = 0
	for k: Variant in GameState.flags.keys():
		if str(k).begins_with("dish_tier_"):
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	if _cam != null:  # slow dolly + sway
		_cam.position = Vector3(sin(_t * 0.15) * 1.2, 1.6 + sin(_t * 0.1) * 0.1, 8.5 - minf(_t * 0.08, 1.5))
		_cam.look_at(Vector3(0, 1.5, -4))
	if _phase == "story" and _label.visible_ratio < 1.0:
		_chars += delta * 55.0
		_label.visible_characters = int(_chars)


func _next() -> void:
	match _phase:
		"story":
			if _label.visible_ratio < 1.0:
				_label.visible_ratio = 1.0
				return
			_page += 1
			_set_page()
		"credits":
			_show_summary()
		_:
			finished.emit()
			queue_free()
