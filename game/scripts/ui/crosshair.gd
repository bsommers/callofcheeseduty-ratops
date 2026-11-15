class_name Crosshair
extends Control
## Centre-screen crosshair: four ticks that open with weapon spread, plus hit / kill markers.

var spread_px: float = 0.0       ## current gap (pixels) from centre
var _target_px: float = 0.0
var _bloom: float = 0.0          ## transient kick from firing
var _hit_t: float = 0.0
var _kill_t: float = 0.0
var _head: bool = false
var ads: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## radians -> pixels using a 70 deg fov assumption scaled by viewport height.
func set_spread_rad(rad: float, fov_deg: float = 70.0) -> void:
	var h: float = get_viewport_rect().size.y if is_inside_tree() else 1080.0
	var px_per_rad: float = h * 0.5 / tan(deg_to_rad(fov_deg) * 0.5)
	_target_px = rad * px_per_rad


func kick(amount: float = 10.0) -> void:
	_bloom = minf(_bloom + amount, 40.0)


func hit(kill: bool, head: bool = false) -> void:
	_head = head
	if kill:
		_kill_t = 0.45
	else:
		_hit_t = 0.2
	queue_redraw()


func _process(dt: float) -> void:
	_bloom = move_toward(_bloom, 0.0, 60.0 * dt)
	var want: float = _target_px + _bloom
	spread_px = lerpf(spread_px, want, clampf(dt * 18.0, 0.0, 1.0))
	_hit_t = maxf(_hit_t - dt, 0.0)
	_kill_t = maxf(_kill_t - dt, 0.0)
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	var gap: float = 5.0 + spread_px
	var len_: float = 9.0
	var col: Color = Color(1, 1, 1, 0.92)
	var shadow: Color = Color(0, 0, 0, 0.55)
	for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = c + d * gap
		var b: Vector2 = c + d * (gap + len_)
		draw_line(a + Vector2(1, 1), b + Vector2(1, 1), shadow, 4.0)
		draw_line(a, b, col, 2.0)
	draw_circle(c, 1.6, UITheme.ACCENT)
	if _hit_t > 0.0 or _kill_t > 0.0:
		var kill: bool = _kill_t > 0.0
		var t: float = (_kill_t / 0.45) if kill else (_hit_t / 0.2)
		var mc: Color = (UITheme.DANGER if not kill else Color(1, 0.25, 0.2)) if not _head else UITheme.ACCENT
		mc.a = clampf(t * 1.5, 0.0, 1.0)
		var o: float = 8.0 + (1.0 - t) * 4.0
		var l: float = 7.0 if not kill else 11.0
		for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(c + s * o, c + s * (o + l), mc, 3.0 if kill else 2.0)
