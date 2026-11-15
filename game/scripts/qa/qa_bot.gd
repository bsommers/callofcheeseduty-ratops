class_name QaBot
extends Node
## Headless QA bot (owner: botplay-qa). Plays the current level through the real game objects:
## drives the RatPlayer's command interface (cmd_move / rig yaw+pitch / weapons.tick via cmd_fire /
## use()), follows the level navmesh to keys, pickups and the exit, shoots enemies that it has line of
## sight to. Everything it observes goes into `result` (see `_finish`). Emits `finished(result)` once.

signal finished(result: Dictionary)

const MASK_LOS: int = 1 | 64            # world + doors (same as the enemy LOS mask)
const EYE_HEIGHT: float = 1.5
const SHOOT_RANGE: float = 28.0
const HOLD_RANGE: float = 24.0          # stop advancing when a visible enemy is this close
const WAYPOINT_REACH: float = 0.7
const STUCK_WINDOW: float = 1.0
const STUCK_MIN_MOVE: float = 0.35
const MAX_STUCK_LOG: int = 40
const MAX_GOAL_FAILS: int = 3
const PICKUP_DETOUR: float = 11.0       # opportunistic pickup radius (metres)
const NAV_MAX_GAP: float = 2.2          # navmesh end point must be this close to the target

var level_id: String = ""
var time_limit: float = 300.0           # simulated seconds
var visit_pushwalls: bool = false
var god: bool = false                   # QA flow mode: top health up so fights cannot end the run
var result: Dictionary = {}

var _level: Node = null
var _player: RatPlayer = null
var _t: float = 0.0
var _physics_frame: int = 0
var _done: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# goal state
var _goal: Dictionary = {}              # {kind, pos, node?, name}
var _path: PackedVector3Array = PackedVector3Array()
var _path_idx: int = 0
var _repath_t: float = 0.0
var _goal_fails: Dictionary = {}        # goal name -> count
var _goal_blacklist: Dictionary = {}
var _goal_t: float = 0.0
var _use_t: float = 0.0
var _push_done: Dictionary = {}
var _jump_t: float = 0.0

# stuck tracking
var _stuck_t: float = 0.0
var _stuck_ref: Vector3 = Vector3.INF
var _stuck_count: int = 0
var _stuck_points: Array = []
var _stuck_events: int = 0
var _death_points: Array = []
var _last_pos: Vector3 = Vector3.ZERO
var _near_kinds: Array = []
var _last_shot_ref: Dictionary = {}
var _hits: int = 0
var _god_heals: int = 0
var _damage_taken: int = 0
var _nudge_t: float = 0.0
var _nudge_dir: float = 1.0

# stats
var _kills: int = 0
var _deaths: int = 0
var _pickups: int = 0
var _pickup_kinds: Dictionary = {}
var _keys: Array = []
var _doors_opened: int = 0
var _secrets: int = 0
var _shots: int = 0
var _completed: bool = false
var _frame_ms_sum: float = 0.0
var _frame_ms_max: float = 0.0
var _frame_n: int = 0
var _last_tick: int = 0
var _exit_pos: Vector3 = Vector3.ZERO
var _exit_yaw: float = 0.0
var _wall_start: int = 0
var _logger: QaLogCapture = null
var _events_connected: bool = false
var _ev: Node = null
var _bot_map: RID = RID()
var _bot_region: RID = RID()
var _bot_map_sig: String = "?"
var _bound_at: int = 0
var _bind_wait: float = 0.0
var _goal_keysig: String = ""
var _nav_ready_frame: int = 0
var _fight_t: float = 0.0
var _disengage_t: float = 0.0
var _game: Node = null

# cover state
const COVER_RADIUS: float = 13.0        # metres around the player searched for a cell hidden from threats
const COVER_MAX_HOLD: float = 9.0       # seconds spent behind cover per episode
const COVER_COOLDOWN: float = 3.0       # advance for at least this long between episodes
const HEAL_SEEK_HP: int = 55
var _cover_cell: Vector3 = Vector3.INF
var _cover_t: float = 0.0               # time in current cover episode (0 = not in cover mode)
var _cover_cd: float = 0.0
var _cover_path: PackedVector3Array = PackedVector3Array()
var _cover_idx: int = 0
var _cover_quiet: float = 0.0           # seconds since last visible enemy / damage while in cover
var _hurt_t: float = -99.0
var _heal_check_t: float = 0.0
var _cover_episodes: int = 0

const ST_INTERMISSION: int = 3  # Game.State enum values (autoloads are not compile-time names under --script)
const ST_GAME_OVER: int = 4
const ST_VICTORY: int = 5


func start(id: String, limit_s: float, seed_value: int = 1234, with_secrets: bool = false) -> void:
	level_id = id
	time_limit = limit_s
	visit_pushwalls = with_secrets
	_rng.seed = seed_value
	seed(seed_value)
	_wall_start = Time.get_ticks_msec()
	process_physics_priority = -50  # run before the player so our commands are read this tick
	_logger = QaLogCapture.new()
	OS.add_logger(_logger)
	_ev = get_tree().root.get_node("Events")
	_game = get_tree().root.get_node("Game")
	_connect_events()


func _connect_events() -> void:
	if _events_connected:
		return
	_events_connected = true
	_ev.enemy_killed.connect(func(_k: String, _p: Vector3) -> void: _kills += 1)
	_ev.player_died.connect(_on_died)
	_ev.pickup_taken.connect(_on_pickup)
	_ev.player_hurt.connect(func(d: int) -> void:
		_damage_taken += d
		_hurt_t = _t)
	_ev.key_taken.connect(func(c: String) -> void: _keys.append(c))
	_ev.door_opened.connect(func(_i: String) -> void: _doors_opened += 1)
	_ev.secret_found.connect(func() -> void: _secrets += 1)
	_ev.level_completed.connect(func(_s: Dictionary) -> void: _completed = true)
	_ev.level_loaded.connect(func(_id: String) -> void: _on_level_reloaded())


func _on_died() -> void:
	_deaths += 1
	if _death_points.size() < 20:
		var p: Vector3 = _last_pos
		_death_points.append({"pos": [snappedf(p.x, 0.1), snappedf(p.z, 0.1)], "t": snappedf(_t, 0.1), "frame": _physics_frame, "goal": str(_goal.get("name", "")), "near": _near_kinds})


func _on_pickup(kind: String, _amount: int) -> void:
	if OS.get_environment("QA_DEBUG") != "":
		print("QA_PICKUP f=%d %s goalnode_valid=%s goal=%s" % [_physics_frame, kind, is_instance_valid(_goal.get("node")), _goal.get("name")])
	_pickups += 1
	_pickup_kinds[kind] = int(_pickup_kinds.get(kind, 0)) + 1


func _on_level_reloaded() -> void:
	# death restart: a fresh level instance replaces ours
	_free_bot_map()
	_level = null
	_player = null
	_goal = {}
	_path = PackedVector3Array()
	_goal_fails.clear()
	_goal_blacklist.clear()
	_push_done.clear()
	_stuck_ref = Vector3.INF


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last_tick != 0 and not _done:
		var ms: float = float(now - _last_tick) / 1000.0
		_frame_ms_sum += ms
		_frame_ms_max = maxf(_frame_ms_max, ms)
		_frame_n += 1
	_last_tick = now


func _physics_process(delta: float) -> void:
	if _done:
		return
	_physics_frame += 1
	_t += delta
	var gstate: int = int(_game.get("state"))
	if _completed or gstate == ST_INTERMISSION or gstate == ST_VICTORY:
		_finish(true, "exit reached")
		return
	if gstate == ST_GAME_OVER:
		_finish(false, "game over (lives exhausted)")
		return
	if _t >= time_limit:
		_finish(false, "time limit %.0fs" % time_limit)
		return
	if not _bind():
		_bind_wait += delta
		if _bind_wait > 20.0:
			_finish(false, "no player/level after 20s")
		return
	_bind_wait = 0.0
	if _player.dead:
		_player.cmd_move = Vector2.ZERO
		_player.cmd_fire = false
		return
	_last_pos = _player.global_position
	_player.use_device_input = false
	if god and _player.health < 40:
		_player.health = 100
		_god_heals += 1
	if god and _player.weapons != null and _physics_frame % 60 == 0 and _player.weapons.best_weapon() == 0 and not _player.weapons.reloading:
		_player.weapons.add_ammo("hair", 30)  # god mode also restocks the sidearm, so boss arenas are not fought with claws
	_player.cmd_aim = false
	_player.cmd_sprint = false
	_player.cmd_crouch = false
	_player.cmd_jump = false
	_player.cmd_fire = false
	_player.cmd_fire_pressed = false
	_manage_weapon()
	var enemy: Node3D = _pick_enemy()
	if _physics_frame % 10 == 0:
		_near_kinds = _nearby_kinds()
	_nav_map()  # rebuilds after a key pickup
	if _physics_frame < _nav_ready_frame:
		_player.cmd_move = Vector2.ZERO
		return
	if _goal_keysig != _key_signature():
		_goal_keysig = _key_signature()
		if str(_goal.get("kind", "")) != "key":
			_goal = {}
		_goal_blacklist.clear()
		_path = PackedVector3Array()
	_pick_goal_if_needed()
	if _cover_logic(delta, enemy):
		_track_stuck(delta, true)
		return
	var hold: bool = false
	if _disengage_t > 0.0:
		_disengage_t -= delta
	if enemy != null:
		hold = _combat(enemy) and _disengage_t <= 0.0
	_fight_t = _fight_t + delta if hold else 0.0
	if _fight_t > 12.0:  # a standoff that is not resolving: stop holding ground and walk on for a while
		_fight_t = 0.0
		_disengage_t = 10.0
	_navigate(delta, enemy, hold)
	_track_stuck(delta, hold)


## Locate the live level + player. Returns false while the level is still being built.
func _bind() -> bool:
	if _level != null and is_instance_valid(_level) and _player != null and is_instance_valid(_player):
		# the navmesh needs a few physics frames before the nav server answers queries
		_nav_map()
		return _physics_frame - _bound_at > 6 and _physics_frame >= _nav_ready_frame
	var lvl: Node = _game.call("current_level")
	if lvl == null or not is_instance_valid(lvl):
		return false
	var players: Array = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if lvl.is_ancestor_of(p) and p is RatPlayer:
			_level = lvl
			_player = p as RatPlayer
			if _level.get("exit_area") != null:
				var ea: Node3D = _level.get("exit_area") as Node3D
				_exit_pos = ea.global_position
			if _player.rig == null or _level.get("nav_region") == null:
				return false
			_bound_at = _physics_frame
			return false
	return false


# ───────────────────────────── combat ─────────────────────────────
func _manage_weapon() -> void:
	var w: RatWeapons = _player.weapons
	if w == null:
		return
	if not is_same(w.last_shot, _last_shot_ref) and not w.last_shot.is_empty():
		_last_shot_ref = w.last_shot
		_shots += 1
		if bool(w.last_shot.get("hit", false)):
			_hits += 1
	if _physics_frame % 30 == 0:
		var best: int = w.best_weapon()
		if best != w.current and not w.reloading:
			w.select(best)
	if w.has_mag() and w.loaded() <= 0 and w.reserve() > 0 and not w.reloading:
		w.start_reload()


func _eye() -> Vector3:
	return _player.global_position + Vector3.UP * EYE_HEIGHT


## Nearest living enemy with a clear line of sight within SHOOT_RANGE (null otherwise).
func _pick_enemy() -> Node3D:
	var best: Node3D = null
	var best_d: float = SHOOT_RANGE
	var eye: Vector3 = _eye()
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		var e: Node3D = n as Node3D
		if e == null or not is_instance_valid(e) or not e.is_inside_tree():
			continue
		if "state" in e and int(e.get("state")) == RatEnemy.State.DEAD:
			continue
		var d: float = e.global_position.distance_to(_player.global_position)
		if d >= best_d:
			continue
		var tgt: Vector3 = _aim_point(e)
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, tgt, MASK_LOS, [_player.get_rid()])
		if space.intersect_ray(q).is_empty():
			best = e
			best_d = d
	return best


## Name of whatever the player is pressing against (ray along the intended move direction).
func _blocker() -> String:
	var dir: Vector3 = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if dir.length() < 0.1:
		var f: Vector2 = _player.cmd_move
		dir = _player.rig.flat_forward() * f.y + _player.rig.flat_right() * f.x
	if dir.length() < 0.01:
		return "none"
	dir = dir.normalized()
	var from: Vector3 = _player.global_position + Vector3.UP * 0.9
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 1.4, 1 | 4 | 64, [_player.get_rid()])
	var r: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return "open"
	var c: Node = r["collider"] as Node
	return "%s(%s)" % [c.name, c.get_class()]


func _nearby_kinds() -> Array:
	var out: Array = []
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		var e: Node3D = n as Node3D
		if e != null and is_instance_valid(e) and e.global_position.distance_to(_last_pos) < 30.0 and int(e.get("state")) != RatEnemy.State.DEAD:
			out.append("%s@%.0fm:%s" % [str(e.get("kind")), e.global_position.distance_to(_last_pos), RatEnemy.STATE_NAMES[int(e.get("state"))]])
	return out


func _aim_point(e: Node3D) -> Vector3:
	var h: float = float(e.get("height")) if "height" in e else 1.5
	return e.global_position + Vector3.UP * h * 0.62


## Aim at the enemy and fire when roughly on target. Returns true when the bot should stand still.
func _combat(e: Node3D) -> bool:
	var rig: RatPlayerCamera = _player.rig
	var from: Vector3 = rig.camera.global_position if rig.camera != null and rig.camera.is_inside_tree() else _eye()
	var dir: Vector3 = (_aim_point(e) - from).normalized()
	var want_yaw: float = atan2(-dir.x, -dir.z)
	var want_pitch: float = asin(clampf(dir.y, -1.0, 1.0))
	var w: RatWeapons = _player.weapons
	if w != null:
		want_pitch -= w.recoil.x
	rig.yaw = want_yaw
	rig.pitch = clampf(want_pitch, RatPlayerCamera.PITCH_MIN, RatPlayerCamera.PITCH_MAX)
	rig.sync_rotation()
	if w != null and not w.reloading:
		var melee: bool = str(w.def().get("kind", "")) == "melee"
		var d: float = e.global_position.distance_to(_player.global_position)
		var max_d: float = 3.2 if melee else (float(w.def().get("fire_range", 0.0)) if w.def().has("fire_range") else (20.0 if w.current == 1 else SHOOT_RANGE))
		if d < max_d:
			_player.cmd_fire = true
			_player.cmd_fire_pressed = true
	var dist: float = e.global_position.distance_to(_player.global_position)
	if w != null and str(w.def().get("kind", "")) == "melee":
		return false  # claws: close in instead of standing off
	return dist < HOLD_RANGE and _goal.get("kind", "") != "exit"


# ───────────────────────────── cover ─────────────────────────────
## Living enemies within range that are awake (not idle/patrol) or visible; these are the threats cover hides from.
func _threats() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		var e: Node3D = n as Node3D
		if e == null or not is_instance_valid(e) or not e.is_inside_tree():
			continue
		var st: int = int(e.get("state")) if "state" in e else 0
		if st == RatEnemy.State.DEAD or st == RatEnemy.State.IDLE or st == RatEnemy.State.PATROL:
			continue
		if e.global_position.distance_to(_player.global_position) < 32.0:
			out.append(e)
	return out


func _hidden_from(cell_pos: Vector3, threats: Array[Node3D], space: PhysicsDirectSpaceState3D) -> bool:
	var eye: Vector3 = cell_pos + Vector3.UP * EYE_HEIGHT
	for e: Node3D in threats:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, _aim_point(e), MASK_LOS, [_player.get_rid()])
		if space.intersect_ray(q).is_empty():
			return false
	return true


## Nearest walkable cell (by path length) that no current threat can see. Vector3.INF when none.
func _find_cover_cell(threats: Array[Node3D]) -> Vector3:
	if threats.is_empty():
		return Vector3.INF
	var cs: float = float(_level.get("cell"))
	var pos: Vector3 = _player.global_position
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var r: int = int(COVER_RADIUS / cs) + 1
	var pcx: int = int(pos.x / cs)
	var pcy: int = int(pos.z / cs)
	var cands: Array = []
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			var cx: int = pcx + dx
			var cy: int = pcy + dy
			if cx < 0 or cy < 0 or not bool(_level.call("_is_walkable", cx, cy)):
				continue
			var cp: Vector3 = Vector3((cx + 0.5) * cs, 0.0, (cy + 0.5) * cs)
			var d: float = cp.distance_to(Vector3(pos.x, 0.0, pos.z))
			if d > COVER_RADIUS or d < 0.8:
				continue
			# prefer cells that are not nearer to the threats than we are
			var pen: float = 0.0
			for e: Node3D in threats:
				if e.global_position.distance_to(cp) < e.global_position.distance_to(pos) - 1.0:
					pen += 3.0
			cands.append([d + pen, cp])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var tested: int = 0
	for c: Array in cands:
		tested += 1
		if tested > 70:
			break
		var cp: Vector3 = c[1]
		if _hidden_from(cp, threats, space):
			var path: PackedVector3Array = _reachable(cp)
			if not path.is_empty() and _path_len(path) < COVER_RADIUS * 1.6:
				return cp
	return Vector3.INF


## Take cover when hurt or under fire, peek-and-shoot from it, retreat to heal when low. Returns true when it
## drove movement this tick (the normal goal navigation is then skipped).
func _cover_logic(delta: float, enemy: Node3D) -> bool:
	_cover_cd -= delta
	_heal_check_t -= delta
	var hurt_recent: bool = _t - _hurt_t < 1.5
	var hp: int = _player.health
	# low health and calm: walk to a known health pickup instead of continuing to the exit
	if hp < HEAL_SEEK_HP and enemy == null and _heal_check_t <= 0.0 and _cover_t <= 0.0:
		_heal_check_t = 1.5
		_seek_heal()
	if _cover_t <= 0.0:
		# enter cover: under fire, or a visible enemy while not healthy, and not sprinting for the exit
		var near_exit: bool = str(_goal.get("kind", "")) == "exit" and Vector2(_player.global_position.x - _exit_pos.x, _player.global_position.z - _exit_pos.z).length() < 12.0
		if _cover_cd > 0.0 or near_exit or not (hurt_recent or (enemy != null and hp < 101)):
			return false
		var cell: Vector3 = _find_cover_cell(_threats())
		if not cell.is_finite():
			_cover_cd = 1.0
			return false
		_cover_cell = cell
		_cover_t = 0.001
		_cover_quiet = 0.0
		_cover_episodes += 1
		_cover_path = PackedVector3Array()
		_cover_idx = 1
	_cover_t += delta
	if enemy != null or hurt_recent:
		_cover_quiet = 0.0
	else:
		_cover_quiet += delta
	var pos: Vector3 = _player.global_position
	var at_cover: bool = Vector2(pos.x - _cover_cell.x, pos.z - _cover_cell.z).length() < 0.9
	# leave: held long enough, or things are quiet (peeked, killed whatever came) and we are healthy / healing
	var done: bool = _cover_t > COVER_MAX_HOLD or (at_cover and _cover_quiet > (4.0 if hp < 70 else 2.0))
	if done:
		_cover_t = 0.0
		_cover_cd = COVER_COOLDOWN
		_path = PackedVector3Array()
		return false
	if enemy != null:
		# peek-and-shoot: aim + fire (combat sets rig); strafe a little when already in the open
		_combat(enemy)
	if at_cover:
		_player.cmd_move = Vector2.ZERO
		if enemy == null:
			var th: Array[Node3D] = _threats()
			if not th.is_empty():
				var tn: Node3D = th[0]
				_look_at_flat(tn.global_position)
		return true
	if _cover_path.size() < 2 or _cover_idx >= _cover_path.size() or int(_t * 2.0) % 2 == 0 and _physics_frame % 30 == 0:
		_cover_path = _nav_path(pos, _cover_cell)
		_cover_idx = 1
		if _cover_path.size() < 2:
			_cover_t = 0.0
			_cover_cd = 2.0
			return false
	while _cover_idx < _cover_path.size() - 1 and Vector2(pos.x - _cover_path[_cover_idx].x, pos.z - _cover_path[_cover_idx].z).length() < WAYPOINT_REACH:
		_cover_idx += 1
	var wp: Vector3 = _cover_path[mini(_cover_idx, _cover_path.size() - 1)]
	var wish: Vector3 = Vector3(wp.x - pos.x, 0.0, wp.z - pos.z)
	if wish.length() < 0.05:
		_player.cmd_move = Vector2.ZERO
		return true
	wish = wish.normalized()
	var rig: RatPlayerCamera = _player.rig
	if enemy == null:
		rig.yaw = atan2(-wish.x, -wish.z)
		rig.sync_rotation()
	_player.cmd_move = Vector2(rig.flat_right().dot(wish), rig.flat_forward().dot(wish))
	_player.cmd_sprint = enemy == null
	return true


## Redirect the goal to the nearest reachable health pickup (any distance up to 50 m) when hurt.
func _seek_heal() -> void:
	if str(_goal.get("kind", "")) == "pickup" and _goal.has("node") and is_instance_valid(_goal["node"]) and (_goal["node"] as Node).get("item") is Dictionary and ((_goal["node"] as Node).get("item") as Dictionary).has("heal"):
		return
	var pos: Vector3 = _player.global_position
	var best: Dictionary = {}
	var best_len: float = INF
	for n: Node in _pickup_nodes():
		var it: Dictionary = n.get("item") as Dictionary
		if it == null or not it.has("heal") or _goal_blacklist.has(str(n.name)):
			continue
		var n3: Node3D = n as Node3D
		if n3.global_position.distance_to(pos) > 50.0:
			continue
		var p: PackedVector3Array = _reachable(n3.global_position)
		if p.is_empty():
			continue
		var l: float = _path_len(p)
		if l < best_len:
			best_len = l
			best = {"kind": "pickup", "pos": n3.global_position, "node": n3, "name": str(n.name)}
	if not best.is_empty():
		_set_goal(best)


# ───────────────────────────── goals ─────────────────────────────
## The bot keeps its own navigation map built from the level data the same way LevelBuilder builds the
## game's navmesh (one polygon per walkable cell, shared corner vertices), except that LOCKED doors whose
## key is not held count as walls. (The game's navmesh ignores locks, so its paths run into locked doors.)
func _nav_map() -> RID:
	var sig: String = _key_signature()
	if _bot_map.is_valid() and sig == _bot_map_sig:
		return _bot_map
	_free_bot_map()
	var cell: float = float(_level.get("cell"))
	var w: int = 0
	var h: int = 0
	var grid: Array = (_level.get("data") as Dictionary).get("grid", [])
	h = grid.size()
	w = (grid[0] as String).length() if h > 0 else 0
	var locked: Dictionary = {}
	for dd: Variant in (_level.get("data") as Dictionary).get("doors", []):
		var d: Dictionary = dd as Dictionary
		var lk: String = str(d["lock"]) if d.get("lock") != null else ""
		if lk != "" and not (_level.get("keys_held") as Dictionary).has(lk):
			locked[Vector2i(int(d["x"]), int(d["y"]))] = true
	var nm: NavigationMesh = NavigationMesh.new()
	var verts: PackedVector3Array = PackedVector3Array()
	var vi: Dictionary = {}
	var polys: Array[PackedInt32Array] = []
	for cy: int in h:
		for cx: int in w:
			if locked.has(Vector2i(cx, cy)) or not bool(_level.call("_is_walkable", cx, cy)):
				continue
			var ids: PackedInt32Array = PackedInt32Array()
			for corner: Vector2i in [Vector2i(cx, cy), Vector2i(cx + 1, cy), Vector2i(cx + 1, cy + 1), Vector2i(cx, cy + 1)]:
				if not vi.has(corner):
					vi[corner] = verts.size()
					verts.append(Vector3(corner.x * cell, 0.0, corner.y * cell))
				ids.append(vi[corner])
			polys.append(ids)
	nm.vertices = verts  # vertices first: add_polygon indexes into them
	for pids: PackedInt32Array in polys:
		nm.add_polygon(pids)
	_bot_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_active(_bot_map, true)
	_bot_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_bot_region, _bot_map)
	NavigationServer3D.region_set_navigation_mesh(_bot_region, nm)
	NavigationServer3D.map_force_update(_bot_map)
	_bot_map_sig = sig
	_nav_ready_frame = _physics_frame + 8  # the nav server applies the region on its next syncs
	if OS.get_environment("QA_DEBUG") != "":
		print("QA_NAVMAP polys=%d verts=%d locked=%d regions=%d iter=%d" % [polys.size(), verts.size(), locked.size(), NavigationServer3D.map_get_regions(_bot_map).size(), NavigationServer3D.map_get_iteration_id(_bot_map)])
	return _bot_map


func _key_signature() -> String:
	var ks: Array = (_level.get("keys_held") as Dictionary).keys()
	ks.sort()
	return ",".join(PackedStringArray(ks))


func _free_bot_map() -> void:
	if _bot_region.is_valid():
		NavigationServer3D.free_rid(_bot_region)
		_bot_region = RID()
	if _bot_map.is_valid():
		NavigationServer3D.free_rid(_bot_map)
		_bot_map = RID()


func _nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: RID = _nav_map()
	if not map.is_valid():
		return PackedVector3Array()
	var raw: PackedVector3Array = NavigationServer3D.map_get_path(map, Vector3(from.x, 0.0, from.z), Vector3(to.x, 0.0, to.z), true)
	return _clear_corners(raw)


## The funnel path hugs wall corners (zero-radius agent); the capsule then snags on them. Push intermediate
## waypoints that sit on a cell-grid vertex away from the blocked cells around that vertex.
func _clear_corners(p: PackedVector3Array) -> PackedVector3Array:
	if p.size() < 3:
		return p
	var cs: float = float(_level.get("cell"))
	var out: PackedVector3Array = p.duplicate()
	for i: int in range(1, p.size() - 1):
		var gx: float = roundf(p[i].x / cs)
		var gy: float = roundf(p[i].z / cs)
		if absf(p[i].x - gx * cs) > 0.05 or absf(p[i].z - gy * cs) > 0.05:
			continue
		var push: Vector2 = Vector2.ZERO
		for dx: int in [-1, 0]:
			for dy: int in [-1, 0]:
				var cx: int = int(gx) + dx
				var cy: int = int(gy) + dy
				if cx < 0 or cy < 0 or not bool(_level.call("_is_walkable", cx, cy)):
					push += Vector2(-2 * dx - 1, -2 * dy - 1)
		if push != Vector2.ZERO:
			out[i] = Vector3(p[i].x + signf(push.x) * 0.9, p[i].y, p[i].z + signf(push.y) * 0.9)
	return out


func _path_len(p: PackedVector3Array) -> float:
	var l: float = 0.0
	for i: int in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l


func _reachable(to: Vector3) -> PackedVector3Array:
	var p: PackedVector3Array = _nav_path(_player.global_position, to)
	if p.size() < 2:
		return PackedVector3Array()
	var last: Vector3 = p[p.size() - 1]
	if Vector2(last.x - to.x, last.z - to.z).length() > NAV_MAX_GAP:
		return PackedVector3Array()
	return p


func _pickup_nodes() -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(n) and n.is_inside_tree() and _level.is_ancestor_of(n):
			out.append(n)
	return out


func _wanted(it: Dictionary) -> bool:
	if it.has("key") or it.has("weapon"):
		return true
	if it.has("heal"):
		return _player.health < 75
	if it.has("ammo"):
		return true
	return it.has("life") or it.has("treasure")


func _pick_goal_if_needed() -> void:
	if not _goal.is_empty():
		if _goal.has("node") and not is_instance_valid(_goal["node"]):
			_goal = {}  # pickup consumed
		else:
			return
	var pos: Vector3 = _player.global_position
	# 1. keys (locked doors guard the exit route); then 2. nearby opportunistic pickups; 3. secrets; 4. exit
	var best: Dictionary = {}
	var best_len: float = INF
	for n: Node in _pickup_nodes():
		var it: Dictionary = n.get("item") as Dictionary
		var nm: String = str(n.name)
		if it == null or _goal_blacklist.has(nm) or not _wanted(it):
			continue
		var node3: Node3D = n as Node3D
		var straight: float = node3.global_position.distance_to(pos)
		var is_key: bool = it.has("key")
		var dry: bool = it.has("ammo") and _player.weapons != null and _player.weapons.best_weapon() == 0  # claws only: restock
		var detour: float = PICKUP_DETOUR * (4.0 if (it.has("weapon") or dry) else 1.0)
		if not is_key and straight > detour:
			continue
		var p: PackedVector3Array = _reachable(node3.global_position)
		if is_key and OS.get_environment("QA_DEBUG") != "":
			print("QA_KEY ", nm, " reachable=", not p.is_empty(), " path=", _nav_path(pos, node3.global_position), " near=", _nav_path(pos, pos + Vector3(8, 0, 0)), " closest=", NavigationServer3D.map_get_closest_point(_nav_map(), node3.global_position), " start_closest=", NavigationServer3D.map_get_closest_point(_nav_map(), pos))
		if p.is_empty():
			continue
		var l: float = _path_len(p)
		if not is_key and l > detour * 1.6:
			continue
		if is_key:
			l -= 1000.0  # keys outrank everything
		if l < best_len:
			best_len = l
			best = {"kind": "key" if is_key else "pickup", "pos": node3.global_position, "node": n, "name": nm}
	if best.is_empty() and visit_pushwalls:
		best = _pushwall_goal()
	if best.is_empty():
		best = {"kind": "exit", "pos": _exit_pos, "name": "exit"}
	_set_goal(best)


func _pushwall_goal() -> Dictionary:
	var best: Dictionary = {}
	var best_len: float = INF
	for n: Node in get_tree().get_nodes_in_group("pushwall"):
		var pw: Node3D = n as Node3D
		if pw == null or not _level.is_ancestor_of(pw) or _push_done.has(pw.name) or _goal_blacklist.has(str(pw.name)):
			continue
		if bool(pw.get("used")):
			continue
		# stand in the nearest walkable neighbour cell
		var cs: float = float(_level.get("cell"))
		for dv: Vector3 in [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			var stand: Vector3 = pw.global_position + dv * cs
			var p: PackedVector3Array = _reachable(stand)
			if p.is_empty():
				continue
			var l: float = _path_len(p)
			if l < best_len:
				best_len = l
				best = {"kind": "pushwall", "pos": stand, "node": pw, "face": pw.global_position, "name": str(pw.name)}
	return best


func _set_goal(g: Dictionary) -> void:
	if OS.get_environment("QA_DEBUG") != "":
		print("QA_GOAL t=%.1f %s at %s from %s" % [_t, g.get("name"), g.get("pos"), _player.global_position])
	_goal = g
	_goal_t = 0.0
	_repath_t = 0.0
	_path = PackedVector3Array()
	_path_idx = 0
	_stuck_count = 0


func _fail_goal(reason: String) -> void:
	var nm: String = str(_goal.get("name", "?"))
	_goal_fails[nm] = int(_goal_fails.get(nm, 0)) + 1
	if str(_goal.get("kind", "")) != "exit" and int(_goal_fails[nm]) >= 1:
		_goal_blacklist[nm] = reason
	elif str(_goal.get("kind", "")) == "exit" and int(_goal_fails[nm]) >= MAX_GOAL_FAILS and not visit_pushwalls:
		visit_pushwalls = true  # exit unreachable by normal means: try secrets
		_goal_fails[nm] = 0
	_goal = {}


# ───────────────────────────── movement ─────────────────────────────
func _navigate(delta: float, enemy: Node3D, hold: bool) -> void:
	if _goal.is_empty():
		return
	if not hold:
		_goal_t += delta  # time spent fighting does not count against the goal
	_repath_t -= delta
	_use_t -= delta
	_jump_t -= delta
	_nudge_t -= delta
	var kind: String = str(_goal.get("kind", ""))
	var target: Vector3 = _goal["pos"]
	var pos: Vector3 = _player.global_position
	var flat_d: float = Vector2(pos.x - target.x, pos.z - target.z).length()
	# arrival
	if kind == "exit" and flat_d < 2.4:
		_face_exit()
		_player.cmd_move = Vector2.ZERO
		if _use_t <= 0.0:
			_use_t = 0.5
			_player.use()
		return
	if kind == "pushwall" and flat_d < 1.4:
		var pw: Node3D = _goal["node"] as Node3D
		_look_at_flat(_goal["face"])
		_player.cmd_move = Vector2.ZERO
		_player.use()
		_push_done[pw.name] = true
		_goal = {}
		return
	if (kind == "pickup" or kind == "key") and flat_d < 0.8 and _goal_t > 6.0 and is_instance_valid(_goal.get("node")) and not (_goal["node"] as Node).is_queued_for_deletion():
		_fail_goal("not collected on arrival")
		return
	if OS.get_environment("QA_DEBUG") != "" and (kind == "key" or kind == "pickup") and flat_d < 1.2 and _physics_frame % 120 == 0 and is_instance_valid(_goal.get("node")):
		var a: Area3D = _goal["node"] as Area3D
		print("QA_NEAR ", a.name, " mon=", a.monitoring, " mask=", a.collision_mask, " gpos=", a.global_position, " player=", pos, " ovl=", a.get_overlapping_bodies(), " dist3=", a.global_position.distance_to(pos))
	if _goal_t > 150.0 and kind != "exit":
		_fail_goal("goal timeout")
		return
	if _path.size() < 2 or _repath_t <= 0.0 or _path_idx >= _path.size():
		_path = _nav_path(pos, target)
		_path_idx = 1
		_repath_t = 2.0
		if _path.size() < 2:
			_path = PackedVector3Array([pos, Vector3(target.x, 0.0, target.z)])  # direct fallback
			_path_idx = 1
	while _path_idx < _path.size() - 1 and Vector2(pos.x - _path[_path_idx].x, pos.z - _path[_path_idx].z).length() < WAYPOINT_REACH:
		_path_idx += 1
	var wp: Vector3 = _path[mini(_path_idx, _path.size() - 1)]
	var to_wp: Vector3 = Vector3(wp.x - pos.x, 0.0, wp.z - pos.z)
	if to_wp.length() < 0.05:
		_player.cmd_move = Vector2.ZERO
		return
	var wish: Vector3 = to_wp.normalized()
	if enemy != null and _player.weapons != null and str(_player.weapons.def().get("kind", "")) == "melee":
		wish = Vector3(enemy.global_position.x - pos.x, 0.0, enemy.global_position.z - pos.z).normalized()
	if _nudge_t > 0.0:  # stuck recovery: sidestep
		wish = wish.rotated(Vector3.UP, _nudge_dir * 1.1)
	var rig: RatPlayerCamera = _player.rig
	if enemy == null:
		rig.yaw = atan2(-wish.x, -wish.z)
		rig.pitch = lerpf(rig.pitch, 0.0, 0.2)
		rig.sync_rotation()
	var fwd: Vector3 = rig.flat_forward()
	var right: Vector3 = rig.flat_right()
	var mv: Vector2 = Vector2(right.dot(wish), fwd.dot(wish))
	if hold:
		# stand and fight, but strafe (side to side every ~1.2 s) so ranged enemies miss more
		var side: float = 1.0 if int(_t / 1.2) % 2 == 0 else -1.0
		_player.cmd_move = Vector2(side * 0.8, 0.0)
	else:
		_player.cmd_move = mv
	_player.cmd_sprint = enemy == null and mv.y > 0.5
	# open doors in the way (proximity opens them, `use` also works for closed locked-with-key doors)
	if _use_t <= 0.0 and enemy == null:
		_use_t = 1.2
		_player.use()


func _face_exit() -> void:
	var rig: RatPlayerCamera = _player.rig
	var ec: Variant = _level.get("exit_cell")
	var cs: float = float(_level.get("cell"))
	if ec is Vector2i:
		var wc: Vector3 = Vector3(((ec as Vector2i).x + 0.5) * cs, 0.0, ((ec as Vector2i).y + 0.5) * cs)
		var d: Vector3 = wc - _player.global_position
		d.y = 0.0
		if d.length() > 0.01:
			rig.yaw = atan2(-d.x, -d.z)
			rig.pitch = 0.0
			rig.sync_rotation()
			_exit_yaw = rig.yaw


func _look_at_flat(p: Vector3) -> void:
	var d: Vector3 = p - _player.global_position
	d.y = 0.0
	if d.length() > 0.01:
		_player.rig.yaw = atan2(-d.x, -d.z)
		_player.rig.pitch = 0.0
		_player.rig.sync_rotation()


# ───────────────────────────── stuck detection ─────────────────────────────
func _track_stuck(delta: float, hold: bool) -> void:
	if _goal.is_empty() or hold:
		_stuck_t = 0.0
		_stuck_ref = _player.global_position
		return
	if str(_goal.get("kind", "")) == "exit" and Vector2(_player.global_position.x - _exit_pos.x, _player.global_position.z - _exit_pos.z).length() < 2.4:
		return
	_stuck_t += delta
	if _stuck_t < STUCK_WINDOW:
		return
	_stuck_t = 0.0
	var pos: Vector3 = _player.global_position
	if _stuck_ref != Vector3.INF and pos.distance_to(_stuck_ref) < STUCK_MIN_MOVE:
		_stuck_count += 1
		_stuck_events += 1
		if _stuck_points.size() < MAX_STUCK_LOG:
			_stuck_points.append({"pos": [snappedf(pos.x, 0.1), snappedf(pos.y, 0.1), snappedf(pos.z, 0.1)],
				"frame": _physics_frame, "t": snappedf(_t, 0.1), "goal": str(_goal.get("name", "?")), "blocker": _blocker(), "near": _nearby_kinds().slice(0, 3)})
		_nudge_t = 0.8
		_nudge_dir = -_nudge_dir
		_repath_t = 0.0
		if _stuck_count % 2 == 0:
			_player.cmd_jump = true
		_player.use()
		if _stuck_count >= 5:
			_fail_goal("stuck")
	else:
		_stuck_count = maxi(0, _stuck_count - 1)
	_stuck_ref = pos


# ───────────────────────────── result ─────────────────────────────
func _level_total(key: String, fallback: int) -> int:
	if _level != null and is_instance_valid(_level):
		var ls: Variant = _level.get("stats")
		if ls is Dictionary and (ls as Dictionary).has(key):
			return int((ls as Dictionary)[key])
	return fallback


func _finish(reached: bool, reason: String) -> void:
	if _done:
		return
	_done = true
	var st: Dictionary = _game.get("stats")
	var cap: Dictionary = _logger.snapshot() if _logger != null else {}
	var pp: Vector3 = _player.global_position if _player != null and is_instance_valid(_player) else Vector3.ZERO
	result = {
		"level": level_id, "reached_exit": reached, "reason": reason,
		"sim_time": snappedf(_t, 0.1), "wall_s": snappedf(float(Time.get_ticks_msec() - _wall_start) / 1000.0, 0.1),
		"kills": _kills, "kills_total": _level_total("enemies", int(st.get("kills_total", 0))), "deaths": _deaths, "death_points": _death_points,
		"lives_left": int(_game.get("lives")), "health": _player.health if _player != null and is_instance_valid(_player) else 0,
		"pickups": _pickups, "pickup_kinds": _pickup_kinds, "keys": _keys, "doors_opened": _doors_opened,
		"secrets": _secrets, "blacklist": _goal_blacklist, "game_stats": st.duplicate(), "god": god, "god_heals": _god_heals, "damage_taken": _damage_taken, "shots": _shots, "hits": _hits, "weapon": int(_player.weapons.current) if _player != null and is_instance_valid(_player) and _player.weapons != null else -1, "cover_episodes": _cover_episodes, "stuck_events": _stuck_events, "stuck_points": _stuck_points,
		"errors": int(cap.get("errors", 0)), "warnings": int(cap.get("warnings", 0)), "log": cap.get("messages", []),
		"frame_ms_avg": snappedf(_frame_ms_sum / maxf(1.0, float(_frame_n)), 0.01), "frame_ms_max": snappedf(_frame_ms_max, 0.1),
		"physics_frames": _physics_frame,
		"final_pos": [snappedf(pp.x, 0.1), snappedf(pp.y, 0.1), snappedf(pp.z, 0.1)], "final_yaw": snappedf(_exit_yaw, 0.001),
		"exit_pos": [snappedf(_exit_pos.x, 0.1), snappedf(_exit_pos.y, 0.1), snappedf(_exit_pos.z, 0.1)],
		"goal": str(_goal.get("name", "")),
	}
	_free_bot_map()
	if _logger != null:
		OS.remove_logger(_logger)
	if _player != null and is_instance_valid(_player):
		_player.cmd_move = Vector2.ZERO
		_player.cmd_fire = false
	finished.emit(result)
