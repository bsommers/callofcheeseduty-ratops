extends RefCounted
## BattleEngine: termination for every encounter, determinism, balance, and mechanics.

const Rules = preload("res://data/db.gd")
const Engine_ = preload("res://scripts/battle/battle_engine.gd")
const SEEDS_TERMINATE: int = 12
const SEEDS_BALANCE: int = 40

## Gear a player would plausibly own at a level (shop tiers unlocked by bosses).
const GEAR: Array = [
	[1, {"fennel": ["cheese_knife", "farm_apron", ""], "brie": ["feather_wand", "farm_apron", ""],
		"clover": ["iron_skillet", "quilted_vest", ""], "maple": ["cellar_lantern", "farm_apron", ""]}],
	[5, {"fennel": ["chef_ladle", "quilted_vest", ""], "brie": ["egg_scepter", "quilted_vest", ""],
		"clover": ["cast_iron_wok", "quilted_vest", "lucky_bell"], "maple": ["frost_tongs", "quilted_vest", ""]}],
	[10, {"fennel": ["flambe_knife", "chef_whites", "whisker_charm"], "brie": ["egg_scepter", "chef_whites", "lucky_bell"],
		"clover": ["cast_iron_wok", "chef_whites", "lucky_bell"], "maple": ["frost_tongs", "chef_whites", "whisker_charm"]}],
	# Rind-mail tier is sold only after the Mold Dragon (tinker unlock), so it applies from L18 up.
	[18, {"fennel": ["flambe_knife", "rind_mail", "smoke_ring"], "brie": ["cyclone_whisk", "rind_mail", "curd_amulet"],
		"clover": ["ancient_griddle", "rind_mail", "curd_amulet"], "maple": ["ice_cellar_key_staff", "rind_mail", "chill_pendant"]}],
]

const PRE_DRAGON: Array = ["cave_mouth_blobs", "cave_golems", "cave_spiders", "cave_mixed", "cellar_ticks", "boss_mold_dragon"]

var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


static func party_at(level: int, gear_level: int = -1) -> Array:
	var tier: Dictionary = GEAR[0][1]
	var gl: int = level if gear_level < 0 else mini(level, gear_level)
	for g: Array in GEAR:
		if gl >= int(g[0]):
			tier = g[1]
	var out: Array = []
	for cid: String in Rules.PARTY_ORDER:
		var eq: Array = tier[cid]
		out.append({"id": cid, "level": level, "equip": {"weapon": eq[0], "armor": eq[1], "charm": eq[2]}})
	return out


static func inv_for(level: int, boss: bool) -> Dictionary:
	var n: int = 3 if boss else 1
	var inv: Dictionary = {"milk_bottle": 2 * n, "smelling_salts": n, "wheat": 2, "butter": 2, "cheddar": 2}
	if level >= 8:
		inv.merge({"cream_flask": 2 * n, "herb_salve": n})
	if level >= 15:
		inv.merge({"whey_tonic": 2 * n, "mega_salve": n, "catnip_tincture": n})
	return inv


static func summons_for(level: int) -> Array:
	var s: Array = []
	if level >= 9:
		s.append("jesse")
	if level >= 13:
		s.append("tripper")
	if level >= 17:
		s.append("samantha")
	if level >= 22:
		s.append("spooky")
	return s


static func simulate(enc_id: String, seed: int, level_bonus: int = 0) -> Engine_:
	var enc: Dictionary = Rules.ENCOUNTERS[enc_id]
	var lv: int = int(enc.level) + level_bonus
	var e: Engine_ = Engine_.new()
	# Cave fights before the Mold Dragon (and the dragon itself) cannot use post-dragon shop gear.
	var gear_cap: int = 17 if enc_id in PRE_DRAGON else -1
	e.setup(enc_id, party_at(lv, gear_cap), {"seed": seed, "inventory": inv_for(lv, enc.get("boss", false)),
		"summons": summons_for(lv), "gauge": 0, "recipes": ["grilled_cheese", "garlic_bread"], "gold": 500})
	e.run_auto()
	return e


func test_every_encounter_terminates() -> void:
	for enc_id: String in Rules.ENCOUNTERS:
		for s: int in SEEDS_TERMINATE:
			var e: Engine_ = simulate(enc_id, 1000 + s)
			check(e.is_over(), "%s seed %d did not end" % [enc_id, s])
			check(not e.timed_out, "%s seed %d timed out (%d actions)" % [enc_id, s, e.actions])


func test_deterministic() -> void:
	var a: Engine_ = simulate("crop_mixed", 42)
	var b: Engine_ = simulate("crop_mixed", 42)
	check(a.actions == b.actions and a.won == b.won, "same seed same outcome")
	check(str(a.result()) == str(b.result()), "same seed same result")


func test_balance_normal_battles() -> void:
	var wins: int = 0
	var total: int = 0
	var report: Array = []
	for enc_id: String in Rules.ENCOUNTERS:
		if Rules.ENCOUNTERS[enc_id].get("boss", false):
			continue
		var w: int = 0
		for s: int in SEEDS_BALANCE:
			if simulate(enc_id, 5000 + s).won:
				w += 1
		wins += w
		total += SEEDS_BALANCE
		report.append("%s %d%%" % [enc_id, 100 * w / SEEDS_BALANCE])
		check(w >= SEEDS_BALANCE * 0.6, "encounter %s too hard: %d/%d" % [enc_id, w, SEEDS_BALANCE])
	var rate: float = float(wins) / float(total)
	print("     balance: overall %.1f%% | %s" % [rate * 100.0, ", ".join(report)])
	check(rate >= 0.78 and rate <= 0.995, "overall normal win rate %.1f%% outside 78-99.5%%" % (rate * 100.0))


func test_bosses_winnable() -> void:
	for enc_id: String in ["boss_crow_baron", "boss_mold_dragon", "boss_rat_king"]:
		var w: int = 0
		var turns: int = 0
		for s: int in 20:
			var e: Engine_ = simulate(enc_id, 9000 + s, 1)
			w += 1 if e.won else 0
			turns += e.actions
		print("     boss %s: %d/20 wins, avg %d actions" % [enc_id, w, turns / 20])
		check(w >= 6, "%s should be winnable at level+1 (%d/20)" % [enc_id, w])
		check(w <= 19 or turns / 20 > 20, "%s should not be trivial" % enc_id)


## Late-game tuning bands (docs/swarm/reports/tuning.md): a party at the intended level wins >=90% of normal fights
## and >=75% of boss fights over 40 seeds. Intended boss level: Crow Baron 10, Mold Dragon 17-18, Rat King 24-25.
func test_late_game_win_bands() -> void:
	var low: Array = []
	for enc_id: String in Rules.ENCOUNTERS:
		var boss: bool = Rules.ENCOUNTERS[enc_id].get("boss", false)
		var w: int = 0
		for s: int in 40:
			w += 1 if simulate(enc_id, 5000 + s, 1 if boss else 0).won else 0
		if w < (30 if boss else 36):
			low.append("%s %d/40" % [enc_id, w])
	check(low.is_empty(), "below the win band at intended level: %s" % ", ".join(low))
	for pair: Array in [["boss_mold_dragon", 0], ["boss_rat_king", 1]]:
		var w2: int = 0
		for s: int in 40:
			w2 += 1 if simulate(pair[0], 7000 + s, pair[1]).won else 0
		check(w2 >= 30, "%s at party L%d should be >=75%% (%d/40)" % [pair[0], int(Rules.ENCOUNTERS[pair[0]].level) + pair[1], w2])


func test_flavor_chain_and_gauge() -> void:
	var e: Engine_ = Engine_.new()
	e.setup("meadow_grunts", party_at(20), {"seed": 3})
	e.start()
	e.last_elem = "fire"
	e.chain_len = 1
	var m: float = e._chain_extend("wind")
	check(is_equal_approx(m, 1.0 + Rules.CHAIN_STEP_MULT + 0.3), "Smoked chain mult (%f)" % m)
	check(e.gauge > 0, "gauge filled by cast")


func test_cook_in_battle() -> void:
	var e: Engine_ = Engine_.new()
	var p: Array = party_at(5)
	p[0].hp = 10
	e.setup("meadow_grunts", p, {"seed": 4, "inventory": {"wheat": 1, "butter": 1, "cheddar": 1}})
	e.start()
	while e.current_actor().get("id", "") != "fennel" and not e.is_over():
		e.step({"type": "guard"})
	var beats: Array = e.step({"type": "cook", "ingredients": ["wheat", "butter", "cheddar"], "stir": 1.0, "target": "p0"})
	var cooked: Array = beats.filter(func(b: Dictionary) -> bool: return b.type == "cook")
	check(not cooked.is_empty() and cooked[0].dish == "grilled_cheese" and cooked[0].quality == 3, "gourmet grilled cheese cooked")
	check(beats.any(func(b: Dictionary) -> bool: return b.type == "recipe_discovered"), "recipe discovered")
	check(e.inventory.is_empty(), "ingredients consumed")
	check(int(e.used_items.get("wheat", 0)) == 1, "used items tracked")


func test_summon() -> void:
	var e: Engine_ = Engine_.new()
	e.setup("pasture_rats", party_at(10), {"seed": 5, "summons": ["tripper"], "gauge": 100})
	e.start()
	check(e.can_summon("tripper"), "can summon at 100")
	var beats: Array = e.step({"type": "summon", "summon": "tripper"})
	check(beats.any(func(b: Dictionary) -> bool: return b.type == "summon_attack"), "summon attack beat")
	check(beats.filter(func(b: Dictionary) -> bool: return b.type == "damage").size() >= 1, "summon dealt damage")
	check(e.summons_used == 1, "summon counted")


func test_boss_phases() -> void:
	var e: Engine_ = Engine_.new()
	e.setup("boss_mold_dragon", party_at(18), {"seed": 6})
	e.start()
	var boss: Dictionary = e.enemies()[0]
	boss.hp = int(boss.max_hp * 0.3)
	e._beats = []
	e._check_phase(boss)
	check(boss.phase == 1, "jumped to phase 2 (got %d)" % boss.phase)
	check(e._beats.filter(func(b: Dictionary) -> bool: return b.type == "phase").size() == 2, "phase beats for both thresholds")


func test_flee_rules() -> void:
	var e: Engine_ = Engine_.new()
	e.setup("boss_crow_baron", party_at(9), {"seed": 7})
	e.start()
	e.step({"type": "flee"})
	check(not e.fled, "cannot flee a boss")
	var fled_any: bool = false
	for s: int in 10:
		var n: Engine_ = Engine_.new()
		n.setup("meadow_grunts", party_at(3), {"seed": s})
		n.start()
		n.step({"type": "flee"})
		fled_any = fled_any or n.fled
	check(fled_any, "fleeing normal battles works sometimes")


func test_result_shape() -> void:
	var e: Engine_ = simulate("meadow_grunts", 11, 3)
	var r: Dictionary = e.result()
	for k: String in ["won", "fled", "xp", "gold", "drops", "party"]:
		check(r.has(k), "result has " + k)
	check(r.won and r.xp > 0 and r.gold > 0, "won with xp+gold")


func test_result_never_negative() -> void:
	var e: Engine_ = simulate("meadow_grunts", 7)
	e.stolen_gold = 100000
	var r: Dictionary = e.result()
	check(int(r.gold) >= 0 and int(r.xp) >= 0, "result gold/xp clamped at 0")
