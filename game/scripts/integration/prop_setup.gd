class_name PropSetup
extends RefCounted
## Replaces the level builder's decor placeholder cylinders with prop_*.glb models (owner: integ-lead).

const MAP: Dictionary = {
	"pillar": "prop_pillar", "candelabra": "prop_candelabra", "floor_lamp": "prop_lamp",
	"chandelier": "prop_chandelier", "crate": "prop_crate", "barrel": "prop_barrel",
	"flag_stand": "prop_banner", "cauldron": "prop_cauldron", "table_cheese": "prop_table",
	"cheese_stack": "prop_cheese_stack", "mousetrap": "prop_mousetrap", "bunk": "prop_shelf",
	"rat_armor": "prop_statue", "radio_desk": "prop_table", "glow_cheese": "prop_cheese_wedge",
}
const DIR: String = "res://assets/models/"


## Returns the number of placeholders replaced.
static func apply(level: Node) -> int:
	var n: int = 0
	for node: Node in level.find_children("Decor_*", "Node3D", true, false):
		var d: Node3D = node as Node3D
		if d.has_meta("prop_done"):
			continue
		var id: String = d.name.trim_prefix("Decor_")
		id = id.substr(0, id.rfind("_", id.rfind("_") - 1)) if id.count("_") >= 2 else id
		var path: String = DIR + str(MAP.get(id, "")) + ".glb"
		if not MAP.has(id) or not ResourceLoader.exists(path):
			continue
		var ph: MeshInstance3D = null
		for c: Node in d.get_children():
			if c is MeshInstance3D:
				ph = c as MeshInstance3D
				break
		if ph == null:
			continue
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			continue
		var prop: Node3D = ps.instantiate() as Node3D
		prop.name = "Prop"
		var top: float = ph.position.y + 0.8
		var hang: bool = ph.position.y > 1.5
		d.add_child(prop)
		var bb: AABB = _aabb(prop)
		prop.position.y = (top - bb.end.y) if hang else 0.0
		prop.rotation.y = float((int(d.position.x * 7.0) + int(d.position.z * 13.0)) % 4) * PI * 0.5 if not hang else 0.0
		ph.queue_free()
		d.set_meta("prop_done", true)
		n += 1
	return n


static func _aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		var b: AABB = m.mesh.get_aabb() if m.mesh != null else AABB()
		var t: Transform3D = m.transform
		var p: Node = m.get_parent()
		while p != null and p != root:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		b = t * b
		out = b if first else out.merge(b)
		first = false
	return out
