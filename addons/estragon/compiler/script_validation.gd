extends RefCounted
## Optional Godot semantic validation, separate from deterministic source emission.
## Uses native Logger only for the synchronous reload window; never spawns tools.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")

class Validation extends RefCounted:
	var generated_script: GDScript
	var diagnostics: Array[Model.Diagnostic] = []
	var ok: bool:
		get: return generated_script != null and diagnostics.is_empty()

class Capture extends Logger:
	var path: String
	var messages: Array[Dictionary] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if file != path or error_type != ERROR_TYPE_SCRIPT: return
		_mutex.lock()
		messages.append({"line": line, "message": rationale if not rationale.is_empty() else code})
		_mutex.unlock()

	func snapshot() -> Array[Dictionary]:
		_mutex.lock()
		var copy: Array[Dictionary] = messages.duplicate()
		_mutex.unlock()
		return copy

static func validate(compilation: Compiler.Compilation, generated_path: String = "res://Generated.gd") -> Validation:
	var result := Validation.new()
	if not compilation.ok:
		result.diagnostics.assign(compilation.diagnostics)
		return result
	var script := GDScript.new()
	# Preserve relative references and registered class_name identity while
	# leaving any cached application script untouched (Godot 4.7 Resource API).
	script.set_path_cache(generated_path)
	script.source_code = compilation.code
	var logger := Capture.new()
	logger.path = script.resource_path
	OS.add_logger(logger)
	var error := script.reload()
	OS.remove_logger(logger)
	for message in logger.snapshot():
		var diagnostic := Model.Diagnostic.new()
		diagnostic.source_name = compilation.source_map.source.name
		var position := compilation.source_map.original_position(message.line)
		diagnostic.span = compilation.source_map.source.span(position.index if position != null else 0)
		diagnostic.message = message.message
		result.diagnostics.append(diagnostic)
	if error != OK and result.diagnostics.is_empty():
		var diagnostic := Model.Diagnostic.new()
		diagnostic.source_name = compilation.source_map.source.name
		diagnostic.span = compilation.source_map.source.span(0)
		diagnostic.message = "Godot rejected generated GDScript (%s); inspect engine diagnostics for dependency errors" % error_string(error)
		result.diagnostics.append(diagnostic)
	if error == OK and result.diagnostics.is_empty(): result.generated_script = script
	return result
