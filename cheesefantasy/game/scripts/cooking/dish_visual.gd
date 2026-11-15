class_name DishVisual
extends Control
## Procedural dish picture. The recipe id picks a KIND (bowl of soup, grilled sandwich, pizza, fondue pot, pie, omelette,
## salad, pasta, cheese wheel, bottle...) so each dish reads as what it is. silhouette = true draws flat dark shapes.

var dish_id: String = "":
	set(v):
		dish_id = v
		_kind = kind_of(v)
		_rebuild()
var tier: int = 1:
	set(v):
		tier = clampi(v, 0, 3)
		queue_redraw()
var silhouette: bool = false:
	set(v):
		silhouette = v
		queue_redraw()
var steam: bool = true
var _kind: String = "plate"
var _rng_seed: int = 0
var _t: float = 0.0

const CHEESE := Color(1.0, 0.8, 0.2)
const CRUST := Color(0.82, 0.55, 0.25)
const CHINA := Color(0.96, 0.95, 0.92)


## Public so tests / other UI can ask what a dish looks like.
static func kind_of(id: String) -> String:
	if id.contains("fondue") or id == "spicy_queso":
		return "fondue"
	if id.contains("pizza"):
		return "pizza"
	if id.contains("soup") or id.contains("chowder"):
		return "soup"
	if id.contains("salad") or id == "caprese_salad":
		return "salad"
	if id in ["grilled_cheese", "croque_monsieur", "smoked_trout_melt", "welsh_rarebit", "olive_tapenade_toast", "garlic_bread"]:
		return "sandwich"
	if id.contains("pie") or id.contains("tart") or id.contains("quiche") or id.contains("cheesecake") or id.contains("cake") or id.contains("crumble"):
		return "pie"
	if id.contains("omelette"):
		return "omelette"
	if id.contains("souffle") or id.contains("souffl"):
		return "souffle"
	if id.contains("pasta") or id.contains("mac_") or id.contains("gnocchi") or id.contains("risotto") or id.contains("poutine") or id.contains("corn"):
		return "bowl"
	if id.contains("tonic") or id.contains("cooler") or id.contains("bomb"):
		return "bottle"
	if id.contains("scone") or id.contains("bites") or id.contains("bake") or id.contains("raclette") or id.contains("feast"):
		return "wheel"
	return "plate"


func _init() -> void:
	custom_minimum_size = Vector2(120, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _rebuild() -> void:
	_rng_seed = hash(dish_id)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if steam and not silhouette and is_visible_in_tree():
		queue_redraw()


# ---------------------------------------------------------------- drawing helpers
func _c(col: Color) -> Color:
	if silhouette and dish_id != "":
		return Color(0.06, 0.05, 0.08)
	if tier == 0:
		return col.darkened(0.55)
	return col


func _ell(center: Vector2, r: Vector2, col: Color, a0: float = 0.0, a1: float = TAU) -> void:
	var pts := PackedVector2Array()
	var n := 32
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, _c(col))


func _rrect(center: Vector2, half: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var starts := [0.0, PI * 0.5, PI, PI * 1.5]
	for k in 4:
		var cc: Vector2 = center + Vector2((half.x - rad) * corners[k].x, (half.y - rad) * corners[k].y)
		for i in 7:
			var a: float = starts[k] + PI * 0.5 * float(i) / 6.0
			pts.append(cc + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, _c(col))


func _plate(c: Vector2, s: float) -> void:
	_ell(c + Vector2(0, s * 0.08), Vector2(s * 1.0, s * 0.42), Color(0, 0, 0, 0.25))
	_ell(c, Vector2(s * 0.98, s * 0.4), CHINA.darkened(0.15))
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.82, s * 0.32), CHINA)


func _draw() -> void:
	var c := size * 0.5 + Vector2(0, size.y * 0.04)
	var s := minf(size.x * 0.46, size.y * 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	if dish_id == "":
		_draw_cauldron(c, s)
		return
	match _kind:
		"soup": _draw_soup(c, s, rng)
		"salad": _draw_salad(c, s, rng)
		"bowl": _draw_bowl(c, s, rng)
		"sandwich": _draw_sandwich(c, s, rng)
		"pizza": _draw_pizza(c, s, rng)
		"fondue": _draw_fondue(c, s, rng)
		"pie": _draw_pie(c, s, rng)
		"omelette": _draw_omelette(c, s, rng)
		"souffle": _draw_souffle(c, s, rng)
		"bottle": _draw_bottle(c, s, rng)
		"wheel": _draw_wheel(c, s, rng)
		_: _draw_plate_mound(c, s, rng)
	if silhouette:
		return
	if tier >= 2:
		for i in 4 + tier * 2:
			var a := float(i) * 2.4 + _t * 1.5
			var sp := c + Vector2(cos(a) * s * 0.9, -s * 0.5 + sin(a * 1.3) * s * 0.3)
			var k := 0.5 + 0.5 * sin(_t * 4.0 + i)
			_star(sp, s * 0.07 * (0.6 + k), Color(1, 0.95, 0.6, 0.4 + 0.5 * k))
	if steam and _kind != "bottle":
		for i in 3:
			var x := c.x + (i - 1) * s * 0.35
			var col2 := Color(1, 1, 1, 0.25) if tier > 0 else Color(0.2, 0.2, 0.2, 0.4)
			var pts := PackedVector2Array()
			for j in 8:
				var f := float(j) / 7.0
				pts.append(Vector2(x + sin(_t * 2.0 + f * 4.0 + i) * s * 0.08, c.y - s * 0.4 - f * s * 0.45))
			draw_polyline(pts, col2, 3.0, true)


# ---------------------------------------------------------------- kinds
func _bowl_body(c: Vector2, s: float, rim: Color, inside: Color) -> void:
	_ell(c + Vector2(0, s * 0.62), Vector2(s * 0.95, s * 0.18), Color(0, 0, 0, 0.25))
	_ell(c + Vector2(0, s * 0.05), Vector2(s * 0.9, s * 0.8), rim.darkened(0.2), 0.0, PI)  # lower half
	_ell(c + Vector2(0, s * 0.05), Vector2(s * 0.9, s * 0.8), rim, 0.15, PI - 0.15)
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.9, s * 0.3), rim)
	_ell(c - Vector2(0, s * 0.0), Vector2(s * 0.78, s * 0.24), inside)


func _draw_cauldron(c: Vector2, s: float) -> void:
	_ell(c + Vector2(0, s * 0.62), Vector2(s * 0.95, s * 0.18), Color(0, 0, 0, 0.25))
	var fl := 0.8 + 0.2 * sin(_t * 9.0)
	_ell(c + Vector2(-s * 0.25, s * 0.62), Vector2(s * 0.1, s * 0.16 * fl), Color(1.0, 0.55, 0.15))
	_ell(c + Vector2(s * 0.25, s * 0.62), Vector2(s * 0.1, s * 0.16 * fl), Color(1.0, 0.55, 0.15))
	_ell(c + Vector2(0, s * 0.05), Vector2(s * 0.8, s * 0.6), Color(0.2, 0.2, 0.24), 0.0, PI)
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.8, s * 0.26), Color(0.3, 0.3, 0.34))
	_ell(c, Vector2(s * 0.68, s * 0.19), Color(0.15, 0.12, 0.14))
	for i in 3:
		var bx := c.x + (i - 1) * s * 0.3
		var by := c.y + sin(_t * 3.0 + i * 2.0) * s * 0.03
		draw_arc(Vector2(bx, by), s * 0.06, 0, TAU, 12, Color(0.9, 0.85, 0.7, 0.6), 2.0)


func _draw_soup(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var id := dish_id
	var liquid := Color(0.9, 0.35, 0.2)
	if id.contains("pumpkin"):
		liquid = Color(0.95, 0.6, 0.15)
	elif id.contains("corn"):
		liquid = Color(0.98, 0.82, 0.35)
	elif id.contains("cheddar"):
		liquid = Color(0.98, 0.72, 0.2)
	_bowl_body(c, s, Color(0.35, 0.5, 0.75), liquid)
	_ell(c, Vector2(s * 0.4, s * 0.1), liquid.lightened(0.25))
	_ell(c + Vector2(s * 0.1, 0), Vector2(s * 0.18, s * 0.05), Color(1, 0.95, 0.85))  # cream swirl
	for i in 5:
		_ell(c + Vector2(rng.randf_range(-0.45, 0.45) * s, rng.randf_range(-0.07, 0.08) * s), Vector2(s * 0.04, s * 0.025), Color(0.3, 0.6, 0.2))
	if id.contains("corn"):
		for i in 6:
			_ell(c + Vector2(rng.randf_range(-0.5, 0.5) * s, rng.randf_range(-0.1, 0.1) * s), Vector2(s * 0.035, s * 0.025), Color(1, 0.9, 0.3))


func _draw_bowl(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var inside := Color(0.98, 0.84, 0.4)
	if dish_id.contains("pesto"):
		inside = Color(0.55, 0.72, 0.3)
	elif dish_id.contains("risotto"):
		inside = Color(0.93, 0.88, 0.72)
	_bowl_body(c, s, Color(0.85, 0.8, 0.7), inside)
	for i in 14:
		var p := c + Vector2(rng.randf_range(-0.62, 0.62) * s, rng.randf_range(-0.14, 0.1) * s)
		if dish_id.contains("poutine"):
			_rrect(p, Vector2(s * 0.09, s * 0.03), 2, Color(0.9, 0.7, 0.3))
		else:
			_ell(p, Vector2(s * 0.06, s * 0.035), inside.darkened(0.15 + rng.randf() * 0.1))
	for i in 4:
		_ell(c + Vector2(rng.randf_range(-0.4, 0.4) * s, rng.randf_range(-0.1, 0.06) * s), Vector2(s * 0.07, s * 0.035), CHEESE.lightened(0.2))


func _draw_salad(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_bowl_body(c, s, Color(0.9, 0.88, 0.82), Color(0.45, 0.7, 0.3))
	for i in 12:
		var p := c + Vector2(rng.randf_range(-0.6, 0.6) * s, rng.randf_range(-0.2, 0.0) * s)
		_ell(p, Vector2(s * 0.12, s * 0.09), Color(0.3 + rng.randf() * 0.2, 0.65 + rng.randf() * 0.2, 0.25))
	var accent := Color(0.9, 0.25, 0.2) if dish_id.contains("caprese") else Color(0.9, 0.85, 0.5)
	for i in 5:
		_ell(c + Vector2(rng.randf_range(-0.5, 0.5) * s, rng.randf_range(-0.2, 0.02) * s), Vector2(s * 0.09, s * 0.06), accent)
	for i in 3:
		_ell(c + Vector2(rng.randf_range(-0.4, 0.4) * s, rng.randf_range(-0.2, 0.0) * s), Vector2(s * 0.08, s * 0.05), Color(0.97, 0.96, 0.9))


func _draw_sandwich(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_plate(c + Vector2(0, s * 0.1), s)
	var bread := Color(0.9, 0.66, 0.3)
	if dish_id.contains("garlic") or dish_id.contains("toast"):
		bread = Color(0.88, 0.7, 0.35)
	# bottom slice
	_rrect(c + Vector2(0, s * 0.03), Vector2(s * 0.58, s * 0.16), s * 0.1, bread.darkened(0.25))
	# oozing cheese
	_rrect(c - Vector2(0, s * 0.08), Vector2(s * 0.6, s * 0.09), s * 0.06, CHEESE)
	for i in 3:
		_ell(c + Vector2((i - 1) * s * 0.35, s * 0.0), Vector2(s * 0.08, s * 0.1), CHEESE)
	# top slice with grill marks
	_rrect(c - Vector2(0, s * 0.27), Vector2(s * 0.58, s * 0.17), s * 0.12, bread)
	_rrect(c - Vector2(0, s * 0.29), Vector2(s * 0.5, s * 0.11), s * 0.08, bread.lightened(0.15))
	for i in 3:
		var x := c.x + (i - 1) * s * 0.28
		draw_line(Vector2(x - s * 0.08, c.y - s * 0.34), Vector2(x + s * 0.08, c.y - s * 0.22), _c(Color(0.45, 0.25, 0.1)), 3.0)
	if dish_id.contains("garlic"):
		for i in 5:
			_ell(c + Vector2(rng.randf_range(-0.4, 0.4) * s, -s * 0.28 + rng.randf_range(-0.05, 0.05) * s), Vector2(s * 0.04, s * 0.025), Color(0.4, 0.7, 0.25))


func _draw_pizza(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_ell(c + Vector2(0, s * 0.08), Vector2(s * 1.0, s * 0.45), Color(0, 0, 0, 0.25))
	_ell(c, Vector2(s * 0.98, s * 0.44), Color(0.55, 0.38, 0.22))  # board
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.9, s * 0.4), CRUST)
	_ell(c - Vector2(0, s * 0.03), Vector2(s * 0.78, s * 0.34), Color(0.88, 0.25, 0.15))
	for i in 7:
		var a := TAU * float(i) / 7.0 + rng.randf()
		var r := rng.randf_range(0.15, 0.6)
		_ell(c + Vector2(cos(a) * r * s * 0.9, sin(a) * r * s * 0.38), Vector2(s * 0.13, s * 0.07), Color(0.98, 0.96, 0.88))
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.5
		_ell(c + Vector2(cos(a) * s * 0.4, sin(a) * s * 0.17), Vector2(s * 0.06, s * 0.035), Color(0.2, 0.6, 0.2))


func _draw_fondue(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_ell(c + Vector2(0, s * 0.62), Vector2(s * 0.95, s * 0.18), Color(0, 0, 0, 0.25))
	# burner flame
	var fl := 0.8 + 0.2 * sin(_t * 9.0)
	_ell(c + Vector2(0, s * 0.55), Vector2(s * 0.08, s * 0.14 * fl), Color(1.0, 0.6, 0.15))
	_ell(c + Vector2(0, s * 0.57), Vector2(s * 0.04, s * 0.08 * fl), Color(1.0, 0.9, 0.4))
	_rrect(c + Vector2(0, s * 0.5), Vector2(s * 0.55, s * 0.06), 4, Color(0.3, 0.3, 0.33))
	# iron pot
	_ell(c + Vector2(0, s * 0.1), Vector2(s * 0.72, s * 0.55), Color(0.62, 0.2, 0.18), 0.0, PI)
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.72, s * 0.26), Color(0.72, 0.25, 0.2))
	_ell(c - Vector2(0, s * 0.0), Vector2(s * 0.62, s * 0.2), CHEESE)
	_ell(c - Vector2(s * 0.12, s * 0.02), Vector2(s * 0.25, s * 0.06), CHEESE.lightened(0.3))
	# handles
	_ell(c + Vector2(-s * 0.78, 0), Vector2(s * 0.1, s * 0.06), Color(0.3, 0.2, 0.15))
	_ell(c + Vector2(s * 0.78, 0), Vector2(s * 0.1, s * 0.06), Color(0.3, 0.2, 0.15))
	# skewer with bread cube
	draw_line(c + Vector2(s * 0.45, -s * 0.75), c + Vector2(s * 0.05, -s * 0.05), _c(Color(0.6, 0.45, 0.3)), 4.0)
	_rrect(c + Vector2(s * 0.12, -s * 0.12), Vector2(s * 0.13, s * 0.11), 4, Color(0.92, 0.75, 0.4))
	_ell(c + Vector2(s * 0.12, -s * 0.04), Vector2(s * 0.12, s * 0.05), CHEESE)


func _draw_pie(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_ell(c + Vector2(0, s * 0.1), Vector2(s * 1.0, s * 0.45), Color(0, 0, 0, 0.25))
	var filling := Color(0.85, 0.5, 0.2)
	if dish_id.contains("fig") or dish_id.contains("blue"):
		filling = Color(0.45, 0.25, 0.4)
	elif dish_id.contains("cake"):
		filling = Color(0.95, 0.85, 0.6)
	elif dish_id.contains("quiche"):
		filling = Color(0.98, 0.85, 0.4)
	_ell(c + Vector2(0, s * 0.06), Vector2(s * 0.95, s * 0.42), CRUST.darkened(0.3))
	_ell(c, Vector2(s * 0.95, s * 0.42), CRUST)
	_ell(c, Vector2(s * 0.8, s * 0.34), filling)
	var lattice := not dish_id.contains("cake") and not dish_id.contains("quiche")
	if lattice:
		for i in range(-3, 4):
			draw_line(c + Vector2(i * s * 0.2 - s * 0.25, -s * 0.3), c + Vector2(i * s * 0.2 + s * 0.25, s * 0.3), _c(CRUST.lightened(0.1)), 6.0)
			draw_line(c + Vector2(i * s * 0.2 + s * 0.25, -s * 0.3), c + Vector2(i * s * 0.2 - s * 0.25, s * 0.3), _c(CRUST.lightened(0.1)), 6.0)
		var ring := PackedVector2Array()
		for i in 41:
			var a := TAU * float(i) / 40.0
			ring.append(c + Vector2(cos(a) * s * 0.9, sin(a) * s * 0.38))
		draw_polyline(ring, _c(CRUST.darkened(0.05)), s * 0.14, true)
	else:
		for i in 6:
			_ell(c + Vector2(rng.randf_range(-0.5, 0.5) * s, rng.randf_range(-0.2, 0.2) * s), Vector2(s * 0.06, s * 0.035), filling.lightened(0.25))


func _draw_omelette(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_plate(c, s)
	_ell(c + Vector2(0, s * 0.04), Vector2(s * 0.7, s * 0.28), Color(0.9, 0.7, 0.15), 0.0, TAU)
	_ell(c, Vector2(s * 0.7, s * 0.26), Color(1.0, 0.88, 0.3))
	_ell(c + Vector2(-s * 0.1, -s * 0.04), Vector2(s * 0.5, s * 0.14), Color(1.0, 0.93, 0.5))
	draw_line(c + Vector2(-s * 0.65, 0), c + Vector2(s * 0.65, 0), _c(Color(0.9, 0.7, 0.2)), 3.0)  # fold
	for i in 6:
		_ell(c + Vector2(rng.randf_range(-0.5, 0.5) * s, rng.randf_range(-0.15, 0.15) * s), Vector2(s * 0.035, s * 0.02), Color(0.3, 0.65, 0.2))
	_ell(c + Vector2(s * 0.5, 0.0), Vector2(s * 0.12, s * 0.07), CHEESE)


func _draw_souffle(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_plate(c + Vector2(0, s * 0.2), s)
	_ell(c + Vector2(0, -s * 0.18), Vector2(s * 0.6, s * 0.55), Color(1.0, 0.82, 0.35), PI, TAU)
	_ell(c + Vector2(0, -s * 0.2), Vector2(s * 0.5, s * 0.45), Color(1.0, 0.88, 0.45), PI, TAU)
	_ell(c + Vector2(-s * 0.15, -s * 0.5), Vector2(s * 0.15, s * 0.07), Color(1, 1, 0.8))
	_rrect(c + Vector2(0, s * 0.05), Vector2(s * 0.52, s * 0.22), s * 0.04, Color(0.95, 0.93, 0.9))
	_rrect(c + Vector2(0, -s * 0.12), Vector2(s * 0.56, s * 0.05), 3, Color(0.85, 0.82, 0.78))


func _draw_bottle(c: Vector2, s: float, _rng: RandomNumberGenerator) -> void:
	_ell(c + Vector2(0, s * 0.62), Vector2(s * 0.5, s * 0.12), Color(0, 0, 0, 0.25))
	var liquid := Color(0.5, 0.85, 0.4)
	if dish_id.contains("bomb") or dish_id.contains("stinky"):
		liquid = Color(0.55, 0.7, 0.2)
	elif dish_id.contains("cooler"):
		liquid = Color(0.6, 0.95, 0.8)
	_ell(c + Vector2(0, s * 0.25), Vector2(s * 0.4, s * 0.4), Color(0.8, 0.9, 0.95, 0.85))
	_ell(c + Vector2(0, s * 0.3), Vector2(s * 0.34, s * 0.32), liquid)
	_rrect(c + Vector2(0, -s * 0.25), Vector2(s * 0.12, s * 0.22), 4, Color(0.8, 0.9, 0.95, 0.85))
	_rrect(c + Vector2(0, -s * 0.5), Vector2(s * 0.15, s * 0.08), 4, Color(0.62, 0.42, 0.25))
	_ell(c + Vector2(-s * 0.15, s * 0.15), Vector2(s * 0.06, s * 0.14), Color(1, 1, 1, 0.5))
	if dish_id.contains("bomb") or dish_id.contains("stinky"):
		for i in 3:  # stink lines
			var x := c.x + (i - 1) * s * 0.3
			var pts := PackedVector2Array()
			for j in 8:
				pts.append(Vector2(x + sin(_t * 3.0 + j + i) * s * 0.06, c.y - s * 0.6 - j * s * 0.07))
			draw_polyline(pts, _c(Color(0.5, 0.75, 0.2, 0.6)), 3.0, true)


func _draw_wheel(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_plate(c, s)
	_ell(c + Vector2(0, s * 0.1), Vector2(s * 0.62, s * 0.3), CHEESE.darkened(0.3))
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.62, s * 0.3), CHEESE)
	_ell(c - Vector2(0, s * 0.02), Vector2(s * 0.5, s * 0.22), CHEESE.lightened(0.15))
	for i in 4:
		_ell(c + Vector2(rng.randf_range(-0.35, 0.35) * s, rng.randf_range(-0.12, 0.1) * s), Vector2(s * 0.06, s * 0.035), CHEESE.darkened(0.3))
	for i in 3:
		_ell(c + Vector2(rng.randf_range(-0.4, 0.4) * s, rng.randf_range(-0.12, 0.08) * s), Vector2(s * 0.04, s * 0.03), Color(0.4, 0.6, 0.2))


func _draw_plate_mound(c: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	_plate(c, s)
	for i in 6:
		var p := c + Vector2(rng.randf_range(-0.45, 0.45) * s, rng.randf_range(-0.25, 0.05) * s)
		var col := Color(0.9, 0.7, 0.3).lerp(Color(0.85, 0.4, 0.2), rng.randf())
		_ell(p + Vector2(0, s * 0.03), Vector2(s * 0.2, s * 0.14), col.darkened(0.3))
		_ell(p, Vector2(s * 0.2, s * 0.14), col)


func _star(p: Vector2, r: float, col: Color) -> void:
	draw_line(p - Vector2(r, 0), p + Vector2(r, 0), col, 2.0)
	draw_line(p - Vector2(0, r), p + Vector2(0, r), col, 2.0)
