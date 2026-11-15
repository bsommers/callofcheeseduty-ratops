extends SceneTree
## Balance report: win rate + average party HP left per encounter at the recommended level.
## usage: tools/godot.sh --headless --path game --script res://tests/balance_report.gd -- [seeds] [level_bonus]

const Rules = preload("res://data/db.gd")
const T = preload("res://tests/test_battle.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = int(args[0]) if args.size() > 0 else 30
	var bonus: int = int(args[1]) if args.size() > 1 else 0
	var tw: int = 0
	var tn: int = 0
	for enc_id: String in Rules.ENCOUNTERS:
		var w: int = 0
		var hp: float = 0.0
		var acts: int = 0
		var b: int = bonus + (1 if Rules.ENCOUNTERS[enc_id].get("boss", false) else 0)
		for s: int in seeds:
			var e: RefCounted = T.simulate(enc_id, 5000 + s, b)
			acts += e.actions
			if e.won:
				w += 1
				var f: float = 0.0
				for p: Dictionary in e.party():
					f += float(p.hp) / p.max_hp
				hp += f / 4.0
		if not Rules.ENCOUNTERS[enc_id].get("boss", false):
			tw += w
			tn += seeds
		print("%-20s L%-2d win %3d%%  hp_left %3d%%  actions %d" % [enc_id, Rules.ENCOUNTERS[enc_id].level, 100 * w / seeds,
			int(100.0 * hp / maxf(1, w)), acts / seeds])
	print("NORMAL OVERALL %.1f%%" % (100.0 * tw / tn))
	quit()
