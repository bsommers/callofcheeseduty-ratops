extends Node3D
## Scripted enemy encounter for screenshots (owner: enemy-ai). Started by enemy.tscn when it is the
## scene root and the user args contain --enemy_demo=<level-id>:
##   tools/shot.sh res://scenes/enemy.tscn out.png --user-arg --enemy_demo=e1m1 [--user-arg --demo_kind=sewer]
##     [--user-arg --demo_view=shoulder|close] [--user-arg --demo_dist=9] [--frames 150]
## Builds the level, spawns the hero + all enemies (RatEnemySpawner), puts the hero in front of one
## enemy of demo_kind, alerts the room and frames it with its own camera.

var args: Dictionary = {}
var level: LevelBuilder = null
var player: Node3D = null
var focus: RatEnemy = null
var cam: Camera3D = null
var _frames: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	level = LevelBuilder.new()
	level.name = "Level"
	add_child(level)
	if not level.build_level(str(args.get("enemy_demo", "e1m1"))):
		push_error("enemy_demo: level build failed")
		return
	var we: WorldEnvironment = level.find_child("LevelEnvironment", true, false) as WorldEnvironment
	if we != null and we.environment != null:
		we.environment.ambient_light_energy = 3.0
		we.environment.tonemap_exposure = 1.6
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemies: Array[RatEnemy] = RatEnemySpawner.spawn_in_level(level)
	var want: String = str(args.get("demo_kind", ""))
	for e: RatEnemy in enemies:
		if want == "" or e.kind == want:
			focus = e
			break
	if focus == null and not enemies.is_empty():
		focus = enemies[0]
	if focus == null:
		push_error("enemy_demo: no enemies")
		return
	await get_tree().physics_frame
	var dist: float = float(args.get("demo_dist", "9"))
	var best: Vector3 = Vector3.FORWARD
	var bl: float = -1.0
	for d: Vector3 in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		var l: float = focus._ray_len(d, 30.0)
		if l > bl:
			bl = l
			best = d
	var ppos: Vector3 = focus.global_position + best * clampf(bl - 1.0, 3.0, dist)
	var yaw: float = atan2(best.x, best.z)   # hero looks back at the enemy (-Z forward)
	var pscr: Script = load("res://scripts/player/player.gd") as Script
	if pscr != null:
		player = pscr.call("spawn_in_level", level, Transform3D(Basis(Vector3.UP, yaw), ppos)) as Node3D
		if player != null and "use_device_input" in player:
			player.set("use_device_input", false)
		if ResourceLoader.exists("res://scripts/integration/hero_setup.gd") and player != null:
			var hs: Script = load("res://scripts/integration/hero_setup.gd") as Script
			hs.call("apply", player)
	var fill: OmniLight3D = OmniLight3D.new()
	fill.light_energy = 1.2
	fill.omni_range = 12.0
	fill.light_color = Color(1.0, 0.9, 0.75)
	add_child(fill)
	fill.global_position = (focus.global_position + ppos) * 0.5 + Vector3.UP * 2.6
	focus.alert(ppos, true)
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	var look: Vector3 = focus.global_position + Vector3.UP * focus.height * 0.6
	var side: Vector3 = best.cross(Vector3.UP).normalized()
	if str(args.get("demo_view", "shoulder")) == "close":
		cam.global_position = focus.global_position + best * 3.2 + side * 1.6 + Vector3.UP * 1.5
	else:
		cam.global_position = ppos + best * 2.6 + side * 0.9 + Vector3.UP * 2.1
	cam.look_at(look, Vector3.UP)
	cam.make_current()
	print("ENEMY_DEMO focus=%s pos=%s player=%s enemies=%d" % [focus.kind, focus.global_position, ppos, enemies.size()])


func _process(_delta: float) -> void:
	if cam != null:
		cam.make_current()
	_frames += 1
	if focus != null and _frames % 30 == 0:
		print("ENEMY_DEMO t=%d state=%s anim=%s hp_player=%s" % [_frames, focus.state_name(), focus.current_anim(),
			str(player.get("health")) if player != null else "?"])
