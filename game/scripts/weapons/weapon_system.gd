class_name RatWeapons
extends Node3D
## The hero's weapon inventory and firing logic (ARCHITECTURE section 6). Data: res://data/weapons.json
## (port of reference defs.js WEAPONS). Kinds: melee (cone pick), hitscan (spread + recoil pattern,
## headshots, falloff, tracer, flash, decal), projectile (RatYarnBall, splash), beam (dps + stun).
## Damage goes to `take_damage(amount, source, hitbox)` on the nearest ancestor in group `enemy`.
## Emits Events.weapon_changed / ammo_changed / sfx. Positioned at the muzzle (child of the player).

const DATA_PATH: String = "res://data/weapons.json"
const HIT_MASK: int = 1 | 4 | 64          # world, enemy, door
const ENEMY_LAYER: int = 4
const AMMO_MAX_FALLBACK: Dictionary = {"hair": 99, "yarn": 20, "cell": 200}

## Player that owns these weapons (excluded from rays, passed as damage source).
var player: Node3D = null
## Camera used for aiming: shots go where the screen centre points.
var aim_camera: Camera3D = null
## Movement state fed by the player each frame (accuracy penalties).
var move_fraction: float = 0.0
var crouched: bool = false
var airborne: bool = false
var aiming: bool = false

var defs: Array = []                      # weapon dicts, index = slot
var projectiles: Dictionary = {}
var headshot_default: float = 2.5
var falloff: Dictionary = {"start_m": 40.0, "per_m": 0.01, "min": 0.55}

var owned: Array[bool] = [true, true, false, false, false]
var ammo: Dictionary = {"hair": 16, "yarn": 0, "cell": 0}   # reserve pools (not in magazines)
var mags: Array[int] = [0, 0, 0, 0, 0]
var current: int = 1

## Accumulated recoil view offset (x = pitch up, y = yaw) in radians; the camera adds it to the view.
var recoil: Vector2 = Vector2.ZERO
var reloading: bool = false
var beam_on: bool = false
## Last shot result for tests/debug: {"hit": bool, "pos", "collider", "hitbox", "damage"}.
var last_shot: Dictionary = {}

var _cooldown: float = 0.0
var _reload_t: float = 0.0
var _shot_index: int = 0
var _since_shot: float = 99.0
var _beam_acc_ammo: float = 0.0
var _beam_acc_dmg: float = 0.0
var _beam_mesh: MeshInstance3D = null
var _beam_dot: OmniLight3D = null


func _ready() -> void:
	if defs.is_empty():
		load_data()


func load_data(path: String = DATA_PATH) -> void:
	var txt: String = FileAccess.get_file_as_string(path)
	var d: Variant = JSON.parse_string(txt) if txt != "" else null
	if d is Dictionary:
		defs = (d as Dictionary).get("weapons", [])
		projectiles = (d as Dictionary).get("projectiles", {})
		headshot_default = float((d as Dictionary).get("headshot_multiplier", 2.5))
		falloff = (d as Dictionary).get("falloff", falloff)
	if defs.is_empty():
		push_warning("RatWeapons: %s missing; falling back to Defs.WEAPONS" % path)
		for w: Dictionary in Defs.WEAPONS:
			var c: Dictionary = w.duplicate(true)
			c["range"] = float(c.get("range", 1.0)) * (1.75 if c.get("kind") == "melee" else 4.0)
			defs.append(c)
	while owned.size() < defs.size():
		owned.append(false)
	while mags.size() < defs.size():
		mags.append(0)


# ───────────────────────────── loadout ─────────────────────────────
## Load Game.loadout-style data ({"ammo": {type: n}, "owned": [bool], "weapon": int}); fills magazines from the pools.
func apply_loadout(lo: Dictionary) -> void:
	var a: Variant = lo.get("ammo", null)
	if a is Dictionary:
		ammo = (a as Dictionary).duplicate(true)
	for t: String in ["hair", "yarn", "cell"]:
		if not ammo.has(t):
			ammo[t] = 0
	var o: Variant = lo.get("owned", null)
	if o is Array:
		for i: int in mini((o as Array).size(), owned.size()):
			owned[i] = bool(o[i])
	owned[0] = true
	for i: int in mags.size():
		mags[i] = 0
	for i: int in defs.size():
		if owned[i]:
			_top_up_mag(i)
	var w: int = int(lo.get("weapon", 1))
	current = w if _usable(w) else best_weapon()
	reloading = false
	_emit_all()


## Loadout snapshot for Game (magazine rounds are folded back into the pools).
func export_loadout() -> Dictionary:
	var pools: Dictionary = ammo.duplicate(true)
	for i: int in defs.size():
		var t: String = str(defs[i].get("ammo", ""))
		if t != "" and mags[i] > 0:
			pools[t] = int(pools.get(t, 0)) + mags[i]
	return {"ammo": pools, "owned": owned.duplicate(), "weapon": current}


func def(i: int = -1) -> Dictionary:
	var k: int = current if i < 0 else i
	return defs[k] if k >= 0 and k < defs.size() else {}


func ammo_type(i: int = -1) -> String:
	return str(def(i).get("ammo", ""))


func has_mag(i: int = -1) -> bool:
	return int(def(i).get("mag", 0)) > 0


## Rounds available right now for slot i (magazine, or pool for magazine-less weapons).
func loaded(i: int = -1) -> int:
	var k: int = current if i < 0 else i
	if ammo_type(k) == "":
		return 0
	return mags[k] if has_mag(k) else int(ammo.get(ammo_type(k), 0))


func reserve(i: int = -1) -> int:
	var k: int = current if i < 0 else i
	if ammo_type(k) == "" or not has_mag(k):
		return 0
	return int(ammo.get(ammo_type(k), 0))


func total_ammo(i: int = -1) -> int:
	var k: int = current if i < 0 else i
	if ammo_type(k) == "":
		return 1
	return loaded(k) + reserve(k)


func _usable(i: int) -> bool:
	return i >= 0 and i < defs.size() and owned[i] and (ammo_type(i) == "" or total_ammo(i) > 0)


## Best owned weapon with ammo (highest slot first, reference bestWeapon).
func best_weapon() -> int:
	for i: int in range(defs.size() - 1, -1, -1):
		if _usable(i):
			return i
	return 0


func _top_up_mag(i: int) -> void:
	if not has_mag(i):
		return
	var t: String = ammo_type(i)
	var need: int = int(def(i).get("mag", 0)) - mags[i]
	var take: int = mini(need, int(ammo.get(t, 0)))
	if take > 0:
		mags[i] += take
		ammo[t] = int(ammo[t]) - take


func ammo_max(t: String) -> int:
	var m: Dictionary = Defs.AMMO_MAX if not Defs.AMMO_MAX.is_empty() else AMMO_MAX_FALLBACK
	return int(m.get(t, 999))


## Add ammo to a pool (clamped to Defs.AMMO_MAX including loaded rounds). Returns the amount accepted.
func add_ammo(t: String, n: int) -> int:
	if t == "" or n <= 0:
		return 0
	var in_mags: int = 0
	for i: int in defs.size():
		if ammo_type(i) == t and has_mag(i):
			in_mags += mags[i]
	var room: int = maxi(0, ammo_max(t) - in_mags - int(ammo.get(t, 0)))
	var got: int = mini(room, n)
	ammo[t] = int(ammo.get(t, 0)) + got
	if loaded() == 0 and has_mag() and ammo_type() == t and not reloading:
		start_reload()
	_emit_ammo()
	return got


## Give a weapon slot (pickup). Switches to it when it outranks the current one.
func give_weapon(i: int) -> void:
	if i < 0 or i >= defs.size():
		return
	var had: bool = owned[i]
	owned[i] = true
	_top_up_mag(i)
	if not had and i > current:
		select(i, true)
	else:
		_emit_ammo()


# ───────────────────────────── switching ─────────────────────────────
func select(i: int, force: bool = false) -> bool:
	if i < 0 or i >= defs.size() or not owned[i]:
		return false
	if not force and not _usable(i):
		return false
	if i == current and not force:
		return false
	current = i
	reloading = false
	_reload_t = 0.0
	_cooldown = maxf(_cooldown, 0.25)
	_shot_index = 0
	_stop_beam()
	_emit_all()
	Events.sfx.emit("weapon_switch", global_position if is_inside_tree() else Vector3.ZERO)
	return true


func cycle(dir: int) -> bool:
	var n: int = defs.size()
	for step: int in range(1, n):
		var i: int = posmod(current + dir * step, n)
		if _usable(i):
			return select(i)
	return false


# ───────────────────────────── reload ─────────────────────────────
func start_reload() -> bool:
	if reloading or not has_mag():
		return false
	if mags[current] >= int(def().get("mag", 0)) or int(ammo.get(ammo_type(), 0)) <= 0:
		return false
	reloading = true
	_reload_t = float(def().get("reload", 1.5))
	Events.sfx.emit("reload_" + str(def().get("id", "")), global_position if is_inside_tree() else Vector3.ZERO)
	return true


func _finish_reload() -> void:
	reloading = false
	_top_up_mag(current)
	_emit_ammo()


# ───────────────────────────── per-frame ─────────────────────────────
## Advance timers and fire. `held` = fire button down, `pressed` = went down this frame.
func tick(delta: float, held: bool, pressed: bool) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_since_shot += delta
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()
	var w: Dictionary = def()
	var rec_rate: float = float(w.get("recoil_recover", 5.0))
	if _since_shot > maxf(0.12, float(w.get("period", 0.1)) * 1.6):
		recoil = recoil.lerp(Vector2.ZERO, clampf(rec_rate * delta, 0.0, 1.0))
		if recoil.length() < 0.002:
			_shot_index = 0
	if str(w.get("kind", "")) == "beam":
		if held and loaded() > 0:
			_beam(delta)
		else:
			_stop_beam()
			if pressed and loaded() <= 0:
				_out_of_ammo()
		return
	var want: bool = pressed or (held and bool(w.get("auto", false)))
	if want and _cooldown <= 0.0:
		fire()


## Fire once if possible. Returns true when a shot/swing/launch happened.
func fire() -> bool:
	if _cooldown > 0.0 or reloading:
		return false
	var w: Dictionary = def()
	var kind: String = str(w.get("kind", ""))
	if ammo_type() != "" and loaded() < int(w.get("use", 1)):
		if has_mag() and reserve() > 0:
			start_reload()
		else:
			_out_of_ammo()
		return false
	_cooldown = float(w.get("period", 0.3))
	match kind:
		"melee":
			_melee(w)
		"hitscan":
			_spend(w)
			_hitscan(w)
		"projectile":
			_spend(w)
			_launch(w)
		_:
			return false
	_since_shot = 0.0
	_kick(w)
	_noise(w)
	if has_mag() and mags[current] <= 0 and reserve() > 0:
		start_reload()
	return true


func _spend(w: Dictionary) -> void:
	var use: int = int(w.get("use", 1))
	if has_mag():
		mags[current] = maxi(0, mags[current] - use)
	else:
		var t: String = ammo_type()
		ammo[t] = maxi(0, int(ammo.get(t, 0)) - use)
	_emit_ammo()


func _out_of_ammo() -> void:
	Events.sfx.emit("dry_fire", global_position if is_inside_tree() else Vector3.ZERO)
	var b: int = best_weapon()
	if b != current:
		select(b)


func _kick(w: Dictionary) -> void:
	var pat: Array = w.get("recoil", [])
	if pat.is_empty():
		return
	var k: Array = pat[mini(_shot_index, pat.size() - 1)]
	var mult: float = (0.6 if crouched else 1.0) * (0.8 if aiming else 1.0)
	recoil += Vector2(float(k[0]), float(k[1])) * mult
	recoil.x = minf(recoil.x, 0.35)
	_shot_index += 1


func _noise(w: Dictionary) -> void:
	if not is_inside_tree():
		return
	Events.sfx.emit(str(w.get("id", "")), global_position)
	if int(w.get("loud", 0)) > 0 and Events.has_signal("noise"):
		Events.emit_signal("noise", global_position, float(w.get("loud", 0)) * 4.0)


## Current spread cone half-angle in radians.
func current_spread() -> float:
	var w: Dictionary = def()
	var s: float = float(w.get("spread", 0.0)) + float(w.get("spread_move", 0.0)) * clampf(move_fraction, 0.0, 1.5)
	if airborne:
		s += float(w.get("spread_air", 0.0))
	if crouched:
		s *= float(w.get("crouch_mult", 0.7))
	if aiming:
		s *= float(w.get("ads_mult", 0.5))
	return s


# ───────────────────────────── aiming helpers ─────────────────────────────
func _excludes() -> Array[RID]:
	var ex: Array[RID] = []
	if player is CollisionObject3D:
		ex.append((player as CollisionObject3D).get_rid())
	return ex


## [origin, direction] of the aim ray (screen centre; starts level with the player so walls behind the hero are ignored).
func aim_ray() -> Array:
	var origin: Vector3 = global_position
	var dir: Vector3 = -global_transform.basis.z
	if aim_camera != null and aim_camera.is_inside_tree():
		dir = -aim_camera.global_transform.basis.z
		origin = aim_camera.global_position
		if player != null:
			var ahead: float = (player.global_position + Vector3.UP * 1.4 - origin).dot(dir)
			origin += dir * maxf(0.0, ahead)
	elif player != null:
		dir = -player.global_transform.basis.z
	return [origin, dir.normalized()]


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, _excludes())
	q.collide_with_areas = true
	q.hit_from_inside = false
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var r: Dictionary = space.intersect_ray(q)
	# ignore non-hitbox areas (sensors) that slipped into the mask
	var guard: int = 0
	while not r.is_empty() and r["collider"] is Area3D and (((r["collider"] as Area3D).collision_layer & ENEMY_LAYER) == 0) and guard < 6:
		var ex: Array[RID] = q.exclude
		ex.append((r["collider"] as Area3D).get_rid())
		q.exclude = ex
		r = space.intersect_ray(q)
		guard += 1
	return r


static func _spread_dir(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return dir
	var up: Vector3 = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var right: Vector3 = dir.cross(up).normalized()
	var up2: Vector3 = right.cross(dir).normalized()
	var a: float = randf() * TAU
	var r: float = sqrt(randf()) * spread
	return (dir + (right * cos(a) + up2 * sin(a)) * tan(r)).normalized()


## Walk up from a collider to the enemy node (group `enemy` with take_damage). Null if none.
static func find_enemy(n: Node) -> Node:
	var cur: Node = n
	var depth: int = 0
	while cur != null and depth < 8:
		if cur.is_in_group("enemy") and cur.has_method("take_damage"):
			return cur
		if cur.has_meta("enemy") and cur.get_meta("enemy") is Node:
			return cur.get_meta("enemy")
		cur = cur.get_parent()
		depth += 1
	return null


## "head" when the hit collider/shape is a head hitbox (group `hitbox_head`, node name containing "head",
## or meta hitbox="head"), or when the hit is above the enemy's `head_y` meta (metres above its origin).
static func hitbox_of(r: Dictionary, enemy: Node) -> String:
	var col: Object = r.get("collider", null)
	var nodes: Array[Node] = []
	if col is Node:
		nodes.append(col as Node)
	if col is CollisionObject3D and r.has("shape"):
		var co := col as CollisionObject3D
		var owner_id: int = co.shape_find_owner(int(r["shape"]))
		if owner_id >= 0:
			var so: Object = co.shape_owner_get_owner(owner_id)
			if so is Node:
				nodes.append(so as Node)
	for n: Node in nodes:
		if n.is_in_group("hitbox_head") or str(n.get_meta("hitbox", "")) == "head" or str(n.name).to_lower().contains("head"):
			return "head"
	if enemy is Node3D and enemy.has_meta("head_y") and r.has("position"):
		var local_y: float = (r["position"] as Vector3).y - (enemy as Node3D).global_position.y
		if local_y >= float(enemy.get_meta("head_y")):
			return "head"
	return "body"


func _deal(enemy: Node, base: int, hitbox: String, w: Dictionary) -> int:
	var mult: float = float(w.get("headshot", headshot_default)) if hitbox == "head" else 1.0
	var amount: int = maxi(1, roundi(base * mult))
	enemy.call("take_damage", amount, player, hitbox)
	return amount


# ───────────────────────────── kinds ─────────────────────────────
func _melee(w: Dictionary) -> void:
	var origin: Vector3 = player.global_position + Vector3.UP * 1.0 if player != null else global_position
	var fwd: Vector3 = -(player.global_transform.basis.z if player != null else global_transform.basis.z)
	if aim_camera != null and aim_camera.is_inside_tree():
		var cf: Vector3 = -aim_camera.global_transform.basis.z
		fwd = Vector3(cf.x, 0.0, cf.z).normalized() if Vector2(cf.x, cf.z).length() > 0.01 else fwd
	fwd.y = 0.0
	fwd = fwd.normalized()
	var reach: float = float(w.get("range", 2.0))
	var cone: float = cos(deg_to_rad(float(w.get("cone_deg", 35.0))))
	var best: Node3D = null
	var best_d: float = INF
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group("enemy"):
			if not (n is Node3D) or not n.has_method("take_damage"):
				continue
			var e := n as Node3D
			var to: Vector3 = e.global_position - (player.global_position if player != null else global_position)
			to.y = 0.0
			var d: float = to.length()
			if d > reach + 0.45:
				continue
			if d > 0.05 and to.normalized().dot(fwd) < cone:
				continue
			var los: Dictionary = _ray(origin, e.global_position + Vector3.UP * 0.8)
			if not los.is_empty() and find_enemy(los["collider"] as Node) != e:
				continue
			if d < best_d:
				best_d = d
				best = e
	var dmg: int = randi_range(int(w["dmg"][0]), int(w["dmg"][1]))
	if best != null:
		var dealt: int = _deal(best, dmg, "body", w)
		last_shot = {"hit": true, "pos": best.global_position, "collider": best, "hitbox": "body", "damage": dealt}
		Events.sfx.emit("claw_hit", best.global_position)
	else:
		last_shot = {"hit": false}
		Events.sfx.emit("claw_swipe", origin)


func _hitscan(w: Dictionary) -> void:
	var ar: Array = aim_ray()
	var origin: Vector3 = ar[0]
	var dir: Vector3 = _spread_dir(ar[1], current_spread())
	var reach: float = float(w.get("range", 96.0))
	var aim_end: Vector3 = origin + dir * reach
	var r: Dictionary = _ray(origin, aim_end)
	var target: Vector3 = r["position"] if not r.is_empty() else aim_end
	# the muzzle must also see the target (no shooting through a wall the hero is hugging)
	var muzzle: Vector3 = global_position
	var r2: Dictionary = _ray(muzzle, target + (target - muzzle).normalized() * 0.05)
	if not r2.is_empty() and (r.is_empty() or (r2["position"] as Vector3).distance_to(target) > 0.15):
		r = r2
		target = r2["position"]
	var parent: Node = _fx_parent()
	RatWeaponFx.tracer(parent, muzzle, target, w.get("tracer", null))
	RatWeaponFx.flash(parent, muzzle, w.get("flash", null), 3.0, 5.0, 0.05)
	last_shot = {"hit": false, "pos": target}
	if r.is_empty():
		return
	var enemy: Node = find_enemy(r["collider"] as Node)
	if enemy != null:
		var hb: String = hitbox_of(r, enemy)
		var base: float = float(randi_range(int(w["dmg"][0]), int(w["dmg"][1])))
		var dist: float = muzzle.distance_to(target)
		var f0: float = float(falloff.get("start_m", 40.0))
		if dist > f0:
			base *= maxf(float(falloff.get("min", 0.55)), 1.0 - (dist - f0) * float(falloff.get("per_m", 0.01)))
		var dealt: int = _deal(enemy, roundi(base), hb, w)
		last_shot = {"hit": true, "pos": target, "collider": r["collider"], "hitbox": hb, "damage": dealt, "enemy": enemy}
		Events.sfx.emit("hit_flesh" if hb != "head" else "headshot", target)
	else:
		RatWeaponFx.decal(parent, target, r.get("normal", Vector3.UP))
		RatWeaponFx.flash(parent, target + (r.get("normal", Vector3.UP) as Vector3) * 0.05, Color(1.6, 1.2, 0.5), 1.0, 1.5, 0.04)
		last_shot = {"hit": false, "pos": target, "collider": r["collider"], "wall": true}
		if randf() < 0.25:
			Events.sfx.emit("ricochet" if randf() < 0.5 else "hit_wall", target)


func _launch(w: Dictionary) -> void:
	var conf: Dictionary = projectiles.get(str(w.get("projectile", "yarnball")), {})
	if conf.is_empty():
		conf = (Defs.PROJECTILES.get("yarnball", {}) as Dictionary).duplicate()
		conf["speed"] = 24.0
		conf["splash"] = 3.5
	var ar: Array = aim_ray()
	var origin: Vector3 = global_position
	var r: Dictionary = _ray(ar[0], ar[0] + (ar[1] as Vector3) * 200.0)
	var target: Vector3 = r["position"] if not r.is_empty() else (ar[0] as Vector3) + (ar[1] as Vector3) * 200.0
	var dir: Vector3 = (target - origin).normalized()
	# never spawn inside a wall the hero is touching
	var blocked: Dictionary = _ray(origin - dir * 0.3, origin + dir * 0.4)
	if not blocked.is_empty():
		origin = (blocked["position"] as Vector3) - dir * 0.3
	var ball := RatYarnBall.new()
	ball.setup(conf, player, dir * float(conf.get("speed", 24.0)) + Vector3.UP * 1.0)
	var parent: Node = _fx_parent()
	parent.add_child(ball)
	ball.global_position = origin
	RatWeaponFx.flash(parent, origin, w.get("flash", null), 2.0, 4.0, 0.1)
	last_shot = {"hit": false, "projectile": ball}
	Events.sfx.emit("yarn_launch", origin)


func _beam(delta: float) -> void:
	var w: Dictionary = def()
	var ar: Array = aim_ray()
	var reach: float = float(w.get("range", 64.0))
	var r: Dictionary = _ray(ar[0], (ar[0] as Vector3) + (ar[1] as Vector3) * reach)
	var muzzle: Vector3 = global_position
	var end: Vector3 = r["position"] if not r.is_empty() else (ar[0] as Vector3) + (ar[1] as Vector3) * reach
	_beam_acc_ammo += float(w.get("use_per_sec", 14)) * delta
	while _beam_acc_ammo >= 1.0 and int(ammo.get("cell", 0)) > 0:
		ammo["cell"] = int(ammo["cell"]) - 1
		_beam_acc_ammo -= 1.0
	if not beam_on:
		beam_on = true
		_since_shot = 0.0
	_emit_ammo()
	_show_beam(muzzle, end, w)
	if r.is_empty():
		return
	var enemy: Node = find_enemy(r["collider"] as Node)
	if enemy == null:
		return
	var hb: String = hitbox_of(r, enemy)
	var mult: float = float(w.get("headshot", headshot_default)) if hb == "head" else 1.0
	_beam_acc_dmg += float(w.get("dps", 55)) * mult * delta
	if _beam_acc_dmg >= 1.0:
		var amt: int = int(_beam_acc_dmg)
		_beam_acc_dmg -= amt
		enemy.call("take_damage", amt, player, hb)
		if enemy.has_method("stun"):
			enemy.call("stun", float(w.get("stun", 0.6)))
	last_shot = {"hit": true, "pos": end, "enemy": enemy}


func _show_beam(from: Vector3, to: Vector3, w: Dictionary) -> void:
	var parent: Node = _fx_parent()
	if parent == null or not parent.is_inside_tree():
		return
	if _beam_mesh == null or not is_instance_valid(_beam_mesh):
		_beam_mesh = MeshInstance3D.new()
		_beam_mesh.name = "LaserBeam"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.012, 1.0)
		_beam_mesh.mesh = bm
		_beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.1, 0.05)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.1, 0.05)
		m.emission_energy_multiplier = 6.0
		_beam_mesh.material_override = m
		parent.add_child(_beam_mesh)
		_beam_dot = OmniLight3D.new()
		_beam_dot.light_color = Color(1.0, 0.1, 0.05)
		_beam_dot.light_energy = 2.0
		_beam_dot.omni_range = 1.2
		parent.add_child(_beam_dot)
	var len: float = maxf(0.05, from.distance_to(to))
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	_beam_mesh.global_transform = Transform3D(Basis.IDENTITY, (from + to) * 0.5).looking_at(to, up).scaled_local(Vector3(1, 1, len))
	_beam_mesh.visible = true
	_beam_dot.global_position = to - (to - from).normalized() * 0.05
	_beam_dot.visible = true


func _stop_beam() -> void:
	beam_on = false
	if _beam_mesh != null and is_instance_valid(_beam_mesh):
		_beam_mesh.visible = false
	if _beam_dot != null and is_instance_valid(_beam_dot):
		_beam_dot.visible = false


func _exit_tree() -> void:
	if _beam_mesh != null and is_instance_valid(_beam_mesh):
		_beam_mesh.queue_free()
	if _beam_dot != null and is_instance_valid(_beam_dot):
		_beam_dot.queue_free()


func _fx_parent() -> Node:
	if player != null and player.get_parent() != null:
		return player.get_parent()
	return get_parent() if get_parent() != null else self


func _emit_ammo() -> void:
	Events.ammo_changed.emit(loaded(), reserve())


func _emit_all() -> void:
	Events.weapon_changed.emit(str(def().get("id", "")))
	_emit_ammo()
