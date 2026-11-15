class_name RatWeaponFx
extends RefCounted
## Transient weapon effects built in code: tracer, muzzle-flash light, bullet decal, explosion flash.
## All effects free themselves; decals are capped (ring buffer) per scene tree.

const MAX_DECALS: int = 64
const TRACER_LIFE: float = 0.06

static var _decals: Array[Node] = []


static func _unshaded(c: Color, energy: float = 4.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _col(a: Variant, fallback: Color) -> Color:
	if a is Array and (a as Array).size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback


## Thin glowing box stretched from `from` to `to`, fading out quickly.
static func tracer(parent: Node, from: Vector3, to: Vector3, color: Variant = null, width: float = 0.02) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var len: float = from.distance_to(to)
	if len < 0.05:
		return null
	var mi := MeshInstance3D.new()
	mi.name = "Tracer"
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, len)
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _unshaded(_col(color, Color(1.0, 0.85, 0.5)))
	mi.material_override = mat
	parent.add_child(mi)
	var mid: Vector3 = (from + to) * 0.5
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.IDENTITY, mid).looking_at(to, up)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, TRACER_LIFE)
	tw.tween_callback(mi.queue_free)
	return mi


## Short OmniLight3D pop (muzzle flash / impact spark).
static func flash(parent: Node, pos: Vector3, color: Variant = null, energy: float = 3.0, radius: float = 4.0, life: float = 0.05) -> OmniLight3D:
	if parent == null or not parent.is_inside_tree():
		return null
	var l := OmniLight3D.new()
	l.name = "MuzzleFlash"
	l.light_color = _col(color, Color(1.0, 0.75, 0.35))
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)
	return l


## Cached on the effect parent (meta) so it is released with the level, not held by a static at exit.
static func _get_decal_tex(owner: Node) -> Texture2D:
	if owner.has_meta("_rat_decal_tex"):
		return owner.get_meta("_rat_decal_tex") as Texture2D
	if true:
		var g := Gradient.new()
		g.set_color(0, Color(0.02, 0.015, 0.01, 0.95))
		g.set_color(1, Color(0.05, 0.04, 0.03, 0.0))
		g.add_point(0.35, Color(0.03, 0.02, 0.015, 0.85))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		owner.set_meta("_rat_decal_tex", t)
		return t
	return null


## Bullet hole: a Decal projected along -normal. Oldest decals are recycled past MAX_DECALS.
static func decal(parent: Node, pos: Vector3, normal: Vector3, size: float = 0.12) -> Decal:
	if parent == null or not parent.is_inside_tree():
		return null
	var d := Decal.new()
	d.name = "BulletDecal"
	d.texture_albedo = _get_decal_tex(parent)
	d.size = Vector3(size, 0.1, size)
	d.cull_mask = 1
	parent.add_child(d)
	var n: Vector3 = normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var ref: Vector3 = Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = ref.cross(n).normalized()
	var z: Vector3 = x.cross(n).normalized()
	d.global_transform = Transform3D(Basis(x, n, z), pos)
	var kept: Array[Node] = []
	for o: Variant in _decals:
		if is_instance_valid(o):
			kept.append(o as Node)
	_decals = kept
	_decals.append(d)
	while _decals.size() > MAX_DECALS:
		var old: Node = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return d


## Explosion: bright light pulse plus an expanding emissive sphere.
static func explosion(parent: Node, pos: Vector3, color: Variant = null, radius: float = 3.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var c: Color = _col(color, Color(1.6, 0.4, 1.4))
	flash(parent, pos, c, 8.0, radius * 3.0, 0.35)
	var mi := MeshInstance3D.new()
	mi.name = "Blast"
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := _unshaded(c, 3.0)
	mat.albedo_color.a = 0.7
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius * 2.0, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
