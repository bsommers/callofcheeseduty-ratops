extends SceneTree
const CookingLogic = preload("res://scripts/cooking/cooking_logic.gd")
## Run: tools/godot.sh --headless --path game --script res://../test/cooking_logic_test.gd  (or copy under game/tests)
func _init() -> void:
	var rec: Dictionary = load("res://data/recipes.gd").RECIPES
	var ing: Dictionary = load("res://data/items.gd").INGREDIENTS
	var fails := 0
	var bad := 0
	for rid in rec:
		var picked: Array = []
		for s: String in rec[rid]["slots"]:
			if s == "cheese":
				picked.append("cheddar")
			elif s.begins_with("tag:"):
				for k in ing:
					if s.substr(4) in ing[k]["tags"]:
						picked.append(k); break
			else:
				picked.append(s)
		var m: String = CookingLogic.match_recipe(picked, rec, ing)
		if m != rid:
			fails += 1
			print("MISMATCH ", rid, " -> ", m, " ", picked)
	if CookingLogic.match_recipe(["milk", "garlic", "truffle"], rec, ing) != "" : print("note: milk/garlic/truffle matched")
	if CookingLogic.stir_tier([1.0, 1.0, 0.95, 0.9]) != 3: bad += 1
	if CookingLogic.stir_tier([0.0, 0.0, 0.5, 0.0]) != 0: bad += 1
	if CookingLogic.stir_tier([0.7, 0.7, 0.7, 0.7]) != 2: bad += 1
	if CookingLogic.final_tier(3, 1) != 3: bad += 1
	print("recipes=%d mismatches=%d logic_bad=%d" % [rec.size(), fails, bad])
	quit(1 if fails + bad > 0 else 0)
