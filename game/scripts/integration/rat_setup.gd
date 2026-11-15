class_name RatModelSetup
extends RefCounted
## Post-processing for rat_<kind>.glb once RatEnemy.set_model has loaded it (owner: integ-lead):
## fur shells / skin / cheese materials by slot name, LOD1 at distance, muzzle flash on the muzzle bones,
## loop flags (idempotent, enemy.gd does it too).

const LOOPING: PackedStringArray = ["idle", "walk", "run", "aim_idle", "charge", "take_cover"]
const LOD_DIST: float = 16.0
const FUR_BY_KIND: Dictionary = {
	"mouse": "fur_mouse", "trooper": "fur_rat_grey", "officer": "fur_rat_grey",
	"sewer": "fur_rat_brown", "panzer": "fur_rat_grey", "boss": "fur_rat_grey",
}
const SLOT_MATS: Dictionary = {
	"skin": "skin_nose", "cheese": "cheese_cheddar", "tail": "skin_rat_tail",
}


static func hook(enemy: RatEnemy) -> void:
	if enemy.model != null:
		apply(enemy, enemy.model)
	if not enemy.model_ready.is_connected(_on_model_ready.bind(enemy)):
		enemy.model_ready.connect(_on_model_ready.bind(enemy))


static func _on_model_ready(model: Node3D, enemy: RatEnemy) -> void:
	apply(enemy, model)


static func apply(enemy: RatEnemy, model: Node3D) -> void:
	if model == null or model.has_meta("rat_setup"):
		return
	model.set_meta("rat_setup", true)
	var kind: String = str(enemy.kind) if "kind" in enemy else "trooper"
	set_loops(model)
	var fur_name: String = FUR_BY_KIND.get(kind, "fur_rat_grey")
	var base: ShaderMaterial = RatMaterials.get_material(fur_name) as ShaderMaterial
	var shells: Material = null
	var lod_mat: Material = null
	if base != null:
		shells = RatMaterials.build_fur(base, mini(RatMaterials.fur_shell_count(), 10))
		lod_mat = RatMaterials.make_fur_lod(base)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh == null:
			continue
		var is_lod1: bool = String(mi.name).ends_with("_LOD1")
		for s: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m == null:
				continue
			var slot: String = m.resource_name
			if slot == "fur" and base != null:
				mi.set_surface_override_material(s, lod_mat if is_lod1 else shells)
			elif slot.begins_with("cheese") and not slot.contains("rind") and RatMaterials.has_material(SLOT_MATS["cheese"]):
				mi.set_surface_override_material(s, RatMaterials.get_material(SLOT_MATS["cheese"]))
			elif slot == "skin" and RatMaterials.has_material(SLOT_MATS["skin"]):
				mi.set_surface_override_material(s, RatMaterials.get_material(SLOT_MATS["skin"]))
		if String(mi.name).ends_with("_LOD0"):
			mi.visibility_range_end = LOD_DIST
			mi.visibility_range_end_margin = 2.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		elif is_lod1:
			mi.visible = true
			mi.visibility_range_begin = LOD_DIST
			mi.visibility_range_begin_margin = 2.0
	add_muzzle_flash(enemy, model)


static func set_loops(model: Node) -> void:
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap == null:
		return
	for a: String in ap.get_animation_list():
		var short: String = a.get_slice("|", a.get_slice_count("|") - 1).get_slice("/", a.get_slice_count("/") - 1).to_lower()
		if LOOPING.has(short):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR


## Flash lights on LeftMuzzle/RightMuzzle bones, shown while the enemy's own MuzzleFlash node is visible.
static func add_muzzle_flash(enemy: RatEnemy, model: Node3D) -> void:
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	var src: Node3D = enemy.get_node_or_null("MuzzleFlash") as Node3D
	for bone: String in ["RightMuzzle", "LeftMuzzle"]:
		if sk.find_bone(bone) < 0 or sk.get_node_or_null("Flash_" + bone) != null:
			continue
		var ba: BoneAttachment3D = BoneAttachment3D.new()
		ba.name = "Flash_" + bone
		ba.bone_name = bone
		sk.add_child(ba)
		var holder: Node3D = Node3D.new()
		holder.name = "Flash"
		holder.visible = false
		ba.add_child(holder)
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var sp: SphereMesh = SphereMesh.new()
		sp.radius = 0.07
		sp.height = 0.14
		mesh.mesh = sp
		mesh.rotation_degrees.x = 0.0
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.25)
		mat.emission_energy_multiplier = 4.0
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mesh)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 2.5
		l.omni_range = 4.0
		l.shadow_enabled = false
		holder.add_child(l)
		if src != null:
			src.visibility_changed.connect(func() -> void: holder.visible = src.visible)
