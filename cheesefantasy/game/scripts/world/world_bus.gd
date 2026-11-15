class_name WorldBus
extends RefCounted
## Defensive glue between the overworld and the shared autoloads (Events, GameState, Data).
## Every call degrades to a no-op/local fallback when an autoload is missing.

static var locked: bool = false
static var _local_flags: Dictionary = {}

static func autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(autoload_name)

static func emit(sig: StringName, args: Array = []) -> void:
	var ev := autoload("Events")
	if ev != null and ev.has_signal(sig):
		ev.callv("emit_signal", [sig] + args)

static func listen(sig: StringName, c: Callable) -> void:
	var ev := autoload("Events")
	if ev != null and ev.has_signal(sig) and not ev.is_connected(sig, c):
		ev.connect(sig, c)

static func unlisten(sig: StringName, c: Callable) -> void:
	var ev := autoload("Events")
	if ev != null and ev.has_signal(sig) and ev.is_connected(sig, c):
		ev.disconnect(sig, c)

static func has_signal_on_events(sig: StringName) -> bool:
	var ev := autoload("Events")
	return ev != null and ev.has_signal(sig)

static func flags() -> Dictionary:
	var st := autoload("GameState")
	if st != null:
		var f: Variant = st.get("flags")
		if f is Dictionary:
			return f
	return _local_flags

static func get_flag(flag_name: String, default: Variant = false) -> Variant:
	return flags().get(flag_name, default)

static func set_flag(flag_name: String, value: Variant = true) -> void:
	flags()[flag_name] = value

static func set_quest(quest_id: String, state: String) -> void:
	var st := autoload("GameState")
	if st != null:
		if st.has_method("set_quest"):
			st.call("set_quest", quest_id, state)
			return
		var q: Variant = st.get("quests")
		if q is Dictionary:
			q[quest_id] = state
	flags()["quest_" + quest_id] = state
	emit(&"quest_updated", [quest_id, state])

static func quest_state(quest_id: String) -> String:
	var st := autoload("GameState")
	if st != null:
		var q: Variant = st.get("quests")
		if q is Dictionary and q.has(quest_id):
			return str(q[quest_id])
	return str(flags().get("quest_" + quest_id, ""))

static func give_item(item_id: String, count: int = 1) -> void:
	var st := autoload("GameState")
	if st != null and st.has_method("add_item"):
		st.call("add_item", item_id, count)
	elif st != null and st.get("inventory") is Dictionary:
		var inv: Dictionary = st.get("inventory")
		inv[item_id] = int(inv.get(item_id, 0)) + count
	emit(&"item_gained", [item_id, count])

static func give_gold(amount: int) -> void:
	var st := autoload("GameState")
	if st != null and st.has_method("add_gold"):
		st.call("add_gold", amount)
	elif st != null and st.get("gold") != null:
		st.set("gold", int(st.get("gold")) + amount)
		emit(&"gold_changed", [int(st.get("gold"))])
	else:
		emit(&"gold_changed", [amount])

static func toast(text: String) -> void:
	emit(&"toast", [text])

## Pick a valid encounter id (falls back to any known encounter so battles always start).
static func resolve_encounter(wanted: String) -> String:
	var d := autoload("Data")
	if d != null:
		var enc: Variant = d.get("ENCOUNTERS")
		if enc is Dictionary and not enc.is_empty() and not enc.has(wanted):
			for k in enc.keys():
				if str(k).begins_with("farm") or str(k).begins_with("rat"):
					return str(k)
			return str(enc.keys()[0])
	return wanted
