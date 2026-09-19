extends Logger
## Counts engine and script errors so headless runs can fail on them.

var errors: PackedStringArray = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
	_mutex.unlock()


func count() -> int:
	_mutex.lock()
	var n: int = errors.size()
	_mutex.unlock()
	return n
