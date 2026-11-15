class_name CookingUI
extends Control
## Kitchen / cauldron UI: pick up to 3 ingredients, stir-timing mini-game, cookbook with silhouettes.
## Usage: instance scenes/ui/cooking.tscn, add to tree, call open("field"|"battle", cook_char_id).
## Emits `finished(result)` ({ok, dish_id, tier, tier_name, mult, new_recipe, ingredients, mode}) and `closed`.
## In "battle" mode ingredients are consumed but the dish is NOT added to inventory (the battle applies it).
## In "field" mode the dish is added to the inventory and the recipe is learned.

signal finished(result: Dictionary)
signal closed

enum Phase { PICK, STIR, RESULT, BOOK }

var mode: String = "field"
var cook_char: String = ""
var phase: int = Phase.PICK
var picked: Array[String] = []

# stir mini-game state (also driven directly by tests via stir_press)
var beats_total: int = 4
var beat_idx: int = 0
var marker: float = 0.0
var marker_dir: float = 1.0
var marker_speed: float = 1.1
var zone_center: float = 0.5
var zone_half: float = 0.16
var hits: Array = []
var rng := RandomNumberGenerator.new()
var last_result: Dictionary = {}

var _inv_box: VBoxContainer
var _slot_row: HBoxContainer
var _slot_btns: Array[Button] = []
var _pot_visual: DishVisual
var _hint: Label
var _cook_btn: Button
var _stir_panel: PanelContainer
var _stir_bar: Control
var _stir_label: Label
var _result_panel: PanelContainer
var _result_visual: DishVisual
var _result_label: RichTextLabel
var _book_panel: PanelContainer
var _book_grid: GridContainer
var _book_info: Label
var _main_panel: PanelContainer
var _built: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

# ---------- autoload access (no hard references) ----------
func _auto(n: String) -> Node:
	var tree := get_tree()
	return tree.root.get_node_or_null(n) if tree else null

func _data_dict(key: String) -> Dictionary:
	var d := _auto("Data")
	if d == null:
		return {}
	var v: Variant = d.get(key)
	return v if v is Dictionary else {}

func recipes() -> Dictionary:
	return _data_dict("RECIPES")

func ingredients() -> Dictionary:
	return _data_dict("INGREDIENTS")

func items() -> Dictionary:
	return _data_dict("ITEMS")

func inv_count(id: String) -> int:
	var s := _auto("GameState")
	if s == null:
		return 0
	if s.has_method("count"):
		return int(s.call("count", id))
	var inv: Variant = s.get("inventory")
	return int((inv as Dictionary).get(id, 0)) if inv is Dictionary else 0

func inv_take(id: String, n: int = 1) -> void:
	var s := _auto("GameState")
	if s == null:
		return
	if s.has_method("remove_item"):
		s.call("remove_item", id, n)
		return
	var inv: Variant = s.get("inventory")
	if inv is Dictionary:
		var d := inv as Dictionary
		d[id] = maxi(0, int(d.get(id, 0)) - n)
		if d[id] == 0:
			d.erase(id)

func inv_give(id: String, n: int = 1) -> void:
	var s := _auto("GameState")
	if s == null:
		return
	if s.has_method("add_item"):
		s.call("add_item", id, n)
		return
	var inv: Variant = s.get("inventory")
	if inv is Dictionary:
		(inv as Dictionary)[id] = int((inv as Dictionary).get(id, 0)) + n

func is_known(rid: String) -> bool:
	var s := _auto("GameState")
	if s != null and s.has_method("knows_recipe"):
		return bool(s.call("knows_recipe", rid))
	var u: Variant = s.get("unlocked_recipes") if s else null
	if u is Array:
		return rid in (u as Array)
	if u is Dictionary:
		return (u as Dictionary).has(rid)
	return String(recipes().get(rid, {}).get("learn", "")) == "start"

func learn(rid: String) -> void:
	var s := _auto("GameState")
	if s != null and s.has_method("learn_recipe"):
		s.call("learn_recipe", rid)
		return
	else:
		var u: Variant = s.get("unlocked_recipes") if s else null
		if u is Array and not (rid in (u as Array)):
			(u as Array).append(rid)
		elif u is Dictionary:
			(u as Dictionary)[rid] = true
	var ev := _auto("Events")
	if ev != null and ev.has_signal("recipe_learned"):
		ev.emit_signal("recipe_learned", rid)

func _toast(t: String) -> void:
	var ev := _auto("Events")
	if ev != null and ev.has_signal("toast"):
		ev.emit_signal("toast", t)

func _sfx(id: String) -> void:
	var a := _auto("Audio")
	if a != null and a.has_method("play_sfx"):
		a.call("play_sfx", id)

# ---------- public API ----------
func open(p_mode: String = "field", p_cook: String = "") -> void:
	mode = p_mode
	cook_char = p_cook
	beats_total = 2 if mode == "battle" else 4
	if not _built:
		_build()
	picked.clear()
	visible = true
	_set_phase(Phase.PICK)
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func pick(id: String) -> bool:
	if phase != Phase.PICK or picked.size() >= CookingLogic.MAX_SLOTS:
		return false
	if inv_count(id) - picked.count(id) <= 0:
		return false
	picked.append(id)
	_sfx("ui_select")
	_refresh()
	return true

func unpick(idx: int) -> void:
	if phase == Phase.PICK and idx >= 0 and idx < picked.size():
		picked.remove_at(idx)
		_refresh()

func clear_pot() -> void:
	picked.clear()
	_refresh()

func current_match() -> String:
	return CookingLogic.match_recipe(picked, recipes(), ingredients())

func start_stir() -> bool:
	if picked.size() < 1 or phase != Phase.PICK:
		return false
	if picked.size() < 2 and current_match() == "":
		_toast("Add another ingredient")
		return false
	beat_idx = 0
	hits.clear()
	marker = 0.0
	marker_dir = 1.0
	_next_zone()
	_set_phase(Phase.STIR)
	return true

func _next_zone() -> void:
	zone_half = maxf(0.07, 0.17 - 0.03 * beat_idx)
	zone_center = rng.randf_range(0.2 + zone_half, 0.8 - zone_half)
	marker_speed = 1.0 + 0.25 * beat_idx

## Register a stir press at the current marker; returns accuracy 0..1.
func stir_press() -> float:
	if phase != Phase.STIR:
		return 0.0
	var d := absf(marker - zone_center)
	var acc := clampf(1.0 - maxf(0.0, d - zone_half * 0.35) / (zone_half * 1.6), 0.0, 1.0)
	if d > zone_half * 1.6:
		acc = 0.0
	hits.append(acc)
	_sfx("ui_confirm" if acc > 0.5 else "ui_cancel")
	beat_idx += 1
	if beat_idx >= beats_total:
		finish_cooking()
	else:
		_next_zone()
	if _stir_bar:
		_stir_bar.queue_redraw()
	return acc

func finish_cooking() -> Dictionary:
	var rec := recipes()
	var ing := ingredients()
	var rid := current_match()
	var mush := rid == ""
	var recipe: Dictionary = {} if mush else rec[rid]
	var stir := CookingLogic.stir_tier(hits)
	var bonus := 0 if mush else CookingLogic.pairing_bonus(recipe, picked, ing)
	var role := _role_bonus(rid, recipe, stir + bonus)
	var tier := CookingLogic.final_tier(stir, bonus, role, mush)
	if cook_char == "clover" and tier == 0 and not mush:
		tier = 1
	if cook_char == "brie" and not mush and picked.has("egg"):
		tier = maxi(tier, 2)
	var dish := CookingLogic.MUSH if mush else rid
	for id in picked:
		inv_take(id)
	var new_recipe := false
	if not mush and not is_known(rid):
		new_recipe = true
	if mode == "field":
		inv_give(dish)
	if new_recipe:
		learn(rid)
	var base_fx: Dictionary = items().get(dish, {}).get("effect", recipe.get("effect", {}))
	last_result = {
		"ok": not mush, "dish_id": dish, "tier": tier, "tier_name": CookingLogic.TIER_NAMES[tier],
		"mult": CookingLogic.TIER_MULT[tier], "new_recipe": new_recipe, "ingredients": picked.duplicate(),
		"mode": mode, "effect": base_fx, "stir": stir, "pair_bonus": bonus,
	}
	_show_result()
	return last_result

func _role_bonus(_rid: String, recipe: Dictionary, base: int) -> int:
	if cook_char == "fennel" and base >= 2 and String(recipe.get("element", "")) == "fire":
		return 1
	return 0

# ---------- UI building ----------
func _build() -> void:
	if _built:
		return
	_built = true
	rng.randomize()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_main_panel = _panel(Vector2(0.04, 0.05), Vector2(0.96, 0.95))
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	_main_panel.add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	root.add_child(left)
	left.add_child(_title("Pantry"))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	_inv_box = VBoxContainer.new()
	_inv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_inv_box)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	root.add_child(mid)
	mid.add_child(_title("The Pot"))
	_pot_visual = DishVisual.new()
	_pot_visual.custom_minimum_size = Vector2(260, 190)
	_pot_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pot_visual.silhouette = false
	mid.add_child(_pot_visual)
	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(_slot_row)
	for i in CookingLogic.MAX_SLOTS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 48)
		b.pressed.connect(unpick.bind(i))
		_slot_row.add_child(b)
		_slot_btns.append(b)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(0, 54)
	mid.add_child(_hint)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	mid.add_child(btns)
	_cook_btn = _button("Stir the pot!", start_stir)
	btns.add_child(_cook_btn)
	btns.add_child(_button("Empty pot", clear_pot))
	btns.add_child(_button("Cookbook", func() -> void: _set_phase(Phase.BOOK); _refresh_book()))
	btns.add_child(_button("Leave", close))

	# stir overlay
	_stir_panel = _panel(Vector2(0.2, 0.3), Vector2(0.8, 0.7))
	_stir_panel.visible = false
	var sv := VBoxContainer.new()
	_stir_panel.add_child(sv)
	_stir_label = Label.new()
	_stir_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(_stir_label)
	_stir_bar = Control.new()
	_stir_bar.custom_minimum_size = Vector2(0, 90)
	_stir_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stir_bar.draw.connect(_draw_stir)
	sv.add_child(_stir_bar)
	sv.add_child(_button("STIR! (Space / Enter)", stir_press))

	# result overlay
	_result_panel = _panel(Vector2(0.28, 0.12), Vector2(0.72, 0.88))
	_result_panel.visible = false
	var rv := VBoxContainer.new()
	_result_panel.add_child(rv)
	_result_visual = DishVisual.new()
	_result_visual.custom_minimum_size = Vector2(420, 360)
	_result_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(_result_visual)
	_result_label = RichTextLabel.new()
	_result_label.bbcode_enabled = true
	_result_label.fit_content = true
	_result_label.custom_minimum_size = Vector2(0, 150)
	_result_label.add_theme_font_size_override("normal_font_size", 26)
	rv.add_child(_result_label)
	rv.add_child(_button("Delicious!", _result_done))

	# cookbook overlay
	_book_panel = _panel(Vector2(0.08, 0.08), Vector2(0.92, 0.92))
	_book_panel.visible = false
	var bv := VBoxContainer.new()
	_book_panel.add_child(bv)
	bv.add_child(_title("Cookbook"))
	var bsc := ScrollContainer.new()
	bsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bv.add_child(bsc)
	_book_grid = GridContainer.new()
	_book_grid.columns = 5
	_book_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_grid.add_theme_constant_override("h_separation", 10)
	_book_grid.add_theme_constant_override("v_separation", 10)
	bsc.add_child(_book_grid)
	_book_info = Label.new()
	_book_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_book_info.custom_minimum_size = Vector2(0, 70)
	bv.add_child(_book_info)
	bv.add_child(_button("Back to the pot", func() -> void: _set_phase(Phase.PICK)))

func _panel(a: Vector2, b: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = a.x
	p.anchor_top = a.y
	p.anchor_right = b.x
	p.anchor_bottom = b.y
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.14, 0.08, 1.0)
	sb.border_color = Color(0.95, 0.7, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", sb)
	p.add_theme_font_size_override("font_size", 24)
	p.theme = _theme24()
	add_child(p)
	return p

func _theme24() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	return t

func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	return l

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(190, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b

func _set_phase(p: int) -> void:
	phase = p
	if _main_panel == null:
		return
	_main_panel.visible = p != Phase.RESULT and p != Phase.BOOK
	_stir_panel.visible = p == Phase.STIR
	_result_panel.visible = p == Phase.RESULT
	_book_panel.visible = p == Phase.BOOK
	set_process(p == Phase.STIR)
	if p == Phase.PICK:
		_refresh()

func _refresh() -> void:
	if _inv_box == null:
		return
	for c in _inv_box.get_children():
		c.queue_free()
	var ing := ingredients()
	var ids: Array = ing.keys()
	ids.sort()
	var any := false
	for id: String in ids:
		var n := inv_count(id) - picked.count(id)
		if n <= 0:
			continue
		any = true
		var b := Button.new()
		b.text = "%s  x%d" % [String(ing[id].get("name", id)), n]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = String(ing[id].get("desc", ""))
		b.pressed.connect(pick.bind(id))
		_inv_box.add_child(b)
	if not any:
		var l := Label.new()
		l.text = "No ingredients left.\nGo forage, farmer!"
		_inv_box.add_child(l)
	for i in _slot_btns.size():
		_slot_btns[i].text = String(ing.get(picked[i], {}).get("name", picked[i])) if i < picked.size() else "(empty)"
	var m := current_match() if picked.size() >= 2 else ""
	var rec := recipes()
	if m != "" and is_known(m):
		_hint.text = "This will make: %s" % String(rec[m].get("name", m))
		_pot_visual.silhouette = false
		_pot_visual.tier = 2
		_pot_visual.dish_id = m
	elif m != "":
		_hint.text = "Something is cooking... a recipe you do not know yet?"
		_pot_visual.silhouette = true
		_pot_visual.dish_id = m
	else:
		_hint.text = "Pick up to 3 ingredients. Experiment to discover recipes!" if picked.size() < 2 else "Hmm. That might turn out as mystery mush."
		_pot_visual.silhouette = true
		_pot_visual.dish_id = ""
	_cook_btn.disabled = picked.size() < 2

func _refresh_book() -> void:
	for c in _book_grid.get_children():
		c.queue_free()
	var rec := recipes()
	var ids: Array = rec.keys()
	ids.sort()
	var known := 0
	for rid: String in ids:
		var ok := is_known(rid)
		known += 1 if ok else 0
		var card := Button.new()
		card.custom_minimum_size = Vector2(240, 190)
		var cl := Label.new()
		cl.text = String(rec[rid].get("name", rid)) if ok else "???"
		cl.add_theme_font_size_override("font_size", 20)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cl.offset_top = -36
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.pressed.connect(_book_select.bind(rid))
		var v := DishVisual.new()
		v.dish_id = rid
		v.silhouette = not ok
		v.tier = 2
		v.steam = false
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_bottom = -40
		card.add_child(v)
		card.add_child(cl)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_book_grid.add_child(card)
	_book_info.text = "Discovered %d / %d recipes. Select one for details." % [known, ids.size()]

func _book_select(rid: String) -> void:
	var r: Dictionary = recipes().get(rid, {})
	if is_known(rid):
		var parts: Array[String] = []
		for s in r.get("slots", []):
			parts.append(_slot_name(String(s)))
		_book_info.text = "%s: %s\n%s" % [r.get("name", rid), " + ".join(parts), r.get("desc", "")]
	else:
		_book_info.text = "Undiscovered (%d ingredients). Hint: %s" % [(r.get("slots", []) as Array).size(), r.get("hint", "Experiment!")]

func _slot_name(s: String) -> String:
	if s == "cheese":
		return "any cheese"
	if s.begins_with("tag:"):
		return "any %s" % s.substr(4)
	return String(ingredients().get(s, {}).get("name", s))

func _show_result() -> void:
	var r := last_result
	var rec := recipes()
	var nm: String = String(items().get(r["dish_id"], rec.get(r["dish_id"], {})).get("name", String(r["dish_id"]).capitalize()))
	_result_visual.dish_id = r["dish_id"]
	_result_visual.tier = r["tier"]
	_result_visual.silhouette = false
	var col: Color = CookingLogic.TIER_COLORS[r["tier"]]
	var txt := "[center][font_size=40]%s[/font_size]\n[color=#%s]%s[/color]  (x%.2f effect)" % [nm, col.to_html(false), r["tier_name"], r["mult"]]
	if r["new_recipe"]:
		txt += "\n[color=#ffd966]New recipe discovered![/color]"
	if not r["ok"]:
		txt += "\nThat combination is no recipe at all..."
	_result_label.text = txt + "[/center]"
	_set_phase(Phase.RESULT)
	finished.emit(r)

func _result_done() -> void:
	picked.clear()
	if mode == "battle":
		close()
	else:
		_set_phase(Phase.PICK)

# ---------- stir mini-game ----------
func _process(delta: float) -> void:
	if phase != Phase.STIR:
		return
	marker += marker_dir * marker_speed * delta
	if marker >= 1.0:
		marker = 1.0
		marker_dir = -1.0
	elif marker <= 0.0:
		marker = 0.0
		marker_dir = 1.0
	_stir_label.text = "Stir in the golden zone!  Beat %d / %d" % [mini(beat_idx + 1, beats_total), beats_total]
	_stir_bar.queue_redraw()

func _draw_stir() -> void:
	var r := Rect2(Vector2.ZERO, _stir_bar.size)
	var bar := Rect2(r.position + Vector2(10, r.size.y * 0.35), Vector2(r.size.x - 20, r.size.y * 0.3))
	_stir_bar.draw_rect(bar, Color(0.1, 0.06, 0.04))
	var zx := bar.position.x + (zone_center - zone_half) * bar.size.x
	_stir_bar.draw_rect(Rect2(zx, bar.position.y, zone_half * 2.0 * bar.size.x, bar.size.y), Color(0.95, 0.75, 0.2, 0.85))
	var mx := bar.position.x + marker * bar.size.x
	_stir_bar.draw_rect(Rect2(mx - 4, bar.position.y - 10, 8, bar.size.y + 20), Color(1, 1, 1))
	for i in hits.size():
		var c := Color(0.4, 0.9, 0.4) if float(hits[i]) > 0.5 else Color(0.9, 0.3, 0.3)
		_stir_bar.draw_circle(Vector2(bar.position.x + 16 + i * 22, bar.end.y + 18), 7, c)

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if phase == Phase.STIR and (e.is_action_pressed("confirm") or e.is_action_pressed("interact")):
		stir_press()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("cancel"):
		if phase == Phase.BOOK:
			_set_phase(Phase.PICK)
		elif phase == Phase.PICK:
			close()
		get_viewport().set_input_as_handled()
