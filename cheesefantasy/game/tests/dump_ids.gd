extends SceneTree
## Prints every id table (owner rpg-core): tools/godot.sh --headless --path game -s res://tests/dump_ids.gd

const Rules = preload("res://data/db.gd")


func _initialize() -> void:
	var tables: Dictionary = {"ELEMENTS": Rules.ELEMENTS, "STATUSES": Rules.STATUSES, "CHARACTERS": Rules.CHARACTERS,
		"SUMMONS": Rules.SUMMONS, "SKILLS": Rules.SKILLS, "ENEMIES": Rules.ENEMIES, "INGREDIENTS": Rules.INGREDIENTS,
		"RECIPES": Rules.RECIPES, "ITEMS": Rules.items(), "ENCOUNTERS": Rules.ENCOUNTERS, "SHOPS": Rules.SHOPS,
		"QUESTS": Rules.QUESTS, "AREAS": Rules.AREAS}
	for t: String in tables:
		print("%s (%d): %s" % [t, tables[t].size(), ", ".join(PackedStringArray(tables[t].keys()))])
	quit()
