class_name HeroSetup
extends RefCounted
## Post-processing for hero.glb once it is the RatPlayer model (owner: integ-lead):
## loop flags on looping clips, hide LOD1 meshes, fur shells on the `fur` slot, weapon hand attachment.

const LOOPING: PackedStringArray = ["idle", "walk", "run", "sprint", "crouch_idle", "crouch_walk", "fall", "aim_idle", "aim_walk", "victory"]
const LENGTH_MASK: String = "res://assets/models/hero_fur_length.png"
const COLOR_MAP: String = "res://assets/models/hero_body_albedo.png"
const FUR_NAME: String = "fur_rat_brown"
const HAND_BONE: String = "RightHand"


static func apply(player: RatPlayer) -> void:
	var model: Node = player.model
	if model == null:
		return
	model.rotation.y = 0.0  # hero.glb already faces -Z (player.gd rotates by PI, which made it face backwards)
	set_loops(model)
	hide_lod1(model)
	apply_fur(model)
	attach_hand(model)


static func set_loops(model: Node) -> int:
	var n: int = 0
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return 0
	for a: String in ap.get_animation_list():
		var short: String = a.get_slice("/", a.get_slice_count("/") - 1).get_slice("|", a.get_slice_count("|") - 1)
		var anim: Animation = ap.get_animation(a)
		if anim != null and LOOPING.has(short):
			anim.loop_mode = Animation.LOOP_LINEAR
			n += 1
	return n


static func hide_lod1(model: Node) -> int:
	var n: int = 0
	for mi: Node in model.find_children("*_LOD1", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visible = false
		n += 1
	return n


## Fur shells on every surface whose material slot is named `fur`. Returns the number of surfaces.
static func apply_fur(model: Node) -> int:
	var n: int = 0
	var base: ShaderMaterial = RatMaterials.get_material(FUR_NAME) as ShaderMaterial
	if base == null:
		return 0
	base = base.duplicate() as ShaderMaterial
	if ResourceLoader.exists(LENGTH_MASK):
		base.set_shader_parameter("length_mask", load(LENGTH_MASK))
	if ResourceLoader.exists(COLOR_MAP):
		base.set_shader_parameter("color_map", load(COLOR_MAP))
	base.set_shader_parameter("stripe_amount", 0.0)
	base.set_shader_parameter("density", 200.0)
	var chain: Material = RatMaterials.build_fur(base, RatMaterials.fur_shell_count())
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null or String(mi.name).ends_with("_LOD1"):
			continue
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m != null and m.resource_name == "fur":
				mi.set_surface_override_material(s, chain)
				n += 1
	return n


## BoneAttachment3D on the right hand; weapon models are parented under it. Returns the attachment.
static func attach_hand(model: Node) -> BoneAttachment3D:
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone(HAND_BONE) < 0:
		return null
	var existing: Node = sk.get_node_or_null("WeaponHand")
	if existing != null:
		return existing as BoneAttachment3D
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = "WeaponHand"
	ba.bone_name = HAND_BONE
	sk.add_child(ba)
	return ba


## Parent a weapon model scene/node under the hand attachment (stage B helper).
static func equip(model: Node, weapon: Variant) -> Node3D:
	var ba: BoneAttachment3D = attach_hand(model)
	if ba == null:
		return null
	for c: Node in ba.get_children():
		c.queue_free()
	var w: Node3D = null
	if weapon is PackedScene:
		w = (weapon as PackedScene).instantiate() as Node3D
	elif weapon is Node3D:
		w = weapon
	if w != null:
		ba.add_child(w)
	return w


const WEAPON_DIR: String = "res://assets/models/weapon_%s.glb"


## Swap the held weapon model by weapon id (claws, pistol, gatling, yarn, laser). The model's `Grip` empty
## is placed at the hand; barrel points along -Z.
static func equip_weapon(model: Node, id: String) -> Node3D:
	var path: String = WEAPON_DIR % id
	if not ResourceLoader.exists(path):
		return null
	var w: Node3D = equip(model, load(path) as PackedScene)
	if w == null:
		return null
	w.name = "WeaponModel"
	var grip: Node3D = w.find_child("Grip", true, false) as Node3D
	if grip != null:
		w.position = -grip.position
	return w
