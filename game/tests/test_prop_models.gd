extends RatTestCase
## Weapon and prop glb checks (owner: model-weapons-props): files exist, load, weapons have Muzzle and Grip.

const WEAPONS: Array[String] = ["claws", "pistol", "gatling", "yarn", "laser"]
const PROPS: Array[String] = ["cheese_wheel", "cheese_wedge", "brie_wheel", "cheese_crown", "ammo_box", "ammo_clip", "battery", "yarn_ammo",
	"fish_treat", "tuna", "catnip", "key_gold", "key_silver", "crate", "barrel", "shelf", "table", "chair", "lamp", "torch", "banner",
	"sandbags", "pipes", "rug", "statue", "pillar", "doorway", "chandelier", "candelabra", "cheese_stack", "cauldron", "mousetrap"]


func _inst(path: String) -> Node:
	if not check(ResourceLoader.exists(path), "missing " + path):
		return null
	var ps: PackedScene = load(path) as PackedScene
	if not check(ps != null, "not loadable " + path):
		return null
	return ps.instantiate()


func test_weapons_have_muzzle_and_grip() -> void:
	for id: String in WEAPONS:
		var n: Node = _inst("res://assets/models/weapon_%s.glb" % id)
		if n == null:
			continue
		check(n.find_child("Muzzle", true, false) != null, id + " Muzzle")
		check(n.find_child("Grip", true, false) != null, id + " Grip")
		check(_has_mesh(n), id + " has mesh")
		n.free()


func test_props_load_with_mesh() -> void:
	for id: String in PROPS:
		var n: Node = _inst("res://assets/models/prop_%s.glb" % id)
		if n == null:
			continue
		check(_has_mesh(n), id + " has mesh")
		n.free()


func _has_mesh(n: Node) -> bool:
	if n is MeshInstance3D:
		return true
	for c: Node in n.get_children():
		if _has_mesh(c):
			return true
	return false
