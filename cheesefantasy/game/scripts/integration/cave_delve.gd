class_name CaveDelve
extends CanvasLayer
## The cheese cave, the Mold Dragon's lair and the Rat Throne as a floor-by-floor descent
## (the farm scene has no dungeon geometry). Floor progress persists in GameState flag `cave_floor`.
## Shows the floor's monster on a ModelStage (auto-framed, so the 3.3 m Rat King fits).

signal left
signal ending_requested

const FLOORS: Array = [
	{"name": "Cave Mouth", "enc": "cave_mouth_blobs", "model": "enemy_mold_blob", "music": "cave",
		"text": "Cool, stinky air. Blue-green rot creeps along the first racks of aging wheels."},
	{"name": "The Aging Racks", "enc": "cave_golems", "model": "enemy_wheel_golem", "music": "cave",
		"text": "Endless racks of wheels, each older than the farmer. Some of them are looking back."},
	{"name": "The Deep Cellar", "enc": "cave_mixed", "model": "enemy_wheel_golem", "music": "cave",
		"text": "The rot is humming now. Something enormous breathes in the dark below."},
	{"name": "The Mold Dragon's Lair", "enc": "boss_mold_dragon", "model": "boss_mold_dragon", "music": "rot", "boss": true,
		"text": "A dragon of living blue mould coils around a stolen cheese vault."},
	{"name": "The Rat Throne Approach", "enc": "king_guard", "model": "enemy_rat_grunt", "music": "throne",
		"text": "Up a ramp of gnawed rinds. The old dairy's gates hang open. Royal guards stand ready."},
	{"name": "The Rat Throne", "enc": "boss_rat_king", "model": "boss_rat_king", "music": "throne", "boss": true,
		"text": "Rat King Gorgonzolo lounges on a throne of stolen rinds, the Last Wheel behind him."},
]

var _root: Control
var _box: VBoxContainer
var _stage: ModelStage
var _fighting: String = ""
var _busy_modal: IntegModal = null


static func floor_index() -> int:
	return clampi(int(GameState.flag("cave_floor", 0)), 0, FLOORS.size() - 1)


func _ready() -> void:
	layer = 42
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = MenuStyle.theme()
	add_child(_root)
	var bg: TextureRect = TextureRect.new()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(0.05, 0.07, 0.09), Color(0.1, 0.16, 0.2), Color(0.03, 0.03, 0.05)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0)
	gt.fill_to = Vector2(0.5, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(bg)
	var m: MarginContainer = MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 48)
	_root.add_child(m)
	var h: HBoxContainer = MenuStyle.hbox(30)
	m.add_child(h)
	_box = MenuStyle.vbox(14)
	_box.custom_minimum_size = Vector2(700, 0)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_box)
	_stage = ModelStage.new()
	_stage.custom_minimum_size = Vector2(760, 760)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.spin = 0.35
	h.add_child(_stage)
	Events.battle_finished.connect(_on_battle_finished)
	Events.battle_requested.connect(_on_battle_requested)
	_show_floor()


func _show_floor() -> void:
	for c: Node in _box.get_children():
		c.queue_free()
	var idx: int = floor_index()
	var f: Dictionary = FLOORS[idx]
	Audio.play_music(str(f.music))
	GameState.area = "rat_throne" if idx >= 4 else "cheese_cave"
	_box.add_child(MenuStyle.label("Cheese Cave  -  Floor %d / %d" % [idx + 1, FLOORS.size()], 22, MenuStyle.DIM))
	_box.add_child(MenuStyle.label(str(f.name), 44, MenuStyle.GOLD))
	_box.add_child(MenuStyle.label(str(f.text), 24, MenuStyle.INK, true))
	var enc: Dictionary = Data.ENCOUNTERS.get(str(f.enc), {})
	var lvl: int = int(enc.get("level", 1))
	var pl: int = Story.party_level()
	var warn: String = "Party level %d.  Enemy level %d." % [pl, lvl]
	if pl + 3 < lvl:
		warn += "  You may want to train or cook first."
	_box.add_child(MenuStyle.label(warn, 20, MenuStyle.BAD if pl + 3 < lvl else MenuStyle.GOOD, true))
	var b1: Button = MenuStyle.button("Face the boss" if f.get("boss", false) else "Press on", 420)
	b1.pressed.connect(_fight)
	_box.add_child(b1)
	var b2: Button = MenuStyle.button("Rest and eat (restore the party)", 420)
	b2.pressed.connect(_rest)
	_box.add_child(b2)
	var b3: Button = MenuStyle.button("Cook something", 420)
	b3.pressed.connect(func() -> void: Director.open_cooking("field"))
	_box.add_child(b3)
	var b4: Button = MenuStyle.button("Leave the cave", 420)
	b4.pressed.connect(leave)
	_box.add_child(b4)
	b1.grab_focus.call_deferred()
	if ActorFactory.has_model(str(f.model)):
		_stage.visible = true
		_stage.show_model(str(f.model))
	else:
		_stage.visible = false


func _fight() -> void:
	var f: Dictionary = FLOORS[floor_index()]
	_fighting = str(f.enc)
	Events.battle_requested.emit(_fighting)


func _rest() -> void:
	GameState.heal_all()
	Audio.play_sfx("heal")
	Events.party_changed.emit()
	Events.toast.emit("The party rests among the cheese racks and recovers.")


func leave() -> void:
	left.emit()
	queue_free()


func _on_battle_requested(_e: String) -> void:
	if _fighting != "":
		_root.visible = false


func _on_battle_finished(result: Dictionary) -> void:
	if _fighting == "":
		return
	var won: bool = bool(result.get("won", false))
	var was: String = _fighting
	_fighting = ""
	_root.visible = true
	if won and was == str(FLOORS[floor_index()].enc):
		var nxt: int = int(GameState.flag("cave_floor", 0)) + 1
		GameState.set_flag("cave_floor", nxt)
		if nxt >= FLOORS.size():
			GameState.set_flag("cave_floor", FLOORS.size() - 1)
			ending_requested.emit()
			queue_free()
			return
	call_deferred("_show_floor")
