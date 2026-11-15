class_name HudIcon
extends Control
## Tiny vector icons drawn in code (no texture assets): weapon silhouettes, keys, cat-head lives.

enum Kind { WEAPON, KEY, LIFE }
var kind: Kind = Kind.WEAPON
var slot: int = 0                 ## weapon slot index, or life 0 = alive / 1 = lost
var tint: Color = UITheme.TEXT


static func make(k: Kind, s: int, sz: Vector2, c: Color = UITheme.TEXT) -> HudIcon:
	var i: HudIcon = HudIcon.new()
	i.kind = k
	i.slot = s
	i.tint = c
	i.custom_minimum_size = sz
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func set_slot(s: int) -> void:
	slot = s
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	match kind:
		Kind.WEAPON: _draw_weapon(sz)
		Kind.KEY: _draw_key(sz)
		Kind.LIFE: _draw_life(sz)


func _draw_key(sz: Vector2) -> void:
	var u: float = minf(sz.x, sz.y)
	var c: Vector2 = Vector2(u * 0.3, sz.y * 0.5)
	draw_arc(c, u * 0.22, 0.0, TAU, 20, tint, u * 0.11)
	draw_line(Vector2(u * 0.52, c.y), Vector2(sz.x * 0.95, c.y), tint, u * 0.11)
	draw_line(Vector2(sz.x * 0.78, c.y), Vector2(sz.x * 0.78, c.y + u * 0.2), tint, u * 0.11)
	draw_line(Vector2(sz.x * 0.92, c.y), Vector2(sz.x * 0.92, c.y + u * 0.16), tint, u * 0.11)


func _draw_life(sz: Vector2) -> void:
	var col: Color = tint if slot == 0 else Color(1, 1, 1, 0.14)
	var u: float = minf(sz.x, sz.y)
	var c: Vector2 = sz * 0.5 + Vector2(0, u * 0.08)
	draw_circle(c, u * 0.34, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-u * 0.34, -u * 0.05), c + Vector2(-u * 0.30, -u * 0.46), c + Vector2(-u * 0.05, -u * 0.30)]), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(u * 0.34, -u * 0.05), c + Vector2(u * 0.30, -u * 0.46), c + Vector2(u * 0.05, -u * 0.30)]), col)
	if slot == 0:
		draw_circle(c + Vector2(-u * 0.12, -u * 0.04), u * 0.045, Color(0.1, 0.07, 0.04))
		draw_circle(c + Vector2(u * 0.12, -u * 0.04), u * 0.045, Color(0.1, 0.07, 0.04))


func _draw_weapon(sz: Vector2) -> void:
	var w: float = sz.x
	var h: float = sz.y
	var c: Color = tint
	match slot:
		0: # claws: three curved slashes
			for i: int in 3:
				var x: float = w * (0.3 + 0.18 * i)
				draw_arc(Vector2(x + w * 0.25, h * 0.95), h * 0.85, deg_to_rad(205), deg_to_rad(275), 12, c, h * 0.07)
		1: # pistol
			draw_rect(Rect2(w * 0.15, h * 0.28, w * 0.6, h * 0.2), c)
			draw_rect(Rect2(w * 0.15, h * 0.28, w * 0.3, h * 0.3), c)
			draw_rect(Rect2(w * 0.22, h * 0.5, w * 0.14, h * 0.38), c)
			draw_rect(Rect2(w * 0.74, h * 0.33, w * 0.1, h * 0.1), c)
		2: # gatling: barrel bundle
			for i: int in 3:
				draw_rect(Rect2(w * 0.38, h * (0.22 + 0.15 * i), w * 0.52, h * 0.09), c)
			draw_rect(Rect2(w * 0.12, h * 0.2, w * 0.28, h * 0.42), c)
			draw_rect(Rect2(w * 0.2, h * 0.6, w * 0.1, h * 0.28), c)
		3: # yarn launcher
			draw_rect(Rect2(w * 0.12, h * 0.3, w * 0.58, h * 0.24), c)
			draw_circle(Vector2(w * 0.8, h * 0.42), h * 0.22, c)
			draw_rect(Rect2(w * 0.2, h * 0.5, w * 0.1, h * 0.36), c)
		4: # laser pointer
			draw_rect(Rect2(w * 0.12, h * 0.38, w * 0.5, h * 0.16), c)
			draw_line(Vector2(w * 0.62, h * 0.46), Vector2(w * 0.95, h * 0.46), Color(1, 0.2, 0.2), h * 0.05)
			draw_circle(Vector2(w * 0.95, h * 0.46), h * 0.08, Color(1, 0.3, 0.3))
