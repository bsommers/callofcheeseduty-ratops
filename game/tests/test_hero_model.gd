extends "res://tests/test_case.gd"
## hero.glb (owner: model-hero): skeleton, clips, LODs, material slots, size.

const PATH: String = "res://assets/models/hero.glb"
const CLIPS: PackedStringArray = ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "jump", "fall", "land",
	"aim_idle", "aim_walk", "fire_pistol", "fire_rifle", "reload", "melee_slash", "hurt", "death_a", "death_b", "victory"]
const BONES: PackedStringArray = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "Jaw",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftIndexProximal", "LeftThumbMetacarpal",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand", "RightMiddleDistal",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
	"Tail1", "Tail6", "LeftEar", "RightEar", "LeftEye", "RightEye"]

var _root: Node3D


func _hero() -> Node3D:
	if _root == null:
		var ps: PackedScene = load(PATH)
		if ps != null:
			_root = ps.instantiate()
	return _root


func _find(n: Node, cls: String, out: Array) -> void:
	if n.is_class(cls):
		out.append(n)
	for c: Node in n.get_children():
		_find(c, cls, out)


func _tris(mi: MeshInstance3D) -> int:
	var t: int = 0
	for s: int in mi.mesh.get_surface_count():
		var arr: Array = mi.mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else arr[Mesh.ARRAY_VERTEX].size()) / 3
	return t


func test_loads_with_skeleton() -> void:
	var h: Node3D = _hero()
	if not check(h != null, "hero.glb loads"):
		return
	var sk: Array = []
	_find(h, "Skeleton3D", sk)
	if not eq(sk.size(), 1, "one Skeleton3D"):
		return
	var s: Skeleton3D = sk[0]
	for b: String in BONES:
		check(s.find_bone(b) >= 0, "bone " + b)


func test_all_clips_present() -> void:
	var h: Node3D = _hero()
	if h == null:
		return
	var aps: Array = []
	_find(h, "AnimationPlayer", aps)
	if not check(aps.size() >= 1, "AnimationPlayer"):
		return
	var ap: AnimationPlayer = aps[0]
	for c: String in CLIPS:
		if check(ap.has_animation(c), "clip " + c):
			var a: Animation = ap.get_animation(c)
			check(a.length > 0.1 and a.get_track_count() > 30, "clip %s has tracks" % c)


func test_lods_and_budget() -> void:
	var h: Node3D = _hero()
	if h == null:
		return
	var ms: Array = []
	_find(h, "MeshInstance3D", ms)
	var lod0: int = 0
	var lod1: int = 0
	var mats: Dictionary = {}
	for mi: MeshInstance3D in ms:
		check(mi.skin != null or mi.get_parent() is Skeleton3D, "%s skinned" % mi.name)
		if mi.name.ends_with("LOD1"):
			lod1 += _tris(mi)
		else:
			lod0 += _tris(mi)
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m != null:
				mats[m.resource_name] = true
	check(lod0 > 20000 and lod0 < 60000, "LOD0 tris %d in (20k, 60k)" % lod0)
	check(lod1 > 8000 and lod1 < 20000, "LOD1 tris %d ~15k" % lod1)
	for m: String in ["fur", "skin", "cloth_vest", "leather", "metal", "emblem"]:
		check(mats.has(m), "material slot " + m)


func test_height_about_1_9m() -> void:
	var h: Node3D = _hero()
	if h == null:
		return
	var ms: Array = []
	_find(h, "MeshInstance3D", ms)
	var top: float = -INF
	var bottom: float = INF
	for mi: MeshInstance3D in ms:
		var bb: AABB = mi.get_aabb()
		top = maxf(top, bb.end.y)
		bottom = minf(bottom, bb.position.y)
	check(bottom > -0.05 and bottom < 0.05, "feet at y=0 (%.3f)" % bottom)
	check(top > 1.8 and top < 2.0, "height %.3f ~1.9 m" % top)


func after_each() -> void:
	if _root != null:
		_root.free()
		_root = null
