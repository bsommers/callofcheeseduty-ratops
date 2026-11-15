class_name WorldPoint
extends WorldInteractable
## Non-character interaction point: campfire (save), cauldron (cook), shrine, cave mouth, signpost.
## kind: "campfire" | "cauldron" | "shrine" | "cave" | "sign" | "chest"

signal triggered(kind: String, point_id: String)

@export var kind: String = "sign"
@export var point_id: String = ""
@export var text: String = ""
@export var flag_once: String = ""
@export var gives_item: String = ""

func _ready() -> void:
	match kind:
		"campfire": prompt = "Rest at the campfire (save)"
		"cauldron": prompt = "Cook at the cauldron"
		"shrine": prompt = "Pray at the Rainbow Orchard shrine"
		"cave": prompt = "Enter the Cheese Cave"
		"chest": prompt = "Open"
		_: prompt = "Read"

func interact(player: Node3D) -> void:
	if kind == "chest" and flag_once != "":
		if WorldBus.get_flag(flag_once, false):
			WorldBus.toast("It's empty. Just crumbs.")
			return
		WorldBus.set_flag(flag_once, true)
		if gives_item != "":
			WorldBus.give_item(gives_item, 1)
			WorldBus.toast("Found %s!" % gives_item.replace("_", " "))
	var sig_name := &""
	match kind:
		"campfire": sig_name = &"save_requested"
		"cauldron": sig_name = &"cook_requested"
		"shrine": sig_name = &"shrine_requested"
		"cave": sig_name = &"area_entered"
	triggered.emit(kind, point_id)
	var farm := get_tree().get_first_node_in_group("farm")
	if farm != null and farm.has_signal("interaction_triggered"):
		farm.emit_signal("interaction_triggered", kind, point_id)
	if sig_name == &"area_entered":
		WorldBus.emit(&"area_entered", [point_id if point_id != "" else "cheese_cave"])
		WorldBus.toast(text if text != "" else "The cave mouth breathes cool, stinky air...")
	elif sig_name != &"" and WorldBus.has_signal_on_events(sig_name):
		WorldBus.emit(sig_name, [point_id])
	else:
		var st := WorldBus.autoload("GameState")
		if kind == "campfire" and st != null and st.has_method("save_game"):
			st.call("save_game", 0)
			WorldBus.toast("Game saved. Toasty!")
		elif text != "" and kind != "sign":
			WorldBus.toast(text)
		elif kind == "campfire":
			WorldBus.toast("The fire crackles. (Save UI pending.)")
		elif kind == "cauldron":
			WorldBus.toast("The cauldron bubbles. (Cooking UI pending.)")
		elif kind == "shrine":
			WorldBus.toast("The shrine hums softly. (Summon UI pending.)")
	if kind == "sign" and text != "":
		var box := get_tree().get_first_node_in_group("dialogue_box")
		if box != null and box.has_method("say"):
			box.call("say", "Signpost", text)
