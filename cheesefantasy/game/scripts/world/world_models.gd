class_name WorldModels
extends RefCounted
## Model loading with graceful fallbacks. Uses ActorFactory when present, else loads the
## glb directly, else builds a procedural placeholder so the overworld always runs.

static var _scene_cache: Dictionary = {}

static func glb_path(id: String) -> String:
	return "res://assets/models/%s.glb" % id

static func has_model(id: String) -> bool:
	return ResourceLoader.exists(glb_path(id))

static func _load_scene(id: String) -> PackedScene:
	if _scene_cache.has(id):
		return _scene_cache[id]
	var ps: PackedScene = null
	if has_model(id):
		var res: Variant = load(glb_path(id))
		if res is PackedScene:
			ps = res
	_scene_cache[id] = ps
	return ps

## Character/animal style spawn. height > 0 rescales to that standing height.
static func spawn_actor(id: String, height: float = 0.0, tint: Color = Color(0.85, 0.65, 0.35)) -> Node3D:
	var af_path := "res://scripts/actors/actor_factory.gd"
	if ResourceLoader.exists(af_path):
		var af: Variant = load(af_path)
		if af != null and af.has_method("spawn"):
			var n: Variant = af.call("spawn", id, height)
			if n is Node3D:
				return n
	var ps := _load_scene(id)
	if ps != null:
		var root := Node3D.new()
		root.name = id
		var inst := ps.instantiate()
		root.add_child(inst)
		if height > 0.0 and inst is Node3D:
			var bb := _local_bounds(inst as Node3D)
			if bb.size.y > 0.01:
				(inst as Node3D).scale = Vector3.ONE * (height / bb.size.y)
		return root
	return placeholder_actor(id, height if height > 0.0 else 1.2, tint)

static func _local_bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var bb := xf * m.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out

static func placeholder_actor(id: String, height: float, tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var col := tint
	var h := float(id.hash() % 360) / 360.0
	if id.begins_with("enemy") or id.begins_with("boss"):
		col = Color.from_hsv(0.3 + h * 0.2, 0.5, 0.45)
	elif id.begins_with("animal"):
		col = Color.from_hsv(0.08 + h * 0.1, 0.25, 0.9)
	else:
		col = Color.from_hsv(h, 0.45, 0.85)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = height * 0.22
	cap.height = height * 0.75
	body.mesh = cap
	body.material_override = mat
	body.position.y = cap.height * 0.5
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = height * 0.17
	sph.height = sph.radius * 2.0
	head.mesh = sph
	head.material_override = mat
	head.position.y = height * 0.82
	root.add_child(head)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.08, 0.08, 0.14) * height
	nose.mesh = nb
	nose.position = Vector3(0, height * 0.8, height * 0.19)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = col.darkened(0.35)
	nose.material_override = nm
	root.add_child(nose)
	var lab := Label3D.new()
	lab.text = id.replace("_", " ")
	lab.font_size = 28
	lab.pixel_size = 0.004
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.no_depth_test = true
	lab.position.y = height + 0.25
	lab.modulate = Color(1, 1, 1, 0.85)
	root.add_child(lab)
	return root

static func find_anim_player(n: Node) -> AnimationPlayer:
	var found := n.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer if found.size() > 0 else null

## Play a clip with fallbacks (via ActorFactory-style play() or a raw AnimationPlayer).
static func play(n: Node, anim: String, speed: float = 1.0) -> void:
	if n == null:
		return
	if n.has_method("play"):
		n.call("play", anim)
		return
	var ap := find_anim_player(n)
	if ap == null:
		return
	var clip := anim
	if not ap.has_animation(clip):
		for cand in [anim, "idle", "Idle"]:
			if ap.has_animation(cand):
				clip = cand
				break
		if not ap.has_animation(clip):
			return
	if ap.current_animation != clip or not ap.is_playing():
		ap.play(clip, 0.2, speed)
		var a := ap.get_animation(clip)
		if a != null and clip in ["idle", "walk", "run"]:
			a.loop_mode = Animation.LOOP_LINEAR
