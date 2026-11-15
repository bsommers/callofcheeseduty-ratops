class_name ActorFactory
extends RefCounted
## Spawns character/creature/prop models by id (owner rpg-core; ARCHITECTURE section 6).
##   var rig: ActorRig = ActorFactory.spawn("hero_fennel", 1.2)   # height 0 = native size
##   rig.play("attack")
## Loads res://assets/models/<model_id>.glb; if missing (or broken) builds a procedural placeholder
## (coloured capsule + head + name label) that has every standard clip, so the game always runs.

const MODEL_DIR: String = "res://assets/models/"
const ALL_CLIPS: Array = ["idle", "walk", "run", "attack", "cast", "hurt", "down", "victory", "defend",
	"summon_intro", "special", "outro", "intro"]

static var _cache: Dictionary = {}


static func model_path(model_id: String) -> String:
	return MODEL_DIR + model_id + ".glb"


static func has_model(model_id: String) -> bool:
	return ResourceLoader.exists(model_path(model_id))


## Returns an ActorRig (a Node3D) wrapping the model, origin at feet. height > 0 rescales to that height (metres).
static func spawn(model_id: String, height: float = 0.0) -> Node3D:
	var rig: ActorRig = ActorRig.new()
	rig.name = model_id
	var root: Node3D = null
	var path: String = model_path(model_id)
	if ResourceLoader.exists(path):
		var ps: PackedScene = _cache.get(path) as PackedScene
		if ps == null:
			ps = load(path) as PackedScene
			_cache[path] = ps
		if ps != null:
			root = ps.instantiate() as Node3D
	var is_ph: bool = root == null
	if is_ph:
		root = make_placeholder(model_id)
	rig.setup(model_id, root, is_ph)
	var aabb: AABB = measure(root)
	rig.height = aabb.size.y if aabb.size.y > 0.01 else 1.0
	if height > 0.0 and aabb.size.y > 0.01:
		var s: float = height / aabb.size.y
		root.scale = Vector3.ONE * s
		rig.height = height
	rig.play("idle", 0.0)
	return rig


## Combined local-space AABB of all visual instances under `n`.
static func measure(n: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for v: Node in n.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = v as VisualInstance3D
		if vi is Label3D:
			continue
		var xf: Transform3D = Transform3D.IDENTITY
		var p: Node = vi
		while p != null and p != n:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var box: AABB = xf * vi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _color_for(model_id: String) -> Color:
	var table: Dictionary = {"hero_fennel": Color(0.95, 0.55, 0.2), "hero_brie": Color(0.9, 0.85, 0.75),
		"hero_clover": Color(0.6, 0.5, 0.4), "hero_maple": Color(0.45, 0.65, 0.9)}
	if table.has(model_id):
		return table[model_id]
	if model_id.begins_with("summon_"):
		return Color(0.8, 0.9, 1.0, 0.6)
	if model_id.begins_with("boss_"):
		return Color(0.4, 0.2, 0.45)
	if model_id.begins_with("enemy_"):
		return Color(0.45, 0.5, 0.4)
	var h: float = float(hash(model_id) % 1000) / 1000.0
	return Color.from_hsv(h, 0.45, 0.85)


static func _height_for(model_id: String) -> float:
	if model_id.begins_with("summon_"):
		return 3.0
	if model_id.begins_with("boss_"):
		return 2.6
	if model_id.begins_with("world_"):
		return 1.5
	if model_id.begins_with("animal_") or model_id.begins_with("enemy_"):
		return 0.9
	return 1.3


## Procedural stand-in: capsule body, sphere head, eyes, floating name. Includes an AnimationPlayer with every clip.
static func make_placeholder(model_id: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Placeholder"
	var h: float = _height_for(model_id)
	var col: Color = _color_for(model_id)
	var body_pivot: Node3D = Node3D.new()
	body_pivot.name = "Body"
	root.add_child(body_pivot)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(col.r, col.g, col.b)
		mat.emission_energy_multiplier = 0.6
	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = h * 0.22
	cap.height = h * 0.7
	body.mesh = cap
	body.material_override = mat
	body.position.y = h * 0.35
	body_pivot.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = h * 0.17
	sph.height = h * 0.34
	head.mesh = sph
	head.material_override = mat
	head.position.y = h * 0.82
	body_pivot.add_child(head)
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.05, 0.05)
	for side: float in [-1.0, 1.0]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		var es: SphereMesh = SphereMesh.new()
		es.radius = h * 0.03
		es.height = h * 0.06
		eye.mesh = es
		eye.material_override = eye_mat
		eye.position = Vector3(side * h * 0.07, h * 0.85, h * 0.15)
		body_pivot.add_child(eye)
	var label: Label3D = Label3D.new()
	label.text = model_id.get_slice("_", 1).capitalize() if model_id.contains("_") else model_id
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = h * 1.12
	label.font_size = 48
	label.outline_size = 12
	label.pixel_size = 0.004
	root.add_child(label)
	root.add_child(_placeholder_player(h))
	return root


static func _placeholder_player(h: float) -> AnimationPlayer:
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib: AnimationLibrary = AnimationLibrary.new()
	# [clip, length, loop, [[time, position, rotation_deg_xyz]...]]
	var specs: Array = [
		["idle", 1.6, true, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.8, Vector3(0, h * 0.03, 0), Vector3.ZERO], [1.6, Vector3.ZERO, Vector3.ZERO]]],
		["walk", 0.6, true, [[0.0, Vector3.ZERO, Vector3(0, 0, -5)], [0.3, Vector3(0, h * 0.05, 0), Vector3(0, 0, 5)], [0.6, Vector3.ZERO, Vector3(0, 0, -5)]]],
		["run", 0.4, true, [[0.0, Vector3.ZERO, Vector3(10, 0, -6)], [0.2, Vector3(0, h * 0.1, 0), Vector3(10, 0, 6)], [0.4, Vector3.ZERO, Vector3(10, 0, -6)]]],
		["attack", 0.6, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.2, Vector3(0, 0, -h * 0.05), Vector3(-10, 0, 0)], [0.35, Vector3(0, 0, h * 0.4), Vector3(20, 0, 0)], [0.6, Vector3.ZERO, Vector3.ZERO]]],
		["cast", 0.9, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.45, Vector3(0, h * 0.15, 0), Vector3(0, 180, 0)], [0.9, Vector3.ZERO, Vector3(0, 360, 0)]]],
		["hurt", 0.4, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.1, Vector3(0, 0, -h * 0.12), Vector3(-15, 0, 0)], [0.4, Vector3.ZERO, Vector3.ZERO]]],
		["down", 0.6, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.6, Vector3(0, 0, -h * 0.2), Vector3(-85, 0, 0)]]],
		["victory", 0.8, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0, h * 0.35, 0), Vector3(0, 180, 0)], [0.8, Vector3.ZERO, Vector3(0, 360, 0)]]],
		["defend", 1.0, true, [[0.0, Vector3(0, -h * 0.05, 0), Vector3(-8, 0, 0)], [0.5, Vector3(0, -h * 0.07, 0), Vector3(-8, 0, 0)], [1.0, Vector3(0, -h * 0.05, 0), Vector3(-8, 0, 0)]]],
		["summon_intro", 1.5, false, [[0.0, Vector3(0, h * 0.8, 0), Vector3.ZERO], [1.5, Vector3.ZERO, Vector3(0, 360, 0)]]],
		["intro", 1.2, false, [[0.0, Vector3(0, h * 0.4, 0), Vector3.ZERO], [0.6, Vector3.ZERO, Vector3.ZERO], [1.2, Vector3(0, h * 0.1, 0), Vector3(-10, 0, 0)]]],
		["special", 1.2, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [0.4, Vector3(0, h * 0.3, 0), Vector3(-20, 0, 0)], [0.7, Vector3(0, 0, h * 0.5), Vector3(25, 0, 0)], [1.2, Vector3.ZERO, Vector3.ZERO]]],
		["outro", 1.0, false, [[0.0, Vector3.ZERO, Vector3.ZERO], [1.0, Vector3(0, h * 1.5, 0), Vector3(0, 180, 0)]]],
	]
	for sp: Array in specs:
		var a: Animation = Animation.new()
		a.length = float(sp[1])
		a.loop_mode = Animation.LOOP_LINEAR if sp[2] else Animation.LOOP_NONE
		var tp: int = a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(tp, NodePath("../Body"))
		var tr: int = a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(tr, NodePath("../Body"))
		for k: Array in sp[3]:
			a.position_track_insert_key(tp, float(k[0]), k[1])
			var r: Vector3 = k[2]
			a.rotation_track_insert_key(tr, float(k[0]), Quaternion.from_euler(Vector3(deg_to_rad(r.x), deg_to_rad(r.y), deg_to_rad(r.z))))
		lib.add_animation(sp[0], a)
	ap.add_animation_library("", lib)
	return ap
