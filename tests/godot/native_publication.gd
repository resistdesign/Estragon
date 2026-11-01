extends SceneTree
## Dedicated isolated project only. The outer harness counts native diagnostics;
## this test never suppresses errors or requires Logger on old engines.
const Build = preload("res://addons/estragon/editor/build_service.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")
var _failed := false
var _checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> bool:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native publication: " + message)
	return value

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _config(folder: String) -> void:
	_write("res://gogo.config.json", JSON.stringify({"version": 1, "source_roots": [folder]}))

func _build() -> Dictionary:
	var report := Build.run_build()
	if report.ok:
		_check(report.isolated_preflight.status == ("PASS" if Validation.supports_isolated_path() else "BLOCKED"), "preflight capability is separate from actual publication success")
	return report

func _run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	if mode == "registered": _registered()
	elif mode == "fresh_failure": _fresh_failure()
	else: _dependencies(mode == "rollback")
	var minimum := {"registered": 7, "positive": 11, "rollback": 15, "fresh_failure": 5}
	_check(_checks >= minimum[mode], "all publication phases executed")
	print("Native publication assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_PUBLICATION_OK")
	quit(1 if _failed else 0)

func _registered() -> void:
	_config("ui")
	var path := "res://ui/generated/Registered.gd"
	var cached = load(path)
	var live = cached.new()
	live.state = 17
	_write("res://ui/Registered.gogo", "class_name EstragonPublicationProbe\nextends RefCounted\nvar state: int = 1\nfunc value() -> int: return 2\n")
	var report := _build()
	if not _check(report.ok, "registered publication validates: " + str(report.diagnostics)): return
	_check(load(path) == cached and cached.new().value() == 2, "registered Script identity and fresh bytecode")
	_check(live.state == 17 and live.value() == 2, "registered live state survives publication")
	var source: String = cached.source_code
	var timestamp := FileAccess.get_modified_time(path)
	_write(path + ".uid", "uid://c01epreserved\n")
	# Source equality is not bytecode freshness: a cached Script can have its
	# source reset without reloading the previously compiled implementation.
	cached.source_code = source.replace("return 2", "return 91")
	_check(cached.reload(true) == OK and live.value() == 91, "stale bytecode fixture established")
	cached.source_code = source
	report = _build()
	_check(report.ok and report.changed.is_empty() and cached.source_code == source and live.value() == 2, "unchanged publication refreshes actual cached bytecode")
	_check(FileAccess.get_modified_time(path) == timestamp and FileAccess.get_file_as_string(path + ".uid") == "uid://c01epreserved\n", "no-op preserves bytes/timestamp/UID")

func _dependencies(rollback: bool) -> void:
	_config("dependency")
	var a := "res://dependency/A.gogo"
	var b := "res://dependency/B.gogo"
	_write(a, "extends RefCounted\nfunc value() -> int: return 1\n")
	_write(b, 'extends RefCounted\nconst Peer = preload("A.gd")\nvar state: int = 1\nfunc value() -> int: return Peer.new().value()\n')
	var report := _build()
	if not _check(report.ok, "fresh dependency publication: " + str(report.diagnostics)): return
	var path := "res://dependency/generated/B.gd"
	var cached = load(path)
	var live = cached.new()
	live.state = 17
	_check(live.value() == 1, "initial dependent bytecode")
	var old_source: String = cached.source_code
	var old_file := FileAccess.get_file_as_string(path)
	var old_map := FileAccess.get_file_as_string(path + ".map.json")
	var timestamp := FileAccess.get_modified_time(path)
	_write(a, 'extends RefCounted\nfunc value() -> String: return "latest"\n')
	if rollback:
		report = _build()
		if not _check(not report.ok and not report.diagnostics.is_empty() and report.changed.is_empty(), "changed dependency rejects stale dependent type"): return
		_check(FileAccess.get_file_as_string(path) == old_file and FileAccess.get_file_as_string(path + ".map.json") == old_map, "failed transaction restores code and map")
		_check(FileAccess.get_modified_time(path) == timestamp, "failed transaction restores timestamp")
		_check(load(path) == cached and cached.source_code == old_source and live.value() == 1 and live.state == 17, "rollback restores cached identity/bytecode and live state")
	_write(b, 'extends RefCounted\nconst Peer = preload("A.gd")\nvar state: int = 1\nfunc value() -> String: return Peer.new().value()\n')
	report = _build()
	if not _check(report.ok, "current dependency repair validates: " + str(report.diagnostics)): return
	_check(load(path) == cached and str(live.value()) == "latest" and live.state == 17, "repair refreshes same Script and live state")
	_config("inheritance")
	_write("res://inheritance/ZBase.gogo", "extends RefCounted\nvar first: int = 1\n")
	_write("res://inheritance/ADerived.gogo", 'extends "ZBase.gd"\nfunc value() -> int: return first\n')
	report = _build()
	if not _check(report.ok, "relative inheritance base-first despite filename order: " + str(report.diagnostics)): return
	var derived = load("res://inheritance/generated/ADerived.gd")
	var instance = derived.new()
	instance.first = 17
	_write("res://inheritance/ZBase.gogo", "extends RefCounted\nvar first: int = 1\nvar second: int = 2\n")
	_write("res://inheritance/ADerived.gogo", 'extends "ZBase.gd"\nfunc value() -> int: return first + second\n')
	report = _build()
	if not _check(report.ok, "inherited member update validates: " + str(report.diagnostics)): return
	_check(load("res://inheritance/generated/ADerived.gd") == derived and instance.first == 17 and instance.value() == 19 and derived.new().value() == 3, "inherited identity/live state/defaults preserved")

func _fresh_failure() -> void:
	_config("fresh_failure")
	var path := "res://fresh_failure/generated/Bad.gd"
	_write("res://fresh_failure/Bad.gogo", "extends RefCounted\nfunc value(): return missing_publication_value\n")
	var report := _build()
	_check(not report.ok and not report.diagnostics.is_empty() and report.changed.is_empty(), "unpublished semantic failure rejects build")
	_check(not FileAccess.file_exists(path) and not ResourceLoader.has_cached(path), "failed fresh output leaves neither file nor cached invalid Script")
	_write("res://fresh_failure/Bad.gogo", "extends RefCounted\nfunc value() -> int: return 9\n")
	report = _build()
	if not _check(report.ok, "fresh failure recovers: " + str(report.diagnostics)): return
	_check(load(path).new().value() == 9, "recovery executes current valid code")
