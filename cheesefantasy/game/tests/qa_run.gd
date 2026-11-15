extends SceneTree
## usage: tools/godot.sh --headless --path game --script res://tests/qa_run.gd
func _initialize() -> void:
	await process_frame
	var inst: RefCounted = (load("res://tests/qa_playthrough.gd") as GDScript).new()
	var n: int = await inst.run(self)
	quit(1 if n > 0 else 0)
