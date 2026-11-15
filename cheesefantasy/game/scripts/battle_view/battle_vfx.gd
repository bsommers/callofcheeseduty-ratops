class_name BattleVfx
extends Node3D
## Spell / hit VFX for the battle scene (owner battle-presentation). Everything is built in code from the shaders in
## res://assets/vfx/: GPU particle bursts (soft additive billboards) + tweened hero meshes (flame tongues, ice crystals,
## Swiss discs, rind slabs, spore puffs, claw arcs). All nodes free themselves.
## play(vfx_id, element, from, targets) returns the seconds until the hit "lands" (when damage numbers should pop).

signal shake_requested(strength: float, duration: float)
signal flash_requested(color: Color, strength: float)

const SH_SOFT: Shader = preload("res://assets/vfx/soft_particle.gdshader")
const SH_FLAME: Shader = preload("res://assets/vfx/flame.gdshader")
const SH_SWISS: Shader = preload("res://assets/vfx/swiss.gdshader")
const SH_CRYSTAL: Shader = preload("res://assets/vfx/crystal.gdshader")
const SH_SLASH: Shader = preload("res://assets/vfx/slash.gdshader")
const SH_RING: Shader = preload("res://assets/vfx/ground_ring.gdshader")

const COL: Dictionary = {
	"none": Color(1.0, 0.97, 0.88), "fire": Color(1.0, 0.55, 0.12), "ice": Color(0.55, 0.85, 1.0),
	"wind": Color(0.85, 1.0, 0.7), "earth": Color(0.85, 0.55, 0.22), "rot": Color(0.3, 0.85, 0.65),
	"light": Color(1.0, 0.93, 0.6), "shade": Color(0.6, 0.35, 0.95), "heal": Color(0.45, 1.0, 0.55),
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _soft_cache: Dictionary = {}


func _init() -> void:
	_rng.seed = 7331


## Main entry. `vfx` from the skill table (fire_burst, ice_storm, heal_green, ...), `element` fallback family.
func play(vfx: String, element: String, from: Vector3, targets: Array) -> float:
	var fam: String = family(vfx, element)
	var pts: Array[Vector3] = []
	for t: Variant in targets:
		if t is Vector3:
			pts.append(t as Vector3)
	if pts.is_empty():
		pts.append(from)
	var multi: bool = pts.size() > 1
	match fam:
		"fire": return _fire(vfx, from, pts, multi)
		"ice": return _ice(vfx, from, pts, multi)
		"wind": return _wind(vfx, from, pts, multi)
		"earth": return _earth(vfx, from, pts, multi)
		"rot": return _rot(vfx, from, pts, multi)
		"light": return _light(vfx, pts)
		"shade": return _shade(vfx, from, pts)
		"heal": return _heal(vfx, pts)
		"buff": return _buff(vfx, element, pts)
		_: return _physical(vfx, element, pts)


static func family(vfx: String, element: String) -> String:
	for f: String in ["fire", "ice", "wind", "earth", "rot", "shade"]:
		if vfx.begins_with(f):
			return f
	if vfx.begins_with("heal") or vfx == "revive":
		return "heal" if vfx != "heal_gold" else "light"
	if vfx.begins_with("buff") or vfx == "sparkle":
		return "buff"
	if vfx in ["slash", "bite", "feathers", "web", ""]:
		return element if element in ["fire", "ice", "wind", "earth", "rot", "light", "shade"] and vfx == "" else "phys"
	return element if COL.has(element) else "phys"


# ======================================================================= FIRE: melting cheese flames
func _fire(vfx: String, from: Vector3, pts: Array[Vector3], multi: bool) -> float:
	var t0: float = 0.0
	if vfx == "fire_slash":
		for p: Vector3 in pts:
			slash_arc(p + Vector3(0, 0.8, 0), COL.fire, 1.6, _rng.randf_range(-0.6, 0.6))
		t0 = 0.12
	elif vfx == "fire_rain":
		for i: int in pts.size():
			var p: Vector3 = pts[i]
			_falling_blob(p + Vector3(_rng.randf_range(-0.3, 0.3), 7.0, _rng.randf_range(-0.3, 0.3)), p, 0.45 + 0.08 * i)
		t0 = 0.5
	elif vfx == "fire_burst" and not multi:
		t0 = projectile(from + Vector3(0, 1.0, 0), pts[0] + Vector3(0, 0.8, 0), COL.fire, 0.4, 0.35)
	else:
		t0 = 0.25
		for p: Vector3 in pts:
			ground_ring(p, COL.fire, 2.6, 0.5, t0 - 0.2)
	var big: bool = vfx in ["fire_pillar", "fire_wave"] or multi
	for p: Vector3 in pts:
		_delay(t0, func() -> void: _fire_hit(p, big))
	_delay(t0, func() -> void: shake_requested.emit(0.18 if big else 0.08, 0.3))
	_delay(t0, func() -> void: flash_requested.emit(COL.fire, 0.25 if big else 0.12))
	return t0 + 0.1


func _fire_hit(p: Vector3, big: bool) -> void:
	var n: int = 7 if big else 4
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + _rng.randf() * 0.5
		var r: float = _rng.randf_range(0.05, 0.55 if big else 0.35)
		var h: float = _rng.randf_range(1.2, 2.6 if big else 1.8)
		flame(p + Vector3(cos(a) * r, 0.0, sin(a) * r), h, _rng.randf_range(0.0, 0.15), _rng.randf_range(0.7, 1.2))
	# embers rising + white-hot pop
	burst(p + Vector3(0, 0.7, 0), Color(1.0, 0.8, 0.3), Color(1.0, 0.25, 0.05, 0.0), 60 if big else 32, 1.1,
		Vector3.UP, 70.0, 2.5, 4.5, Vector3(0, 2.0, 0), 0.06, 0.16, 0.4)
	burst(p + Vector3(0, 0.8, 0), Color(1.0, 1.0, 0.85), Color(1.0, 0.6, 0.1, 0.0), 1, 0.35, Vector3.UP, 0.0, 0.0, 0.0,
		Vector3.ZERO, 2.2 if big else 1.4, 2.6 if big else 1.6, 0.0)
	# gooey cheese drips sliding down
	for i: int in (6 if big else 3):
		_drip(p + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(1.0, 1.7), _rng.randf_range(-0.4, 0.4)))
	burst(p + Vector3(0, 1.6, 0), Color(0.35, 0.3, 0.28, 0.5), Color(0.2, 0.2, 0.2, 0.0), 14, 1.6, Vector3.UP, 30.0,
		0.5, 1.2, Vector3(0, 0.6, 0), 0.5, 0.9, 0.2, false)
	pulse_light(p + Vector3(0, 1.0, 0), Color(1.0, 0.55, 0.2), 6.0 if big else 3.5, 0.7)


func flame(p: Vector3, height: float, delay: float, life: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.center_offset = Vector3(0, 0.5, 0)
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_FLAME
	m.set_shader_parameter("seed", _rng.randf() * 10.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = p
	mi.scale = Vector3(0.01, 0.01, 0.01)
	var tw: Tween = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3(height * 0.55, height, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(life * 0.5)
	tw.tween_method(_sp.bind(m, "fade"), 1.0, 0.0, life * 0.5)
	tw.parallel().tween_property(mi, "scale:y", height * 0.4, life * 0.5)
	tw.tween_callback(mi.queue_free)


func _drip(p: Vector3) -> void:
	var mi: MeshInstance3D = _blob_mesh(Color(1.0, 0.78, 0.22), 0.09, 1.6)
	add_child(mi)
	mi.global_position = p
	mi.scale = Vector3(1.0, 1.6, 1.0)
	var tw: Tween = mi.create_tween()
	tw.tween_interval(_rng.randf_range(0.05, 0.3))
	tw.tween_property(mi, "global_position:y", 0.05, _rng.randf_range(0.5, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(mi, "scale", Vector3(2.4, 0.25, 2.4), 0.12)   # splat into a puddle
	tw.tween_interval(0.5)
	tw.tween_property(mi, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
	tw.tween_callback(mi.queue_free)


func _falling_blob(start: Vector3, end: Vector3, delay: float) -> void:
	var mi: MeshInstance3D = _blob_mesh(Color(1.0, 0.6, 0.15), 0.28, 3.0)
	add_child(mi)
	mi.global_position = start
	mi.visible = false
	var tw: Tween = mi.create_tween()
	tw.tween_interval(delay - 0.35 if delay > 0.35 else 0.0)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_property(mi, "global_position", end + Vector3(0, 0.3, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _fire_hit(end, false))
	tw.tween_callback(mi.queue_free)


# ======================================================================= ICE: frosty cave crystals
func _ice(vfx: String, from: Vector3, pts: Array[Vector3], multi: bool) -> float:
	var t0: float = 0.3
	if (vfx == "ice_spark" or vfx == "ice_burst") and not multi:
		t0 = projectile(from + Vector3(0, 1.0, 0), pts[0] + Vector3(0, 0.8, 0), COL.ice, 0.45, 0.3)
	else:
		for p: Vector3 in pts:
			ground_ring(p, COL.ice, 2.8, 0.6, 0.0, true)
			burst(p + Vector3(0, 3.0, 0), Color(0.9, 0.97, 1.0), Color(0.6, 0.85, 1.0, 0.0), 70, 1.4, Vector3.DOWN, 40.0,
				1.0, 3.0, Vector3(0.6, -2.0, 0.0), 0.05, 0.12, 2.0)
	var big: bool = multi or vfx == "ice_storm"
	for p: Vector3 in pts:
		_delay(t0, func() -> void: _ice_hit(p, big))
	_delay(t0, func() -> void: shake_requested.emit(0.1, 0.25))
	_delay(t0, func() -> void: flash_requested.emit(Color(0.8, 0.95, 1.0), 0.2))
	return t0 + 0.1


func _ice_hit(p: Vector3, big: bool) -> void:
	var n: int = 9 if big else 6
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + _rng.randf() * 0.4
		var r: float = _rng.randf_range(0.25, 0.75)
		var tilt: Vector3 = Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.25, 0.6)
		crystal(p + Vector3(cos(a) * r, -0.1, sin(a) * r), _rng.randf_range(0.8, 1.9 if big else 1.4), tilt, 0.02 * i)
	crystal(p, 2.2 if big else 1.6, Vector3.ZERO, 0.0)
	burst(p + Vector3(0, 0.9, 0), Color(0.95, 1.0, 1.0), Color(0.5, 0.8, 1.0, 0.0), 50, 0.9, Vector3.UP, 180.0,
		2.0, 4.0, Vector3(0, -3.0, 0), 0.04, 0.1, 0.6)
	burst(p + Vector3(0, 0.4, 0), Color(0.85, 0.95, 1.0, 0.6), Color(0.7, 0.9, 1.0, 0.0), 16, 1.5, Vector3.UP, 90.0,
		0.3, 0.8, Vector3.ZERO, 0.6, 1.1, 0.5, false)
	pulse_light(p + Vector3(0, 1.0, 0), Color(0.6, 0.85, 1.0), 4.0, 0.8)


func crystal(base: Vector3, height: float, tilt: Vector3, delay: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = height * 0.18
	c.height = height
	c.radial_segments = 6
	c.rings = 1
	mi.mesh = c
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_CRYSTAL
	mi.material_override = m
	add_child(mi)
	mi.global_position = base
	var up: Vector3 = (Vector3.UP + tilt).normalized()
	var xa: Vector3 = up.cross(Vector3.FORWARD)
	if xa.length() < 0.1:
		xa = up.cross(Vector3.RIGHT)
	xa = xa.normalized()
	var b: Basis = Basis(xa, up, xa.cross(up).normalized())
	mi.basis = b.scaled_local(Vector3(1, 0.01, 1))
	var tw: Tween = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(func(s: float) -> void:
		mi.basis = b.scaled_local(Vector3(1, s, 1))
		mi.global_position = base + up * height * 0.5 * s, 0.01, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_method(_sp.bind(m, "fade"), 1.0, 0.0, 0.45)
	tw.parallel().tween_method(func(s: float) -> void: mi.basis = b.scaled_local(Vector3(s, s, s)), 1.0, 1.25, 0.45)
	tw.tween_callback(mi.queue_free)


# ======================================================================= WIND: swirling whey + Swiss holes
func _wind(vfx: String, _from: Vector3, pts: Array[Vector3], multi: bool) -> float:
	var big: bool = multi or vfx == "wind_tornado"
	for p: Vector3 in pts:
		swirl(p, 1.4 if big else 1.0, 1.3, big)
	_delay(0.35, func() -> void: shake_requested.emit(0.08, 0.5))
	return 0.4


func swirl(p: Vector3, radius: float, life: float, big: bool) -> void:
	var holder: Node3D = Node3D.new()
	add_child(holder)
	holder.global_position = p
	var n: int = 14 if big else 9
	for i: int in n:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		var s: float = _rng.randf_range(0.25, 0.5)
		q.size = Vector2(s, s)
		mi.mesh = q
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = SH_SWISS
		m.set_shader_parameter("seed", _rng.randf() * 10.0)
		mi.material_override = m
		holder.add_child(mi)
		var a0: float = TAU * float(i) / float(n)
		var h0: float = _rng.randf_range(0.0, 0.6)
		var rr: float = radius * _rng.randf_range(0.6, 1.1)
		var spin: float = _rng.randf_range(2.5, 4.0) * TAU
		var tw: Tween = mi.create_tween()
		tw.tween_method(func(t: float) -> void:
			var a: float = a0 + spin * t
			var r: float = rr * (1.0 - 0.55 * t)
			mi.position = Vector3(cos(a) * r, h0 + t * 2.6, sin(a) * r)
			mi.rotation = Vector3(t * 9.0 + a0, a, t * 5.0), 0.0, 1.0, life)
		tw.parallel().tween_method(_sp.bind(m, "fade"), 1.0, 0.0, life * 0.35).set_delay(life * 0.65)
	# whey mist streaks
	burst(p + Vector3(0, 0.6, 0), Color(0.95, 1.0, 0.85, 0.35), Color(0.8, 1.0, 0.7, 0.0), 24 if big else 14, life,
		Vector3.UP, 60.0, 1.0, 2.5, Vector3(0, 1.0, 0), 0.1, 0.22, radius * 0.8, false)
	ground_ring(p, COL.wind, radius * 2.6, life * 0.8, 0.0)
	var tw2: Tween = holder.create_tween()
	tw2.tween_interval(life + 0.1)
	tw2.tween_callback(holder.queue_free)


# ======================================================================= EARTH: rind slabs
func _earth(vfx: String, _from: Vector3, pts: Array[Vector3], multi: bool) -> float:
	var big: bool = multi or vfx == "earth_quake"
	for p: Vector3 in pts:
		_earth_hit(p, big)
	_delay(0.12, func() -> void: shake_requested.emit(0.35 if big else 0.18, 0.5))
	return 0.18


func _earth_hit(p: Vector3, big: bool) -> void:
	var n: int = 6 if big else 4
	for i: int in n:
		var a: float = TAU * float(i) / float(n) + _rng.randf() * 0.4
		var r: float = _rng.randf_range(0.7, 1.0)
		rind_slab(p + Vector3(cos(a) * r, 0, sin(a) * r), a, _rng.randf_range(0.45, 0.8), 0.03 * i)
	ground_ring(p, COL.earth, 3.4 if big else 2.4, 0.5, 0.05)
	burst(p + Vector3(0, 0.2, 0), Color(0.75, 0.6, 0.4, 0.5), Color(0.5, 0.4, 0.3, 0.0), 24, 1.1, Vector3.UP, 75.0,
		1.5, 3.0, Vector3(0, -2.0, 0), 0.12, 0.3, 0.8, false)
	burst(p + Vector3(0, 0.4, 0), Color(1.0, 0.8, 0.35), Color(0.7, 0.45, 0.15, 0.0), 24, 0.9, Vector3.UP, 60.0,
		3.0, 5.0, Vector3(0, -9.0, 0), 0.05, 0.11, 0.4)


func rind_slab(p: Vector3, yaw: float, size: float, delay: float) -> void:
	var holder: Node3D = Node3D.new()
	add_child(holder)
	holder.global_position = p
	holder.rotation.y = -yaw
	var slab: MeshInstance3D = MeshInstance3D.new()
	var b: BoxMesh = BoxMesh.new()
	b.size = Vector3(0.18, 1.0, 0.6) * size
	slab.mesh = b
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.72, 0.25)      # cheddar paste
	m.roughness = 0.75
	m.emission_enabled = true
	m.emission = Color(0.4, 0.2, 0.02)
	slab.material_override = m
	var rind: MeshInstance3D = MeshInstance3D.new()   # darker waxed rind face
	var rb: BoxMesh = BoxMesh.new()
	rb.size = Vector3(0.05, 1.02, 0.62) * size
	rind.mesh = rb
	var rm: StandardMaterial3D = StandardMaterial3D.new()
	rm.albedo_color = Color(0.55, 0.28, 0.1)
	rm.roughness = 0.5
	rind.material_override = rm
	rind.position.x = -0.1 * size
	slab.add_child(rind)
	holder.add_child(slab)
	var tilt: float = _rng.randf_range(0.25, 0.55)
	slab.position = Vector3(0, -0.6 * size, 0)
	var tw: Tween = slab.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(slab, "position:y", 0.35 * size, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slab, "rotation:z", tilt, 0.12)
	tw.tween_interval(0.8)
	tw.tween_property(slab, "position:y", -0.7 * size, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


# ======================================================================= ROT: blue spore / gorgonzola gas
func _rot(vfx: String, from: Vector3, pts: Array[Vector3], multi: bool) -> float:
	var t0: float = 0.25
	if vfx == "rot_breath" or vfx == "rot_wave":
		for p: Vector3 in pts:
			stream(from + Vector3(0, 1.0, 0), p + Vector3(0, 0.8, 0), COL.rot, 0.5)
		t0 = 0.45
	elif not multi:
		t0 = projectile(from + Vector3(0, 1.0, 0), pts[0] + Vector3(0, 0.8, 0), COL.rot, 0.35, 0.5)
	for p: Vector3 in pts:
		_delay(t0, func() -> void: _rot_hit(p, multi or vfx == "rot_nova"))
	return t0 + 0.1


func _rot_hit(p: Vector3, big: bool) -> void:
	burst(p + Vector3(0, 0.5, 0), Color(0.35, 0.75, 0.6, 0.35), Color(0.15, 0.35, 0.4, 0.0), 12 if big else 8, 1.2,
		Vector3.UP, 120.0, 0.6, 1.4, Vector3(0, 0.4, 0), 0.15, 0.32, 0.4, false)
	burst(p + Vector3(0, 0.5, 0), Color(0.6, 1.0, 0.75), Color(0.2, 0.6, 0.5, 0.0), 40, 1.6, Vector3.UP, 50.0,
		0.5, 1.6, Vector3(0, 0.4, 0), 0.04, 0.1, 0.6)
	for i: int in 5:
		var mi: MeshInstance3D = _blob_mesh(Color(0.25, 0.6, 0.55), 0.05, 0.8)
		add_child(mi)
		mi.global_position = p + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.1, 0.5), _rng.randf_range(-0.6, 0.6))
		mi.scale = Vector3(0.01, 0.01, 0.01)
		var tw: Tween = mi.create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(mi, "scale", Vector3.ONE * _rng.randf_range(0.8, 1.4), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.25)
		tw.tween_callback(mi.queue_free)
	pulse_light(p + Vector3(0, 1.0, 0), Color(0.3, 0.9, 0.6), 3.0, 0.9)


# ======================================================================= LIGHT / HEAL / BUFF / SHADE / PHYSICAL
func _light(_vfx: String, pts: Array[Vector3]) -> float:
	for p: Vector3 in pts:
		pillar(p, COL.light, 1.0)
		ground_ring(p, COL.light, 2.2, 1.0, 0.0, true)
		burst(p + Vector3(0, 0.2, 0), Color(1.0, 1.0, 0.85), Color(1.0, 0.85, 0.4, 0.0), 40, 1.3, Vector3.UP, 20.0,
			1.5, 3.0, Vector3.ZERO, 0.05, 0.12, 0.5)
		pulse_light(p + Vector3(0, 1.2, 0), COL.light, 5.0, 1.0)
	flash_requested.emit(COL.light, 0.18)
	return 0.35


func _heal(vfx: String, pts: Array[Vector3]) -> float:
	var c: Color = COL.heal
	if vfx == "heal_blue":
		c = Color(0.5, 0.8, 1.0)
	elif vfx == "revive":
		c = Color(1.0, 0.95, 0.7)
	for p: Vector3 in pts:
		ground_ring(p, c, 2.0, 0.9, 0.0, true)
		burst(p + Vector3(0, 0.1, 0), c.lightened(0.4), Color(c.r, c.g, c.b, 0.0), 36, 1.2, Vector3.UP, 15.0,
			1.0, 2.2, Vector3.ZERO, 0.05, 0.13, 0.55)
		if vfx == "revive":
			pillar(p, c, 0.9)
		pulse_light(p + Vector3(0, 1.0, 0), c, 2.5, 0.9)
	return 0.3


func _buff(vfx: String, element: String, pts: Array[Vector3]) -> float:
	var c: Color = COL.get(element, Color.WHITE)
	match vfx:
		"buff_red": c = Color(1.0, 0.4, 0.25)
		"buff_blue": c = Color(0.45, 0.7, 1.0)
		"buff_brown": c = Color(0.85, 0.6, 0.3)
		"buff_white": c = Color(1.0, 1.0, 0.95)
	for p: Vector3 in pts:
		for k: int in 3:
			ground_ring(p + Vector3(0, 0.3 + 0.5 * k, 0), c, 1.8 - 0.3 * k, 0.6, 0.1 * k)
		burst(p + Vector3(0, 0.3, 0), c.lightened(0.3), Color(c.r, c.g, c.b, 0.0), 24, 1.0, Vector3.UP, 25.0,
			1.0, 2.0, Vector3.ZERO, 0.05, 0.1, 0.5)
	return 0.3


func _shade(_vfx: String, from: Vector3, pts: Array[Vector3]) -> float:
	var t0: float = projectile(from + Vector3(0, 1.0, 0), pts[0] + Vector3(0, 0.8, 0), COL.shade, 0.45, 0.4) if pts.size() == 1 else 0.3
	for p: Vector3 in pts:
		_delay(t0, func() -> void:
			for k: int in 3:
				slash_arc(p + Vector3(0.25 * (k - 1), 0.9, 0), COL.shade, 1.7, 0.5 + 0.12 * k, 0.05 * k)
			burst(p + Vector3(0, 0.9, 0), Color(0.15, 0.05, 0.25, 0.9), Color(0.05, 0.0, 0.1, 0.0), 30, 1.2, Vector3.UP, 180.0,
				0.5, 1.5, Vector3(0, 0.5, 0), 0.3, 0.7, 0.4, false)
			pulse_light(p + Vector3(0, 1.0, 0), COL.shade, 4.0, 0.6))
	return t0 + 0.12


func _physical(vfx: String, element: String, pts: Array[Vector3]) -> float:
	var c: Color = COL.get(element, COL.none)
	for p: Vector3 in pts:
		if vfx == "feathers":
			burst(p + Vector3(0, 1.0, 0), Color(0.15, 0.15, 0.2), Color(0.1, 0.1, 0.12, 0.0), 18, 1.2, Vector3.UP, 120.0,
				1.0, 2.5, Vector3(0, -1.0, 0), 0.08, 0.16, 0.3, false)
		elif vfx == "web":
			ground_ring(p, Color(0.9, 0.9, 0.95), 2.0, 0.6, 0.0, true)
		slash_arc(p + Vector3(0, 0.85, 0), c if vfx != "bite" else Color(1.0, 0.6, 0.6), 1.3, _rng.randf_range(-0.5, 0.5))
		burst(p + Vector3(0, 0.85, 0), Color(1.0, 1.0, 0.9), Color(1.0, 0.8, 0.5, 0.0), 18, 0.4, Vector3.UP, 180.0,
			2.5, 4.5, Vector3(0, -6.0, 0), 0.04, 0.08, 0.1)
	_delay(0.08, func() -> void: shake_requested.emit(0.07, 0.15))
	return 0.1


# ======================================================================= primitives
## Glowing orb that flies from a to b. Returns travel time.
func projectile(a: Vector3, b: Vector3, c: Color, size: float, dur: float) -> float:
	var orb: Node3D = Node3D.new()
	add_child(orb)
	orb.global_position = a
	var core: MeshInstance3D = _soft_quad(c.lightened(0.5), size)
	orb.add_child(core)
	var halo: MeshInstance3D = _soft_quad(c, size * 2.4)
	orb.add_child(halo)
	var trail: GPUParticles3D = burst(Vector3.ZERO, c, Color(c.r, c.g, c.b, 0.0), 40, 0.35, Vector3.UP, 180.0, 0.1, 0.4,
		Vector3.ZERO, size * 0.3, size * 0.6, size * 0.2, true, orb, false)
	trail.local_coords = false
	var mid: Vector3 = (a + b) * 0.5 + Vector3(0, 0.9, 0)
	var tw: Tween = orb.create_tween()
	tw.tween_method(func(t: float) -> void:
		orb.global_position = a.lerp(mid, t).lerp(mid.lerp(b, t), t), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		core.visible = false
		halo.visible = false
		trail.emitting = false)
	tw.tween_interval(0.5)
	tw.tween_callback(orb.queue_free)
	return dur


## A ribbon of particles (breath / gas cone) from a to b.
func stream(a: Vector3, b: Vector3, c: Color, dur: float) -> void:
	var dir: Vector3 = (b - a)
	var p: GPUParticles3D = burst(a, Color(c.r, c.g, c.b, 0.45), Color(c.r * 0.5, c.g * 0.5, c.b * 0.5, 0.0), 60, 0.6,
		dir.normalized(), 10.0, dir.length() * 1.4, dir.length() * 1.9, Vector3.ZERO, 0.1, 0.35, 0.1, false, null, false)
	p.one_shot = false
	p.explosiveness = 0.0
	var tw: Tween = p.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(func() -> void: p.emitting = false)


func slash_arc(p: Vector3, c: Color, size: float, roll: float, delay: float = 0.0) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_SLASH
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("progress", 0.0)
	mi.material_override = m
	add_child(mi)
	mi.global_position = p
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		mi.look_at(cam.global_position, Vector3.UP, true)
	mi.rotate_object_local(Vector3.FORWARD, roll)
	var tw: Tween = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_sp.bind(m, "progress"), 0.0, 1.0, 0.14)
	tw.tween_method(_sp.bind(m, "energy"), 3.0, 0.0, 0.25)
	tw.tween_callback(mi.queue_free)


func ground_ring(p: Vector3, c: Color, size: float, life: float, delay: float = 0.0, runes: bool = false) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SH_RING
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("runes", runes)
	m.set_shader_parameter("radius", 0.05)
	mi.material_override = m
	add_child(mi)
	mi.global_position = Vector3(p.x, maxf(p.y, 0.0) + 0.04, p.z)
	var tw: Tween = mi.create_tween()
	tw.tween_interval(delay)
	tw.tween_method(_sp.bind(m, "radius"), 0.05, 0.44, life * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_sp.bind(m, "fade"), 1.0, 0.0, life * 0.5)
	tw.tween_callback(mi.queue_free)


func pillar(p: Vector3, c: Color, life: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.55
	cm.height = 6.0
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c.r, c.g, c.b, 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = p + Vector3(0, 3.0, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tw: Tween = mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.55, 0.15)
	tw.parallel().tween_property(mi, "scale", Vector3(1, 1, 1), 0.2)
	tw.tween_interval(life * 0.4)
	tw.tween_property(m, "albedo_color:a", 0.0, life * 0.5)
	tw.parallel().tween_property(mi, "scale", Vector3(0.05, 1, 0.05), life * 0.5)
	tw.tween_callback(mi.queue_free)


func pulse_light(p: Vector3, c: Color, energy: float, life: float) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = 5.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = p
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)


## One-shot GPU particle burst of soft additive billboards. Returns the node (already emitting).
func burst(p: Vector3, c0: Color, c1: Color, amount: int, life: float, dir: Vector3, spread: float, v_min: float,
		v_max: float, gravity: Vector3, s_min: float, s_max: float, radius: float, additive: bool = true,
		parent: Node3D = null, one_shot: bool = true) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.amount = maxi(1, amount)
	gp.lifetime = life
	gp.one_shot = one_shot
	gp.explosiveness = 0.92 if one_shot else 0.0
	gp.randomness = 0.4
	gp.fixed_fps = 0
	gp.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = dir if dir != Vector3.ZERO else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = v_min
	pm.initial_velocity_max = v_max
	pm.gravity = gravity
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	pm.scale_min = s_min
	pm.scale_max = s_max
	if radius > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius
	var g: Gradient = Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.6))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1.0, 0.3))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	gp.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1, 1)
	q.material = _soft_mat(additive)
	gp.draw_pass_1 = q
	(parent if parent != null else self).add_child(gp)
	if parent == null:
		gp.global_position = p
	else:
		gp.position = p
	gp.emitting = true
	if one_shot:
		var tw: Tween = gp.create_tween()
		tw.tween_interval(life + 0.6)
		tw.tween_callback(gp.queue_free)
	return gp


func _soft_mat(additive: bool) -> Material:
	var key: String = "add" if additive else "mix"
	if _soft_cache.has(key):
		return _soft_cache[key]
	var m: Material
	if additive:
		var sm: ShaderMaterial = ShaderMaterial.new()
		sm.shader = SH_SOFT
		m = sm
	else:
		var st: StandardMaterial3D = StandardMaterial3D.new()   # smoke/dust: alpha-blended soft billboard
		st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		st.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		st.vertex_color_use_as_albedo = true
		st.albedo_texture = _round_tex()
		st.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m = st
	_soft_cache[key] = m
	return m


static func _round_tex() -> Texture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _soft_quad(c: Color, size: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	# vertex COLOR is white on a plain quad, so tint via a per-quad material
	var st: StandardMaterial3D = StandardMaterial3D.new()
	st.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	st.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	st.albedo_texture = _round_tex()
	st.albedo_color = c
	st.emission_enabled = false
	mi.material_override = st
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _blob_mesh(c: Color, radius: float, glow: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var s: SphereMesh = SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	mi.material_override = m
	return mi


static func _sp(v: float, m: ShaderMaterial, n: String) -> void:
	m.set_shader_parameter(n, v)


func _delay(t: float, f: Callable) -> void:
	if t <= 0.0:
		f.call()
		return
	var tw: Tween = create_tween()
	tw.tween_interval(t)
	tw.tween_callback(f)
