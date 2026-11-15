class_name BattleEngine
extends RefCounted
## Pure battle logic (owner rpg-core). Deterministic for a given seed + command sequence; no nodes, no autoloads.
##
## USAGE
##   var e := BattleEngine.new()
##   e.setup("meadow_grunts", GameState.battle_party(), {"seed": 7, "inventory": GameState.inventory,
##           "summons": GameState.summons, "gauge": GameState.fondue_gauge, "recipes": GameState.recipes, "gold": GameState.gold})
##   var beats: Array = e.start()            # intro + enemy turns until a party member must act
##   while not e.is_over():
##       var who: Dictionary = e.current_actor()     # party actor awaiting a command
##       beats = e.step({"type": "skill", "skill": "raclette_blaze", "target": "e0"})   # or e.auto_command(who.uid)
##   Events.battle_finished.emit(e.result())
##
## COMMANDS (Dictionary): type = attack | skill | cook | item | summon | guard | flee
##   attack {target}; skill {skill, target}; item {item, target}; cook {ingredients: [ids], stir: 0..1, target};
##   summon {summon, target?}; guard {}; flee {}. Missing/invalid targets are auto-picked. Invalid commands -> Guard.
##
## BEATS (Array of Dictionary; always keys type, actor, target, amount, element, text): intro, turn, phase, action,
##   damage, miss, heal, mp, revive, down, status, status_end, cure, skip, dot, regen, guard, chain, gauge, cook,
##   recipe_discovered, item, summon, summon_attack, spawn, steal, scan, enemy_flee, flee, flee_fail, victory, defeat.
##   Extra keys: crit, weak (bool), skill, anim, vfx, status, quality, dish, chain, mult.
##
## FORMULAS
##   Turn order: CT gauge. Every tick each living actor gains eff_spd (spd x status mults); at CT>=100 it acts, CT-=100.
##   Hit chance: physical 0.95, magic 1.0; x0.7 if user Stinky; minus target evade (Aerated 0.3; magic half);
##     minus (target.lck - user.lck)*0.003; clamped 0.1..1. Heals/buffs on allies never miss.
##   Damage = max(1, A*2 - D) * power/100 * rand(0.9..1.1) * crit * element * guard * chain
##     A = atk (physical) or mag (magic); D = def or res (0 when ignore_def). Statuses multiply stats (Rinded x1.4 def/res,
##     Spicy x1.3 atk/mag, Melted x0.85 def). crit (physical only) 1.5 at 5% + lck*0.2%. guard 0.5 (pierce ignores).
##     element = DB.element_mult (1.5 weak / 0.5 resist / 0 immune). chain = Flavor Chain multiplier (party only).
##     Enemy all/random-target skills x ENEMY_SPREAD_MULT (0.7).
##   Heal = power/100 * (mag*1.5 + 30) * rand(0.95..1.05). Revive skill: power = % of max HP.
##   Throwables/thrown dishes: damage * (1 + lck/100) * element, ignore defence.
##   Summon damage = power/100 * (best party mag * 2 + avg level * 8) * element (ignore_def or vs res*0.5).
##   Flavor Chain: each party elemental offensive skill extends the chain if its element differs from the last one
##     (chain n -> +10% per extra link, max 5); named pairs (DB.CHAINS, e.g. fire>wind = Smoked) add their bonus.
##     Plain Attack and Guard break the chain. Fondue Gauge (0..100): +8 per elemental cast, +combo gauge,
##     +4 per weakness hit, +3 per physical hit, + dish/skill gauge. Summon costs its `cost` (100); max 2 per battle.
##   Flee: 0.5 + (party avg spd - enemy avg spd) * 0.02, clamp 0.2..0.95; impossible in boss fights.
##   Status ticks at the end of the afflicted actor's own turn (dots/regen, turns-1). Frozen skips the turn.
##   Moldy spreads (25%) to a neighbour on the same side at turn end.
##   Rewards: xp/gold of every defeated (not fled) enemy + encounter bonus; drops rolled per enemy; stolen gold subtracted.

const Rules = preload("res://data/db.gd")
const MAX_ACTIONS: int = 800
const MAX_ENEMIES: int = 5
const MAX_SUMMONS: int = 2
const ENEMY_SPREAD_MULT: float = 0.7  ## enemy multi-target skills hit softer (keeps party wipes rare)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0
var encounter_id: String = ""
var encounter: Dictionary = {}
var actors: Array = []
var inventory: Dictionary = {}
var used_items: Dictionary = {}
var recipes_known: Array = []
var discovered: Array = []
var summons_available: Array = []
var summons_used: int = 0
var gauge: int = 0
var chain_len: int = 0
var last_elem: String = ""
var current_uid: String = ""
var over: bool = false
var won: bool = false
var fled: bool = false
var timed_out: bool = false
var actions: int = 0
var stolen_gold: int = 0
var party_gold: int = 999999
var _enemy_counter: int = 0
var _beats: Array = []


# ================================================================== setup
func setup(enc_id: String, party_records: Array, opts: Dictionary = {}) -> void:
	encounter_id = enc_id
	encounter = Rules.ENCOUNTERS.get(enc_id, {"name": enc_id, "enemies": ["rat_grunt"], "level": 1})
	seed_value = int(opts.get("seed", hash(enc_id)))
	rng.seed = seed_value
	inventory = opts.get("inventory", {}).duplicate()
	recipes_known = opts.get("recipes", []).duplicate()
	summons_available = opts.get("summons", []).duplicate()
	gauge = clampi(int(opts.get("gauge", 0)), 0, Rules.GAUGE_MAX)
	party_gold = int(opts.get("gold", 999999))
	actors.clear()
	var i: int = 0
	for rec: Dictionary in party_records.slice(0, 4):
		var a: Dictionary = make_party_actor(rec)
		a.uid = "p%d" % i
		a.slot = i
		actors.append(a)
		i += 1
	var lv: int = int(encounter.get("level", 1))
	for en: String in encounter.get("enemies", []).slice(0, MAX_ENEMIES):
		_add_enemy(en, lv)
	for a: Dictionary in actors:
		a.ct = rng.randf_range(0.0, 40.0) + float(a.spd)


static func make_party_actor(rec: Dictionary) -> Dictionary:
	var cid: String = str(rec.get("id", "fennel"))
	var c: Dictionary = Rules.CHARACTERS.get(cid, {})
	var lv: int = int(rec.get("level", 1))
	var st: Dictionary = Rules.char_stats(cid, lv)
	var resist: Array = c.get("resist", []).duplicate()
	var immune: Array = []
	var welem: String = "none"
	var equip: Dictionary = rec.get("equip", c.get("equip", {}))
	for slot: String in equip:
		var it: Dictionary = Rules.item(str(equip[slot]))
		for k: String in it.get("stats", {}):
			st[k] = int(st.get(k, 0)) + int(it.stats[k])
		resist.append_array(it.get("resist", []))
		immune.append_array(it.get("immune", []))
		if slot == "weapon":
			welem = str(it.get("element", "none"))
	var a: Dictionary = {"id": cid, "name": c.get("name", cid), "side": "party", "level": lv, "model": c.get("model", "hero_" + cid),
		"element": c.get("element", "none"), "weak": c.get("weak", []).duplicate(), "resist": resist, "immune_status": immune,
		"weapon_element": welem, "skills": rec.get("skills", Rules.char_skills(cid, lv)), "boss": false}
	for k: String in Rules.STAT_KEYS:
		a[k] = int(st[k])
	a.max_hp = a.hp
	a.max_mp = a.mp
	a.hp = clampi(int(rec.get("hp", a.max_hp)), 0, a.max_hp)
	a.mp = clampi(int(rec.get("mp", a.max_mp)), 0, a.max_mp)
	_init_runtime(a)
	return a


static func make_enemy_actor(enemy_id: String, level: int) -> Dictionary:
	var e: Dictionary = Rules.ENEMIES.get(enemy_id, Rules.ENEMIES.rat_grunt)
	var lv: int = maxi(int(e.get("level", 1)), level)
	var st: Dictionary = Rules.enemy_stats(enemy_id, lv)
	var a: Dictionary = {"id": enemy_id, "name": e.get("name", enemy_id), "side": "enemy", "level": lv, "model": e.get("model", "enemy_rat_grunt"),
		"tint": e.get("tint", Color.WHITE), "scale": e.get("scale", 1.0), "element": e.get("element", "none"),
		"weak": e.get("weak", []).duplicate(), "resist": e.get("resist", []).duplicate(), "immune_status": e.get("immune_status", []).duplicate(),
		"weapon_element": "none", "skill_pool": e.get("skills", [["attack", 1]]).duplicate(true), "ai": e.get("ai", "basic"),
		"boss": e.get("boss", false), "phase": -1, "xp": st.xp, "gold": st.gold, "drops": e.get("drops", [])}
	for k: String in Rules.STAT_KEYS:
		a[k] = int(st[k])
	a.max_hp = a.hp
	a.max_mp = a.mp
	_init_runtime(a)
	return a


static func _init_runtime(a: Dictionary) -> void:
	a.alive = a.hp > 0
	a.fled = false
	a.statuses = {}
	a.guard = false
	a.ct = 0.0
	a.dish_boost = false
	a.scanned = false


func _add_enemy(enemy_id: String, level: int) -> Dictionary:
	var a: Dictionary = make_enemy_actor(enemy_id, level)
	a.uid = "e%d" % _enemy_counter
	a.slot = enemies().size()
	_enemy_counter += 1
	actors.append(a)
	return a


# ================================================================== queries
func party() -> Array:
	return actors.filter(func(a: Dictionary) -> bool: return a.side == "party")


func enemies() -> Array:
	return actors.filter(func(a: Dictionary) -> bool: return a.side == "enemy" and not a.fled)


func living(side: String) -> Array:
	return actors.filter(func(a: Dictionary) -> bool: return a.side == side and a.alive and not a.fled)


func get_actor(uid: String) -> Dictionary:
	for a: Dictionary in actors:
		if a.uid == uid:
			return a
	return {}


func current_actor() -> Dictionary:
	return get_actor(current_uid)


func needs_input() -> bool:
	return not over and current_uid != ""


func is_over() -> bool:
	return over


func is_boss() -> bool:
	return bool(encounter.get("boss", false))


func can_summon(summon_id: String = "") -> bool:
	if summons_used >= MAX_SUMMONS:
		return false
	var ids: Array = [summon_id] if summon_id != "" else summons_available
	for s: String in ids:
		if s in summons_available and gauge >= int(Rules.SUMMONS.get(s, {}).get("cost", 100)):
			return true
	return false


## Menu helper for the battle UI: [{type, label, enabled, reason}].
func available_commands(uid: String = current_uid) -> Array:
	var a: Dictionary = get_actor(uid)
	var has_ing: bool = _ingredient_count() >= 2
	var has_item: bool = false
	for id: String in inventory:
		var it: Dictionary = Rules.item(id)
		if int(inventory[id]) > 0 and it.get("kind", "") in ["consumable", "throwable", "dish"]:
			has_item = true
	return [
		{"type": "attack", "label": "Attack", "enabled": true},
		{"type": "skill", "label": "Skill", "enabled": not a.get("skills", []).is_empty()},
		{"type": "cook", "label": "Cook", "enabled": has_ing, "reason": "" if has_ing else "Need 2+ ingredients"},
		{"type": "item", "label": "Item", "enabled": has_item},
		{"type": "summon", "label": "Summon", "enabled": can_summon(), "reason": "Fondue Gauge %d/100" % gauge},
		{"type": "guard", "label": "Guard", "enabled": true},
		{"type": "flee", "label": "Flee", "enabled": not is_boss() and encounter.get("can_flee", true)},
	]


## Skills the actor can use right now: [{id, name, mp, enabled}].
func skill_list(uid: String = current_uid) -> Array:
	var a: Dictionary = get_actor(uid)
	var out: Array = []
	for s: String in a.get("skills", []):
		var sk: Dictionary = Rules.skill(s)
		out.append({"id": s, "name": sk.get("name", s), "mp": int(sk.get("mp", 0)), "element": sk.get("element", "none"),
			"target": sk.get("target", "enemy"), "enabled": a.mp >= int(sk.get("mp", 0))})
	return out


## Valid target uids for a skill/item target type from `uid`'s point of view.
func valid_targets(uid: String, target_type: String) -> Array:
	var a: Dictionary = get_actor(uid)
	var own: String = a.get("side", "party")
	var other: String = "enemy" if own == "party" else "party"
	match target_type:
		"enemy", "all_enemies", "random_enemies":
			return living(other).map(func(x: Dictionary) -> String: return x.uid)
		"ally", "all_allies":
			return living(own).map(func(x: Dictionary) -> String: return x.uid)
		"ally_down":
			return actors.filter(func(x: Dictionary) -> bool: return x.side == own and not x.alive and not x.fled).map(func(x: Dictionary) -> String: return x.uid)
		"self":
			return [uid]
	return []


func result() -> Dictionary:
	var xp: int = 0
	var gold: int = 0
	var drops: Array = []
	if won:
		var drng: RandomNumberGenerator = RandomNumberGenerator.new()
		drng.seed = seed_value * 31 + 17
		for e: Dictionary in actors:
			if e.side == "enemy" and not e.fled and not e.alive:
				xp += int(e.xp)
				gold += int(e.gold)
				for d: Array in e.drops:
					if drng.randf() < float(d[1]):
						drops.append(str(d[0]))
		xp += int(encounter.get("bonus_xp", 0))
		gold += int(encounter.get("bonus_gold", 0))
	var p: Array = []
	for a: Dictionary in party():
		p.append({"id": a.id, "hp": a.hp, "mp": a.mp, "alive": a.alive})
	return {"won": won, "fled": fled, "xp": maxi(0, xp), "gold": maxi(0, gold - stolen_gold), "drops": drops, "encounter": encounter_id,
		"party": p, "gauge": gauge, "used_items": used_items, "discovered": discovered, "turns": actions, "timed_out": timed_out}


# ================================================================== flow
func start() -> Array:
	_beats = []
	_beat("intro", "", "", 0, "", encounter.get("name", encounter_id))
	for e: Dictionary in enemies():
		var intro: String = str(Rules.ENEMIES.get(e.id, {}).get("intro", ""))
		if intro != "":
			_beat("intro", e.uid, "", 0, "", intro)
	_run_until_input()
	return _beats


## Execute a command for the current party actor, then run enemy turns until input is needed again.
func step(cmd: Dictionary) -> Array:
	_beats = []
	if over:
		return _beats
	var a: Dictionary = current_actor()
	if a.is_empty():
		_run_until_input()
		return _beats
	current_uid = ""
	_execute(a, cmd)
	_end_turn(a)
	_check_end()
	_run_until_input()
	return _beats


## Runs the whole battle with auto commands for the party. Returns all beats (for tests / auto-battle).
func run_auto(max_steps: int = MAX_ACTIONS) -> Array:
	var all: Array = start()
	var n: int = 0
	while not over and n < max_steps:
		all.append_array(step(auto_command(current_uid)))
		n += 1
	return all


func _run_until_input() -> void:
	while not over:
		if actions >= MAX_ACTIONS:
			timed_out = true
			_finish(false)
			return
		var a: Dictionary = _next_actor()
		if a.is_empty():
			_finish(false)
			return
		actions += 1
		a.guard = false
		_beat("turn", a.uid, "", 0, "", a.name)
		if a.statuses.has("frozen"):
			_beat("skip", a.uid, "", 0, "ice", "%s is frozen solid!" % a.name)
			_end_turn(a)
			_check_end()
			continue
		if a.side == "party":
			current_uid = a.uid
			return
		_enemy_turn(a)
		_end_turn(a)
		_check_end()


func _eff(a: Dictionary, stat: String) -> float:
	var v: float = float(a.get(stat, 0))
	for s: String in a.statuses:
		v *= float(Rules.STATUSES.get(s, {}).get("mult", {}).get(stat, 1.0))
	return v


func _next_actor() -> Dictionary:
	var alive: Array = actors.filter(func(x: Dictionary) -> bool: return x.alive and not x.fled)
	if alive.is_empty():
		return {}
	for _i: int in 1000:
		var best: Dictionary = {}
		for x: Dictionary in alive:
			if x.ct >= 100.0 and (best.is_empty() or x.ct > best.ct):
				best = x
		if not best.is_empty():
			best.ct -= 100.0
			return best
		for x: Dictionary in alive:
			x.ct += maxf(1.0, _eff(x, "spd"))
	return alive[0]


func _check_end() -> void:
	if over:
		return
	if living("enemy").is_empty():
		_finish(true)
	elif living("party").is_empty():
		_finish(false)


func _finish(victory: bool) -> void:
	over = true
	won = victory
	current_uid = ""
	if victory:
		var r: Dictionary = result()
		_beat("victory", "", "", r.xp, "", "Victory! %d XP, %d gold." % [r.xp, r.gold], {"drops": r.drops})
	elif fled:
		_beat("flee", "", "", 0, "", "Got away safely!")
	else:
		_beat("defeat", "", "", 0, "", "The party was overwhelmed..." if not timed_out else "The battle dragged on forever...")


# ================================================================== execution
func _execute(a: Dictionary, cmd: Dictionary) -> void:
	var t: String = str(cmd.get("type", "guard"))
	match t:
		"attack":
			_chain_break()
			_use_skill(a, "attack", str(cmd.get("target", "")))
		"skill":
			var sid: String = str(cmd.get("skill", ""))
			var sk: Dictionary = Rules.skill(sid)
			if sk.is_empty() or not sid in a.skills or a.mp < int(sk.get("mp", 0)):
				_do_guard(a)
			else:
				_use_skill(a, sid, str(cmd.get("target", "")))
		"item":
			_use_item(a, str(cmd.get("item", "")), str(cmd.get("target", "")))
		"cook":
			_cook(a, cmd.get("ingredients", []), float(cmd.get("stir", 0.5)), str(cmd.get("target", "")))
		"summon":
			_summon(a, str(cmd.get("summon", "")), str(cmd.get("target", "")))
		"flee":
			_flee(a)
		_:
			_do_guard(a)


func _do_guard(a: Dictionary) -> void:
	if a.side == "party":
		_chain_break()
	a.guard = true
	_beat("guard", a.uid, a.uid, 0, "", "%s guards." % a.name)


func _flee(a: Dictionary) -> void:
	if is_boss() or not encounter.get("can_flee", true):
		_beat("flee_fail", a.uid, "", 0, "", "You can't run from this fight!")
		return
	var ps: float = _avg(living("party"), "spd")
	var es: float = _avg(living("enemy"), "spd")
	var ch: float = clampf(0.5 + (ps - es) * 0.02, 0.2, 0.95)
	if rng.randf() < ch:
		fled = true
		over = true
		current_uid = ""
		_beat("flee", a.uid, "", 0, "", "Got away safely!")
	else:
		_beat("flee_fail", a.uid, "", 0, "", "Couldn't escape!")


func _avg(list: Array, stat: String) -> float:
	if list.is_empty():
		return 0.0
	var s: float = 0.0
	for x: Dictionary in list:
		s += _eff(x, stat)
	return s / list.size()


func _chain_break() -> void:
	chain_len = 0
	last_elem = ""


func _add_gauge(n: int) -> void:
	if n == 0:
		return
	var before: int = gauge
	gauge = clampi(gauge + n, 0, Rules.GAUGE_MAX)
	if gauge != before:
		_beat("gauge", "", "", gauge - before, "", "Fondue Gauge %d" % gauge, {"gauge": gauge})


## Resolve targets for a target type. `want` is a preferred uid.
func _targets(a: Dictionary, target_type: String, want: String) -> Array:
	var ids: Array = valid_targets(a.uid, target_type)
	if ids.is_empty():
		return []
	match target_type:
		"all_enemies", "all_allies":
			return ids.map(func(u: String) -> Dictionary: return get_actor(u))
		"self":
			return [a]
	if target_type == "enemy" and a.side == "enemy":
		for u: String in ids:
			if get_actor(u).statuses.has("taunting"):
				return [get_actor(u)]
	if want in ids:
		return [get_actor(want)]
	return [get_actor(ids[rng.randi_range(0, ids.size() - 1)])]


func _use_skill(a: Dictionary, sid: String, want: String) -> void:
	var sk: Dictionary = Rules.skill(sid)
	var cost: int = int(sk.get("mp", 0))
	a.mp = maxi(0, a.mp - cost)
	var elem: String = str(sk.get("element", "none"))
	var kind: String = str(sk.get("kind", "physical"))
	if sid == "attack":
		elem = str(a.get("weapon_element", "none"))
	var ttype: String = str(sk.get("target", "enemy"))
	var targets: Array = _targets(a, ttype, want)
	_beat("action", a.uid, targets[0].uid if not targets.is_empty() else "", cost, elem, sk.get("name", sid),
		{"skill": sid, "anim": sk.get("anim", "attack"), "vfx": sk.get("vfx", ""), "kind": kind, "target_type": ttype,
		"targets": targets.map(func(t: Dictionary) -> String: return t.uid)})
	# Flavor Chain (party offensive elemental skills)
	var chain_mult: float = 1.0
	if a.side == "party" and sid != "attack" and elem != "none" and kind in ["magic", "physical"]:
		chain_mult = _chain_extend(elem)
	if a.side == "party":
		_add_gauge(int(sk.get("gauge", 0)))
	if sk.get("dish_boost", false):
		a.dish_boost = true
	var hits: int = int(sk.get("hits", 1))
	match kind:
		"physical", "magic":
			if ttype == "random_enemies":
				for h: int in hits:
					var pool: Array = valid_targets(a.uid, "enemy")
					if pool.is_empty():
						break
					var t: Dictionary = get_actor(pool[rng.randi_range(0, pool.size() - 1)])
					_hit(a, t, sk, elem, kind, chain_mult)
			else:
				for t: Dictionary in targets:
					for h: int in hits:
						if t.alive:
							_hit(a, t, sk, elem, kind, chain_mult)
		"heal":
			for t: Dictionary in targets:
				_heal(a, t, int(round(float(sk.power) / 100.0 * (_eff(a, "mag") * 1.5 + 30.0) * rng.randf_range(0.95, 1.05))))
				_apply_skill_status(a, t, sk, true)
		"revive":
			for t: Dictionary in targets:
				_revive(t, float(sk.get("power", 30)) / 100.0)
		"cure":
			for t: Dictionary in targets:
				_cure(t, sk.get("cure", []))
				if int(sk.get("power", 0)) > 0:
					_heal(a, t, int(round(float(sk.power) / 100.0 * (_eff(a, "mag") * 1.5 + 30.0))))
		"buff", "debuff", "utility":
			for t: Dictionary in targets:
				_apply_skill_status(a, t, sk, kind != "debuff")
				if sk.has("cure"):
					_cure(t, sk.cure)
				if sk.get("scan", false):
					t.scanned = true
					_beat("scan", a.uid, t.uid, t.hp, t.element, "%s: HP %d/%d. Weak: %s. %s" % [t.name, t.hp, t.max_hp,
						", ".join(t.weak) if not t.weak.is_empty() else "nothing", Rules.ENEMIES.get(t.id, {}).get("flavor", "")],
						{"weak": t.weak, "resist": t.resist})
	if sk.has("self_status"):
		_add_status(a, a, sk.self_status, true)
	if sk.has("summon_ally") and a.side == "enemy":
		if living("enemy").size() < MAX_ENEMIES:
			var n: Dictionary = _add_enemy(str(sk.summon_ally), int(encounter.get("level", 1)))
			n.ct = 50.0
			_beat("spawn", a.uid, n.uid, 0, "", "%s appears!" % n.name, {"enemy": n.id, "model": n.model})
	if sk.has("steal_gold") and a.side == "enemy" and not targets.is_empty():
		var g: int = mini(int(sk.steal_gold) * maxi(1, int(a.level / 3.0)), maxi(0, party_gold - stolen_gold))
		if g > 0:
			stolen_gold += g
			_beat("steal", a.uid, targets[0].uid, g, "", "%s stole %d gold!" % [a.name, g])


func _chain_extend(elem: String) -> float:
	var bonus: Dictionary = {}
	if last_elem != "" and last_elem != elem:
		chain_len = mini(chain_len + 1, Rules.CHAIN_MAX)
		bonus = Rules.CHAINS.get(last_elem + ">" + elem, {})
	else:
		chain_len = 1
	var mult: float = 1.0 + Rules.CHAIN_STEP_MULT * float(chain_len - 1)
	var g: int = Rules.GAUGE_PER_CAST
	if not bonus.is_empty():
		mult += float(bonus.mult) - 1.0
		g += int(bonus.gauge)
	if chain_len > 1:
		_beat("chain", "", "", chain_len, elem, "%s x%d!" % [bonus.get("name", "Flavor Chain"), chain_len],
			{"chain": chain_len, "mult": mult, "combo": bonus.get("name", ""), "from": last_elem})
	last_elem = elem
	_add_gauge(g)
	return mult


func _hit_chance(a: Dictionary, t: Dictionary, kind: String) -> float:
	var ch: float = 0.95 if kind == "physical" else 1.0
	if a.statuses.has("stinky"):
		ch *= float(Rules.STATUSES.stinky.accuracy)
	if t.statuses.has("aerated"):
		ch -= float(Rules.STATUSES.aerated.evade) * (1.0 if kind == "physical" else 0.5)
	ch -= (float(t.lck) - float(a.lck)) * 0.003
	return clampf(ch, 0.1, 1.0)


func _hit(a: Dictionary, t: Dictionary, sk: Dictionary, elem: String, kind: String, chain_mult: float) -> void:
	if rng.randf() > _hit_chance(a, t, kind):
		_beat("miss", a.uid, t.uid, 0, elem, "Miss!")
		return
	var atk: float = _eff(a, "atk" if kind == "physical" else "mag")
	var df: float = 0.0 if sk.get("ignore_def", false) else _eff(t, "def" if kind == "physical" else "res")
	var base: float = maxf(1.0, atk * 2.0 - df)
	var dmg: float = base * float(sk.get("power", 100)) / 100.0 * rng.randf_range(0.9, 1.1)
	var crit: bool = kind == "physical" and rng.randf() < 0.05 + float(a.lck) * 0.002
	if crit:
		dmg *= 1.5
	var em: float = Rules.element_mult(elem, t.element, t.weak, t.resist)
	dmg *= em
	if t.guard and not sk.get("pierce", false):
		dmg *= 0.5
	dmg *= chain_mult
	if a.side == "enemy" and str(sk.get("target", "enemy")) in ["all_enemies", "random_enemies"]:
		dmg *= ENEMY_SPREAD_MULT
	var amount: int = maxi(1, int(round(dmg))) if em > 0.0 else 0
	_damage(a, t, amount, elem, {"crit": crit, "weak": em > 1.0, "resisted": em < 1.0})
	if a.side == "party":
		_add_gauge((Rules.GAUGE_WEAKNESS if em > 1.0 else 0) + (Rules.GAUGE_PER_HIT if kind == "physical" else 0))
	if sk.has("drain") and amount > 0:
		_heal(a, a, int(round(amount * float(sk.drain))))
	if t.alive:
		_apply_skill_status(a, t, sk, false)


func _damage(src: Dictionary, t: Dictionary, amount: int, elem: String, extra: Dictionary = {}) -> void:
	t.hp = maxi(0, t.hp - amount)
	var txt: String = str(amount)
	if extra.get("crit", false):
		txt = "Critical! %d" % amount
	_beat("damage", src.get("uid", ""), t.uid, amount, elem, txt, extra)
	if t.hp <= 0 and t.alive:
		t.alive = false
		t.statuses = {}
		t.guard = false
		_beat("down", src.get("uid", ""), t.uid, 0, elem, "%s is down!" % t.name)


func _heal(src: Dictionary, t: Dictionary, amount: int) -> void:
	if not t.alive or amount <= 0:
		return
	var before: int = t.hp
	t.hp = mini(t.max_hp, t.hp + amount)
	_beat("heal", src.get("uid", ""), t.uid, t.hp - before, "light", "+%d" % (t.hp - before))


func _restore_mp(t: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var before: int = t.mp
	t.mp = mini(t.max_mp, t.mp + amount)
	_beat("mp", "", t.uid, t.mp - before, "", "+%d MP" % (t.mp - before))


func _revive(t: Dictionary, frac: float) -> void:
	if t.alive or t.fled:
		return
	t.alive = true
	t.hp = maxi(1, int(round(t.max_hp * clampf(frac, 0.0, 1.0))))
	t.ct = 0.0
	_beat("revive", "", t.uid, t.hp, "light", "%s is back on their paws!" % t.name)


func _cure(t: Dictionary, list: Array) -> void:
	for s: String in list:
		if t.statuses.has(s):
			t.statuses.erase(s)
			_beat("cure", "", t.uid, 0, "", "%s: %s cured" % [t.name, Rules.STATUSES[s].name], {"status": s})


func _apply_skill_status(a: Dictionary, t: Dictionary, sk: Dictionary, friendly: bool) -> void:
	if not sk.has("status"):
		return
	var st: Dictionary = sk.status
	var is_bad: bool = bool(Rules.STATUSES.get(st.id, {}).get("bad", true))
	if friendly and is_bad:
		return
	_add_status(a, t, st, not is_bad)


func _add_status(_src: Dictionary, t: Dictionary, st: Dictionary, sure: bool) -> void:
	var sid: String = str(st.get("id", ""))
	if not Rules.STATUSES.has(sid) or not t.alive:
		return
	if sid in t.get("immune_status", []):
		_beat("status", "", t.uid, 0, "", "%s is immune!" % t.name, {"status": sid, "immune": true})
		return
	var chance: float = 1.0 if sure else float(st.get("chance", 1.0))
	if t.boss and Rules.STATUSES[sid].bad:
		chance *= 0.5
	if rng.randf() >= chance:
		return
	var turns: int = int(st.get("turns", 3))
	t.statuses[sid] = maxi(int(t.statuses.get(sid, 0)), turns)
	_beat("status", "", t.uid, turns, "", "%s is %s!" % [t.name, Rules.STATUSES[sid].name], {"status": sid})


func _end_turn(a: Dictionary) -> void:
	if not a.alive:
		return
	for sid: String in a.statuses.keys():
		var info: Dictionary = Rules.STATUSES[sid]
		if info.has("dot") and a.alive:
			var d: int = maxi(1, int(round(a.max_hp * float(info.dot))))
			if a.boss:
				d = maxi(1, int(d / 3.0))
			a.hp = maxi(0, a.hp - d)
			_beat("dot", "", a.uid, d, "rot" if sid == "moldy" else "fire", "%s takes %d from %s" % [a.name, d, info.name], {"status": sid})
			if a.hp <= 0:
				a.alive = false
				a.statuses = {}
				_beat("down", "", a.uid, 0, "", "%s is down!" % a.name)
				return
		if info.has("regen"):
			var h: int = maxi(1, int(round(a.max_hp * float(info.regen))))
			var before: int = a.hp
			a.hp = mini(a.max_hp, a.hp + h)
			if a.hp > before:
				_beat("regen", "", a.uid, a.hp - before, "light", "+%d" % (a.hp - before), {"status": sid})
		if info.has("spread") and rng.randf() < float(info.spread):
			var mates: Array = living(a.side).filter(func(x: Dictionary) -> bool: return x.uid != a.uid and not x.statuses.has(sid))
			if not mates.is_empty():
				_add_status(a, mates[rng.randi_range(0, mates.size() - 1)], {"id": sid, "turns": 2}, true)
		a.statuses[sid] = int(a.statuses[sid]) - 1
		if int(a.statuses[sid]) <= 0:
			a.statuses.erase(sid)
			_beat("status_end", "", a.uid, 0, "", "%s is no longer %s" % [a.name, info.name], {"status": sid})


# ================================================================== items / cooking / summons
func _ingredient_count() -> int:
	var n: int = 0
	for id: String in inventory:
		if Rules.INGREDIENTS.has(id):
			n += int(inventory[id])
	return n


func _take(id: String, n: int = 1) -> bool:
	if int(inventory.get(id, 0)) < n:
		return false
	inventory[id] = int(inventory[id]) - n
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	used_items[id] = int(used_items.get(id, 0)) + n
	return true


func _use_item(a: Dictionary, item_id: String, want: String) -> void:
	var it: Dictionary = Rules.item(item_id)
	if it.is_empty() or not it.get("kind", "") in ["consumable", "throwable", "dish"] or not _take(item_id):
		_do_guard(a)
		return
	var targets: Array = _targets(a, str(it.get("target", "ally")), want)
	_beat("item", a.uid, targets[0].uid if not targets.is_empty() else "", 0, str(it.get("element", "")), it.get("name", item_id),
		{"item": item_id, "anim": "cast"})
	if it.get("flee", false):
		if is_boss():
			_beat("flee_fail", a.uid, "", 0, "", "The smoke clears. The boss is still here.")
		else:
			fled = true
			over = true
			_beat("flee", a.uid, "", 0, "", "Poof! Escaped in a cloud of smoked gouda.")
		return
	_apply_effect(a, targets, it, 1.0)


## Applies an item/dish effect dictionary to targets.
func _apply_effect(a: Dictionary, targets: Array, e: Dictionary, _mult: float) -> void:
	for t: Dictionary in targets:
		if e.has("damage"):
			if t.alive:
				var em: float = Rules.element_mult(str(e.get("element", "none")), t.element, t.weak, t.resist)
				var amt: int = int(round(float(e.damage) * (1.0 + float(a.lck) / 100.0) * em * (0.5 if t.guard else 1.0)))
				_damage(a, t, maxi(1, amt) if em > 0.0 else 0, str(e.get("element", "none")), {"weak": em > 1.0})
				if t.alive and e.has("status"):
					_add_status(a, t, {"id": e.status.id, "turns": e.status.get("turns", 3), "chance": 0.8}, false)
			continue
		if e.has("revive"):
			_revive(t, float(e.revive))
		if not t.alive:
			continue
		if e.has("heal"):
			_heal(a, t, int(e.heal))
		if e.has("heal_pct"):
			_heal(a, t, int(round(t.max_hp * float(e.heal_pct))))
		if e.has("mp"):
			_restore_mp(t, int(e.mp))
		if e.has("mp_pct"):
			_restore_mp(t, int(round(t.max_mp * float(e.mp_pct))))
		if e.has("cure"):
			_cure(t, e.cure)
		if e.has("status"):
			_add_status(a, t, e.status, true)
	if int(e.get("gauge", 0)) > 0 and a.side == "party":
		_add_gauge(int(e.gauge))


func _cook(a: Dictionary, ingredients: Array, stir: float, want: String) -> void:
	var ings: Array = []
	for i: Variant in ingredients.slice(0, 3):
		ings.append(str(i))
	var have: Dictionary = {}
	var ok: bool = ings.size() >= 2
	for i: String in ings:
		have[i] = int(have.get(i, 0)) + 1
	for i: String in have:
		if not Rules.INGREDIENTS.has(i) or int(inventory.get(i, 0)) < int(have[i]):
			ok = false
	if not ok:
		_beat("cook", a.uid, "", 0, "", "Not enough ingredients!", {"dish": "", "quality": -1})
		_do_guard(a)
		return
	for i: String in ings:
		_take(i)
	var rid: String = Rules.match_recipe(ings)
	var q: int = Rules.cook_quality(rid, ings, stir, a.id, a.dish_boost)
	a.dish_boost = false
	var e: Dictionary = Rules.dish_effect(rid, q)
	var qname: String = Rules.QUALITY[q].name
	_beat("cook", a.uid, "", q, str(e.get("element", "")), "%s %s!" % [qname, Rules.item_name(rid)],
		{"dish": rid, "quality": q, "quality_name": qname, "ingredients": ings, "anim": "cast"})
	if rid != "mystery_mush" and not rid in recipes_known:
		recipes_known.append(rid)
		discovered.append(rid)
		_beat("recipe_discovered", a.uid, "", 0, "", "New recipe discovered: %s!" % Rules.item_name(rid), {"dish": rid})
	var targets: Array = _targets(a, str(e.get("target", "ally")), want)
	_apply_effect(a, targets, e, 1.0)


func _summon(a: Dictionary, sid: String, want: String) -> void:
	if sid == "" and not summons_available.is_empty():
		sid = summons_available[0]
	if not can_summon(sid):
		_beat("summon", a.uid, "", 0, "", "The spirits do not answer... (Fondue Gauge %d)" % gauge, {"summon": "", "failed": true})
		_do_guard(a)
		return
	var s: Dictionary = Rules.SUMMONS[sid]
	gauge -= int(s.get("cost", 100))
	summons_used += 1
	_beat("summon", a.uid, "", 0, s.element, s.intro, {"summon": sid, "model": s.model, "title": s.title, "attack": s.attack})
	_beat("gauge", "", "", -int(s.get("cost", 100)), "", "Fondue Gauge %d" % gauge, {"gauge": gauge})
	if s.get("target", "") == "all_allies":
		for t: Dictionary in party():
			if not t.alive and s.get("revive", 0.0) > 0.0:
				_revive(t, float(s.revive))
		for t: Dictionary in living("party"):
			if s.has("heal_pct"):
				_heal(a, t, int(round(t.max_hp * float(s.heal_pct))))
			if s.get("cure_all", false):
				_cure(t, t.statuses.keys().filter(func(x: String) -> bool: return Rules.STATUSES[x].bad))
		_beat("summon_attack", a.uid, "", 0, s.element, s.attack, {"summon": sid})
		return
	var best_mag: float = 0.0
	var lv: float = 0.0
	for p: Dictionary in party():
		best_mag = maxf(best_mag, float(p.mag))
		lv += float(p.level)
	lv /= maxf(1.0, float(party().size()))
	var raw: float = float(s.power) / 100.0 * (best_mag * 2.0 + lv * 8.0)
	_beat("summon_attack", a.uid, "", 0, s.element, s.attack, {"summon": sid})
	for t: Dictionary in _targets(a, str(s.target), want):
		var em: float = maxf(Rules.element_mult(s.element, t.element, t.weak, t.resist),
			Rules.element_mult(str(s.get("element2", "")), t.element, t.weak, t.resist) if s.get("element2", "") != "" else 0.0)
		var df: float = 0.0 if s.get("ignore_def", false) else _eff(t, "res") * 0.5
		_damage(a, t, maxi(1, int(round(maxf(1.0, raw - df) * em * rng.randf_range(0.95, 1.05)))), s.element, {"weak": em > 1.0, "summon": sid})
	if s.has("status_party"):
		for t: Dictionary in living("party"):
			_add_status(a, t, s.status_party, true)


# ================================================================== enemy AI
func _enemy_turn(a: Dictionary) -> void:
	if a.boss:
		_check_phase(a)
	var ai: String = str(a.ai)
	# coward / thief escape
	if (ai == "coward" and a.hp < a.max_hp * 0.3 and rng.randf() < 0.4) or (ai == "thief" and stolen_gold > 0 and rng.randf() < 0.25):
		a.fled = true
		a.alive = false
		_beat("enemy_flee", a.uid, "", 0, "", "%s runs away!" % a.name)
		return
	if ai == "berserk" and a.hp < a.max_hp * 0.5 and not a.statuses.has("spicy"):
		_add_status(a, a, {"id": "spicy", "turns": 3}, true)
	var choice: Array = _enemy_pick(a)
	_use_skill(a, choice[0], choice[1])


func _check_phase(a: Dictionary) -> void:
	var phases: Array = Rules.ENEMIES.get(a.id, {}).get("phases", [])
	var frac: float = float(a.hp) / float(maxi(1, a.max_hp))
	var idx: int = -1
	for i: int in phases.size():
		if frac <= float(phases[i].below):
			idx = i
	if idx > a.phase:
		for i: int in range(a.phase + 1, idx + 1):
			var ph: Dictionary = phases[i]
			_beat("phase", a.uid, "", i + 1, a.element, str(ph.get("text", "")), {"phase": i + 1})
			if ph.has("status"):
				_add_status(a, a, ph.status, true)
		a.phase = idx
		a.skill_pool = phases[idx].skills.duplicate(true)
		if phases[idx].has("ai"):
			a.ai = phases[idx].ai


## Returns [skill_id, preferred_target_uid].
func _enemy_pick(a: Dictionary) -> Array:
	var ai: String = str(a.ai)
	var foes: Array = living("party")
	var mates: Array = living("enemy")
	var pool: Array = []
	for pair: Array in a.skill_pool:
		var sk: Dictionary = Rules.skill(str(pair[0]))
		if sk.is_empty() or a.mp < int(sk.get("mp", 0)):
			continue
		var w: float = float(pair[1])
		var kind: String = str(sk.get("kind", "physical"))
		match ai:
			"caster":
				if kind == "magic" or kind == "debuff":
					w *= 2.0
			"thief":
				if sk.has("steal_gold"):
					w *= 2.0
			"spreader":
				if sk.has("status") and Rules.STATUSES.get(sk.status.id, {}).get("bad", false):
					var fresh: int = foes.filter(func(f: Dictionary) -> bool: return not f.statuses.has(sk.status.id)).size()
					w *= 2.5 if fresh > 0 else 0.3
			"defender":
				if kind == "buff":
					var hurt: bool = mates.any(func(m: Dictionary) -> bool: return m.hp < m.max_hp * 0.5)
					w *= 2.5 if hurt else 0.7
			"berserk":
				w *= 1.0 + float(sk.get("power", 100)) / 100.0
			"boss":
				pass
		# useless choices
		if kind == "heal":
			var need: bool = mates.any(func(m: Dictionary) -> bool: return m.hp < m.max_hp * 0.6)
			if sk.get("target", "") == "self":
				need = a.hp < a.max_hp * 0.6
			w *= (3.0 if ai == "healer" else 1.5) if need else 0.0
		if kind in ["buff"] and sk.has("status") and sk.get("target", "") == "self" and a.statuses.has(sk.status.id):
			w *= 0.1
		if sk.has("summon_ally") and mates.size() >= MAX_ENEMIES:
			w = 0.0
		if w > 0.0:
			pool.append([str(pair[0]), w])
	if pool.is_empty():
		pool = [["attack", 1.0]]
	var total: float = 0.0
	for p: Array in pool:
		total += float(p[1])
	var r: float = rng.randf() * total
	var sid: String = pool[0][0]
	for p: Array in pool:
		r -= float(p[1])
		if r <= 0.0:
			sid = p[0]
			break
	var sk2: Dictionary = Rules.skill(sid)
	var want: String = ""
	var tt: String = str(sk2.get("target", "enemy"))
	if tt == "enemy" and not foes.is_empty():
		match ai:
			"aggressive", "berserk":
				if rng.randf() > 0.6:
					return [sid, ""]
				var low: Dictionary = foes[0]
				for f: Dictionary in foes:
					if float(f.hp) / f.max_hp < float(low.hp) / low.max_hp:
						low = f
				want = low.uid
			"caster":
				var el: String = str(sk2.get("element", "none"))
				for f: Dictionary in foes:
					if el in f.weak:
						want = f.uid
			"boss":
				if rng.randf() < 0.5:
					var low2: Dictionary = foes[0]
					for f: Dictionary in foes:
						if f.hp < low2.hp:
							low2 = f
					want = low2.uid
	elif tt == "ally" and not mates.is_empty():
		var lowm: Dictionary = mates[0]
		for m: Dictionary in mates:
			if float(m.hp) / m.max_hp < float(lowm.hp) / lowm.max_hp:
				lowm = m
		want = lowm.uid
	return [sid, want]


# ================================================================== party auto AI
## A reasonable command for a party actor (auto-battle, QA bot, tests).
func auto_command(uid: String) -> Dictionary:
	var a: Dictionary = get_actor(uid)
	if a.is_empty():
		return {"type": "guard"}
	var allies: Array = living("party")
	var downed: Array = valid_targets(uid, "ally_down")
	var foes: Array = living("enemy")
	if foes.is_empty():
		return {"type": "guard"}
	var skills: Array = skill_list(uid).filter(func(s: Dictionary) -> bool: return s.enabled)
	# 1. revive
	if not downed.is_empty():
		for s: Dictionary in skills:
			if Rules.skill(s.id).get("kind", "") == "revive":
				return {"type": "skill", "skill": s.id, "target": downed[0]}
		for it: String in ["smelling_salts", "catnip_tincture", "cranberry_brie_bites"]:
			if int(inventory.get(it, 0)) > 0:
				return {"type": "item", "item": it, "target": downed[0]}
	# 2. summon when gauge is full
	if can_summon():
		var low_party: bool = allies.size() < party().size() or allies.any(func(x: Dictionary) -> bool: return x.hp < x.max_hp * 0.35)
		var pick: String = "samantha" if low_party and can_summon("samantha") else ""
		if pick == "":
			for s: String in ["tripper", "jesse", "spooky", "samantha"]:
				if can_summon(s):
					pick = s
					break
		return {"type": "summon", "summon": pick}
	# 3. heal
	var hurt: Array = allies.filter(func(x: Dictionary) -> bool: return x.hp < x.max_hp * 0.45)
	if not hurt.is_empty():
		hurt.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.hp) / x.max_hp < float(y.hp) / y.max_hp)
		var best_heal: String = ""
		for s: Dictionary in skills:
			var sk: Dictionary = Rules.skill(s.id)
			if sk.get("kind", "") == "heal" and (sk.target in ["ally", "all_allies"]):
				if best_heal == "" or (hurt.size() >= 2 and sk.target == "all_allies") or int(sk.power) > int(Rules.skill(best_heal).power):
					best_heal = s.id
		if best_heal != "":
			return {"type": "skill", "skill": best_heal, "target": hurt[0].uid}
		if hurt[0].hp < hurt[0].max_hp * 0.3:
			# cook something healing if possible, else an item
			var cook: Array = _cookable_heal()
			if not cook.is_empty() and rng.randf() < 0.5:
				return {"type": "cook", "ingredients": cook, "stir": rng.randf_range(0.4, 1.0), "target": hurt[0].uid}
			for it: String in ["cream_flask", "whey_tonic", "milk_bottle", "herb_salve"]:
				if int(inventory.get(it, 0)) > 0:
					return {"type": "item", "item": it, "target": hurt[0].uid}
	# 4. cure Frozen/Moldy on allies via curd_cure
	for s: Dictionary in skills:
		if s.id == "curd_cure":
			for x: Dictionary in allies:
				if x.statuses.has("moldy") or x.statuses.has("melted"):
					return {"type": "skill", "skill": "curd_cure", "target": x.uid}
	# 5. occasional buff early on
	if actions < 12 and rng.randf() < 0.25:
		for s: Dictionary in skills:
			var sk: Dictionary = Rules.skill(s.id)
			if sk.get("kind", "") == "buff" and sk.has("status") and not a.statuses.has(sk.status.id):
				return {"type": "skill", "skill": s.id}
	# 6. best damage skill (keep an MP reserve for healers)
	var reserve: int = 8 if a.id == "brie" else 0
	var best: String = ""
	var best_val: float = 100.0  # plain attack value baseline
	var best_target: String = ""
	var weakest: Dictionary = foes[0]
	for f: Dictionary in foes:
		if f.hp < weakest.hp:
			weakest = f
	for s: Dictionary in skills:
		var sk: Dictionary = Rules.skill(s.id)
		if not sk.get("kind", "") in ["magic", "physical"] or a.mp - int(sk.mp) < reserve:
			continue
		var n: float = 1.0
		match str(sk.target):
			"all_enemies":
				n = float(foes.size())
			"random_enemies":
				n = float(sk.get("hits", 1)) * 0.8
		var tgt: Dictionary = weakest
		var em: float = Rules.element_mult(str(sk.element), tgt.element, tgt.weak, tgt.resist)
		for f: Dictionary in foes:
			var e2: float = Rules.element_mult(str(sk.element), f.element, f.weak, f.resist)
			if e2 > em:
				em = e2
				tgt = f
		var stat: float = float(a.atk if sk.kind == "physical" else a.mag) / maxf(1.0, float(a.atk))
		var val: float = float(sk.power) * float(sk.get("hits", 1) if sk.target != "random_enemies" else 1) * n * em * stat
		val *= 1.15 if last_elem != "" and last_elem != str(sk.element) else 1.0
		if val > best_val:
			best_val = val
			best = s.id
			best_target = tgt.uid
	if best != "":
		return {"type": "skill", "skill": best, "target": best_target}
	return {"type": "attack", "target": weakest.uid}


## Ingredients (2-3) for a known healing recipe that can be cooked from inventory, or [].
func _cookable_heal() -> Array:
	for rid: String in recipes_known:
		var r: Dictionary = Rules.RECIPES.get(rid, {})
		if r.is_empty() or r.effect.has("damage"):
			continue
		var pick: Array = []
		var left: Dictionary = inventory.duplicate()
		var ok: bool = true
		for sl: String in r.slots:
			var found: String = ""
			for id: String in left:
				if int(left[id]) > 0 and Rules._slot_ok(sl, id):
					found = id
					break
			if found == "":
				ok = false
				break
			left[found] = int(left[found]) - 1
			pick.append(found)
		if ok:
			return pick
	return []


# ================================================================== beats
func _beat(type: String, actor: String, target: String, amount: int, element: String, text: String, extra: Dictionary = {}) -> void:
	var b: Dictionary = {"type": type, "actor": actor, "target": target, "amount": amount, "element": element, "text": text}
	b.merge(extra)
	_beats.append(b)
