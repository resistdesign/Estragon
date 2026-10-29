extends SceneTree
const Dependencies = preload("res://addons/estragon/editor/script_dependencies.gd")
const Build = preload("res://addons/estragon/editor/build_service.gd")
var _failed: bool = false
var _checks: int = 0
var _temporary: DirAccess
var _project: String
var _expected_errors: int = 0
class Capture extends Logger:
	var count: int = 0
	var mutex := Mutex.new()
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _notify: bool, kind: int, _traces: Array[ScriptBacktrace]) -> void:
		if kind == ERROR_TYPE_WARNING: return
		mutex.lock()
		count += 1
		mutex.unlock()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native build: " + message)

func _write(path: String, text: String) -> void:
	var full := _project.path_join(path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(_project.path_join(path))

func _build() -> Dictionary:
	return Build.run_build(_project)

func _run() -> void:
	var errors := Capture.new()
	OS.add_logger(errors)
	_temporary = DirAccess.create_temp("estragon-native-build")
	_project = _temporary.get_current_dir()
	_write("ui/Main.gogo", '<VBox><Rect width="10"/></VBox>')
	_write("ui/Other.gogo", 'extends RefCounted\nfunc build():\n    return <Text text="OK"/>\n')
	for name in ["addons", "vendor", "node_modules", "tests", "generated", ".hidden"]:
		_write(name + "/Invalid.gogo", "<Unknown/>")
	var report := _build()
	_check(report.ok and report.outputs == ["ui/generated/Main.gd", "ui/generated/Other.gd"], "no-config discovery excludes unrelated roots and sorts outputs")
	_check(FileAccess.file_exists(_project.path_join("ui/generated/Other.gd.map.json")), "hybrid sidecar emitted")
	var original := _read("ui/generated/Main.gd")
	var original_map := _read("ui/generated/Other.gd.map.json")
	var modified := FileAccess.get_modified_time(_project.path_join("ui/generated/Main.gd"))
	var uid_text := ResourceUID.id_to_text(ResourceUID.create_id()) + "\n"
	_write("ui/generated/Main.gd.uid", uid_text)
	report = _build()
	_check(report.ok and report.changed.is_empty(), "unchanged build performs no writes")
	_check(FileAccess.get_modified_time(_project.path_join("ui/generated/Main.gd")) == modified and _read("ui/generated/Main.gd.uid") == uid_text, "no-op preserves timestamps/UIDs")
	_write("ui/Main.gogo", '<VBox><Rect width="20"/></VBox>')
	_write("ui/Other.gogo", "<Unknown/>")
	report = _build()
	_check(not report.ok and report.changed.is_empty() and _read("ui/generated/Main.gd") == original, "frontend failure preserves every prior output")
	_write("ui/Other.gogo", 'extends RefCounted\nfunc build():\n    return <Text text={42}/>\n')
	report = _build()
	_expected_errors += report.diagnostics.size()
	_check(not report.ok and "ui/Other.gogo:" in str(report.diagnostics), "semantic failure reports authored source")
	_check(_read("ui/generated/Main.gd") == original and _read("ui/generated/Other.gd.map.json") == original_map and report.changed.is_empty(), "semantic failure rolls back code and maps for all files")
	_check(FileAccess.get_modified_time(_project.path_join("ui/generated/Main.gd")) == modified, "rollback preserves original timestamp")
	_write("ui/Other.gogo", '<Button text="fixed"/>')
	report = _build()
	_check(report.ok and _read("ui/generated/Main.gd").contains("20.0"), "repair publishes every current source")
	_check(not FileAccess.file_exists(_project.path_join("ui/generated/Other.gd.map.json")), "standalone transition removes obsolete hybrid map")
	_write("gogo.config.json", '{"version":1,"source_roots":["ui", "ui/Main.gogo"]}')
	report = _build()
	_check(report.ok and report.outputs.size() == 2, "explicit overlapping roots deduplicate")
	for config in ['{}', '{"version":1,"source_roots":["../outside"]}', '{"version":1,"source_roots":["tests"]}', '{"version":1,"source_roots":["missing"]}', '{"version":1,"source_roots":["ui"],"extra":true}', 'invalid json']:
		_write("gogo.config.json", config)
		report = _build()
		_check(not report.ok and not report.diagnostics.is_empty(), "malformed/invalid configuration blocks")
	_write("gogo.config.json", '{"version":1,"source_roots":["ui"]}')
	var link_directory := DirAccess.open(_project)
	_check(link_directory.create_link(_project.path_join("ui"), "linked") == OK, "source symlink fixture created")
	_write("gogo.config.json", '{"version":1,"source_roots":["linked"]}')
	report = _build()
	_check(not report.ok and "Symlinks" in str(report.diagnostics), "symlink source roots rejected")
	_check(link_directory.create_link(_project.path_join("ui/generated/Main.gd"), "ui/generated/Other.gd.map.json") == OK, "output symlink fixture created")
	_write("gogo.config.json", '{"version":1,"source_roots":["ui"]}')
	report = _build()
	_check(not report.ok and "Symlinks" in str(report.diagnostics), "symlink output rejected before mutation")
	DirAccess.remove_absolute(_project.path_join("ui/generated/Other.gd.map.json"))
	_dependencies()
	_inheritance()
	_dependency_literals()
	OS.remove_logger(errors)
	_check(errors.count == _expected_errors, "all engine errors belong to expected semantic rejections")
	print("Native build assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_BUILD_OK")
	quit(1 if _failed else 0)

func _dependencies() -> void:
	_write("gogo.config.json", '{"version":1,"source_roots":["dependency"]}')
	_write("dependency/A.gogo", 'extends RefCounted\nfunc value() -> int:\n    return 1\n')
	_write("dependency/B.gogo", 'extends RefCounted\nconst Peer = preload("A.gd")\nfunc value() -> int:\n    return Peer.new().value()\n')
	var report := _build()
	_check(report.ok, "fresh multi-file generated preload validates")
	var path := _project.path_join("dependency/generated/B.gd")
	var cached := load(path)
	_check(cached.new().value() == 1, "initial generated dependency executes")
	_write("dependency/A.gogo", 'extends RefCounted\nfunc value() -> String:\n    return "latest"\n')
	report = _build()
	_expected_errors += report.diagnostics.size()
	_check(not report.ok, "changed dependency type rejects outdated dependent before Play")
	_write("dependency/B.gogo", 'extends RefCounted\nconst Peer = preload("A.gd")\nfunc value() -> String:\n    return Peer.new().value()\n')
	report = _build()
	_check(report.ok, "changed multi-file dependency validates from current sources: " + str(report.diagnostics))
	_check(load(path) == cached and str(cached.new().value()) == "latest", "current cached dependency executes new code with identity preserved")

func _inheritance() -> void:
	_write("gogo.config.json", '{"version":1,"source_roots":["inheritance"]}')
	_write("inheritance/ZBase.gogo", 'extends RefCounted\nvar first: int = 1\n')
	_write("inheritance/ADerived.gogo", 'extends "ZBase.gd"\nfunc value() -> int:\n    return first\n')
	_check(_build().ok, "generated inheritance validates despite reversed filename order")
	var path := _project.path_join("inheritance/generated/ADerived.gd")
	var script := load(path) as GDScript
	var instance = script.new()
	instance.first = 17
	_write("inheritance/ZBase.gogo", 'extends RefCounted\nvar first: int = 1\nvar second: int = 2\n')
	_write("inheritance/ADerived.gogo", 'extends "ZBase.gd"\nfunc value() -> int:\n    return first + second\n')
	var report := _build()
	_check(report.ok and load(path) == script, "base-first refresh preserves derived Script identity")
	_check(instance.first == 17 and script.new().value() == 3, "base-first reload preserves state and fresh inherited defaults")

func _dependency_literals() -> void:
	var code := 'extends "Base.gd"\n# preload("Ignored.gd")\nconst TEXT = "extends Fake"\nconst RAW = preload(r"Raw.gd")\nconst UNICODE = preload("Unicode\\u0041.gd")\nconst MULTI = preload("""Multi.gd""")\n'
	var paths := Dependencies.paths(code, "res://ui/generated/Current.gd")
	_check(paths == PackedStringArray(["res://ui/generated/Base.gd", "res://ui/generated/Raw.gd", "res://ui/generated/UnicodeA.gd", "res://ui/generated/Multi.gd"]), "dependency lexer ignores comments/strings and respects native string literal semantics")
