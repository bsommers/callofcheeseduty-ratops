extends Node
## Events autoload (owner rpg-core): global signal bus. Emit/connect here instead of referencing other modules.

@warning_ignore_start("unused_signal")
signal battle_requested(encounter_id: String)
signal battle_finished(result: Dictionary)  ## {won, fled, xp, gold, drops: Array[String], encounter, party: Array}
signal dialogue_started(npc_id: String)
signal dialogue_finished(npc_id: String)
signal item_gained(id: String, count: int)
signal recipe_learned(id: String)
signal quest_updated(id: String, state: Variant)
signal summon_unlocked(id: String)
signal area_entered(id: String)
signal gold_changed(gold: int)
signal party_changed()
signal toast(text: String)
signal level_up(char_id: String, level: int)
signal game_loaded(slot: int)
signal game_saved(slot: int)
@warning_ignore_restore("unused_signal")
