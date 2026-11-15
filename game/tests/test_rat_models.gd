extends "res://tests/test_case.gd"
## Rat enemy models (owner: model-rats): every rat_<kind>.glb imports, has the shared rig, all clips,
## LOD0/LOD1 meshes within the triangle budget, and roughly the contract height.

const KINDS: Dictionary = {
	"mouse": 1.4, "trooper": 1.7, "officer": 1.75, "sewer": 1.55, "panzer": 2.2, "boss": 3.2,
}
const BONES: PackedStringArray = [
	"Root", "Hips", "Spine", "Chest", "Neck", "Head", "Jaw", "LeftEar", "RightEar",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes", "RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
	"Tail1", "Tail2", "Tail3", "Tail4", "Tail5", "Tail6", "Tail7", "Tail8", "LeftMuzzle", "RightMuzzle",
]
const CLIPS: PackedStringArray = [
	"idle", "walk", "run", "aim_idle", "fire", "reload", "hurt", "death_a", "death_b", "take_cover", "melee", "taunt",
]


func _load(kind: String) -> Node3D:
	var path: String = "res://assets/models/rat_%s.glb" % kind
	if not check(ResourceLoader.exists(path), "%s exists (run the import first)" % path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if not check(ps != null, "%s loads as PackedScene" % path):
		return null
	return ps.instantiate() as Node3D


func _tris(mi: MeshInstance3D) -> int:
	var n: int = 0
	var m: Mesh = mi.mesh
	for s: int in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func test_all_rats() -> void:
	for kind: String in KINDS:
		var root: Node3D = _load(kind)
		if root == null:
			continue
		var skels: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
		if check(skels.size() == 1, "%s: one Skeleton3D" % kind):
			var sk: Skeleton3D = skels[0]
			for b: String in BONES:
				check(sk.find_bone(b) >= 0, "%s: bone %s" % [kind, b])
		var aps: Array[Node] = root.find_children("*", "AnimationPlayer", true, false)
		if check(aps.size() == 1, "%s: AnimationPlayer" % kind):
			var ap: AnimationPlayer = aps[0]
			var want: PackedStringArray = CLIPS.duplicate()
			if kind == "boss":
				want.append_array(PackedStringArray(["charge", "slam"]))
			for c: String in want:
				if check(ap.has_animation(c), "%s: clip %s" % [kind, c]):
					check(ap.get_animation(c).length > 0.05, "%s: clip %s has length" % [kind, c])
		var lod0: int = 0
		var lod1: int = 0
		var top: float = 0.0
		var slots: Dictionary = {}
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			var t: int = _tris(mi)
			if String(mi.name).contains("LOD1"):
				lod1 += t
			else:
				lod0 += t
				if String(mi.name).contains("LOD0"):
					top = maxf(top, mi.get_aabb().end.y)
			for s: int in mi.mesh.get_surface_count():
				var mat: Material = mi.mesh.surface_get_material(s)
				if mat != null:
					slots[mat.resource_name] = true
		var budget: int = 60000 if kind == "boss" else 40000
		check(lod0 > 5000 and lod0 <= budget, "%s: LOD0 tris %d within budget %d" % [kind, lod0, budget])
		check(lod1 > 2000 and lod1 <= 12000, "%s: LOD1 tris %d ~10k" % [kind, lod1])
		var h: float = KINDS[kind]
		check(top > h * 0.92 and top < h * 1.15, "%s: height %.2f vs %.2f" % [kind, top, h])
		for want_slot: String in ["fur", "skin"]:
			check(slots.has(want_slot), "%s: material slot %s" % [kind, want_slot])
		# facing: muzzle in front of the hips along -Z (contract section 4: -Z forward)
		if skels.size() == 1:
			var sk2: Skeleton3D = skels[0]
			var mz: Vector3 = sk2.get_bone_global_rest(sk2.find_bone("RightMuzzle")).origin
			var hp: Vector3 = sk2.get_bone_global_rest(sk2.find_bone("Hips")).origin
			check(mz.z < hp.z, "%s: faces -Z (muzzle z %.2f < hips z %.2f)" % [kind, mz.z, hp.z])
		root.free()
