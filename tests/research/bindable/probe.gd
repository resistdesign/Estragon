extends SceneTree
## Each mode runs in a fresh project/process: caches cannot mask failures.
const Loader = preload("loader.gd")
const Capture = preload("capture.gd")
const Language = preload("language.gd")
var failed: bool = false
var checks: int = 0
var changes: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	print("R01_CHECK ", message, ": ", condition)
	failed = failed or not condition

func _initialize() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	print("R01_MODE ", mode)
	check(OS.get_environment("PATH").ends_with("/no-tools"), "no external tools on PATH")
	var original := FileAccess.get_file_as_bytes("res://model.gd")
	var loader := Loader.new()
	loader.generic_type = mode.ends_with("-generic")
	ResourceLoader.add_resource_format_loader(loader, true)
	var capture := Capture.new()
	OS.add_logger(capture)
	match mode:
		"baseline":
			var raw := GDScript.new()
			raw.set_path_cache("res://model.gd")
			raw.source_code = original.get_string_from_utf8()
			check(raw.reload() == ERR_PARSE_ERROR, "direct GDScript rejects @Bindable")
			check(loader.calls.is_empty(), "direct reload bypasses resource loader")
		"explicit":
			var script: GDScript = ResourceLoader.load("res://model.gd", "GDScript")
			check(script != null and script.can_instantiate(), "explicit load intercepts source")
			check(loader.calls == ["res://model.gd"], "front loader invoked once")
			if script != null and script.can_instantiate():
				var model: RefCounted = script.new()
				model.changed.connect(func(property: StringName, previous: Variant, current: Variant): changes.append([property, previous, current]))
				check(model.count == 7 and model.title == "initial" and model.notification_count == 0 and changes.is_empty(), "typed non-Node initialization")
				model.increment()
				model.count = 8
				model.set("count", 9)
				model.title = "updated"
				model.title = "updated"
				check(changes == [[&"count", 7, 8], [&"count", 8, 9], [&"title", "initial", "updated"]] and model.notification_count == 3, "ordinary assignments notify once; equality suppressed")
				var cached := ResourceLoader.load("res://model.gd")
				print("R01_CACHE ", cached == script, " calls ", loader.calls)
				check(cached != script and loader.calls.size() == 2, "fixture loader does not establish native script cache identity")
				check(script.is_tool(), "transformed tool flag survives")
				check(script.source_code != original.get_string_from_utf8(), "resource exposes generated rather than authored source")
		"remap-preload", "remap-inheritance", "remap-inheritance-warm":
			var warm: Resource
			if mode.ends_with("-warm"):
				warm = ResourceLoader.load("res://model.gd")
			var consumer := GDScript.new()
			consumer.set_path_cache("res://consumer.gd")
			consumer.source_code = 'extends RefCounted\nconst Model = preload("res://model.gd")\nfunc make(): return Model.new()\n' if mode == "remap-preload" else 'extends "res://model.gd"\n'
			var result := consumer.reload()
			print("R01_REMAP_RESULT ", result, " loader calls ", loader.calls)
			check(result == OK, "sidecar remapping supports native dependency parsing")
			if mode == "remap-inheritance":
				check(not consumer.get_base_script().can_instantiate(), "cold remapped base is not executable despite successful reload")
			elif result == OK:
				var instance = consumer.new()
				var model = instance.make() if mode == "remap-preload" else instance
				model.increment()
				check(model.count == 8, "remapped model executes")
		"preload", "inheritance", "preload-generic", "inheritance-generic", "preload-warm", "inheritance-warm":
			var warm: Resource
			if mode.ends_with("-warm"):
				warm = ResourceLoader.load("res://model.gd")
			var consumer := GDScript.new()
			consumer.set_path_cache("res://consumer.gd")
			consumer.source_code = 'extends RefCounted\nconst Model = preload("res://model.gd")\n' if mode.begins_with("preload") else 'extends "res://model.gd"\n'
			var result := consumer.reload()
			print("R01_CONSUMER_RESULT ", result, " loader calls ", loader.calls)
			check(result != OK, "native dependency parser rejects authored annotation")
		"language":
			var collision := Language.new()
			collision.extension = "gd"
			check(Engine.register_script_language(collision) == ERR_ALREADY_EXISTS, "cannot register replacement gd language")
			collision.free()
		_:
			check(false, "known mode")
	OS.remove_logger(capture)
	var diagnostics := capture.snapshot()
	print("R01_DIAGNOSTICS ", diagnostics)
	match mode:
		"baseline":
			check(diagnostics.size() == 1 and diagnostics[0].file == "res://model.gd" and diagnostics[0].line == 5 and diagnostics[0].message == 'Parse Error: Unrecognized annotation: "@Bindable".', "exact authored parser diagnostic")
		"explicit", "remap-preload", "remap-inheritance", "remap-inheritance-warm":
			check(diagnostics.is_empty(), "positive runtime has no errors")
		"language":
			check(diagnostics.size() == 1 and diagnostics[0].message == "A script language with extension 'gd' is already registered.", "only expected language collision")
		_:
			check(diagnostics.size() == (2 if mode == "preload" else 1), "only expected dependency errors")
			for diagnostic in diagnostics:
				check(diagnostic.file == "res://consumer.gd" and diagnostic.line == (2 if mode.begins_with("preload") else 1) and ('script "res://model.gd"' in diagnostic.message or 'inheritance from "res://model.gd"' in diagnostic.message), "dependency diagnostic path and line")
			check(loader.calls.size() == (1 if mode.ends_with("-warm") or mode == "preload-generic" else 0), "dependency loader interception count")
	check(FileAccess.get_file_as_bytes("res://model.gd") == original, "authored gd bytes unchanged")
	ResourceLoader.remove_resource_format_loader(loader)
	print("R01_RESULT ", mode, " ", checks, " ", "FAIL" if failed else "OK")
	quit(1 if failed else 0)
