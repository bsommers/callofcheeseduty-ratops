# Headless Godot check: each party/summon GLB spawns via ActorFactory as a real model (not the placeholder)
# with every contract clip. Run: tools/godot.sh --headless --path game -s ../test/party_models_godot.gd
extends SceneTree

const HERO := ["idle", "walk", "run", "attack", "cast", "hurt", "down", "victory", "defend"]
const SUM := ["idle", "summon_intro", "special", "outro"]


func _init() -> void:
	var ids := {"hero_fennel": HERO, "hero_brie": HERO, "hero_clover": HERO, "hero_maple": HERO,
		"summon_jesse": SUM, "summon_tripper": SUM, "summon_samantha": SUM, "summon_spooky": SUM}
	var bad := 0
	for id: String in ids:
		var ok_file: bool = ActorFactory.has_model(id)
		var rig = ActorFactory.spawn(id)
		root.add_child(rig)
		var missing := []
		for c: String in ids[id]:
			if not rig.has_anim(c):
				missing.append(c)
		var good: bool = ok_file and missing.is_empty()
		if not good:
			bad += 1
		print("GODOT %-16s %s file=%s h=%.2f missing=%s" % [id, "OK" if good else "FAIL", ok_file, rig.height, missing])
		rig.queue_free()
	quit(1 if bad else 0)
