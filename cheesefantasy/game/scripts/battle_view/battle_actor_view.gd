class_name BattleActorView
extends Node3D
## One combatant on the battle stage (owner battle-presentation). Wraps a model from ActorFactory (loaded dynamically so
## this file parses even when actors/ is missing), falling back to a direct glb load, then to a procedural placeholder.
## Handles animation fallbacks, hit flash/knockback, KO slump, guard pose, status aura tint and idle bob.

const FACTORY_PATH: String = "res://scripts/actors/actor_factory.gd"

var uid: String = ""
var side: String = "party"
var model_id: String = ""
var display_name: String = ""
var height: float = 1.2
var home: Vector3 = Vector3.ZERO
var model: Node3D
var anim: AnimationPlayer
var _down: bool = false
var _meshes: Array[MeshInstance3D] = []
var _flash_mat: StandardMaterial3D


static func spawn_model(id: String, tint: Color = Color.WHITE) -> Node3D:
	var n: Node3D = null
	if ResourceLoader.exists(FACTORY_PATH):
		var f: GDScript = load(FACTORY_PATH) as GDScript
		if f != null and _script_has(f, "spawn"):
			var v: Variant = f.call("spawn", id)
			if v is Node3D:
				n = v as Node3D
	if n == null:
		var p: String = "res://assets/models/%s.glb" % id
		if ResourceLoader.exists(p):
			var ps: PackedScene = load(p) as PackedScene
			if ps != null:
				n = ps.instantiate() as Node3D
	if n == null:
		n = placeholder(id, tint)
	return n


static func _script_has(s: GDScript, m: String) -> bool:
	for d: Dictionary in s.get_script_method_list():
		if str(d.get("name", "")) == m:
			return true
	return false


## Coloured capsule + head + ears: always works, even with no assets.
static func placeholder(id: String, tint: Color) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Placeholder_" + id
	var c: Color = tint if tint != Color.WHITE else Color.from_hsv(float(hash(id) % 360) / 360.0, 0.45, 0.85)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.0
	body.mesh = cap
	body.material_override = m
	body.position.y = 0.5
	root.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.26
	sp.height = 0.5
	head.mesh = sp
	head.material_override = m
	head.position.y = 1.2
	root.add_child(head)
	for sx: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.09
		cm.height = 0.2
		cm.radial_segments = 4
		ear.mesh = cm
		ear.material_override = m
		ear.position = Vector3(0.14 * sx, 1.45, 0)
		root.add_child(ear)
	return root


func setup(p_uid: String, p_side: String, p_model: String, p_name: String, tint: Color, scl: float) -> void:
	uid = p_uid
	side = p_side
	model_id = p_model
	display_name = p_name
	model = spawn_model(p_model, tint)
	add_child(model)
	model.scale = Vector3.ONE * scl
	_collect(model)
	if tint != Color.WHITE and not model.name.begins_with("Placeholder"):
		for mi: MeshInstance3D in _meshes:
			var ov: StandardMaterial3D = StandardMaterial3D.new()
			ov.albedo_color = Color(tint.r, tint.g, tint.b, 0.35)
			ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ov.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
			mi.material_overlay = ov
	var aabb: AABB = _aabb()
	height = clampf(aabb.end.y, 0.6, 6.0) if aabb.size != Vector3.ZERO else 1.2 * scl
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1, 1, 1, 0)
	play("idle")


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n as MeshInstance3D)
	if n is AnimationPlayer and anim == null:
		anim = n as AnimationPlayer
	for c: Node in n.get_children():
		_collect(c)


func _aabb() -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi: MeshInstance3D in _meshes:
		if mi.mesh == null:
			continue
		var bb: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.get_aabb()
		bb = global_transform.affine_inverse() * bb if is_inside_tree() else bb
		out = bb if first else out.merge(bb)
		first = false
	return out


func refresh_height() -> void:
	var bb: AABB = _aabb()
	if bb.size != Vector3.ZERO:
		height = clampf(bb.end.y, 0.6, 6.0)


## Play a clip with fallbacks (cast->attack, defend->idle, ...). Returns the clip length (0 if none).
func play(clip: String, loop_back_to_idle: bool = true) -> float:
	if model != null and model.has_method("play") and anim == null:
		model.call("play", clip)
		return 0.6
	if anim == null:
		return 0.0
	var order: Array[String] = [clip]
	match clip:
		"cast": order.append_array(["special", "attack"])
		"special": order.append_array(["attack", "cast"])
		"defend": order.append_array(["hurt"])
		"victory": order.append_array(["idle"])
		"summon_intro": order.append_array(["run", "walk"])
		"outro": order.append_array(["idle"])
	order.append("idle")
	for c: String in order:
		var nm: String = _find_clip(c)
		if nm != "":
			anim.play(nm, 0.15)
			var ln: float = anim.get_animation(nm).length
			if loop_back_to_idle and c != "idle" and c != "down" and c != "run" and c != "walk":
				anim.queue(_find_clip("idle") if _find_clip("idle") != "" else nm)
			return ln
	return 0.0


func _find_clip(c: String) -> String:
	if anim.has_animation(c):
		return c
	for nm: StringName in anim.get_animation_list():
		var s: String = String(nm)
		if s.ends_with("/" + c) or s.to_lower() == c or s.to_lower().ends_with("_" + c):
			return s
	return ""


func top() -> Vector3:
	return global_position + Vector3(0, height + 0.25, 0)


func chest() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func hit(strength: float = 1.0) -> void:
	play("hurt")
	var away: Vector3 = Vector3(0.25 if side == "party" else -0.25, 0, 0) * strength
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", home + away, 0.06)
	tw.tween_property(self, "position", home, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	flash(Color(1, 0.95, 0.9))


func flash(c: Color) -> void:
	for mi: MeshInstance3D in _meshes:
		mi.material_overlay = _flash_mat
	_flash_mat.albedo_color = Color(c.r, c.g, c.b, 0.85)
	var tw: Tween = create_tween()
	tw.tween_property(_flash_mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		for mi: MeshInstance3D in _meshes:
			if mi.material_overlay == _flash_mat:
				mi.material_overlay = null)


func step_forward() -> void:
	var fwd: Vector3 = Vector3(-0.9 if side == "party" else 0.9, 0, 0)
	create_tween().tween_property(self, "position", home + fwd, 0.18).set_trans(Tween.TRANS_QUAD)


func step_back() -> void:
	create_tween().tween_property(self, "position", home, 0.22).set_trans(Tween.TRANS_QUAD)


func lunge_to(p: Vector3) -> void:
	var tgt: Vector3 = p.lerp(global_position, 0.35)
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", Vector3(tgt.x, global_position.y, tgt.z), 0.16).set_trans(Tween.TRANS_QUAD)


func set_down(v: bool) -> void:
	if v == _down:
		return
	_down = v
	var tw: Tween = create_tween()
	tw.tween_interval(0.01)
	if v:
		var clip: float = play("down", false)
		if clip <= 0.0 or anim == null:
			tw.tween_property(model, "rotation:z", (PI * 0.5) * (1.0 if side == "party" else -1.0), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if side == "enemy":
			tw.tween_interval(0.4)
			tw.tween_callback(func() -> void: flash(Color(0.8, 0.2, 0.9)))
			tw.tween_property(self, "scale", Vector3(1.0, 0.02, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: visible = false)
	else:
		visible = true
		scale = Vector3.ONE
		tw.tween_property(model, "rotation:z", 0.0, 0.3)
		play("idle")


func is_down() -> bool:
	return _down


func run_away() -> void:
	play("run", false)
	var dir: float = -1.0 if side == "enemy" else 1.0
	var tw: Tween = create_tween()
	tw.tween_property(self, "rotation:y", rotation.y + PI, 0.15)
	tw.tween_property(self, "position:x", position.x + 9.0 * dir, 0.8)
	tw.tween_callback(func() -> void: visible = false)
