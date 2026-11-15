class_name QaLogCapture
extends Logger
## Captures engine errors and warnings (script errors, push_error/push_warning) while the QA bot plays.
## Registered with OS.add_logger; thread-safe because the engine may log from worker threads.

const MAX_KEPT: int = 40

var errors: int = 0
var warnings: int = 0
var messages: PackedStringArray = []
var _mutex: Mutex = Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	var is_warning: bool = error_type == Logger.ERROR_TYPE_WARNING
	if is_warning:
		warnings += 1
	else:
		errors += 1
	if messages.size() < MAX_KEPT:
		var text: String = rationale if rationale != "" else code
		messages.append("%s %s (%s:%d %s)" % ["WARN" if is_warning else "ERR", text.strip_edges(), file.get_file(), line, function])
	_mutex.unlock()


func snapshot() -> Dictionary:
	_mutex.lock()
	var d: Dictionary = {"errors": errors, "warnings": warnings, "messages": Array(messages)}
	_mutex.unlock()
	return d
