@tool
extends Logger
## Verify exact negative results, including source paths/lines; do not suppress logs.
var messages: Array[Dictionary] = []
var mutex := Mutex.new()
func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, _error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
	mutex.lock()
	messages.append({"file": file, "line": line, "message": rationale if not rationale.is_empty() else code})
	mutex.unlock()
func snapshot() -> Array[Dictionary]:
	mutex.lock()
	var copy: Array[Dictionary] = messages.duplicate()
	mutex.unlock()
	return copy
