extends RefCounted
## Party members (owner rpg-core). Re-exported as Data.CHARACTERS.
## growth[stat] = [base, per_level, curve]; stat(L) = round(base + per_level*(L-1) + curve*(L-1)^2)  (see Data.char_stats).
## learn: {level: [skill ids]} - learned on reaching that level. equip: starting gear (Data.ITEMS ids).

const MAX_LEVEL: int = 30

const CHARACTERS: Dictionary = {
	"fennel": {
		"name": "Fennel", "title": "Apprentice Cheesemonger", "species": "ginger tabby kitten",
		"element": "fire", "role": "Hero / damage", "cook_role": "Saucier (fire dishes +1 tier on Tasty+)",
		"model": "hero_fennel", "color": Color(0.95, 0.55, 0.2), "weak": ["ice"], "resist": ["fire"],
		"growth": {"hp": [62, 14.0, 0.22], "mp": [16, 2.0, 0.03], "atk": [14, 2.5, 0.03], "def": [9, 1.6, 0.02],
			"mag": [11, 2.1, 0.025], "res": [8, 1.5, 0.02], "spd": [13, 1.0, 0.01], "lck": [10, 0.7, 0.0]},
		"learn": {1: ["melt_slash", "taste_test"], 3: ["raclette_blaze"], 6: ["mise_en_place"], 8: ["fondue_flare"],
			11: ["toasty_aura"], 14: ["welsh_rarebit_rain"], 18: ["second_helping"], 22: ["grilled_cheese_inferno"], 27: ["flambe_finale"]},
		"equip": {"weapon": "cheese_knife", "armor": "farm_apron", "charm": ""},
		"bio": "Ginger, small, absolutely certain he can cook anything. Usually right. Occasionally on fire.",
	},
	"brie": {
		"name": "Madame Brie", "title": "Grand Hen Wizard", "species": "speckled hen",
		"element": "wind", "role": "Healer / buffer", "cook_role": "Pâtissière (egg dishes always at least Tasty)",
		"model": "hero_brie", "color": Color(0.85, 0.8, 0.7), "weak": ["earth"], "resist": ["wind"],
		"growth": {"hp": [52, 11.0, 0.18], "mp": [26, 3.2, 0.05], "atk": [8, 1.4, 0.015], "def": [8, 1.4, 0.015],
			"mag": [14, 2.5, 0.03], "res": [12, 2.0, 0.025], "spd": [10, 0.8, 0.01], "lck": [12, 0.8, 0.0]},
		"learn": {1: ["omelette_mend", "whey_whirl"], 4: ["curd_cure"], 6: ["smoked_breeze"], 9: ["swiss_gale"],
			12: ["herb_poultice"], 15: ["souffle_rise"], 18: ["feather_frenzy"], 21: ["chefs_kiss"], 24: ["holey_cyclone"], 28: ["sunny_side_up"]},
		"equip": {"weapon": "feather_wand", "armor": "farm_apron", "charm": ""},
		"bio": "Retired from the coop, never retired from opinions. Lays healing eggs with great dignity.",
	},
	"clover": {
		"name": "Clover", "title": "Skillet Knight", "species": "stout goat",
		"element": "earth", "role": "Tank", "cook_role": "Grill-master (cooking never Burnt)",
		"model": "hero_clover", "color": Color(0.6, 0.5, 0.4), "weak": ["fire"], "resist": ["earth", "rot"],
		"growth": {"hp": [78, 17.0, 0.28], "mp": [10, 1.3, 0.02], "atk": [13, 2.3, 0.028], "def": [13, 2.2, 0.03],
			"mag": [6, 1.0, 0.01], "res": [9, 1.6, 0.02], "spd": [8, 0.7, 0.008], "lck": [8, 0.5, 0.0]},
		"learn": {1: ["skillet_bash"], 4: ["stinky_stance"], 7: ["rind_wall"], 10: ["cheddar_crush"], 13: ["aged_bulwark"],
			17: ["parmesan_pound"], 21: ["gouda_quake"], 25: ["cast_iron_cover"]},
		"equip": {"weapon": "iron_skillet", "armor": "quilted_vest", "charm": ""},
		"bio": "Will eat the enemy's shield. Has, on occasion, eaten his own.",
	},
	"maple": {
		"name": "Maple", "title": "Cellar-Keeper", "species": "farmer's daughter",
		"element": "ice", "role": "Support / debuffer", "cook_role": "Affineur (aged dishes: +25% effect)",
		"model": "hero_maple", "color": Color(0.45, 0.65, 0.9), "weak": ["fire"], "resist": ["ice"],
		"growth": {"hp": [56, 12.0, 0.2], "mp": [22, 2.8, 0.04], "atk": [10, 1.8, 0.02], "def": [9, 1.5, 0.018],
			"mag": [13, 2.3, 0.028], "res": [11, 1.8, 0.022], "spd": [12, 0.95, 0.01], "lck": [11, 0.8, 0.0]},
		"learn": {1: ["chill_touch", "pinch_of_salt"], 3: ["brie_freeze"], 5: ["frost_rind"], 8: ["cellar_draft"],
			10: ["cave_frost"], 13: ["cold_storage"], 19: ["parmesan_blizzard"], 26: ["permafrost_wheel"]},
		"equip": {"weapon": "cellar_lantern", "armor": "farm_apron", "charm": ""},
		"bio": "Knows every wheel in the cave by name and age. Talks to them. They do not talk back. Mostly.",
	},
}

const PARTY_ORDER: Array = ["fennel", "brie", "clover", "maple"]
