extends Node
## Dev harness: render the farm from a given camera to PNG. Args after --: --out=path --cam=x,y,z,yaw,pitch [--frames=N]
func _ready() -> void:
	var a := {}
	for s: String in OS.get_cmdline_user_args():
		var kv := s.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	var farm: Node = (load("res://scenes/world/farm.tscn") as PackedScene).instantiate()
	add_child(farm)
	var cam := Camera3D.new()
	cam.far = 500.0
	cam.fov = 65.0
	add_child(cam)
	if a.has("cam"):
		var c := String(a["cam"]).split(",")
		cam.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.rotation_degrees = Vector3(float(c[4]), float(c[3]), 0)
		cam.make_current()
	for i in int(a.get("frames", "40")):
		await RenderingServer.frame_post_draw
	if a.has("cam"):
		cam.make_current()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(String(a["out"]))
	get_tree().quit()
