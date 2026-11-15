extends Node
## Data autoload (owner rpg-core): read-only game tables. All ids are lowercase snake_case strings.
## Tables live in res://data/*.gd; rules/formulas in res://data/db.gd (class DB, usable without autoloads).
## ITEMS includes every dish (recipe id, kind "dish") and "mystery_mush"; ingredients are in INGREDIENTS
## (use Data.item(id) to look up any inventory id). DIALOGUE is loaded from res://data/dialogue/<npc_id>.json.

const DB = preload("res://data/db.gd")

const ELEMENTS: Dictionary = DB.ELEMENTS
const STATUSES: Dictionary = DB.STATUSES
const CHAINS: Dictionary = DB.CHAINS
const QUALITY: Array = DB.QUALITY
const SKILLS: Dictionary = DB.SKILLS
const CHARACTERS: Dictionary = DB.CHARACTERS
const PARTY_ORDER: Array = DB.PARTY_ORDER
const MAX_LEVEL: int = DB.MAX_LEVEL
const ENEMIES: Dictionary = DB.ENEMIES
const INGREDIENTS: Dictionary = DB.INGREDIENTS
const RECIPES: Dictionary = DB.RECIPES
const SUMMONS: Dictionary = DB.SUMMONS
const ENCOUNTERS: Dictionary = DB.ENCOUNTERS
const SHOPS: Dictionary = DB.SHOPS
const QUESTS: Dictionary = DB.QUESTS
const AREAS: Dictionary = DB.AREAS

var ITEMS: Dictionary = DB.items()
var DIALOGUE: Dictionary = {}


func _init() -> void:
	_load_dialogue()


func _load_dialogue() -> void:
	var dir: DirAccess = DirAccess.open("res://data/dialogue")
	if dir == null:
		return
	for f: String in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var txt: String = FileAccess.get_file_as_string("res://data/dialogue/" + f)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed != null:
			DIALOGUE[f.get_basename()] = parsed


func item(id: String) -> Dictionary:
	return DB.item(id)


func item_name(id: String) -> String:
	return DB.item_name(id)


func skill(id: String) -> Dictionary:
	return DB.skill(id)


func char_stats(char_id: String, level: int) -> Dictionary:
	return DB.char_stats(char_id, level)


func char_skills(char_id: String, level: int) -> Array:
	return DB.char_skills(char_id, level)


func enemy_stats(enemy_id: String, level: int = -1) -> Dictionary:
	return DB.enemy_stats(enemy_id, level)


func xp_to_next(level: int) -> int:
	return DB.xp_to_next(level)


func element_mult(elem: String, def_elem: String, weak: Array = [], resist: Array = []) -> float:
	return DB.element_mult(elem, def_elem, weak, resist)


func is_cheese(id: String) -> bool:
	return DB.is_cheese(id)


func match_recipe(ingredients: Array) -> String:
	return DB.match_recipe(ingredients)


func cook_quality(recipe_id: String, ingredients: Array, stir: float, cook_char: String = "", boost: bool = false) -> int:
	return DB.cook_quality(recipe_id, ingredients, stir, cook_char, boost)


func pairing_bonus(recipe_id: String, ingredients: Array) -> int:
	return DB.pairing_bonus(recipe_id, ingredients)


func dish_effect(dish_id: String, quality: int) -> Dictionary:
	return DB.dish_effect(dish_id, quality)
