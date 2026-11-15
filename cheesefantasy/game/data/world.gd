extends RefCounted
## Summons, encounters, shops, quests, areas (owner rpg-core). Re-exported by Data.
##
## SUMMONS fields: name, title, cat (description), element, element2, model, color, power, target, effect keys
##   (status_party {id,turns}, heal_pct, revive, cure_all, ignore_def), cost (gauge, default 100), unlock_quest, intro, desc.
## ENCOUNTERS fields: name, area, enemies (Array of enemy ids, max 5), level (recommended party level; enemies scale to
##   max(enemy base level, level)), boss (bool), can_flee, bg (backdrop id for battle scene), music, weight (random table),
##   bonus_xp / bonus_gold, flag (GameState flag set on win, bosses).
## SHOPS: name, keeper (npc id), area, stock [ids], buy_mult, sell_mult, unlock {flag: stock ids}.
## QUESTS: name, giver, area, stages [text...], reward {gold, xp, items {id: n}, recipe, summon}, kind (main|memory|side).
## AREAS: name, kind (hub|field|dungeon|shrine), encounters [ids] (random table for tall grass), music, desc.

const SUMMONS: Dictionary = {
	"jesse": {"name": "Jesse", "title": "Silver Stalker", "cat": "gray cat", "element": "wind", "element2": "ice",
		"model": "summon_jesse", "color": Color(0.75, 0.8, 0.9), "power": 260, "target": "all_enemies",
		"status_party": {"id": "aerated", "turns": 3}, "attack": "Misty Pounce", "cost": 100, "unlock_quest": "memory_jesse",
		"intro": "A gray shape drifts out of the morning mist, silent as a held breath.",
		"desc": "Misty Pounce: a gale of icy wind on all enemies; party gains Aerated (evade up)."},
	"tripper": {"name": "Tripper", "title": "Stripe Quake", "cat": "American tabby, brown with black stripes", "element": "earth", "element2": "",
		"model": "summon_tripper", "color": Color(0.6, 0.45, 0.3), "power": 340, "target": "all_enemies",
		"status_party": {"id": "rinded", "turns": 3}, "attack": "Tabby Tremor", "cost": 100, "unlock_quest": "memory_tripper",
		"intro": "The ground purrs. Then it ROARS.",
		"desc": "Tabby Tremor: heavy earth damage to all enemies; party gains Rinded (defence up)."},
	"samantha": {"name": "Samantha", "title": "Snow Angel", "cat": "white cat", "element": "light", "element2": "ice",
		"model": "summon_samantha", "color": Color(0.95, 0.97, 1.0), "power": 0, "target": "all_allies",
		"heal_pct": 1.0, "revive": 1.0, "cure_all": true, "attack": "Halo Lick", "cost": 100, "unlock_quest": "memory_samantha",
		"intro": "Snow falls upward. A white cat with a halo of frost settles over the party.",
		"desc": "Halo Lick: fully heals and revives the party and cleanses every status."},
	"spooky": {"name": "Spooky", "title": "Midnight Walker", "cat": "black cat", "element": "shade", "element2": "",
		"model": "summon_spooky", "color": Color(0.15, 0.1, 0.25), "power": 620, "target": "enemy",
		"ignore_def": true, "attack": "Eclipse Claw", "cost": 100, "unlock_quest": "memory_spooky",
		"intro": "The lanterns gutter. Two green eyes open where the moon used to be.",
		"desc": "Eclipse Claw: massive single-target shade damage that ignores defence."},
}

const ENCOUNTERS: Dictionary = {
	# ------------------------------------------------------- crop fields / meadow (lv 1-4)
	"meadow_grunts": {"name": "Grunt Patrol", "area": "crop_fields", "enemies": ["rat_grunt", "rat_grunt"], "level": 1, "bg": "fields", "weight": 5},
	"meadow_pair": {"name": "Rat and Crow", "area": "crop_fields", "enemies": ["rat_grunt", "crow"], "level": 2, "bg": "fields", "weight": 4},
	"crop_crows": {"name": "Crow Swarm", "area": "crop_fields", "enemies": ["crow", "crow", "crow"], "level": 2, "bg": "fields", "weight": 3},
	"crop_mixed": {"name": "Field Raiders", "area": "crop_fields", "enemies": ["rat_grunt", "rat_sapper", "crow"], "level": 2, "bg": "fields", "weight": 3},
	"scarecrow_patch": {"name": "The Wrong Scarecrow", "area": "crop_fields", "enemies": ["moldy_scarecrow", "crow"], "level": 8, "bg": "fields", "weight": 1},
	# ------------------------------------------------------- coop / pond / orchard (lv 3-8)
	"coop_raid": {"name": "Coop Raid", "area": "coop", "enemies": ["weasel", "rat_grunt"], "level": 3, "bg": "coop", "weight": 3},
	"pond_blobs": {"name": "Pond Scum", "area": "pond", "enemies": ["mold_blob", "curd_slime"], "level": 3, "bg": "pond", "weight": 3},
	"orchard_magpies": {"name": "Shiny Thieves", "area": "orchard", "enemies": ["magpie_thief", "crow_scout"], "level": 6, "bg": "orchard", "weight": 3},
	"orchard_weasels": {"name": "Weasel Gang", "area": "orchard", "enemies": ["weasel", "weasel_bandit"], "level": 7, "bg": "orchard", "weight": 2},
	# ------------------------------------------------------- pasture / barn (lv 5-10)
	"pasture_rats": {"name": "Pasture Pests", "area": "pasture", "enemies": ["rat_grunt", "rat_slinger"], "level": 4, "bg": "pasture", "weight": 4},
	"pasture_mixed": {"name": "Hoof and Claw", "area": "pasture", "enemies": ["rat_brute", "fuzzy_spore"], "level": 7, "bg": "pasture", "weight": 3},
	"barn_sappers": {"name": "Barn Burners", "area": "barnyard", "enemies": ["rat_sapper", "rat_grunt"], "level": 5, "bg": "barn", "weight": 3},
	"barn_mixed": {"name": "Barnyard Brawl", "area": "barnyard", "enemies": ["rat_brute", "rat_shaman", "rot_beetle"], "level": 9, "bg": "barn", "weight": 2},
	# ------------------------------------------------------- silo / windmill (lv 9-14)
	"silo_crows": {"name": "Silo Lookouts", "area": "silo", "enemies": ["crow_scout", "crow_scout", "crow"], "level": 8, "bg": "silo", "weight": 3},
	"silo_ravens": {"name": "Raven Coven", "area": "silo", "enemies": ["raven_hexer", "crow_scout"], "level": 11, "bg": "silo", "weight": 2},
	"windmill_weasels": {"name": "Windmill Bandits", "area": "windmill", "enemies": ["weasel_bandit", "ferret_rogue"], "level": 12, "bg": "windmill", "weight": 2},
	# ------------------------------------------------------- cheese cave (lv 10-17)
	"cave_mouth_blobs": {"name": "Cave Mouth Rot", "area": "cheese_cave", "enemies": ["blue_rot_blob", "mold_blob", "fuzzy_spore"], "level": 10, "bg": "cave", "weight": 3},
	"cave_golems": {"name": "Wheel Guardians", "area": "cheese_cave", "enemies": ["wheel_golem", "curd_slime"], "level": 12, "bg": "cave", "weight": 2},
	"cave_spiders": {"name": "Cellar Webs", "area": "cheese_cave", "enemies": ["cellar_spider", "rind_tick"], "level": 14, "bg": "cave", "weight": 2},
	"cave_mixed": {"name": "Deep Cellar", "area": "cheese_cave", "enemies": ["rotten_wheel_golem", "curd_slime", "rot_toadstool"], "level": 16, "bg": "cave", "weight": 2},
	# ------------------------------------------------------- rot fields / hill / throne (lv 17-26)
	"rot_fields_spores": {"name": "Spore Bloom", "area": "rot_fields", "enemies": ["rot_toadstool", "fuzzy_spore", "fuzzy_spore", "blue_rot_blob"], "level": 18, "bg": "rot", "weight": 3},
	"rot_fields_mixed": {"name": "Blight Patrol", "area": "rot_fields", "enemies": ["rat_captain", "rat_shaman", "rotten_wheel_golem"], "level": 20, "bg": "rot", "weight": 2},
	"hill_ninjas": {"name": "Stoat Ambush", "area": "rot_fields", "enemies": ["stoat_ninja", "ferret_rogue"], "level": 20, "bg": "rot", "weight": 2},
	"cellar_ticks": {"name": "Tick Swarm", "area": "cheese_cave", "enemies": ["rind_tick", "rind_tick", "cellar_spider"], "level": 17, "bg": "cave", "weight": 2},
	"king_guard": {"name": "Royal Guard", "area": "rat_throne", "enemies": ["rat_captain", "rat_brute", "rat_shaman"], "level": 24, "bg": "throne", "weight": 1},
	# ------------------------------------------------------- bosses
	"boss_crow_baron": {"name": "The Crow Baron", "area": "silo", "enemies": ["crow_baron", "crow", "crow"], "level": 9, "boss": true,
		"can_flee": false, "bg": "silo", "music": "boss", "flag": "beat_crow_baron", "bonus_gold": 300},
	"boss_mold_dragon": {"name": "The Mold Dragon", "area": "cheese_cave", "enemies": ["mold_dragon"], "level": 17, "boss": true,
		"can_flee": false, "bg": "cave", "music": "boss", "flag": "beat_mold_dragon", "bonus_gold": 800},
	"boss_rat_king": {"name": "Rat King Gorgonzolo", "area": "rat_throne", "enemies": ["rat_king", "rat_captain"], "level": 24, "boss": true,
		"can_flee": false, "bg": "throne", "music": "final_boss", "flag": "beat_rat_king", "bonus_gold": 2000},
}

const SHOPS: Dictionary = {
	"cheesemonger_shop": {"name": "Curdlewick Cheesemonger", "keeper": "cheesemonger", "area": "farmhouse", "buy_mult": 1.0, "sell_mult": 0.5,
		"stock": ["cheddar", "brie_wheel", "swiss", "gouda", "curd", "wine", "olive", "milk_bottle", "smelling_salts", "ether_cheese"],
		"unlock": {"beat_crow_baron": ["parmesan", "blue_cheese", "cream_flask", "chef_ladle"], "beat_mold_dragon": ["truffle", "curd_elixir"]}},
	"cook_pantry": {"name": "Cook's Pantry", "keeper": "cook", "area": "farmhouse", "buy_mult": 1.0, "sell_mult": 0.5,
		"stock": ["milk", "cream", "butter", "egg", "wheat", "black_pepper", "sea_salt", "mozzarella", "fresh_bread", "warm_cocoa"],
		"unlock": {"beat_crow_baron": ["chili_pepper", "mushroom"]}},
	"tinker_wares": {"name": "Tinker's Wares", "keeper": "tinker", "area": "barnyard", "buy_mult": 1.0, "sell_mult": 0.5,
		"stock": ["throwing_pebble", "firecracker", "smoke_pellet", "defrost_mitten", "quilted_vest", "lucky_bell", "egg_scepter", "frost_tongs", "cast_iron_wok"],
		"unlock": {"beat_crow_baron": ["ice_cube", "pepper_spray", "chef_whites", "whisker_charm", "flambe_knife"],
			"beat_mold_dragon": ["rind_mail", "cyclone_whisk", "ancient_griddle", "ice_cellar_key_staff", "smoke_ring", "chill_pendant"],
			"beat_rat_king": ["wheel_plate"]}},
	"granny_stall": {"name": "Granny's Stall", "keeper": "granny", "area": "orchard", "buy_mult": 1.0, "sell_mult": 0.5,
		"stock": ["apple", "pear", "fig", "honey", "walnut", "thyme", "sage", "rosemary", "lavender", "herb_salve", "rot_cure", "whey_tonic"],
		"unlock": {"beat_mold_dragon": ["mega_salve", "catnip_tincture", "curd_amulet"]}},
}

const QUESTS: Dictionary = {
	"main_last_wheel": {"name": "The Last Wheel", "kind": "main", "giver": "farmer_gouda", "area": "farmhouse",
		"stages": ["The Last Wheel is gone! Ask around the farm.", "Drive the Crow Baron out of the silo.",
			"Take the Cave Key into the cheese cave.", "Defeat the Mold Dragon.", "Storm the Rat Throne.", "Bring the Last Wheel home."],
		"reward": {"gold": 5000, "xp": 0, "items": {}, "recipe": "gourmet_last_wheel_feast"}},
	"memory_jesse": {"name": "Memory: The Gray Mist", "kind": "memory", "giver": "shrine_whisper", "area": "rainbow_orchard",
		"stages": ["Ring the Shrine Bell at dawn.", "Find Jesse's favourite windowsill (the farmhouse).", "Return to the shrine."],
		"reward": {"gold": 0, "xp": 300, "items": {}, "summon": "jesse"}},
	"memory_tripper": {"name": "Memory: Stripes in the Hay", "kind": "memory", "giver": "shrine_whisper", "area": "rainbow_orchard",
		"stages": ["Search the barn loft for an old collar.", "Chase off the rats in the hay.", "Return to the shrine."],
		"reward": {"gold": 0, "xp": 500, "items": {}, "summon": "tripper"}},
	"memory_samantha": {"name": "Memory: First Snow", "kind": "memory", "giver": "shrine_whisper", "area": "rainbow_orchard",
		"stages": ["Bring warm cocoa to the cheese cave's frozen pool.", "Find the white feather.", "Return to the shrine."],
		"reward": {"gold": 0, "xp": 800, "items": {}, "summon": "samantha"}},
	"memory_spooky": {"name": "Memory: The Midnight Walk", "kind": "memory", "giver": "shrine_whisper", "area": "rainbow_orchard",
		"stages": ["Walk the fence line at night.", "Follow the green eyes.", "Return to the shrine with the Memory Yarn."],
		"reward": {"gold": 0, "xp": 1200, "items": {}, "summon": "spooky"}},
	"lost_chickens": {"name": "Lost Chickens", "kind": "side", "giver": "chicken_hen", "area": "coop",
		"stages": ["Find the 3 lost chicks around the farm.", "Return them to the coop."],
		"reward": {"gold": 150, "xp": 80, "items": {"egg": 6}, "recipe": "cheese_omelette"}},
	"scarecrow_hat": {"name": "A Hat for Hector", "kind": "side", "giver": "scarecrow", "area": "crop_fields",
		"stages": ["The crows stole the scarecrow's hat. Get it back from the Crow Swarm.", "Give the hat back."],
		"reward": {"gold": 200, "xp": 120, "items": {"lucky_bell": 1}}},
	"cook_recipe_book": {"name": "The Cook's Recipe Book", "kind": "side", "giver": "cook", "area": "farmhouse",
		"stages": ["A magpie stole the recipe book. Search the orchard.", "Return the book to the cook."],
		"reward": {"gold": 250, "xp": 200, "items": {"recipe_book": 1}, "recipe": "cheese_souffle"}},
	"pond_frog_cheese": {"name": "The Frog Who Wanted Cheese", "kind": "side", "giver": "duck_quackers", "area": "pond",
		"stages": ["Cook a Tasty (or better) Grilled Cheese.", "Bring it to the frog on the dock."],
		"reward": {"gold": 120, "xp": 150, "items": {"trout": 3}, "recipe": "smoked_trout_melt"}},
	"tinker_parts": {"name": "Tinker's Spare Parts", "kind": "side", "giver": "tinker", "area": "barnyard",
		"stages": ["Collect 5 Rat Badges from Rat Captains and patrols.", "Bring them to the tinker."],
		"reward": {"gold": 600, "xp": 400, "items": {"whisker_charm": 1}, "recipe": "rot_away_tonic"}},
}

const AREAS: Dictionary = {
	"farmhouse": {"name": "Farmhouse", "kind": "hub", "encounters": [], "music": "farm_day", "desc": "Kitchen, hearth, and Granny's rocking chair."},
	"barnyard": {"name": "Barnyard", "kind": "hub", "encounters": ["barn_sappers", "barn_mixed"], "music": "farm_day", "desc": "The big red barn and the tinker's bench."},
	"crop_fields": {"name": "Crop Fields", "kind": "field", "encounters": ["meadow_grunts", "meadow_pair", "crop_crows", "crop_mixed"], "music": "fields", "desc": "Corn, wheat, tomatoes, and too many rats."},
	"pasture": {"name": "Cow Pasture", "kind": "field", "encounters": ["pasture_rats", "pasture_mixed"], "music": "fields", "desc": "Bessie and Moolissa graze here, unbothered."},
	"coop": {"name": "Chicken Coop", "kind": "field", "encounters": ["coop_raid"], "music": "farm_day", "desc": "Madame Brie's old home. She does not miss it."},
	"pond": {"name": "Duck Pond", "kind": "field", "encounters": ["pond_blobs"], "music": "pond", "desc": "A dock, ducks, and a frog with opinions about cheese."},
	"orchard": {"name": "Orchard", "kind": "field", "encounters": ["orchard_magpies", "orchard_weasels"], "music": "orchard", "desc": "Apple and pear trees; Granny's stall."},
	"windmill": {"name": "Windmill Hill", "kind": "field", "encounters": ["windmill_weasels"], "music": "fields", "desc": "The sails still turn. Weasels nest in the gears."},
	"silo": {"name": "The Silo", "kind": "dungeon", "encounters": ["silo_crows", "silo_ravens"], "music": "silo", "desc": "The Crow Baron's tower of corn."},
	"rainbow_orchard": {"name": "Rainbow Orchard Shrine", "kind": "shrine", "encounters": [], "music": "shrine", "desc": "Where the old house cats rest. The light here is warm."},
	"cheese_cave": {"name": "Cheese Cave", "kind": "dungeon", "encounters": ["cave_mouth_blobs", "cave_golems", "cave_spiders", "cave_mixed", "cellar_ticks"], "music": "cave", "desc": "Endless racks of aging wheels. Something big sleeps below."},
	"rot_fields": {"name": "Rot Fields", "kind": "field", "encounters": ["rot_fields_spores", "rot_fields_mixed", "hill_ninjas"], "music": "rot", "desc": "Where the blight has taken the wheat. Blue-green and humming."},
	"rat_throne": {"name": "Rat Throne", "kind": "dungeon", "encounters": ["king_guard"], "music": "throne", "desc": "A throne of stolen rinds atop the old dairy."},
}
