extends Node
## Headless smoke test (battle-presentation): plays several encounters start-to-finish in auto mode through the full
## presentation (beats, VFX, summons, result screens) and checks Events.battle_finished fires with a sane result.
## tools/godot.sh --headless --path game res://scenes/battle/battle_smoke.tscn [-- --encounters=a,b]
var got: Array = []


func _ready() -> void:
	Events.battle_finished.connect(func(r: Dictionary) -> void: got.append(r))
	var encs: PackedStringArray = PackedStringArray(["meadow_grunts", "barn_mixed", "pond_blobs"])
	for s: String in OS.get_cmdline_user_args():
		if s.begins_with("--encounters="):
			encs = s.trim_prefix("--encounters=").split(",")
	var fails: int = 0
	for e: String in encs:
		GameState.new_game()
		for sid: String in Data.SUMMONS:
			GameState.summons.append(sid)
		var bs: BattleScene = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
		bs._started = true
		add_child(bs)
		var n: int = got.size()
		var t0: int = Time.get_ticks_msec()
		await bs.start(e, {"auto": true, "fast": true, "seed": 11, "gauge": 100, "apply_result": true})
		var ok: bool = got.size() == n + 1 and got[-1].has("won") and got[-1].has("level_ups")
		print("SMOKE %s %s won=%s turns=%s %.1fs" % [e, "OK" if ok else "FAIL", got[-1].get("won") if got.size() > n else "?",
			got[-1].get("turns") if got.size() > n else "?", (Time.get_ticks_msec() - t0) / 1000.0])
		fails += 0 if ok else 1
		bs.queue_free()
		await get_tree().process_frame
	print("SMOKE_DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
