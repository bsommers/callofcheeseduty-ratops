class_name SummonCinematic
extends Node3D
## Nine Lives Spirit cinematics (owner battle-presentation): dim + letterbox, sweeping orbit over a rune circle,
## name card, the giant glowing cat runs in behind the party and leaps over the field, signature attack, departure.
## Jesse (Misty Pounce), Tripper (Tabby Tremor), Samantha (Halo Lick), Spooky (Eclipse Claw).
## Uses the summon_* glb when present (via BattleActorView.spawn_model / ActorFactory), else a procedural spirit cat.
## `await play(...)`; `on_impact` is called once when the hit lands (the scene pops numbers then).

const SH_SPIRIT: Shader = preload("res://assets/vfx/spirit.gdshader")

const LOOK: Dictionary = {
	"jesse": {"fur": Color(0.62, 0.65, 0.7), "glow": Color(0.7, 0.88, 1.0), "eye": Color(0.6, 1.0, 0.95), "stripes": false},
	"tripper": {"fur": Color(0.55, 0.38, 0.2), "glow": Color(1.0, 0.75, 0.4), "eye": Color(0.9, 1.0, 0.4), "stripes": true},
	"samantha": {"fur": Color(0.97, 0.97, 1.0), "glow": Color(1.0, 0.97, 0.8), "eye": Color(0.5, 0.8, 1.0), "stripes": false},
	"spooky": {"fur": Color(0.06, 0.05, 0.09), "glow": Color(0.65, 0.35, 1.0), "eye": Color(1.0, 0.85, 0.2), "stripes": false},
}

var cam: BattleCamera
var hud: BattleHud
var vfx: BattleVfx
var arena: BattleArena
var _meshes: Array[GeometryInstance3D] = []
var _overlay: ShaderMaterial
var _gait: float = 0.0
var _legs: Array[Node3D] = []
var _tail: Node3D


func play(sid: String, s: Dictionary, p_cam: BattleCamera, p_hud: BattleHud, p_vfx: BattleVfx, p_arena: BattleArena,
		party: Array, targets: Array, on_impact: Callable) -> void:
	cam = p_cam
	hud = p_hud
	vfx = p_vfx
	arena = p_arena
	var look: Dictionary = LOOK.get(sid, LOOK.jesse)
	var col: Color = s.get("color", look.glow)
	var glow: Color = look.glow
	var party_c: Vector3 = _center(party, Vector3(3.5, 0, 0))
	var foe_c: Vector3 = _center(targets, Vector3(-3.6, 0, 0))

	# ---- 1. the world holds its breath
	hud.set_chrome(false)
	hud.letterbox(true)
	hud.vignette(0.75, glow.darkened(0.85))
	_dim(0.0, 0.72, 0.6)
	Audio.play_sfx("summon")
	vfx.ground_ring(Vector3(0, 0, 0), glow, 12.0, 3.2, 0.1, true)
	vfx.burst(Vector3(0, 0.2, 0), glow.lightened(0.4), Color(glow.r, glow.g, glow.b, 0.0), 160, 2.4, Vector3.UP, 25.0,
		1.0, 4.0, Vector3.ZERO, 0.06, 0.16, 5.0)
	var orbit: Tween = cam.orbit(Vector3(0, 0, 0), 12.0, 4.5, 35.0, -35.0, 2.4)
	await _wait(0.5)
	hud.name_card(str(s.get("name", sid)), str(s.get("title", "")), str(s.get("attack", "")), glow, 1.5)
	await orbit.finished

	# ---- 2. the spirit arrives
	var spirit: Node3D = _make_spirit(sid, look)
	add_child(spirit)
	_set_fade(0.0)
	var trail: GPUParticles3D = vfx.burst(Vector3(0, 1.2, 0), glow.lightened(0.3), Color(glow.r, glow.g, glow.b, 0.0), 120, 1.2,
		Vector3.UP, 180.0, 0.2, 0.8, Vector3(0, 0.6, 0), 0.08, 0.25, 0.9, true, spirit, false)
	trail.local_coords = false
	if sid == "samantha":
		await _samantha(spirit, party, party_c, glow, on_impact)
	elif sid == "spooky":
		await _spooky(spirit, targets, foe_c, glow, on_impact)
	else:
		await _run_and_leap(spirit, party_c, foe_c, glow)
		if sid == "tripper":
			await _tripper(spirit, targets, party, glow, on_impact)
		else:
			await _jesse(spirit, targets, party, glow, on_impact)

	# ---- 3. departure
	trail.emitting = false
	cam.move_to(spirit.global_position + Vector3(0, 3.0, 11.0), spirit.global_position + Vector3(0, 2.0, 0), 0.9, 50.0)
	_play(spirit, "outro")
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_fade, 1.0, 0.0, 1.0)
	tw.tween_property(spirit, "position:y", spirit.position.y + 3.5, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	vfx.burst(spirit.global_position + Vector3(0, 1.5, 0), Color(1, 1, 1), Color(glow.r, glow.g, glow.b, 0.0), 120, 1.6,
		Vector3.UP, 60.0, 1.0, 3.0, Vector3(0, 1.0, 0), 0.05, 0.14, 1.5)
	await tw.finished
	spirit.queue_free()
	hud.vignette(0.0)
	hud.letterbox(false)
	_dim(0.72, 0.0, 0.5)
	hud.set_chrome(true)
	cam.wide(0.6)
	await _wait(0.5)


# ======================================================================= per-summon beats
func _run_and_leap(spirit: Node3D, party_c: Vector3, foe_c: Vector3, glow: Color) -> void:
	var start: Vector3 = party_c + Vector3(11.0, 0, -5.0)
	var mid: Vector3 = party_c + Vector3(1.5, 0, -1.0)
	spirit.global_position = start
	_face(spirit, mid - start)
	_play(spirit, "summon_intro")
	create_tween().tween_method(_set_fade, 0.0, 1.0, 0.5)
	# tracking shot alongside the run
	var tw: Tween = create_tween()
	tw.tween_method(func(t: float) -> void:
		spirit.global_position = start.lerp(mid, t)
		_gait += 0.55
		_animate_gait(1.0)
		cam.rig_pos = spirit.global_position + Vector3(-1.0, 2.2, 8.5)
		cam.focus = spirit.global_position + Vector3(0, 1.6, 0), 0.0, 1.0, 1.1)
	await tw.finished
	# the leap: low angle by the enemies looking up
	cam.move_to(foe_c + Vector3(2.5, 0.6, 7.0), (mid + foe_c) * 0.5 + Vector3(0, 4.0, 0), 0.25, 62.0)
	_face(spirit, foe_c - mid)
	_play(spirit, "special")
	var land: Vector3 = foe_c + Vector3(1.6, 0, 0)
	var jump: Tween = create_tween()
	jump.tween_method(func(t: float) -> void:
		var p: Vector3 = mid.lerp(land, t)
		p.y = sin(t * PI) * 5.5
		spirit.global_position = p
		spirit.rotation.x = lerpf(-0.35, 0.45, t)
		cam.focus = cam.focus.lerp(p + Vector3(0, 1.0, 0), 0.25), 0.0, 1.0, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await jump.finished
	spirit.rotation.x = 0.0
	vfx.burst(land + Vector3(0, 0.3, 0), glow.lightened(0.5), Color(glow.r, glow.g, glow.b, 0.0), 80, 0.8, Vector3.UP, 85.0,
		3.0, 7.0, Vector3(0, -5.0, 0), 0.06, 0.14, 0.6)


func _jesse(spirit: Node3D, targets: Array, party: Array, glow: Color, on_impact: Callable) -> void:
	# Misty Pounce: a wall of icy mist rolls over every enemy, gale swirls, frost crystals, claw rakes
	cam.side_view("enemy", 0.3)
	cam.shake(0.25, 0.6)
	hud.flash(Color(0.85, 0.95, 1.0), 0.55)
	for t: Variant in targets:
		var v: BattleActorView = t as BattleActorView
		vfx.burst(v.global_position + Vector3(0, 0.5, 0), Color(0.9, 0.97, 1.0, 0.35), Color(0.7, 0.85, 1.0, 0.0), 24, 1.6,
			Vector3.LEFT, 70.0, 1.0, 3.0, Vector3(-1.0, 0.2, 0), 0.2, 0.45, 0.8, false)
		vfx.swirl(v.global_position, 1.5, 1.4, true)
		vfx.slash_arc(v.chest(), glow, 2.4, 0.6)
		vfx.slash_arc(v.chest() + Vector3(0.2, 0.2, 0), Color(1, 1, 1), 2.0, 0.9, 0.08)
		vfx._ice_hit(v.global_position, false)
	_play(spirit, "special")
	on_impact.call()
	await _wait(1.0)
	for p: Variant in party:
		var pv: BattleActorView = p as BattleActorView
		vfx.swirl(pv.global_position, 0.8, 1.0, false)
	await _wait(0.6)


func _tripper(spirit: Node3D, targets: Array, party: Array, glow: Color, on_impact: Callable) -> void:
	# Tabby Tremor: stomp, the farm itself heaves, rind slabs erupt under every enemy
	var land: Vector3 = spirit.global_position
	var up: Tween = create_tween()
	up.tween_property(spirit, "position:y", 2.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	up.tween_property(spirit, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	cam.move_to(land + Vector3(5.0, 1.2, 8.0), land + Vector3(-1.0, 1.0, 0), 0.35, 55.0)
	await up.finished
	cam.shake(0.7, 1.2)
	hud.flash(Color(1.0, 0.8, 0.45), 0.5)
	for k: int in 3:
		vfx.ground_ring(land, glow, 6.0 + 5.0 * k, 0.9, 0.12 * k)
	for t: Variant in targets:
		var v: BattleActorView = t as BattleActorView
		vfx._earth_hit(v.global_position, true)
		vfx.rind_slab(v.global_position + Vector3(0, 0, 0.05), 0.0, 2.0, 0.05)
	on_impact.call()
	await _wait(1.1)
	for p: Variant in party:
		var pv: BattleActorView = p as BattleActorView
		vfx._buff("buff_brown", "earth", [pv.global_position])
	await _wait(0.5)


func _samantha(spirit: Node3D, party: Array, party_c: Vector3, glow: Color, on_impact: Callable) -> void:
	# Halo Lick: she descends from a snowy sky above the party, haloed, and every wound closes
	var top: Vector3 = party_c + Vector3(-1.5, 9.0, -2.5)
	var hover: Vector3 = party_c + Vector3(-1.5, 0.0, -2.5)
	spirit.global_position = top
	_face(spirit, Vector3(0, 0, 1))
	cam.move_to(party_c + Vector3(-6.0, 1.0, 7.0), top + Vector3(0, -2.0, 0), 0.0, 60.0)
	var halo: MeshInstance3D = _halo(glow)
	spirit.add_child(halo)
	vfx.burst(party_c + Vector3(0, 7.0, 0), Color(1, 1, 1), Color(0.8, 0.9, 1.0, 0.0), 220, 3.0, Vector3.DOWN, 30.0, 0.5,
		1.5, Vector3(0.3, -1.2, 0), 0.05, 0.12, 5.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_method(_set_fade, 0.0, 1.0, 0.8)
	tw.tween_property(spirit, "global_position", hover, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(cam, "focus", hover + Vector3(0, 2.0, 0), 1.4)
	_play(spirit, "summon_intro")
	await tw.finished
	_play(spirit, "special")
	cam.move_to(party_c + Vector3(-5.5, 2.6, 6.5), party_c + Vector3(-0.8, 1.2, -0.5), 0.4, 52.0)
	hud.flash(Color(1, 1, 0.92), 0.6, 0.6)
	for p: Variant in party:
		var pv: BattleActorView = p as BattleActorView
		vfx.pillar(pv.global_position, glow, 1.4)
		vfx.ground_ring(pv.global_position, glow, 2.6, 1.2, 0.0, true)
		vfx.burst(pv.global_position + Vector3(0, 0.2, 0), Color(1, 1, 0.9), Color(1, 0.9, 0.6, 0.0), 50, 1.5, Vector3.UP,
			20.0, 1.0, 2.5, Vector3.ZERO, 0.05, 0.13, 0.6)
	on_impact.call()
	await _wait(1.6)


func _spooky(spirit: Node3D, targets: Array, foe_c: Vector3, glow: Color, on_impact: Callable) -> void:
	# Eclipse Claw: the sun goes out, two eyes open behind the target, and the night itself takes a swipe
	var t0: BattleActorView = (targets[0] as BattleActorView) if not targets.is_empty() else null
	var tp: Vector3 = t0.global_position if t0 != null else foe_c
	_dim(0.72, 0.97, 0.5)
	hud.vignette(0.95, Color(0.08, 0.0, 0.15), 0.5)
	var eclipse: Node3D = _eclipse(tp + Vector3(-6.0, 9.0, -14.0))
	add_child(eclipse)
	cam.move_to(tp + Vector3(3.5, 1.4, 6.5), tp + Vector3(-1.2, 2.5, -1.0), 0.6, 52.0)
	await _wait(0.8)
	spirit.global_position = tp + Vector3(-2.6, 0, -1.6)
	_face(spirit, tp - spirit.global_position)
	create_tween().tween_method(_set_fade, 0.0, 1.0, 0.6)
	_play(spirit, "summon_intro")
	await _wait(0.8)
	_play(spirit, "special")
	cam.move_to(tp + Vector3(4.5, 1.5, 5.5), tp + Vector3(-0.6, 1.3, 0), 0.12, 50.0)
	for k: int in 3:
		vfx.slash_arc(tp + Vector3(0.3 * (k - 1), 1.2, 0.3), glow, 4.2, 0.45 + 0.15 * k, 0.07 * k)
		vfx.slash_arc(tp + Vector3(0.3 * (k - 1), 1.2, 0.32), Color(1, 1, 1), 3.6, 0.45 + 0.15 * k, 0.07 * k + 0.02)
	await _wait(0.2)
	cam.shake(0.5, 0.6)
	hud.flash(Color(0.85, 0.6, 1.0), 0.7, 0.5)
	vfx.burst(tp + Vector3(0, 1.0, 0), Color(0.15, 0.0, 0.25, 0.6), Color(0, 0, 0, 0), 30, 1.2, Vector3.UP, 180.0, 1.5, 3.0,
		Vector3.ZERO, 0.15, 0.35, 0.4, false)
	vfx.burst(tp + Vector3(0, 1.0, 0), glow, Color(glow.r, glow.g, glow.b, 0.0), 80, 0.9, Vector3.UP, 180.0, 3.0, 7.0,
		Vector3.ZERO, 0.05, 0.15, 0.3)
	on_impact.call()
	await _wait(1.2)
	var tw: Tween = create_tween()
	tw.tween_property(eclipse, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(eclipse.queue_free)
	_dim(0.97, 0.72, 0.4)
	hud.vignette(0.75, glow.darkened(0.85), 0.4)


# ======================================================================= spirit model
func _make_spirit(sid: String, look: Dictionary) -> Node3D:
	_meshes.clear()
	_legs.clear()
	_tail = null
	var root: Node3D = Node3D.new()
	root.name = "Spirit_" + sid
	var mid: String = "summon_" + sid
	var model: Node3D = null
	if ResourceLoader.exists("res://assets/models/%s.glb" % mid):
		model = BattleActorView.spawn_model(mid)
		model.rotation.y = PI   # glb models face -Z; the rig faces +Z
	if model == null:
		model = _procedural_cat(look)
	root.add_child(model)
	root.set_meta("model", model)
	_overlay = ShaderMaterial.new()
	_overlay.shader = SH_SPIRIT
	_overlay.set_shader_parameter("glow_color", look.glow)
	_collect(model)
	for g: GeometryInstance3D in _meshes:
		g.material_overlay = _overlay
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = look.glow
	l.light_energy = 3.0
	l.omni_range = 8.0
	l.position = Vector3(0, 2.0, 0)
	root.add_child(l)
	return root


func _collect(n: Node) -> void:
	if n is GeometryInstance3D:
		_meshes.append(n as GeometryInstance3D)
	for c: Node in n.get_children():
		_collect(c)


func _procedural_cat(look: Dictionary) -> Node3D:
	var cat: Node3D = Node3D.new()
	cat.name = "ProceduralSpiritCat"
	var fur: StandardMaterial3D = StandardMaterial3D.new()
	fur.albedo_color = look.fur
	fur.roughness = 0.6
	fur.emission_enabled = true
	fur.emission = (look.glow as Color) * 0.25
	var s: float = 1.6    # ~3 m tall at the ear tips
	var body: MeshInstance3D = _mi(_capsule(0.55 * s, 2.0 * s), fur)
	body.rotation.x = PI * 0.5
	body.position = Vector3(0, 1.15 * s, 0)
	cat.add_child(body)
	var chest: MeshInstance3D = _mi(_sphere(0.62 * s), fur)
	chest.position = Vector3(0, 1.3 * s, 0.6 * s)
	cat.add_child(chest)
	var head: MeshInstance3D = _mi(_sphere(0.5 * s), fur)
	head.position = Vector3(0, 1.85 * s, 1.15 * s)
	head.scale = Vector3(1.1, 0.95, 1.0)
	cat.add_child(head)
	var muzzle: MeshInstance3D = _mi(_sphere(0.22 * s), fur)
	muzzle.position = Vector3(0, 1.72 * s, 1.55 * s)
	muzzle.scale = Vector3(1.3, 0.8, 0.9)
	cat.add_child(muzzle)
	var eye_m: StandardMaterial3D = StandardMaterial3D.new()
	eye_m.albedo_color = look.eye
	eye_m.emission_enabled = true
	eye_m.emission = look.eye
	eye_m.emission_energy_multiplier = 4.0
	for sx: float in [-1.0, 1.0]:
		var ear: MeshInstance3D = _mi(_cone(0.2 * s, 0.45 * s), fur)
		ear.position = Vector3(0.28 * s * sx, 2.3 * s, 1.05 * s)
		ear.rotation.z = -0.25 * sx
		cat.add_child(ear)
		var eye: MeshInstance3D = _mi(_sphere(0.08 * s), eye_m)
		eye.position = Vector3(0.19 * s * sx, 1.93 * s, 1.58 * s)
		eye.scale = Vector3(1.0, 1.3, 0.6)
		cat.add_child(eye)
	for i: int in 4:
		var leg: Node3D = Node3D.new()
		leg.position = Vector3((0.3 if i % 2 == 0 else -0.3) * s, 1.0 * s, (0.75 if i < 2 else -0.7) * s)
		var lm: MeshInstance3D = _mi(_capsule(0.15 * s, 1.1 * s), fur)
		lm.position = Vector3(0, -0.5 * s, 0)
		leg.add_child(lm)
		cat.add_child(leg)
		_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.3 * s, -1.0 * s)
	var prev: Node3D = _tail
	for i: int in 5:
		var seg: Node3D = Node3D.new()
		seg.rotation.x = -0.35
		var sm: MeshInstance3D = _mi(_capsule(0.1 * s, 0.5 * s), fur)
		sm.position = Vector3(0, 0.22 * s, 0)
		seg.add_child(sm)
		seg.position = Vector3(0, 0.4 * s, 0) if i > 0 else Vector3.ZERO
		prev.add_child(seg)
		prev = seg
	cat.add_child(_tail)
	if look.get("stripes", false):
		var st: StandardMaterial3D = StandardMaterial3D.new()
		st.albedo_color = Color(0.12, 0.08, 0.05)
		for i: int in 5:
			var band: MeshInstance3D = _mi(_capsule(0.565 * s, 0.25 * s), st)
			band.rotation.x = PI * 0.5
			band.scale = Vector3(1.0, 0.35, 1.0)
			band.position = Vector3(0, 1.15 * s, (-0.6 + 0.3 * i) * s)
			cat.add_child(band)
	return cat


func _animate_gait(amp: float) -> void:
	for i: int in _legs.size():
		var ph: float = _gait + (PI if i == 1 or i == 2 else 0.0)
		_legs[i].rotation.x = sin(ph) * 0.7 * amp
	if _tail != null:
		_tail.rotation.x = -0.4 + sin(_gait * 0.5) * 0.2


func _mi(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	return c


func _sphere(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _cone(r: float, h: float) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


func _halo(c: Color) -> MeshInstance3D:
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.68
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 5.0
	var mi: MeshInstance3D = _mi(t, m)
	mi.position = Vector3(0, 4.3, 1.6)
	return mi


func _eclipse(p: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = p
	var corona: MeshInstance3D = _mi(_sphere(3.2), _unlit(Color(1.0, 0.85, 0.6), 4.0))
	n.add_child(corona)
	var moon: MeshInstance3D = _mi(_sphere(3.0), _unlit(Color(0.02, 0.0, 0.04), 0.0))
	moon.position = Vector3(0.4, 0.2, 1.0)
	n.add_child(moon)
	n.scale = Vector3.ONE * 0.01
	create_tween().tween_property(n, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return n


func _unlit(c: Color, e: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c * maxf(1.0, e)
	return m


# ======================================================================= helpers
func _set_fade(v: float) -> void:
	for g: GeometryInstance3D in _meshes:
		if is_instance_valid(g):
			g.transparency = clampf(1.0 - v * 0.8, 0.0, 1.0)   # spirits never become fully solid
	if _overlay != null:
		_overlay.set_shader_parameter("fade", v)


func _play(spirit: Node3D, clip: String) -> void:
	var m: Node = spirit.get_meta("model", null) as Node
	if m == null:
		return
	var ap: AnimationPlayer = _find_anim(m)
	if ap == null:
		return
	for c: String in [clip, "special", "idle"]:
		if ap.has_animation(c):
			ap.play(c, 0.2)
			return


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c: Node in n.get_children():
		var a: AnimationPlayer = _find_anim(c)
		if a != null:
			return a
	return null


func _face(n: Node3D, dir: Vector3) -> void:
	var d: Vector3 = Vector3(dir.x, 0, dir.z)
	if d.length() > 0.01:
		n.rotation.y = atan2(d.x, d.z)


func _dim(a: float, b: float, dur: float) -> void:
	if arena != null:
		create_tween().tween_method(arena.set_dim, a, b, dur)


func _center(list: Array, fallback: Vector3) -> Vector3:
	if list.is_empty():
		return fallback
	var c: Vector3 = Vector3.ZERO
	for v: Variant in list:
		c += (v as Node3D).global_position
	return c / float(list.size())


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
