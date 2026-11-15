extends SceneTree
## Run: tools/godot.sh --headless --path game --script res://../test/rpg_world_test.gd (copy into game/ if needed)
## Checks the farm builds, has NPCs/mobs/points/player, and all dialogue JSON parses with valid goto targets.
func _init() -> void:
	var fails := 0
	var farm: Node = (load("res://scenes/world/farm.tscn") as PackedScene).instantiate()
	root.add_child(farm)
	await process_frame
	var n_npc := get_nodes_in_group("interactable").size()
	print("interactables: ", n_npc)
	if n_npc < 25: fails += 1; print("FAIL few interactables")
	if get_first_node_in_group("player") == null: fails += 1; print("FAIL no player")
	if get_first_node_in_group("dialogue_box") == null: fails += 1; print("FAIL no dialogue box")
	var d := DirAccess.open("res://data/dialogue")
	var count := 0
	for f in d.get_files():
		if not f.ends_with(".json"): continue
		count += 1
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
		if not (j is Dictionary): fails += 1; print("FAIL parse ", f); continue
		var nodes: Dictionary = j["nodes"]
		for k in nodes:
			var nd: Dictionary = nodes[k]
			var targets: Array = []
			if nd.has("next"): targets.append(nd["next"])
			for c in nd.get("choices", []): targets.append(c.get("next", ""))
			for t in targets:
				if t != "" and t != "end" and not nodes.has(t): fails += 1; print("FAIL ", f, " dangling ", t)
	print("dialogues: ", count)
	print("RPG_WORLD_TEST ", "PASS" if fails == 0 else "FAIL")
	quit(fails)
