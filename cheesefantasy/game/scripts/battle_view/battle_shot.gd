extends Node
## Screenshot harness for the battle scene (owner battle-presentation; used because tools/shot.sh did not exist yet).
## Run through scripts/battle_view/shot.sh. User args: --out=prefix --encounter=id --mode=idle|menu|vfx|summon|victory|auto
##   --vfx=fire_burst --element=fire --all=1 --summon=jesse --times=0.5,1.2 (seconds after the trigger; one PNG each:
##   <prefix>_<i>.png) --seed=N --bg=<override>
var a: Dictionary = {}


func _ready() -> void:
	for s: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = s.trim_prefix("--").split("=", true, 1)
		a[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if GameState.party.is_empty():
		GameState.new_game()
	for sid: String in Data.SUMMONS:
		if not sid in GameState.summons:
			GameState.summons.append(sid)
	var bs: BattleScene = (load("res://scenes/battle/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	bs._started = true
	add_child(bs)
	var mode: String = str(a.get("mode", "idle"))
	var enc: String = str(a.get("encounter", "meadow_grunts"))
	var o: Dictionary = {"seed": int(a.get("seed", "3")), "auto": mode == "auto", "apply_result": false, "gauge": 100, "wait_screen": false}
	bs.opts = o
	bs.auto = mode == "auto"
	bs.setup_stage(enc, o)
	await _frames(20)
	var times: PackedStringArray = str(a.get("times", "0.0")).split(",")
	match mode:
		"idle":
			bs.cam.wide(0.0)
		"menu":
			bs.cam.wide(0.0)
			await bs.play_beats(bs.engine.start())
			var who: Dictionary = bs.engine.current_actor()
			bs._refresh_order()
			bs.hud.highlight_member(str(who.uid))
			bs.cam.over_shoulder(bs.views[str(who.uid)].global_position, "party", 0.0)
			bs.hud.open_menu(str(who.name), bs.engine.available_commands(), bs.engine.skill_list(), bs._items(), bs._summons())
			if a.has("sub"):
				bs.hud._root_pick(str(a.sub))
		"vfx":
			bs.cam.side_view("party" if a.has("party") else "enemy", 0.0)
			bs.cam.move_to(Vector3(-1.0, 2.6, 8.0), Vector3(-3.4, 1.0, 0), 0.0, 48.0) if not a.has("party") else bs.cam.move_to(Vector3(1.0, 2.6, 8.0), Vector3(3.4, 1.0, 0), 0.0, 48.0)
			bs.debug_vfx(str(a.get("vfx", "fire_burst")), str(a.get("element", "fire")), a.has("party"), a.has("all"))
		"summon":
			bs.debug_summon(str(a.get("summon", "jesse")))
		"victory":
			for e: Dictionary in bs.engine.enemies():
				e.hp = 0
				e.alive = false
				bs.views[str(e.uid)].set_down(true)
			bs.engine.over = true
			bs.engine.won = true
			bs._finish()
		"auto":
			bs.run()
	var t0: float = 0.0
	for i: int in times.size():
		var t: float = float(times[i])
		if t > t0:
			await get_tree().create_timer(t - t0).timeout
			t0 = t
		await RenderingServer.frame_post_draw
		var out: String = "%s_%d.png" % [str(a.get("out", "/tmp/battle")), i]
		get_viewport().get_texture().get_image().save_png(out)
		print("SHOT ", out)
	get_tree().quit()


func _frames(n: int) -> void:
	for i: int in n:
		await RenderingServer.frame_post_draw
