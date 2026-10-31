@tool
extends RefCounted
## Explicit Godot semantic validation, separate from deterministic source emission.
## Uses native Logger only for the synchronous reload window; never spawns tools.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")

class Validation extends RefCounted:
	var generated_script: GDScript
	var diagnostics: Array[Model.Diagnostic] = []
	var ok: bool:
		get: return generated_script != null and diagnostics.is_empty()

# This source is text so old editors never parse unsupported native base/types.
# It contains only the bundled logger adapter, never authored application code.
static func _capture(path: String) -> Object:
	if not ClassDB.class_exists("Logger") or not ClassDB.class_exists("ScriptBacktrace"):
		return null
	if not OS.has_method("add_logger") or not OS.has_method("remove_logger"):
		return null
	var factory := GDScript.new()
	factory.source_code = FileAccess.get_file_as_string("res://addons/estragon/compiler/diagnostic_capture.gd.txt")
	if factory.reload() != OK: return null # Native errors remain visible.
	var logger = factory.new()
	logger.path = path
	return logger

static func supports_isolated_path() -> bool:
	return GDScript.new().has_method("set_path_cache")

static func validate(compilation: Compiler.Compilation, generated_path: String = "res://Generated.gd") -> Validation:
	var result := Validation.new()
	if not compilation.ok:
		result.diagnostics.assign(compilation.diagnostics)
		return result
	var script := GDScript.new()
	if not supports_isolated_path():
		var diagnostic := Model.Diagnostic.new()
		diagnostic.source_name = compilation.source_map.source.name
		diagnostic.span = compilation.source_map.source.span(0)
		diagnostic.message = "This Godot lacks isolated script-path assignment; no candidate was validated or cached script modified (C01-E legacy contract pending)"
		result.diagnostics.append(diagnostic)
		return result
	# Resource's cache-only setter avoids ownership transfer. On 4.4/4.5 the
	# same-path ordinary setter also establishes GDScript's internal parser path.
	# Resource returns before touching cache ownership because paths already match.
	script.call("set_path_cache", generated_path)
	script.resource_path = generated_path
	return reload_script(compilation, script)

## Explicit editor publication step; callers retain Resource identity and state.
## validate() above remains isolated from the application's resource cache.
static func reload_script(compilation: Compiler.Compilation, script: GDScript, keep_state: bool = false) -> Validation:
	var result := Validation.new()
	if not compilation.ok:
		result.diagnostics.assign(compilation.diagnostics)
		return result
	script.source_code = compilation.code
	var logger = _capture(script.resource_path)
	if logger != null: OS.call("add_logger", logger)
	var error := script.reload(keep_state)
	var messages: Array = []
	if logger != null:
		OS.call("remove_logger", logger)
		messages = logger.snapshot()
	for message in messages:
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
		diagnostic.message = "Godot rejected generated GDScript (%s); exact authored location unavailable here, inspect native engine diagnostics" % error_string(error)
		result.diagnostics.append(diagnostic)
	if error == OK and result.diagnostics.is_empty(): result.generated_script = script
	return result
