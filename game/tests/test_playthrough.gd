extends "res://tests/test_case.gd"
## botplay-qa: regression test. The QA bot plays e1m1 from main.tscn -> New Game for a short simulated
## time and must make progress (collect/kill/move) without engine errors. The full run is tools/qa.sh.

const LIMIT_S: float = 25.0


func after_each() -> void:
	autoload("Game").call("_reset_run")
	Engine.time_scale = 1.0


func test_bot_plays_e1m1_short() -> void:
	Engine.time_scale = 4.0  # simulated seconds pass faster than wall time (physics runs at 60 Hz regardless)
	var runner: GDScript = load("res://scripts/qa/qa_run.gd") as GDScript
	if not check(runner != null and runner.can_instantiate(), "qa_run.gd loads"):
		return
	var res: Dictionary = await runner.call("run_level", tree, "e1m1", LIMIT_S, 1234, false, 0)
	Engine.time_scale = 1.0
	check(not res.is_empty(), "bot produced a result")
	check(int(res.get("errors", 0)) == 0, "no engine errors while playing: %s" % str(res.get("log", [])))
	check(float(res.get("sim_time", 0.0)) > 5.0, "bot ran for >5 simulated seconds: %s" % str(res.get("sim_time")))
	var fp: Array = res.get("final_pos", [0, 0, 0])
	var start := Vector2(18.0, 110.0)  # e1m1 start cell (4,27) centre
	var moved: float = Vector2(float(fp[0]), float(fp[2])).distance_to(start)
	check(moved > 6.0 or int(res.get("kills", 0)) > 0 or bool(res.get("reached_exit", false)), "bot made progress (moved %.1f m, %d kills)" % [moved, int(res.get("kills", 0))])
	check(int(res.get("stuck_events", 0)) < 8, "not stuck: %d stuck events" % int(res.get("stuck_events", 0)))
