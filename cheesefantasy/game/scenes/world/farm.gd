class_name Farm
extends Node3D
## Curdlewick Farm overworld, built entirely in code: terrain, sky, buildings, fields, fences,
## trees, NPCs, animals, roaming enemies, interaction points, player and dialogue box.
## World pieces use res://assets/models/world_*.glb when present, else WorldProps placeholders.

signal interaction_triggered(kind: String, point_id: String)

const SPAWN := Vector3(2.0, 0.0, 16.0)

var terrain: FarmTerrain
var player: WorldPlayer
var dialogue_box: Node
var sun: DirectionalLight3D
var windmill_blades: Node3D
var _flickers: Array[Node3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _colliders: Node3D

# Path polylines (x,z) – dirt trails connecting everything.
const PATHS: Array = [
	[Vector2(2, 20), Vector2(2, 8), Vector2(0, -10), Vector2(0, -30), Vector2(0, -50), Vector2(0, -60)],
	[Vector2(2, 8), Vector2(18, 8), Vector2(24, 8)],
	[Vector2(0, -10), Vector2(-20, -8), Vector2(-40, -32), Vector2(-52, -36)],
	[Vector2(0, -22), Vector2(20, -30), Vector2(30, -26)],
	[Vector2(2, 14), Vector2(-14, 12), Vector2(-26, 22)],
	[Vector2(2, 14), Vector2(16, 20), Vector2(30, 28)],
	[Vector2(2, 20), Vector2(2, 40), Vector2(0, 60)],
]
const FIELDS: Array = [Rect2(-44, -26, 20, 14), Rect2(-44, -8, 20, 12), Rect2(-20, -30, 12, 14), Rect2(12, -22, 14, 12)]
const FIELD_CROPS: Array = ["corn", "wheat", "tomato", "wheat"]
const GRASS_ZONES: Array = [Rect2(-60, 34, 30, 22), Rect2(22, 44, 28, 18), Rect2(-70, -8, 18, 26)]

func _ready() -> void:
	add_to_group("farm")
	_rng.seed = 4242
	_build_terrain()
	_build_environment()
	_colliders = Node3D.new()
	_colliders.name = "Colliders"
	add_child(_colliders)
	_build_buildings()
	_build_fields()
	_build_fences()
	_build_trees()
	_build_points()
	_build_npcs()
	_build_animals()
	_build_mobs()
	_build_player()
	_build_ui()
	WorldBus.emit(&"area_entered", ["curdlewick_farm"])

# ------------------------------------------------------------------ terrain / sky

func _build_terrain() -> void:
	terrain = FarmTerrain.new()
	terrain.name = "Terrain"
	var polys: Array = []
	for p: Array in PATHS:
		var pv := PackedVector2Array()
		for v: Vector2 in p:
			pv.append(v)
		polys.append(pv)
	terrain.setup(polys, FIELDS)
	terrain.grass_rects = GRASS_ZONES
	add_child(terrain)
	terrain.build(self)
	WorldInteractable.ground = terrain

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.25, 0.52, 0.92)
	psm.sky_horizon_color = Color(0.75, 0.87, 0.97)
	psm.ground_horizon_color = Color(0.72, 0.82, 0.78)
	psm.ground_bottom_color = Color(0.3, 0.42, 0.3)
	psm.sun_angle_max = 30.0
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 8.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.88, 0.97)
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.3
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.08
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.04
	if _quality() >= 2:
		env.sdfgi_enabled = true
		env.sdfgi_use_occlusion = true
		env.sdfgi_cascades = 4
		env.sdfgi_max_distance = 128.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

func _quality() -> int:
	var s := WorldBus.autoload("Settings")
	if s != null:
		var q: Variant = s.get("quality")
		if q is int:
			return q
	return 2

# ------------------------------------------------------------------ helpers

func _gh(x: float, z: float) -> float:
	return maxf(terrain.height_at(x, z), FarmTerrain.WATER_LEVEL)

## World-piece factory: real glb if authored, else procedural placeholder.
func _piece(kind: String, text: String = "") -> Dictionary:
	var model_id: String = "world_" + {"tree_oak": "tree_oak", "tree_apple": "tree_apple", "dock": "pond_dock", "cave": "cheese_cave", "sign": "signpost", "wheel": "wheel_cheese"}.get(kind, kind)
	if WorldModels.has_model(model_id):
		var ps := WorldModels._load_scene(model_id)
		if ps != null:
			var root := Node3D.new()
			root.add_child(ps.instantiate())
			var fp: Vector3 = WorldProps.build(kind, text).get("fp", Vector3.ZERO)
			return {"node": root, "fp": fp}
	return WorldProps.build(kind, text)

func _place(kind: String, x: float, z: float, yaw_deg: float = 0.0, solid := true, text: String = "") -> Node3D:
	var d := _piece(kind, text)
	var n: Node3D = d["node"]
	var fp: Vector3 = d["fp"]
	n.position = Vector3(x, _gh(x, z) - 0.05, z)
	n.rotation_degrees.y = yaw_deg
	n.name = kind.capitalize().replace(" ", "")
	add_child(n)
	if solid and fp != Vector3.ZERO:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(fp.x, maxf(fp.y, 1.0), fp.z)
		cs.shape = bs
		cs.position.y = bs.size.y * 0.5
		body.add_child(cs)
		n.add_child(body)
	if kind == "windmill":
		windmill_blades = n.find_child("Blades", true, false) as Node3D
	return n

func _scatter_y(n: Node3D) -> void:
	n.position.y = _gh(n.position.x, n.position.z) - 0.05

# ------------------------------------------------------------------ buildings

func _build_buildings() -> void:
	_place("farmhouse", -16, 6, 0)
	_place("barn", 22, 4, -90)
	_place("silo", 22, -8, 0)
	_place("windmill", -34, 22, 20)
	_place("coop", -8, -14, 10)
	_place("well", 6, 2, 0)
	_place("tractor", 12, 14, 35)
	for i in 5:
		_place("haybale", 16 + i * 1.7, 14 - i * 0.2, _rng.randf_range(0, 90))
	for i in 3:
		_place("crate", -12 + i * 1.2, 14.5, _rng.randf_range(0, 90))
	var pond := terrain.pond_center
	_place("dock", pond.x - 10.0, pond.y + 4.0, 55.0, false)
	# Pig pen (fenced mud patch) next to the farmhouse.
	var mud := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 4.2
	cm.bottom_radius = 4.2
	cm.height = 0.06
	cm.radial_segments = 20
	mud.mesh = cm
	mud.material_override = WorldProps.mat(Color(0.36, 0.24, 0.14), 1.0)
	mud.position = Vector3(-28, _gh(-28, 28) + 0.03, 28)
	add_child(mud)
	var cave := _place("cave", terrain.cave_pos.x, terrain.cave_pos.y, 0, false)
	cave.position.y = terrain.height_at(terrain.cave_pos.x, terrain.cave_pos.y)
	# Rainbow Orchard shrine.
	_place("shrine", -52, -36, 40)
	for i in 12:
		var a := TAU * i / 12.0
		var r := 7.0 + _rng.randf_range(-0.6, 1.5)
		_place("tree_apple", -52 + cos(a) * r, -36 + sin(a) * r, _rng.randf_range(0, 360))
	for i in 14:
		var gx := -62.0 + (i % 7) * 4.5 + _rng.randf_range(-1, 1)
		var gz := -52.0 + (i / 7) * 5.0
		_place("tree_apple", gx, gz, _rng.randf_range(0, 360))

# ------------------------------------------------------------------ fields

func _build_fields() -> void:
	for i in FIELDS.size():
		var r: Rect2 = FIELDS[i]
		var kind: String = FIELD_CROPS[i]
		var mesh := WorldProps.crop_mesh(kind)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var pts: Array[Vector3] = []
		var step := 1.5 if kind == "corn" else 1.1
		var x := r.position.x + 1.0
		while x < r.end.x - 0.5:
			var z := r.position.y + 1.0
			while z < r.end.y - 0.5:
				pts.append(Vector3(x + _rng.randf_range(-0.2, 0.2), 0, z + _rng.randf_range(-0.2, 0.2)))
				z += step
			x += step
		mm.mesh = mesh
		mm.instance_count = pts.size()
		var h := mesh.get_aabb().size.y
		for j in pts.size():
			var s := _rng.randf_range(0.85, 1.15)
			var p := pts[j]
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(j, Transform3D(b, Vector3(p.x, _gh(p.x, p.z) + h * 0.5 * s - 0.05, p.z)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Crops_" + kind + str(i)
		mmi.multimesh = mm
		add_child(mmi)
	# Tall grass patches (random-encounter zones): a few blade clumps for visual cue.
	var blade := CylinderMesh.new()
	blade.top_radius = 0.0
	blade.bottom_radius = 0.07
	blade.height = 0.9
	blade.radial_segments = 4
	blade.rings = 1
	blade.material = WorldProps.mat(Color(0.28, 0.6, 0.2), 1.0)
	for zi in GRASS_ZONES.size():
		var r: Rect2 = GRASS_ZONES[zi]
		var cnt := int(r.get_area() * 0.5)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = blade
		mm.instance_count = cnt
		for j in cnt:
			var gx := r.position.x + _rng.randf() * r.size.x
			var gz := r.position.y + _rng.randf() * r.size.y
			var s := _rng.randf_range(0.8, 1.5)
			var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			b = Basis(Vector3(1, 0, 0), _rng.randf_range(-0.2, 0.2)) * b
			mm.set_instance_transform(j, Transform3D(b, Vector3(gx, _gh(gx, gz) + 0.4 * s, gz)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TallGrass%d" % zi
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

# ------------------------------------------------------------------ fences

func _fence_line(a: Vector2, b: Vector2) -> void:
	var len := a.distance_to(b)
	var wood := WorldProps.mat(Color(0.55, 0.38, 0.22), 0.9)
	var count := int(ceil(len / 2.2))
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var yaw := atan2(-dir.y, dir.x)
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 1.3, 0.18)
		post.mesh = bm
		post.material_override = wood
		post.position = Vector3(p.x, _gh(p.x, p.y) + 0.6, p.y)
		add_child(post)
	for ry in [0.45, 0.95]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(len, 0.1, 0.07)
		rail.mesh = rm
		rail.material_override = wood
		rail.position = Vector3(mid.x, _gh(mid.x, mid.y) + ry, mid.y)
		rail.rotation.y = yaw
		add_child(rail)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(len, 1.4, 0.25)
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(mid.x, _gh(mid.x, mid.y) + 0.7, mid.y)
	body.rotation.y = yaw
	add_child(body)

## Fenced rectangle with a gap (gate) in the middle of the side facing `gate_side`: "n","s","e","w".
func _fence_rect(r: Rect2, gate_side: String) -> void:
	var p0 := r.position
	var p1 := Vector2(r.end.x, r.position.y)
	var p2 := r.end
	var p3 := Vector2(r.position.x, r.end.y)
	var sides := {"n": [p0, p1], "e": [p1, p2], "s": [p2, p3], "w": [p3, p0]}
	for k: String in sides:
		var a: Vector2 = sides[k][0]
		var b: Vector2 = sides[k][1]
		if k == gate_side:
			var m := (a + b) * 0.5
			var d := (b - a).normalized() * 1.8
			_fence_line(a, m - d)
			_fence_line(m + d, b)
		else:
			_fence_line(a, b)

func _build_fences() -> void:
	_fence_rect(Rect2(20, 22, 22, 16), "w")     # cow / sheep pasture
	_fence_rect(Rect2(-33, 23, 10, 10), "e")    # pig pen
	_fence_rect(Rect2(-14, -20, 12, 10), "s")   # chicken yard

# ------------------------------------------------------------------ trees

func _build_trees() -> void:
	var placed := 0
	var tries := 0
	var keep_clear := [Vector2(-16, 6), Vector2(22, 4), Vector2(-34, 22), Vector2(0, -62), Vector2(-52, -36)]
	while placed < 130 and tries < 1500:
		tries += 1
		var x := _rng.randf_range(-92, 92)
		var z := _rng.randf_range(-92, 92)
		var p := Vector2(x, z)
		var edge := maxf(absf(x), absf(z))
		if edge < 50 and _rng.randf() > 0.12:
			continue
		if p.distance_to(terrain.pond_center) < 15.0 or p.distance_to(terrain.cave_pos) < 12.0:
			continue
		if terrain._dist_to_paths(p) < 4.0:
			continue
		var bad := false
		for c: Vector2 in keep_clear:
			if p.distance_to(c) < 12.0:
				bad = true
		for f: Rect2 in FIELDS + GRASS_ZONES:
			if f.grow(3.0).has_point(p):
				bad = true
		if bad or terrain.height_at(x, z) < -0.3:
			continue
		var t := _place("tree_oak", x, z, _rng.randf() * 360.0, false)
		t.scale = Vector3.ONE * _rng.randf_range(0.85, 1.5)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.5
		cy.height = 3.0
		cs.shape = cy
		cs.position.y = 1.5
		body.add_child(cs)
		t.add_child(body)
		placed += 1

# ------------------------------------------------------------------ interaction points

func _point(kind: String, pid: String, x: float, z: float, text := "", flag_once := "", item := "") -> WorldPoint:
	var p := WorldPoint.new()
	p.kind = kind
	p.point_id = pid
	p.text = text
	p.flag_once = flag_once
	p.gives_item = item
	p.position = Vector3(x, _gh(x, z), z)
	p.name = "Point_" + pid
	add_child(p)
	return p

func _build_points() -> void:
	_place("campfire", 8, 22, 0, false)
	_point("campfire", "farm_campfire", 8, 22)
	_place("cauldron", -22, 12, 0)
	_point("cauldron", "farm_cauldron", -22, 13.5)
	_point("shrine", "rainbow_shrine", -52, -32.5)
	_point("cave", "cheese_cave", terrain.cave_pos.x, terrain.cave_pos.y + 4.0, "The cave mouth breathes cool, stinky air. It is sealed by rubble for now.")
	var sg := _place("sign", 4, 18, -10, false, "Curdlewick Farm. Est. before the fridge was invented.")
	_point("sign", "sign_farm", 4, 18, "Curdlewick Farm. Est. before the fridge was invented. North: Cheese Cave. East: Barn. West: Orchard.")
	_point("sign", "sign_cave", 2, -52, "DANGER: Cheese Cave. Rats, mould, and an unreasonable amount of smell ahead.")
	_point("chest", "chest_pond", terrain.pond_center.x + 14.0, terrain.pond_center.y + 6.0, "", "chest_pond_opened", "milk_bottle")
	_place("crate", terrain.pond_center.x + 14.0, terrain.pond_center.y + 6.0, 0)
	sg.name = "SignFarm"
	# Faint glowing wheel cheese in the cave mouth sells the quest.
	_place("wheel", terrain.cave_pos.x + 3.0, terrain.cave_pos.y + 6.0, 0, false)
	for n in find_children("Flicker", "Node3D", true, false):
		_flickers.append(n as Node3D)

# ------------------------------------------------------------------ people / animals / mobs

func _npc(id: String, model: String, name_: String, x: float, z: float, mode := "idle", radius := 4.0, height := 0.0, spd := 1.1) -> WorldNPC:
	var n := WorldNPC.new()
	n.npc_id = id
	n.display_name = name_
	n.model_id = model
	n.dialogue_id = id
	n.mode = mode
	n.wander_radius = radius
	n.model_height = height
	n.speed = spd
	n.position = Vector3(x, 0, z)
	n.name = "NPC_" + id
	add_child(n)
	return n

func _build_npcs() -> void:
	_npc("farmer_gouda", "npc_farmer", "Farmer Gouda", 0.5, 11.5)
	_npc("cook", "npc_cook", "Chef Camembert", -20, 14)
	_npc("cheesemonger", "npc_cheesemonger", "Monger Havarti", 26, 12)
	_npc("tinker", "npc_tinker", "Tinker Tilsit", 14, 18)
	_npc("granny", "npc_granny", "Granny Edam", -12, 11, "wander", 3.0)
	_npc("kid_colby", "npc_kid", "Little Colby", 4, 6, "wander", 8.0, 0.0, 1.8)
	_npc("kid_pip", "npc_kid", "Pip", 8, 4, "wander", 8.0, 0.0, 1.8)
	_npc("scarecrow", "npc_scarecrow", "Sir Strawsworth", -34, -19)
	_npc("brie", "hero_brie", "Madame Brie", 28, -26)
	_npc("clover", "hero_clover", "Clover", -48, -44)
	_npc("maple", "hero_maple", "Maple", terrain.pond_center.x - 12.0, terrain.pond_center.y - 8.0)

func _build_animals() -> void:
	_npc("cow_bessie", "animal_cow", "Bessie", 28, 28, "wander", 5.0)
	_npc("cow_moolissa", "animal_cow", "Moolissa", 34, 32, "wander", 5.0)
	_npc("sheep_barbara", "animal_sheep", "Baa-rbara", 26, 34, "wander", 5.0)
	_npc("sheep_woolly", "animal_sheep", "Woolly Nelson", 36, 26, "wander", 5.0)
	_npc("goat_feta", "animal_goat", "Nanny Feta", 30, 24, "wander", 5.0)
	_npc("pig_oinks", "animal_pig", "Sir Oinks-a-Lot", -28, 28, "wander", 2.5)
	_npc("chicken_cluck", "animal_chicken", "Cluck Norris", -8, -15, "wander", 3.5)
	_npc("chicken_hen", "animal_chicken", "Hen Solo", -6, -17, "wander", 3.5)
	_npc("duck_quackers", "animal_duck", "Quackers", terrain.pond_center.x - 9.0, terrain.pond_center.y + 8.0, "wander", 3.0)
	_npc("dog_wensleydale", "animal_dog", "Captain Wensleydale", 6, 12, "wander", 6.0, 0.0, 2.2)
	# Extra scenery critters (no dialogue).
	for i in 3:
		var c := _npc("", "animal_chicken", "Chicken", -10 + i * 2.0, -16, "wander", 3.0)
		c.dialogue_id = "chicken_cluck"

func _mob(id: String, model: String, enc: String, x: float, z: float, patrol := 7.0, aggro := 9.0) -> void:
	var m := WorldMob.new()
	m.mob_id = id
	m.model_id = model
	m.encounter_id = enc
	m.patrol_radius = patrol
	m.aggro_radius = aggro
	m.position = Vector3(x, 0, z)
	m.name = "Mob_" + id
	add_child(m)

func _build_mobs() -> void:
	_mob("rats_corn_1", "enemy_rat_grunt", "meadow_grunts", -32, -18)
	_mob("rats_corn_2", "enemy_rat_grunt", "meadow_grunts", -36, -2)
	_mob("sapper_1", "enemy_rat_sapper", "crop_mixed", 20, -22, 6.0, 8.0)
	_mob("crow_1", "enemy_crow", "crop_crows", -14, -26, 8.0, 10.0)
	_mob("mold_1", "enemy_mold_blob", "pond_blobs", 4, -40, 5.0, 8.0)
	_mob("weasel_1", "enemy_weasel", "coop_raid", -50, 40, 8.0, 9.0)
	_mob("rats_cave_1", "enemy_rat_grunt", "meadow_pair", -4, -54, 5.0, 8.0)

# ------------------------------------------------------------------ player / ui

func _build_player() -> void:
	player = WorldPlayer.new()
	player.name = "Player"
	var sp := Vector3(SPAWN.x, terrain.height_at(SPAWN.x, SPAWN.z) + 0.6, SPAWN.z)
	player.position = sp
	player.area_checks = [
		{"id": "cheese_cave", "pos": terrain.cave_pos, "radius": 9.0},
		{"id": "rainbow_orchard", "pos": Vector2(-52, -36), "radius": 14.0},
		{"id": "pond", "pos": terrain.pond_center, "radius": 13.0},
		{"id": "barnyard", "pos": Vector2(22, 4), "radius": 14.0},
	]
	player.grass_zones = GRASS_ZONES
	add_child(player)
	player.encounter_roll.connect(_on_encounter_roll)

func _on_encounter_roll(_zone: String) -> void:
	var enc := WorldBus.resolve_encounter(["meadow_grunts", "meadow_pair", "crop_crows"][_rng.randi() % 3])
	WorldBus.emit(&"battle_requested", [enc])

func _build_ui() -> void:
	var ps: Variant = load("res://scripts/ui/dialogue_box.gd")
	dialogue_box = ps.new()
	dialogue_box.name = "DialogueBox"
	add_child(dialogue_box)
	var cl := CanvasLayer.new()
	cl.layer = 6
	var hint := Label.new()
	hint.text = "[WASD] move    [Shift] run    [Q/C] orbit camera    [E] interact"
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 0.97, 0.85, 1))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 10)
	hint.position = Vector2(24, 18)
	cl.add_child(hint)
	add_child(cl)
	var tw := create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(hint, "modulate:a", 0.0, 2.0)
	interaction_triggered.connect(_on_interaction)

func _on_interaction(kind: String, _pid: String) -> void:
	if kind == "shrine" and dialogue_box != null:
		dialogue_box.call("start", "shrine_whisper")

func _process(delta: float) -> void:
	_t += delta
	if windmill_blades != null:
		windmill_blades.rotate_z(delta * 0.6)
	for f in _flickers:
		if is_instance_valid(f):
			f.scale = Vector3.ONE * (1.0 + sin(_t * 11.0) * 0.08)
