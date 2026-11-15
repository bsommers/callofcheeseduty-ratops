class_name CheeseEmblem
extends Control
## Title emblem: a cheese wedge with holes on a disc (drawn in code).

func _init() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var o: Vector2 = (size - Vector2(s, s)) * 0.5
	var c: Vector2 = o + Vector2(s, s) * 0.5
	draw_circle(c, s * 0.5, Color(0.10, 0.10, 0.12, 0.85))
	draw_arc(c, s * 0.48, 0.0, TAU, 48, UITheme.ACCENT_DIM, 3.0, true)
	# wedge: side face + top face
	var p0: Vector2 = o + Vector2(0.14, 0.70) * s
	var p1: Vector2 = o + Vector2(0.86, 0.52) * s
	var p2: Vector2 = o + Vector2(0.86, 0.72) * s
	var p3: Vector2 = o + Vector2(0.14, 0.86) * s
	var t0: Vector2 = o + Vector2(0.20, 0.50) * s
	draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), Color(0.93, 0.62, 0.10))
	draw_colored_polygon(PackedVector2Array([p0, t0, p1]), Color(1.0, 0.85, 0.30))
	draw_polyline(PackedVector2Array([p0, t0, p1, p2, p3, p0]), Color(0.45, 0.28, 0.04), 2.0, true)
	for h: Array in [[0.40, 0.62, 0.045], [0.60, 0.58, 0.03], [0.30, 0.78, 0.035], [0.62, 0.72, 0.04], [0.74, 0.62, 0.025]]:
		draw_circle(o + Vector2(h[0], h[1]) * s, float(h[2]) * s, Color(0.62, 0.38, 0.05))
