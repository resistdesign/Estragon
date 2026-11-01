extends SceneTree
## Each strategy runs in a separate disposable project process. Deliberately
## unsafe strategies are evidence, never production fallbacks or passing gates.
const OUTPUT = "res://nested/Named.gd"

func _initialize() -> void:
	var cached = load(OUTPUT)
	var original: String = cached.source_code
	var mode: String = OS.get_cmdline_user_args()[0]
	var script := GDScript.new()
	var evidence := {"mode": mode, "version": Engine.get_version_info().string}
	if mode == "ignore":
		script = ResourceLoader.load(OUTPUT, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	elif mode == "alias":
		script.resource_path = OUTPUT + "::candidate"
	elif mode == "collision":
		script.resource_path = OUTPUT
	elif mode == "fresh":
		script.resource_path = "res://nested/Fresh.gd"
	elif script.has_method("set_path_cache"):
		script.set_path_cache(OUTPUT)
		if mode == "paired": script.resource_path = OUTPUT
	else:
		evidence["status"] = "BLOCKED"
		evidence["reason"] = "Resource.set_path_cache unavailable"
		print("ESTRAGON_CONTEXT_EVIDENCE ", JSON.stringify(evidence))
		quit(0)
		return
	script.source_code = ("" if mode == "fresh" else "class_name EstragonContextProbe\n") + 'extends RefCounted\nconst Dep = preload("../Dependency.gd")\nfunc value() -> int: return Dep.VALUE + 1\n'
	var error := script.reload()
	evidence["reload_error"] = error
	evidence["path"] = script.resource_path
	evidence["separate_candidate"] = script != cached
	evidence["source_unchanged"] = cached.source_code == original
	evidence["cached_value"] = cached.new().value()
	evidence["cache_identity_unchanged"] = load(OUTPUT) == cached
	if error == OK: evidence["candidate_value"] = script.new().value()
	# The collector also rejects ANY engine error, even when reload returns OK.
	evidence["status"] = "PASS" if error == OK and script != cached and cached.source_code == original and cached.new().value() == 1 and evidence.cache_identity_unchanged and evidence.get("candidate_value") == 41 else "FAIL"
	print("ESTRAGON_CONTEXT_EVIDENCE ", JSON.stringify(evidence))
	quit(0)
