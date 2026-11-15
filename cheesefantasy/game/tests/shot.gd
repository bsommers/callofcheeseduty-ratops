extends Node
## Screenshot driver (owner rpg-core), launched by tools/shot.sh inside a private Xvfb (never the user's desktop).
## User args (after `--`): --target=<res://scene.tscn | model:<model_id> | title> --out=<abs.png> [--frames=N]
##   [--cam=x,y,z,yaw,pitch] [--fov=deg] [--start=<arg>] (calls root.start(arg) if the scene has start(), e.g.
##   BattleScene.start("meadow_grunts")) [--anim=clip] (model: targets) [--yaw=deg] (model: turntable angle).
## Renders N frames, saves the viewport to PNG, prints SHOT_OK <path> <w>x<h> mean=<0..1> std=<0..1>, quits 0 (1 on failure).

var _args: Dictionary = {}
var _frames: int = 90
var _frame: int = 0
var _out: String = ""


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	_out = str(_args.get("out", ""))
	var target: String = str(_args.get("target", ""))
	_frames = maxi(2, int(_args.get("frames", "90")))
	if _out == "" or target == "":
		_fail("usage: --target=<scene|model:id> --out=<png>")
		return
	var root: Node = null
	if target.begins_with("model:"):
		root = _model_stage(target.substr(6))
	else:
		var path: String = "res://scenes/ui/title.tscn" if target == "title" else target
		if not ResourceLoader.exists(path):
			_fail("no such scene " + path)
			return
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			_fail("cannot load " + path)
			return
		root = ps.instantiate()
	add_child(root)
	if _args.has("start") and root.has_method("start"):
		root.call("start", str(_args.start))
	if _args.has("cam"):
		_place_camera(str(_args.cam))


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < _frames:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_fail("empty viewport image")
		return
	var err: Error = img.save_png(_out)
	if err != OK:
		_fail("save_png failed: %d" % err)
		return
	var st: Vector2 = image_stats(img)
	print("SHOT_OK %s %dx%d mean=%.3f std=%.3f" % [_out, img.get_width(), img.get_height(), st.x, st.y])
	get_tree().quit(0)


## Mean and standard deviation of luminance over a 64x36 downsample (std < 0.01 = blank frame).
static func image_stats(src: Image) -> Vector2:
	var img: Image = src.duplicate() as Image
	img.resize(64, 36, Image.INTERPOLATE_BILINEAR)
	var sum: float = 0.0
	var sq: float = 0.0
	var n: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			var l: float = img.get_pixel(x, y).get_luminance()
			sum += l
			sq += l * l
			n += 1
	var mean: float = sum / n
	return Vector2(mean, sqrt(maxf(0.0, sq / n - mean * mean)))


func _model_stage(model_id: String) -> Node3D:
	var stage: Node3D = Node3D.new()
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: Sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	stage.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	stage.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(20, 20)
	ground.mesh = pm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.6, 0.3)
	ground.material_override = gm
	stage.add_child(ground)
	var rig: Node3D = ActorFactory.spawn(model_id)
	rig.rotation_degrees.y = float(_args.get("yaw", "20"))
	stage.add_child(rig)
	if _args.has("anim") and rig.has_method("play"):
		rig.call("play", str(_args.anim))
	var h: float = maxf(0.3, float(rig.get("height")))
	var cam: Camera3D = Camera3D.new()
	cam.fov = float(_args.get("fov", "40"))
	cam.position = Vector3(0, h * 0.6, h * 2.6 + 0.5)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, h * 0.5, 0))
	cam.current = true
	return stage


func _place_camera(spec: String) -> void:
	var p: PackedStringArray = spec.split(",")
	if p.size() < 5:
		return
	var cam: Camera3D = Camera3D.new()
	cam.fov = float(_args.get("fov", "70"))
	add_child(cam)
	cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	cam.rotation_degrees = Vector3(float(p[4]), float(p[3]), 0)
	cam.current = true


func _fail(msg: String) -> void:
	push_error("SHOT_FAIL " + msg)
	print("SHOT_FAIL " + msg)
	get_tree().quit(1)
