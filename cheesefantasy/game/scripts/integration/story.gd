class_name Story
extends Node
## Story layer (owner integ-lead): main quest line, shrine memory quests, extra interaction points on the farm.
## Child of the Director autoload. Talks to the world only through the farm's `interaction_triggered`
## signal, Events and GameState; extra WorldPoints are added to the farm at runtime.

const MAIN: String = "main_last_wheel"
const MARKER_COLOR: Color = Color(1.0, 0.85, 0.3)

## Memory quest steps: quest -> stage -> {pid, pos (x,z), label, text, need, battle, give, next}
const STEPS: Dictionary = {
	"memory_jesse": {
		1: {"pid": "windowsill", "pos": Vector2(-16, 11), "label": "Look at the windowsill",
			"text": "A sunny windowsill with a cat-shaped dent in the cushion. A gray hair clings to it. You can almost hear a purr.", "next": 2},
	},
	"memory_tripper": {
		0: {"pid": "barn_loft", "pos": Vector2(22, 9), "label": "Search the barn loft",
			"text": "Behind a hay bale you find a tiny, tarnished collar with a bell. Tripper's. Something rustles in the straw...", "next": 1},
		1: {"pid": "hay_rats", "pos": Vector2(27, 4), "label": "Chase off the rats", "battle": "barn_sappers",
			"text": "Rats! Right in Tripper's favourite hay!", "next": 2},
	},
	"memory_samantha": {
		0: {"pid": "frozen_pool", "pos": Vector2(7, -57), "label": "Offer warm cocoa", "need": "warm_cocoa",
			"text": "You set the cocoa by the frozen pool. The ice sings. A little snow swirls up and settles on your nose.",
			"fail": "The frozen pool glints. Samantha always loved something warm to drink... (bring Warm Cocoa)", "next": 1},
		1: {"pid": "white_feather", "pos": Vector2(28, -27), "label": "Pick up the white feather",
			"text": "A single white feather, cold as the first snow, caught in the reeds by the pond.", "next": 2},
	},
	"memory_spooky": {
		0: {"pid": "fence_post", "pos": Vector2(-40, 45), "label": "Walk the fence line",
			"text": "You walk the southern fence line as the light fades. Two green lights blink far to the west.", "next": 1},
		1: {"pid": "green_eyes", "pos": Vector2(-62, 46), "label": "Follow the green eyes", "battle": "orchard_weasels",
			"text": "The green eyes belong to a weasel with a stolen ball of yarn!", "give": "memory_yarn", "next": 2},
	},
}

var farm: Node = null
var _points: Array[Node] = []
var _pending: Dictionary = {}


func _ready() -> void:
	Events.battle_finished.connect(_on_battle_finished)
	Events.dialogue_finished.connect(_on_dialogue_finished)
	Events.game_loaded.connect(func(_s: int) -> void: sync_main())
	Events.quest_updated.connect(func(_q: String, _s: Variant) -> void: refresh_points())
	Events.item_gained.connect(func(_i: String, _c: int) -> void: refresh_points())


func bind_farm(f: Node) -> void:
	farm = f
	_points.clear()
	if f.has_signal("interaction_triggered"):
		f.connect("interaction_triggered", _on_interaction)
	sync_main()
	refresh_points()


# ---------------------------------------------------------------- quest helpers
static func qstage(id: String) -> int:
	var v: Variant = GameState.quest_state(id)
	if str(v) == "done":
		return 99
	return int(v)


## Quest stages are stored as strings: GameState.set_quest compares the stored value to "done" and errors on ints.
static func setq(id: String, stage: Variant) -> void:
	if GameState.quests.has(id):
		GameState.quests[id] = str(GameState.quests[id])
	GameState.set_quest(id, str(stage))


static func party_level() -> int:
	var tot: int = 0
	var n: int = 0
	for cid: Variant in GameState.active:
		tot += int(GameState.party.get(cid, {}).get("level", 1))
		n += 1
	return tot / maxi(n, 1)


func sync_main() -> void:
	if bool(GameState.flag("quest_started", false)) and qstage(MAIN) < 1:
		Story.setq(MAIN, 1)
		Events.toast.emit("Quest: The Last Wheel - %s" % Data.QUESTS[MAIN].stages[1])


func _on_dialogue_finished(_npc: String) -> void:
	sync_main()


# ---------------------------------------------------------------- points
func refresh_points() -> void:
	if farm == null or not is_instance_valid(farm) or farm.get("terrain") == null:
		return
	for p: Node in _points:
		if is_instance_valid(p):
			p.queue_free()
	_points.clear()
	if bool(GameState.flag("quest_started", false)) and not GameState.flag("beat_crow_baron", false):
		_add_point("silo", "silo_door", Vector2(22, -3), "Knock on the silo door", false)
	for q: String in STEPS:
		var st: int = qstage(q)
		if st >= 0 and st < 99 and STEPS[q].has(st):
			var s: Dictionary = STEPS[q][st]
			_add_point("memory", q + ":" + str(s.pid), s.pos, str(s.label), true)


func _add_point(kind: String, pid: String, pos: Vector2, label: String, marker: bool) -> void:
	var t: Object = farm.get("terrain")
	var p: WorldPoint = WorldPoint.new()
	p.kind = kind
	p.point_id = pid
	p.position = Vector3(pos.x, t.call("height_at", pos.x, pos.y), pos.y)
	p.name = "StoryPoint_" + pid.replace(":", "_")
	farm.add_child(p)
	p.prompt = label
	if marker:
		var m: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		m.mesh = sm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = MARKER_COLOR
		mat.emission_enabled = true
		mat.emission = MARKER_COLOR
		mat.emission_energy_multiplier = 2.5
		m.material_override = mat
		m.position = Vector3(0, 1.1, 0)
		p.add_child(m)
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = MARKER_COLOR
		l.omni_range = 4.0
		l.position = Vector3(0, 1.2, 0)
		p.add_child(l)
	_points.append(p)


func _say(speaker: String, text: String) -> void:
	var box: Node = get_tree().get_first_node_in_group("dialogue_box")
	if box != null and box.has_method("say"):
		box.call("say", speaker, text)
	else:
		Events.toast.emit(text)


# ---------------------------------------------------------------- interactions
func _on_interaction(kind: String, pid: String) -> void:
	match kind:
		"silo":
			if not bool(GameState.flag("quest_started", false)):
				_say("Silo", "The door is barred from the inside. Maybe Farmer Gouda knows what is going on.")
			else:
				_say("Silo", "Caw! Caw-caw-CAW!  (The Crow Baron has heard you knocking.)")
				_pending = {"fight": "boss_crow_baron"}
				Events.dialogue_finished.connect(_fight_after_dialogue, CONNECT_ONE_SHOT)
		"memory":
			_memory_point(pid)
		"cave":
			if not GameState.has_item("cave_key"):
				Events.toast.emit("Sealed by rubble. Maybe the silo crows know a way in.")
			else:
				Director.open_cave()


func _fight_after_dialogue(_n: String) -> void:
	var enc: String = str(_pending.get("fight", ""))
	_pending.erase("fight")
	if enc != "":
		Events.battle_requested.emit(enc)


func _memory_point(pid: String) -> void:
	var parts: PackedStringArray = pid.split(":")
	var q: String = parts[0]
	var st: int = qstage(q)
	if not STEPS.has(q) or not STEPS[q].has(st):
		return
	var s: Dictionary = STEPS[q][st]
	if s.has("need") and not GameState.has_item(str(s.need)):
		_say("Memory", str(s.get("fail", "You need something for this.")))
		return
	if s.has("need"):
		GameState.remove_item(str(s.need), 1)
	_say("Memory", str(s.text))
	if s.has("battle"):
		_pending = {"quest": q, "next": int(s.next), "give": str(s.get("give", "")), "enc": WorldBus.resolve_encounter(str(s.battle))}
		Events.dialogue_finished.connect(_battle_after_dialogue, CONNECT_ONE_SHOT)
	else:
		advance_memory(q, int(s.next), str(s.get("give", "")))


func _battle_after_dialogue(_n: String) -> void:
	if _pending.has("enc"):
		Events.battle_requested.emit(str(_pending.enc))


func advance_memory(q: String, to_stage: int, give: String = "") -> void:
	if give != "":
		GameState.add_item(give, 1)
	Story.setq(q, to_stage)
	Audio.play_sfx("ui_confirm")
	if to_stage >= 2:
		Events.toast.emit("%s - return to the Rainbow Orchard shrine." % str(Data.QUESTS[q].name))
	else:
		Events.toast.emit("%s - %s" % [str(Data.QUESTS[q].name), str(Data.QUESTS[q].stages[to_stage])])


func _on_battle_finished(result: Dictionary) -> void:
	var enc: String = str(result.get("encounter", ""))
	var won: bool = bool(result.get("won", false))
	if _pending.has("quest") and enc == str(_pending.get("enc", "")):
		if won:
			advance_memory(str(_pending.quest), int(_pending.next), str(_pending.get("give", "")))
		_pending.clear()
		return
	if not won:
		return
	match enc:
		"boss_crow_baron":
			GameState.add_item("cave_key", 1)
			Story.setq(MAIN, 2)
			Events.toast.emit("Got the Cave Key! The cheese cave is open. (Samantha, Jesse, Tripper and Spooky await at the shrine.)")
			refresh_points()
		"boss_mold_dragon":
			Story.setq(MAIN, 4)
		"boss_rat_king":
			GameState.set_flag("beat_rat_king", true)
