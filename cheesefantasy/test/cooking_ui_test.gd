extends SceneTree
## Headless flow test: drives CookingUI through pick -> stir -> result with real autoloads.
func _init() -> void:
	await process_frame
	var gs: Node = root.get_node("GameState")
	var ui: Control = load("res://scenes/ui/cooking.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	gs.add_item("wheat", 2); gs.add_item("butter", 2); gs.add_item("cheddar", 2); gs.add_item("milk", 1)
	var w0: int = gs.count("wheat")
	var m0: int = gs.count("milk")
	ui.open("field", "fennel")
	var ok := true
	ok = ok and ui.pick("wheat") and ui.pick("butter") and ui.pick("cheddar")
	ok = ok and not ui.pick("milk")
	print("match=", ui.current_match())
	ok = ok and ui.current_match() == "grilled_cheese"
	ok = ok and ui.start_stir()
	for i in ui.beats_total:
		ui.marker = ui.zone_center
		ui.stir_press()
	var r: Dictionary = ui.last_result
	print("result=", r)
	print("cnt ", gs.count("grilled_cheese"), " ", gs.count("wheat"))
	ok = ok and r["dish_id"] == "grilled_cheese" and r["tier"] == 3 and gs.count("grilled_cheese") == 1 and gs.count("wheat") == w0 - 1
	# mush
	ui.open("battle", "clover")
	ui.pick("milk"); ui.pick("cheddar"); ui.pick("butter")
	ui.start_stir()
	for i in ui.beats_total:
		ui.marker = 0.0 if ui.zone_center > 0.4 else 1.0
		ui.stir_press()
	print("battle=", ui.last_result)
	ok = ok and ui.last_result["tier"] >= 0 and gs.count("milk") == m0 - 1
	ui._refresh_book()
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
