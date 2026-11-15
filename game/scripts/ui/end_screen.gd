class_name EndScreen
extends MenuScreen
## Game-over and victory screens (one class, two modes).

enum Mode { GAME_OVER, VICTORY }
var mode: Mode = Mode.GAME_OVER
var _title: Label
var _sub: Label
var _score: Label
var _primary: Button


func _init(m: Mode = Mode.GAME_OVER) -> void:
	super()
	mode = m
	dim = 0.7


func build() -> void:
	_title = UITheme.label("", 64, UITheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_title)
	_sub = UITheme.label("", 22, UITheme.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_sub)
	_score = UITheme.label("", 34, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	body.add_child(_score)
	_primary = UITheme.button("", _on_primary)
	body.add_child(_primary)
	body.add_child(UITheme.button("Quit to Title", func() -> void: Game.quit_to_title()))
	set_focus_target(_primary)


func refresh() -> void:
	if mode == Mode.VICTORY:
		_title.text = "VICTORY!"
		_title.add_theme_color_override("font_color", UITheme.ACCENT)
		_sub.text = "The Big Cheese has fallen. The Rattenreich is no more."
		_primary.text = "Play Again"
	else:
		_title.text = "GAME OVER"
		_title.add_theme_color_override("font_color", UITheme.DANGER)
		_sub.text = "All nine lives are spent."
		_primary.text = "Try Again"
	_score.text = "Final score  %d" % Game.score


func _on_primary() -> void:
	UITheme.ui_sfx("menu_select")
	Game.new_game()


func _unhandled_input(_event: InputEvent) -> void:
	pass
