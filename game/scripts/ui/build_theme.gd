extends SceneTree
## Regenerates res://assets/ui/theme.tres:  tools/godot.sh --headless --path game --script res://scripts/ui/build_theme.gd
const T = preload("res://scripts/ui/ui_theme.gd")

func _init() -> void:
	var err: Error = ResourceSaver.save(T.build(), T.THEME_PATH)
	print("theme saved: ", error_string(err))
	quit(0 if err == OK else 1)
