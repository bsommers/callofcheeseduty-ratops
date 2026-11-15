class_name CookingLogic
extends RefCounted
## Pure cooking logic (headless-testable): recipe matching, stir scoring, quality tiers.
## Works on plain dictionaries so it can run without the autoloads (pass recipes/ingredients in).

const TIER_NAMES: Array[String] = ["Burnt", "Plain", "Tasty", "Gourmet"]
const TIER_MULT: Array[float] = [0.5, 1.0, 1.35, 1.75]
const TIER_COLORS: Array[Color] = [Color(0.35, 0.27, 0.22), Color(0.85, 0.8, 0.65), Color(1.0, 0.8, 0.25), Color(1.0, 0.55, 0.9)]
const MUSH := "mystery_mush"
const MAX_SLOTS := 3

static func _has_tag(ingredients: Dictionary, id: String, tag: String) -> bool:
	var ing: Dictionary = ingredients.get(id, {})
	return tag in ing.get("tags", [])

## Score how well one slot spec accepts ingredient id: 3 exact, 2 tag, 1 cheese, 0 no.
static func slot_score(spec: String, id: String, ingredients: Dictionary) -> int:
	if spec == id:
		return 3
	if spec.begins_with("tag:") and _has_tag(ingredients, id, spec.substr(4)):
		return 2
	if spec == "cheese" and _has_tag(ingredients, id, "cheese"):
		return 1
	return 0

## Best assignment of picked ids to recipe slots; returns total score, or -1 if no match.
static func recipe_score(recipe: Dictionary, picked: Array, ingredients: Dictionary) -> int:
	var slots: Array = recipe.get("slots", [])
	if slots.size() != picked.size() or slots.is_empty():
		return -1
	return _assign(slots, picked, 0, [], ingredients)

static func _assign(slots: Array, picked: Array, i: int, used: Array, ingredients: Dictionary) -> int:
	if i >= slots.size():
		return 0
	var best := -1
	for j in picked.size():
		if j in used:
			continue
		var s := slot_score(String(slots[i]), String(picked[j]), ingredients)
		if s == 0:
			continue
		var rest := _assign(slots, picked, i + 1, used + [j], ingredients)
		if rest >= 0 and s + rest > best:
			best = s + rest
	return best

## Returns the matching recipe id, or "" when nothing matches.
static func match_recipe(picked: Array, recipes: Dictionary, ingredients: Dictionary) -> String:
	var best_id := ""
	var best := -1
	var ids: Array = recipes.keys()
	ids.sort()
	for rid in ids:
		var sc := recipe_score(recipes[rid], picked, ingredients)
		if sc > best:
			best = sc
			best_id = String(rid)
	return best_id

## Pairing bonus 0/1: the recipe's perfect cheese is used, or all picked flavours are distinct (balanced).
static func pairing_bonus(recipe: Dictionary, picked: Array, ingredients: Dictionary) -> int:
	var pair := String(recipe.get("pair", ""))
	if pair != "" and pair in picked:
		return 1
	var seen: Dictionary = {}
	for id in picked:
		var f := String(ingredients.get(id, {}).get("flavor", ""))
		if f == "" or seen.has(f):
			return 0
		seen[f] = true
	return 1 if picked.size() >= 2 else 0

## Stir result 0..3 from accuracy values (each 0..1, one per beat). Average-based with a burn floor.
static func stir_tier(hits: Array) -> int:
	if hits.is_empty():
		return 1
	var total := 0.0
	var misses := 0
	for h in hits:
		total += float(h)
		if float(h) <= 0.0:
			misses += 1
	var avg := total / hits.size()
	if misses > hits.size() / 2.0 or avg < 0.25:
		return 0
	if avg >= 0.85 and misses == 0:
		return 3
	if avg >= 0.6:
		return 2
	return 1

static func final_tier(stir: int, bonus: int, role_bonus: int = 0, is_mush: bool = false) -> int:
	if is_mush:
		return 0 if stir == 0 else 1
	return clampi(stir + bonus + role_bonus, 0, 3)

## Recipe ids whose slots could still be satisfied by the picked ingredients (for hints).
static func could_complete(recipe: Dictionary, picked: Array, ingredients: Dictionary) -> bool:
	var slots: Array = recipe.get("slots", [])
	if picked.size() > slots.size():
		return false
	for p in picked:
		var ok := false
		for s in slots:
			if slot_score(String(s), String(p), ingredients) > 0:
				ok = true
				break
		if not ok:
			return false
	return true
