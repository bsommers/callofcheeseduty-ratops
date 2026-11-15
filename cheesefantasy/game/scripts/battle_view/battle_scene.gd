class_name BattleScene
extends Node3D
## Battle presentation (owner battle-presentation). Root of scenes/battle/battle_scene.tscn.
## API: start(encounter_id, opts) -> runs the whole fight; emits Events.battle_finished(result) and `finished(result)`.
##   opts: seed:int, auto:bool (party auto-battles, for tests/demo), apply_result:bool (default true: applies the result to
##   GameState and shows level-ups), party:Array (BattleEngine party records; default GameState.battle_party()),
##   summons:Array, gauge:int, fast:bool (shorter waits), wait_screen:bool (default true unless auto).
## Logic lives in BattleEngine (scripts/battle/battle_engine.gd); this node only turns its beats into a show:
## 3D farm arena, camera cuts, VFX, floating numbers, HUD (turn order, Fondue Gauge, HP/MP/status), command menu,
## target selection, cooking pot, summon cinematics, victory/level-up screen.
## Run the scene directly to get a demo fight (user args: --encounter=<id> --auto=1 --seed=N).

signal finished(result: Dictionary)

const COOKING_SCENE: String = "res://scenes/ui/cooking.tscn"

var engine: BattleEngine
var arena: BattleArena
var cam: BattleCamera
var hud: BattleHud
var vfx: BattleVfx
var cine: SummonCinematic
var views: Dictionary = {}          ## uid -> BattleActorView
var encounter_id: String = ""
var opts: Dictionary = {}
var auto: bool = false
var running: bool = false
var _cursor: MeshInstance3D
var _cursor_uid: String = ""
var _started: bool = false
var _pace: float = 1.0


func _ready() -> void:
	if get_parent() == get_tree().root and not _started:
		var a: Dictionary = _user_args()
		if GameState.party.is_empty():
			GameState.new_game()
		call_deferred("start", str(a.get("encounter", "meadow_grunts")),
			{"auto": a.get("auto", "0") == "1", "seed": int(a.get("seed", "7")), "apply_result": false})


func _user_args() -> Dictionary:
	var a: Dictionary = {}
	for s: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	return a


# ======================================================================= setup
func start(p_encounter: String, p_opts: Dictionary = {}) -> void:
	_started = true
	encounter_id = p_encounter
	opts = p_opts
	auto = bool(opts.get("auto", false))
	_pace = 0.6 if bool(opts.get("fast", false)) else 1.0
	setup_stage(p_encounter, p_opts)
	await run()


## Build engine, arena, actors, HUD without running the loop (used by start() and the screenshot harness).
func setup_stage(p_encounter: String, p_opts: Dictionary = {}) -> void:
	encounter_id = p_encounter
	opts = p_opts
	engine = BattleEngine.new()
	var party_recs: Array = opts.get("party", GameState.battle_party())
	engine.setup(p_encounter, party_recs, {"seed": int(opts.get("seed", randi())), "inventory": GameState.inventory,
		"summons": opts.get("summons", GameState.summons), "gauge": int(opts.get("gauge", GameState.fondue_gauge)),
		"recipes": GameState.recipes, "gold": GameState.gold})
	var enc: Dictionary = Data.ENCOUNTERS.get(p_encounter, {})
	arena = BattleArena.new()
	add_child(arena)
	arena.build(str(enc.get("bg", "fields")))
	vfx = BattleVfx.new()
	add_child(vfx)
	cam = BattleCamera.new()
	add_child(cam)
	cam.make_current()
	hud = BattleHud.new()
	add_child(hud)
	cine = SummonCinematic.new()
	add_child(cine)
	vfx.shake_requested.connect(func(s: float, d: float) -> void: cam.shake(s, d))
	vfx.flash_requested.connect(func(c: Color, s: float) -> void: hud.flash(c, s))
	_make_cursor()
	var ps: Array = engine.party()
	for i: int in ps.size():
		var a: Dictionary = ps[i]
		_spawn_view(a, BattleArena.party_slot(i, ps.size()))
		hud.add_party_member(str(a.uid), str(a.name), str(a.element))
		hud.update_member(a)
	var es: Array = engine.enemies()
	for i: int in es.size():
		_spawn_view(es[i], BattleArena.enemy_slot(i, es.size(), engine.is_boss()))
	if engine.is_boss():   # big bosses stand in dark arenas: add a warm front fill so they read
		var fill: OmniLight3D = OmniLight3D.new()
		fill.light_color = Color(1.0, 0.9, 0.8)
		fill.light_energy = 6.0
		fill.omni_range = 16.0
		add_child(fill)
		fill.position = Vector3(-2.0, 5.0, 5.0)
	hud.set_gauge(engine.gauge)
	Audio.play_music("battle_boss" if engine.is_boss() else "battle")


func _spawn_view(a: Dictionary, pos: Vector3) -> BattleActorView:
	var v: BattleActorView = BattleActorView.new()
	add_child(v)
	var party: bool = a.side == "party"
	var tint: Color = a.get("tint", Color.WHITE) if not party else Color.WHITE
	v.setup(str(a.uid), str(a.side), str(a.model), str(a.name), tint, float(a.get("scale", 1.0)))
	v.position = pos
	v.home = pos
	# glb models face -Z: party turns to face -X (enemies), enemies +X; both angled a little toward the camera.
	v.rotation.y = (PI * 0.5 + 0.35) if party else (-PI * 0.5 - 0.35)
	v.refresh_height()
	views[str(a.uid)] = v
	if not party:
		hud.add_plate(str(a.uid), "%s  Lv%d" % [a.name, int(a.level)])
	if not bool(a.get("alive", true)):
		v.set_down(true)
	return v


func _make_cursor() -> void:
	_cursor = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.0
	c.height = 0.4
	c.radial_segments = 4
	_cursor.mesh = c
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.85, 0.3)
	m.emission_enabled = true
	m.emission = Color(1, 0.8, 0.2)
	m.emission_energy_multiplier = 2.5
	_cursor.material_override = m
	_cursor.visible = false
	add_child(_cursor)


func _process(delta: float) -> void:
	if engine == null or cam == null:
		return
	for e: Dictionary in engine.enemies():
		var v: BattleActorView = views.get(str(e.uid), null)
		if v == null:
			continue
		var p: Vector3 = v.top()
		var vis: bool = v.visible and bool(e.alive) and not cam.is_position_behind(p)
		hud.update_plate(str(e.uid), cam.unproject_position(p), vis, float(e.hp) / maxf(1.0, float(e.max_hp)), e.statuses)
	if _cursor.visible and views.has(_cursor_uid):
		var cv: BattleActorView = views[_cursor_uid]
		_cursor.global_position = cv.top() + Vector3(0, 0.35 + sin(Time.get_ticks_msec() * 0.008) * 0.12, 0)
		_cursor.rotation.y += delta * 3.0


# ======================================================================= main loop
func run() -> void:
	running = true
	cam.move_to(Vector3(-2.0, 2.2, 7.5), Vector3(-3.5, 1.0, 0), 0.0, 45.0)
	cam.move_to(BattleCamera.WIDE_POS, BattleCamera.WIDE_FOCUS, 1.0 * _pace, 50.0)
	await play_beats(engine.start())
	while not engine.is_over() and engine.needs_input():
		var who: Dictionary = engine.current_actor()
		_refresh_order()
		hud.highlight_member(str(who.uid))
		var cmd: Dictionary = await _ask_command(who)
		hud.highlight_member("")
		await play_beats(engine.step(cmd))
	running = false
	await _finish()


func _refresh_order() -> void:
	var cur: String = engine.current_uid
	var list: Array = []
	if cur != "":
		list.append(engine.get_actor(cur))
	var alive: Array = engine.actors.filter(func(x: Dictionary) -> bool: return x.alive and not x.fled)
	var ct: Dictionary = {}
	for x: Dictionary in alive:
		ct[x.uid] = float(x.ct)
	var guard: int = 0
	while list.size() < 8 and not alive.is_empty() and guard < 2000:
		guard += 1
		var best: Dictionary = {}
		for x: Dictionary in alive:
			if ct[x.uid] >= 100.0 and (best.is_empty() or ct[x.uid] > ct[best.uid]):
				best = x
		if not best.is_empty():
			ct[best.uid] -= 100.0
			list.append(best)
			continue
		for x: Dictionary in alive:
			ct[x.uid] += maxf(1.0, engine._eff(x, "spd"))
	hud.set_turn_order(list, cur)


# ======================================================================= command input
func _ask_command(who: Dictionary) -> Dictionary:
	if auto:
		await _wait(0.25)
		return engine.auto_command(str(who.uid))
	var v: BattleActorView = views.get(str(who.uid), null)
	if v != null:
		cam.over_shoulder(v.global_position, "party")
		v.play("idle")
	while true:
		hud.open_menu(str(who.name), engine.available_commands(), engine.skill_list(), _items(), _summons())
		var c: Dictionary = await hud.chosen
		var t: String = str(c.get("type", ""))
		match t:
			"attack":
				var tgt: String = await _pick_target(str(who.uid), "enemy", "Attack")
				if tgt != "":
					return {"type": "attack", "target": tgt}
			"skill", "item", "summon":
				var tt: String = str(c.get("target_type", "enemy"))
				var tgt: String = ""
				if tt in ["enemy", "ally", "ally_down"]:
					tgt = await _pick_target(str(who.uid), tt, _choice_name(t, str(c.id)))
					if tgt == "":
						continue
				return {"type": t, t: str(c.id), "target": tgt}
			"cook":
				var cmd: Dictionary = await _cook(who)
				if not cmd.is_empty():
					return cmd
			"guard", "flee":
				return {"type": t}
	return {"type": "guard"}


func _choice_name(t: String, id: String) -> String:
	match t:
		"skill": return str(Data.skill(id).get("name", id))
		"item": return Data.item_name(id)
		"summon": return str(Data.SUMMONS.get(id, {}).get("name", id))
	return id


func _items() -> Array:
	var out: Array = []
	for id: String in engine.inventory:
		var it: Dictionary = Data.item(id)
		var n: int = int(engine.inventory[id])
		if n <= 0 or not it.get("kind", "") in ["consumable", "throwable", "dish"]:
			continue
		var tt: String = str(it.get("target", it.get("effect", {}).get("target", "enemy" if it.get("kind", "") == "throwable" else "ally")))
		out.append({"id": id, "name": it.get("name", id), "count": n, "target": tt, "desc": it.get("desc", it.get("hint", ""))})
	return out


func _summons() -> Array:
	var out: Array = []
	for sid: String in engine.summons_available:
		var s: Dictionary = Data.SUMMONS.get(sid, {})
		out.append({"id": sid, "name": s.get("name", sid), "title": s.get("title", ""), "enabled": engine.can_summon(sid),
			"target": "enemy" if str(s.get("target", "")) == "enemy" else "none", "desc": s.get("desc", "")})
	return out


func _pick_target(uid: String, tt: String, title: String) -> String:
	var valid: Array = engine.valid_targets(uid, tt)
	if valid.is_empty():
		return ""
	var entries: Array = []
	for u: Variant in valid:
		var a: Dictionary = engine.get_actor(str(u))
		entries.append({"uid": str(u), "name": "%s   HP %d/%d" % [a.name, int(a.hp), int(a.max_hp)] if a.side == "party" else str(a.name)})
	var side: String = str(engine.get_actor(str(valid[0])).get("side", "enemy"))
	cam.side_view(side, 0.35)
	var hov: Callable = func(u: String) -> void:
		_cursor_uid = u
		_cursor.visible = true
	hud.target_hovered.connect(hov)
	hud.pick_target(entries, title)
	_cursor_uid = str(valid[0])
	_cursor.visible = true
	var picked: String = await hud.target_chosen
	hud.target_hovered.disconnect(hov)
	_cursor.visible = false
	if picked == "":
		var v: BattleActorView = views.get(uid, null)
		if v != null:
			cam.over_shoulder(v.global_position, "party")
	return picked


signal _cook_done(r: Dictionary)


## Cook command: the shared cooking UI in "battle" mode, or a quick fallback when it is missing.
func _cook(who: Dictionary) -> Dictionary:
	var ings: Array = []
	for id: String in engine.inventory:
		if Data.INGREDIENTS.has(id) or Data.is_cheese(id):
			for k: int in mini(int(engine.inventory[id]), 3):
				ings.append(id)
	if ResourceLoader.exists(COOKING_SCENE) and not auto:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		var ui: Node = (load(COOKING_SCENE) as PackedScene).instantiate()
		layer.add_child(ui)
		var done: Callable = func(r: Variant = {}) -> void: _cook_done.emit(r if r is Dictionary else {})
		if ui.has_signal("finished"):
			ui.connect("finished", done)
		if ui.has_signal("closed"):
			ui.connect("closed", done)
		cam.close_on(views[str(who.uid)].global_position, "party", 1.2, 0.5)
		ui.call("open", "battle", str(who.id))
		var r: Dictionary = await _cook_done
		layer.queue_free()
		if r.is_empty() or (r.get("ingredients", []) as Array).is_empty():
			return {}
		# the UI consumed the ingredients from GameState; the engine re-consumes them from its own copy and reports
		# them in result.used_items (removed again by GameState.apply_battle_result) -> hand them back now.
		for id: Variant in r.get("ingredients", []):
			GameState.add_item(str(id), 1, false)
		return {"type": "cook", "ingredients": r.get("ingredients", []), "stir": clampf(float(r.get("tier", 2)) / 3.0, 0.0, 1.0)}
	if ings.size() < 2:
		return {}
	return {"type": "cook", "ingredients": ings.slice(0, 3), "stir": 0.75}


# ======================================================================= beat playback
func play_beats(beats: Array) -> void:
	var i: int = 0
	while i < beats.size():
		var b: Dictionary = beats[i]
		var t: String = str(b.get("type", ""))
		match t:
			"action", "item", "cook":
				# gather the effect beats that belong to this action
				var fx: Array = []
				var j: int = i + 1
				while j < beats.size() and _is_effect(str(beats[j].type)):
					fx.append(beats[j])
					j += 1
				await _play_action(b, fx)
				i = j
				continue
			"summon":
				var fx2: Array = []
				var j2: int = i + 1
				while j2 < beats.size() and (_is_effect(str(beats[j2].type)) or beats[j2].type in ["summon_attack", "gauge"]):
					fx2.append(beats[j2])
					j2 += 1
				await _play_summon(b, fx2)
				i = j2
				continue
			_:
				await _play_misc(b)
		i += 1
	_sync_all()


static func _is_effect(t: String) -> bool:
	return t in ["damage", "miss", "heal", "mp", "revive", "down", "status", "status_end", "cure", "steal", "scan",
		"enemy_flee", "recipe_discovered", "spawn"]


func _play_action(b: Dictionary, fx: Array) -> void:
	var caster: BattleActorView = views.get(str(b.actor), null)
	var tuids: Array = b.get("targets", [])
	if tuids.is_empty():
		for e: Dictionary in fx:
			if str(e.get("target", "")) != "" and not str(e.target) in tuids:
				tuids.append(str(e.target))
	if tuids.is_empty() and str(b.get("target", "")) != "":
		tuids.append(str(b.target))
	var tviews: Array = []
	for u: Variant in tuids:
		if views.has(str(u)):
			tviews.append(views[str(u)])
	var side: String = caster.side if caster != null else "party"
	var col: Color = BattleVfx.COL.get(str(b.get("element", "none")), Color(1, 0.95, 0.75))
	var label: String = str(b.get("text", ""))
	if b.type == "cook":
		label = "Cook: " + label
	hud.banner(label, col.lightened(0.3), 0.9 * _pace)
	var kind: String = str(b.get("kind", "magic"))
	var physical: bool = kind == "physical" or str(b.get("skill", "")) == "attack"
	if caster != null:
		if tviews.size() > 1:
			cam.side_view("enemy" if (tviews[0] as BattleActorView).side == "enemy" else "party", 0.4 * _pace)
		else:
			cam.over_shoulder(caster.home, side, 0.35 * _pace)
		caster.step_forward()
		await _wait(0.2 * _pace)
		var anim: String = str(b.get("anim", "attack" if physical else "cast"))
		caster.play(anim)
		if physical and tviews.size() == 1 and tviews[0] != caster:
			caster.lunge_to((tviews[0] as BattleActorView).global_position)
		if not physical:
			vfx.ground_ring(caster.global_position, col, 2.2, 0.8, 0.0, true)
			Audio.play_sfx("cast")
		await _wait(0.25 * _pace)
	var vfx_id: String = str(b.get("vfx", ""))
	if b.type == "item":
		vfx_id = "sparkle" if str(b.get("element", "")) == "" else str(b.element) + "_burst"
	elif b.type == "cook":
		vfx_id = "heal_gold"
	var pts: Array = tviews.map(func(v: BattleActorView) -> Vector3: return v.global_position)
	if pts.is_empty() and caster != null:
		pts = [caster.global_position]
	if tviews.size() == 1 and caster != null and tviews[0] != caster:
		cam.two_shot(caster.home, (tviews[0] as BattleActorView).global_position, 0.3 * _pace)
	var impact: float = vfx.play(vfx_id, str(b.get("element", "none")), caster.global_position if caster != null else Vector3.ZERO, pts)
	Audio.play_sfx("hit" if physical else "spell")
	await _wait(impact)
	_apply_effects(fx, caster)
	await _wait(0.75 * _pace)
	if caster != null:
		caster.step_back()
	_sync_all()
	await _wait(0.15 * _pace)


func _play_summon(b: Dictionary, fx: Array) -> void:
	var sid: String = str(b.get("summon", ""))
	if sid == "" or b.get("failed", false):
		hud.banner(str(b.text), Color(0.8, 0.8, 1.0), 1.2)
		await _wait(1.2)
		return
	var s: Dictionary = Data.SUMMONS.get(sid, {})
	var party_views: Array = engine.party().map(func(a: Dictionary) -> BattleActorView: return views.get(str(a.uid)))
	var targets: Array = []
	for e: Dictionary in fx:
		if e.type == "damage" and views.has(str(e.target)) and not views[str(e.target)] in targets:
			targets.append(views[str(e.target)])
	if targets.is_empty():
		for e: Dictionary in engine.enemies():
			if views.has(str(e.uid)) and (views[str(e.uid)] as BattleActorView).visible:
				targets.append(views[str(e.uid)])
	for g: Dictionary in fx:
		if g.type == "gauge":
			hud.set_gauge(int(g.get("gauge", engine.gauge)))
	await cine.play(sid, s, cam, hud, vfx, arena, party_views, targets, func() -> void: _apply_effects(fx, null))
	_sync_all()


## Instant visuals for effect beats (numbers, hit reactions, KO, status icons).
func _apply_effects(fx: Array, caster: BattleActorView) -> void:
	var stagger: float = 0.0
	for e: Dictionary in fx:
		var t: String = str(e.type)
		var tv: BattleActorView = views.get(str(e.get("target", "")), null)
		match t:
			"damage":
				if tv != null:
					var big: bool = bool(e.get("crit", false))
					tv.hit(1.6 if big else 1.0)
					var col: Color = Color(1, 1, 1) if not big else Color(1, 0.85, 0.2)
					var el: String = str(e.get("element", "none"))
					if el != "none" and el != "":
						col = col.lerp(BattleVfx.COL.get(el, col), 0.35)
					popup(tv.top() + Vector3(0.35 * (1.0 if int(stagger / 0.18) % 2 == 0 else -1.0), stagger * 2.0, 0), str(int(e.amount)), col, 1.35 if big else 1.0, stagger)
					if big:
						popup(tv.top() + Vector3(0, 0.45, 0), "CRITICAL!", Color(1, 0.8, 0.2), 0.6, stagger)
					if bool(e.get("weak", false)):
						popup(tv.top() + Vector3(0, 0.45 if not big else 0.8, 0), "WEAK!", Color(1, 0.55, 0.2), 0.65, stagger)
					stagger += 0.18
			"miss":
				if tv != null:
					popup(tv.top(), "Miss", Color(0.8, 0.85, 1.0), 0.8, stagger)
			"heal", "regen":
				if tv != null:
					popup(tv.top() + Vector3(0, stagger * 4.0, 0), "+%d" % int(e.amount), Color(0.45, 1.0, 0.5), 1.0, stagger)
					vfx.burst(tv.global_position + Vector3(0, 0.2, 0), Color(0.6, 1.0, 0.6), Color(0.3, 1.0, 0.4, 0.0), 14, 0.9,
						Vector3.UP, 15.0, 0.8, 1.6, Vector3.ZERO, 0.04, 0.09, 0.4)
					stagger += 0.18
			"mp":
				if tv != null:
					popup(tv.top(), "%+d MP" % int(e.amount), Color(0.5, 0.75, 1.0), 0.8, stagger)
			"revive":
				if tv != null:
					tv.set_down(false)
					vfx.play("revive", "light", tv.global_position, [tv.global_position])
					popup(tv.top(), "+%d" % int(e.amount), Color(1, 0.95, 0.6), 1.0, stagger)
			"down":
				if tv != null:
					tv.set_down(true)
			"status":
				if tv != null:
					var sid: String = str(e.get("status", ""))
					var nm: String = str(Data.STATUSES.get(sid, {}).get("name", sid))
					popup(tv.top() + Vector3(0, 0.3, 0), "Immune" if e.get("immune", false) else nm,
						BattleHud.STATUS_COL.get(sid, Color(0.9, 0.9, 0.9)), 0.7, stagger + 0.15)
			"steal", "scan", "recipe_discovered":
				hud.message(str(e.text))
			"enemy_flee":
				var av: BattleActorView = views.get(str(e.actor), null)
				if av != null:
					av.run_away()
			"spawn":
				_on_spawn(e)
	_sync_all()


func _on_spawn(e: Dictionary) -> void:
	var a: Dictionary = engine.get_actor(str(e.target))
	if a.is_empty() or views.has(str(a.uid)):
		return
	var es: Array = engine.enemies()
	var idx: int = es.find(a)
	var v: BattleActorView = _spawn_view(a, BattleArena.enemy_slot(maxi(idx, 0), maxi(es.size(), 1), false) + Vector3(-0.6, 0, 0.4))
	vfx.burst(v.global_position + Vector3(0, 0.5, 0), Color(0.9, 0.9, 0.85, 0.8), Color(0.6, 0.6, 0.6, 0.0), 30, 1.0,
		Vector3.UP, 80.0, 1.0, 2.0, Vector3.ZERO, 0.3, 0.6, 0.4, false)


func _play_misc(b: Dictionary) -> void:
	var t: String = str(b.get("type", ""))
	var v: BattleActorView = views.get(str(b.get("actor", "")), null)
	match t:
		"intro":
			if str(b.actor) == "":
				hud.banner(str(b.text), Color(1, 0.9, 0.6), 1.4)
				await _wait(1.0 * _pace)
			else:
				hud.message(str(b.text))
				if v != null:
					cam.close_on(v.global_position, v.side, v.height, 0.5 * _pace)
				await _wait(1.3 * _pace)
				hud.message("")
		"turn":
			_refresh_order()
			hud.message("")
		"phase":
			hud.banner(str(b.text), Color(1, 0.5, 0.5), 1.6)
			if v != null:
				cam.close_on(v.global_position, v.side, v.height, 0.4)
				v.play("special")
			cam.shake(0.35, 0.8)
			hud.flash(Color(1, 0.3, 0.3), 0.3)
			await _wait(1.6 * _pace)
		"skip":
			if v != null:
				popup(v.top(), "Frozen!", Color(0.6, 0.9, 1.0), 0.8)
				vfx.play("ice_spark", "ice", v.global_position, [v.global_position])
			await _wait(0.7 * _pace)
		"dot":
			var tv: BattleActorView = views.get(str(b.get("target", b.actor)), v)
			if tv != null:
				popup(tv.top(), str(int(b.amount)), BattleVfx.COL.get(str(b.element), Color(1, 0.6, 0.6)).lightened(0.2), 0.8)
				tv.hit(0.4)
				vfx.burst(tv.global_position + Vector3(0, 0.6, 0), BattleVfx.COL.get(str(b.element), Color.WHITE), Color(0, 0, 0, 0), 12,
					0.7, Vector3.UP, 40.0, 0.6, 1.4, Vector3.ZERO, 0.05, 0.12, 0.3)
			await _wait(0.45 * _pace)
		"regen":
			_apply_effects([b], null)
			await _wait(0.35 * _pace)
		"guard":
			if v != null:
				v.play("defend", false)
				vfx.play("buff_white", "none", v.global_position, [v.global_position])
				popup(v.top(), "Guard", Color(0.9, 0.9, 1.0), 0.7)
			await _wait(0.5 * _pace)
		"chain":
			hud.set_gauge(engine.gauge, str(b.text))
			hud.banner(str(b.text), BattleVfx.COL.get(str(b.element), Color(1, 0.8, 0.4)), 0.8)
			await _wait(0.5 * _pace)
		"gauge":
			hud.set_gauge(int(b.get("gauge", engine.gauge)))
		"flee":
			for a: Dictionary in engine.party():
				var pv: BattleActorView = views.get(str(a.uid), null)
				if pv != null and pv.visible:
					pv.run_away()
			hud.banner(str(b.text), Color(0.85, 0.9, 1.0), 1.2)
			await _wait(1.0)
		"flee_fail":
			hud.banner(str(b.text) if str(b.text) != "" else "Couldn't escape!", Color(1, 0.7, 0.6), 1.0)
			await _wait(0.8 * _pace)
		"victory", "defeat":
			pass
		_:
			if _is_effect(t):
				_apply_effects([b], null)
				await _wait(0.4 * _pace)
			elif str(b.get("text", "")) != "":
				hud.message(str(b.text))
				await _wait(0.5 * _pace)


func _sync_all() -> void:
	for a: Dictionary in engine.party():
		hud.update_member(a)
	hud.set_gauge(engine.gauge)


## Floating damage/heal number (billboard Label3D that pops, rises and fades).
func popup(p: Vector3, text: String, col: Color, size: float = 1.0, delay: float = 0.0) -> void:
	var l: Label3D = Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0055 * size
	l.font_size = 110
	l.outline_size = 26
	l.modulate = col
	l.outline_modulate = Color(0.12, 0.05, 0.02)
	l.render_priority = 10
	l.outline_render_priority = 9
	add_child(l)
	l.global_position = p + Vector3(randf_range(-0.15, 0.15), 0, 0.3)
	l.scale = Vector3.ONE * 0.01
	var tw: Tween = l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "scale", Vector3.ONE * 1.25, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.tween_property(l, "position:y", l.position.y + 0.7, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.tween_callback(l.queue_free)


# ======================================================================= end of battle
func _finish() -> void:
	var r: Dictionary = engine.result()
	hud.close_menu()
	var wait_screen: bool = bool(opts.get("wait_screen", not auto))
	if bool(r.get("won", false)):
		Audio.play_music("victory")
		for a: Dictionary in engine.party():
			var v: BattleActorView = views.get(str(a.uid), null)
			if v != null and bool(a.alive):
				v.play("victory", false)
		var pc: Vector3 = BattleArena.party_slot(1, 4)
		cam.move_to(pc + Vector3(-5.0, 1.6, 4.5), pc + Vector3(0.3, 1.0, 0), 1.2, 45.0)
		var rows: Array = _apply_and_levels(r)
		hud.banner("VICTORY!", Color(1, 0.85, 0.3), 1.0)
		await _wait(1.0)
		hud.victory_screen(int(r.xp), int(r.gold), r.drops, rows)
	elif bool(r.get("fled", false)):
		_apply_and_levels(r)
		hud.defeat_screen(true)
	else:
		_apply_and_levels(r)
		cam.move_to(Vector3(0, 6.0, 9.0), Vector3(2.0, 0, 0), 1.5, 50.0)
		arena.set_dim(0.4)
		hud.defeat_screen(false)
	if wait_screen:
		await hud.screen_closed
	else:
		await _wait(1.5)
	finished.emit(r)
	Events.battle_finished.emit(r)


## Applies the result to GameState (unless opts.apply_result == false) and returns victory rows with xp-bar fractions.
func _apply_and_levels(r: Dictionary) -> Array:
	var before: Dictionary = {}
	for cid: String in GameState.party:
		var m: Dictionary = GameState.party[cid]
		before[cid] = {"level": int(m.level), "xp": int(m.xp), "stats": GameState.member_stats(cid)}
	var ups: Dictionary = {}
	var apply: bool = bool(opts.get("apply_result", true))
	if apply:
		ups = GameState.apply_battle_result(r)
	r["level_ups"] = ups
	r["applied"] = apply
	var rows: Array = []
	for a: Dictionary in engine.party():
		var cid: String = str(a.id)
		if not before.has(cid):
			continue
		var b: Dictionary = before[cid]
		var lv0: int = int(b.level)
		var xp1: int = int(b.xp) + int(r.get("xp", 0))
		var lv1: int = lv0
		while lv1 < Data.MAX_LEVEL and xp1 >= DB.xp_for_level(lv1 + 1):
			lv1 += 1
		var gains: Dictionary = {}
		if lv1 > lv0:
			var s1: Dictionary = Data.char_stats(cid, lv1)
			var s0b: Dictionary = Data.char_stats(cid, lv0)
			for k: String in ["hp", "mp", "atk", "mag", "def", "spd"]:
				gains[k] = int(s1.get(k, 0)) - int(s0b.get(k, 0))
		rows.append({"name": a.name, "level_from": lv0, "level_to": lv1, "gains": gains,
			"frac_from": _xp_frac(lv0, int(b.xp)), "frac_to": _xp_frac(lv1, xp1)})
	return rows


static func _xp_frac(lv: int, xp: int) -> float:
	var lo: int = DB.xp_for_level(lv)
	var hi: int = DB.xp_for_level(lv + 1)
	return clampf(float(xp - lo) / maxf(1.0, float(hi - lo)), 0.0, 1.0)


func _wait(t: float) -> void:
	if t <= 0.0:
		return
	await get_tree().create_timer(t).timeout


# ======================================================================= debug hooks (screenshot harness / tests)
## Fire a spell VFX at enemies (or the party) without the engine, for previews.
func debug_vfx(vfx_id: String, element: String, at_party: bool = false, all: bool = false) -> float:
	var list: Array = engine.party() if at_party else engine.enemies()
	var pts: Array = []
	for a: Dictionary in list:
		if views.has(str(a.uid)):
			pts.append((views[str(a.uid)] as BattleActorView).global_position)
		if not all:
			break
	var src: Vector3 = (views[str(engine.party()[0].uid)] as BattleActorView).global_position
	return vfx.play(vfx_id, element, src, pts)


func debug_summon(sid: String) -> void:
	var s: Dictionary = Data.SUMMONS.get(sid, {})
	var pv: Array = engine.party().map(func(a: Dictionary) -> BattleActorView: return views.get(str(a.uid)))
	var tv: Array = engine.enemies().map(func(a: Dictionary) -> BattleActorView: return views.get(str(a.uid)))
	if str(s.get("target", "")) == "enemy":
		tv = tv.slice(0, 1)
	var fake: Array = []
	for v: Variant in (tv if sid != "samantha" else pv):
		fake.append({"type": "damage" if sid != "samantha" else "heal", "target": (v as BattleActorView).uid,
			"amount": 999 if sid == "spooky" else 312, "element": str(s.get("element", "none")), "crit": sid == "spooky"})
	await cine.play(sid, s, cam, hud, vfx, arena, pv, tv, func() -> void: _apply_effects(fake, null))
