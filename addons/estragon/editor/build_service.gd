@tool
extends RefCounted
## Native project build. No editor UI, processes or external tool configuration.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")
const Dependencies = preload("res://addons/estragon/editor/script_dependencies.gd")
const CONFIG := "gogo.config.json"
const EXCLUDED := ["generated", "node_modules", "tests", "vendor"]
var _project: String
var _report := {"ok": false, "outputs": [], "changed": [], "diagnostics": []}
var _sources: Dictionary = {}
var _staging: String
var _previous_code: Dictionary = {}

static func run_build(project: String = "res://") -> Dictionary:
	var build := new()
	build._project = ProjectSettings.globalize_path(project).simplify_path().trim_suffix("/")
	return build._run()

func _fail(message: String) -> void:
	_report.diagnostics.append(message)

func _safe(path: String) -> bool:
	if not path.begins_with(_project + "/"):
		_fail("Generated/source path escapes the project: " + path)
		return false
	var current := path
	while current != _project:
		var directory := DirAccess.open(current.get_base_dir())
		if directory != null and directory.is_link(current.get_file()):
			_fail("Symlinks are not supported in Gogo source/output paths: " + path.trim_prefix(_project + "/"))
			return false
		current = current.get_base_dir()
	return true

func _discover() -> void:
	var config_path := _project.path_join(CONFIG)
	if not FileAccess.file_exists(config_path):
		_visit(_project, true)
		return
	if not _safe(config_path): return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(config_path)) != OK:
		_fail(CONFIG + ": " + json.get_error_message())
		return
	var config: Variant = json.data
	if not config is Dictionary or config.size() != 2 or config.get("version") != 1 or not config.get("source_roots") is Array or config.source_roots.is_empty():
		_fail(CONFIG + ": expected version 1 and nonempty project-relative source_roots only")
		return
	for source_root in config.source_roots:
		if not source_root is String or source_root.is_empty() or source_root.is_absolute_path() or ":" in source_root or "\\" in source_root:
			_fail(CONFIG + ": invalid source root " + str(source_root))
			continue
		var invalid := false
		for part in source_root.split("/"):
			if part.begins_with(".") or part in EXCLUDED: invalid = true
		if invalid:
			_fail(CONFIG + ": invalid source root " + source_root)
			continue
		var path := _project.path_join(source_root).simplify_path()
		if _safe(path): _visit(path)

func _visit(path: String, default_root: bool = false) -> void:
	if path != _project and not _safe(path): return
	if FileAccess.file_exists(path):
		if path.ends_with(".gogo"): _sources[path.trim_prefix(_project + "/")] = true
		return
	var directory := DirAccess.open(path)
	if directory == null:
		_fail("Cannot read Gogo source root: " + path.trim_prefix(_project + "/"))
		return
	var entries := Array(directory.get_directories()) + Array(directory.get_files())
	entries.sort()
	for name in entries:
		if name.begins_with(".") or name in EXCLUDED or default_root and name == "addons": continue
		_visit(path.path_join(name))

static func output_for(source: String) -> String:
	return source.get_base_dir().path_join("generated").path_join(source.get_file().trim_suffix(".gogo") + ".gd")

func _run() -> Dictionary:
	_discover()
	if not _report.diagnostics.is_empty(): return _report
	var sources := _sources.keys()
	sources.sort()
	var compiled: Array[Dictionary] = []
	for source in sources:
		var input := FileAccess.open(_project.path_join(source), FileAccess.READ)
		if input == null:
			_fail(source + ": cannot read source (" + error_string(FileAccess.get_open_error()) + ")")
			continue
		var result := Compiler.compile(input.get_as_text(), source)
		if not result.ok:
			for diagnostic in result.diagnostics: _fail(diagnostic.format())
		else: compiled.append({"source": source, "output": output_for(source), "result": result})
	if not _report.diagnostics.is_empty(): return _report
	var writes: Dictionary = {}
	for item in compiled:
		_report.outputs.append(item.output)
		writes[item.output] = item.result.code.to_utf8_buffer()
		writes[item.output + ".map.json"] = item.result.source_map.serialize().to_utf8_buffer() if item.result.mode == "hybrid" else null
	for path in writes:
		if not _safe(_project.path_join(path)): return _report
	# Stage new bytes; retain old files by rename so rollback preserves their
	# content and timestamps. No filesystem notifications until commit succeeds.
	var stage := _project.path_join(".godot/estragon/transaction-%d" % get_instance_id())
	_staging = stage
	if not _safe(stage): return _report
	if DirAccess.make_dir_recursive_absolute(stage) != OK:
		_fail("Cannot create native Gogo staging directory")
		return _report
	var operations: Array[Dictionary] = []
	for path in writes:
		var target := _project.path_join(path)
		var exists := FileAccess.file_exists(target)
		var bytes: Variant = writes[path]
		if bytes == null and not exists: continue
		if exists:
			var old_file := FileAccess.open(target, FileAccess.READ)
			if old_file == null:
				_fail("Cannot read existing generated output: " + path)
				_cleanup(operations)
				return _report
			var old_bytes := old_file.get_buffer(old_file.get_length())
			old_file.close()
			if path.ends_with(".gd"): _previous_code[path] = old_bytes.get_string_from_utf8()
			if bytes != null and old_bytes == bytes: continue
		var operation := {"path": path, "target": target, "old": stage.path_join("old-%d" % operations.size()), "new": stage.path_join("new-%d" % operations.size()), "existed": exists, "installed": false, "backed_up": false}
		if not _safe(operation.old) or not _safe(operation.new): return _report
		operations.append(operation)
		if bytes != null:
			var file := FileAccess.open(operation.new, FileAccess.WRITE)
			if file == null:
				_fail("Cannot stage generated output: " + path)
				_cleanup(operations)
				return _report
			file.store_buffer(bytes)
			file.flush()
			var write_error := file.get_error()
			file.close()
			if write_error != OK:
				_fail("Cannot write generated output: " + path)
				_cleanup(operations)
				return _report
	for operation in operations:
		if DirAccess.make_dir_recursive_absolute(operation.target.get_base_dir()) != OK:
			_fail("Cannot create generated directory: " + operation.path)
			break
		if operation.existed:
			if DirAccess.rename_absolute(operation.target, operation.old) != OK:
				_fail("Cannot back up generated output: " + operation.path)
				break
			operation.backed_up = true
		if writes[operation.path] != null:
			if DirAccess.rename_absolute(operation.new, operation.target) != OK:
				_fail("Cannot publish generated output: " + operation.path)
				break
			operation.installed = true
	var cache_state: Array[Dictionary] = []
	var refresh_all := operations.any(func(item: Dictionary) -> bool: return item.path.ends_with(".gd"))
	if _report.diagnostics.is_empty():
		compiled = _validation_order(compiled)
		for item in compiled:
			var checked := Validation.validate(item.result, _resource_path(item.output))
			for diagnostic in checked.diagnostics: _fail(diagnostic.format())
			if not checked.ok: break
			_refresh_cache(item, refresh_all, cache_state)
			if not _report.diagnostics.is_empty(): break
	if not _report.diagnostics.is_empty():
		_rollback(operations)
		_restore_cache(cache_state)
	else:
		for operation in operations: _report.changed.append(operation.path)
		_report.ok = true
	_cleanup(operations)
	return _report

func _rollback(operations: Array[Dictionary]) -> void:
	for index in range(operations.size() - 1, -1, -1):
		var operation := operations[index]
		if operation.installed and DirAccess.remove_absolute(operation.target) != OK:
			_fail("Cannot remove rejected output during rollback: " + operation.path)
		if operation.backed_up and DirAccess.rename_absolute(operation.old, operation.target) != OK:
			_fail("Cannot restore output; backup retained at " + operation.old)
			operation.backed_up = false # Preserve the backup for manual recovery.

func _cleanup(operations: Array[Dictionary]) -> void:
	for operation in operations:
		DirAccess.remove_absolute(operation.new)
		if operation.backed_up: DirAccess.remove_absolute(operation.old)
	DirAccess.remove_absolute(_staging)

func _resource_path(output: String) -> String:
	return "res://" + output if _project == ProjectSettings.globalize_path("res://").trim_suffix("/") else _project.path_join(output)

func _refresh_cache(item: Dictionary, force: bool, state: Array[Dictionary]) -> void:
	# GDScript also has an internal cache not exposed by get_cached_ref().
	# Loading the validated path retrieves its existing Script identity.
	var script := ResourceLoader.load(_resource_path(item.output), "GDScript") as GDScript
	if script == null:
		_fail("Cannot load validated generated script: " + item.output)
		return
	if not force and script.source_code == item.result.code: return
	state.append({"script": script, "previous": _previous_code.get(item.output, script.source_code), "output": item.output})
	var checked := Validation.reload_script(item.result, script, true)
	for diagnostic in checked.diagnostics: _fail(diagnostic.format())

func _restore_cache(state: Array[Dictionary]) -> void:
	for item in state: item.script.source_code = item.previous
	for item in state:
		if item.script.reload(true) != OK: _fail("Cannot restore cached script: " + item.output)

func _validation_order(compiled: Array[Dictionary]) -> Array[Dictionary]:
	var by_path: Dictionary = {}
	for item in compiled:
		by_path[_resource_path(item.output)] = item
		item.dependencies = Dependencies.paths(item.result.code, _resource_path(item.output))
	var ordered: Array[Dictionary] = []
	var visited: Dictionary = {}
	for item in compiled: _visit_dependencies(item, by_path, visited, ordered)
	return ordered

func _visit_dependencies(item: Dictionary, by_path: Dictionary, visited: Dictionary, ordered: Array[Dictionary]) -> void:
	if visited.has(item.output): return # Godot diagnoses illegal dependency cycles.
	visited[item.output] = true
	for path in item.dependencies:
		if by_path.has(path): _visit_dependencies(by_path[path], by_path, visited, ordered)
	ordered.append(item)
