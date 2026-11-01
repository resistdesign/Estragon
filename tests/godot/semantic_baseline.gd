extends SceneTree
## No Logger dependency in the test: older engines use native errors. The outer
## harness must count the single expected error in the invalid mode.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")

func _initialize() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	var target := GDScript.new()
	target.resource_path = "res://SemanticBaseline.gd"
	if mode == "invalid":
		var compilation := Compiler.compile("extends RefCounted\nfunc value():\n    return missing_semantic_value\n", "Invalid.gogo")
		assert(compilation.ok)
		var result := Validation.reload_script(compilation, target)
		assert(not result.ok and result.generated_script == null and result.diagnostics.size() == 1)
		assert(result.diagnostics[0].source_name == "Invalid.gogo")
		if ClassDB.class_exists("Logger"):
			assert(result.diagnostics[0].span.start.line == 3)
		else:
			assert(result.diagnostics[0].message.contains("exact authored location unavailable"))
		print("SEMANTIC_BASELINE_DIAGNOSTIC ", result.diagnostics[0].format())
	elif mode == "valid":
		var compilation := Compiler.compile("extends RefCounted\nvar value: int = 9\n", "Valid.gogo")
		var result := Validation.reload_script(compilation, target)
		assert(result.ok and result.generated_script.new().value == 9)
	else:
		var path := "res://tests/godot/generated/NativeNamed.gd"
		var cached = load(path)
		var original: String = cached.source_code
		var source := FileAccess.get_file_as_string("res://tests/fixtures/native-named.gogo")
		source += '\nconst Relative = preload("../../../addons/estragon/runtime/rect.gd")\nfunc candidate_value() -> int: return 7\n'
		if mode == "isolated_failure": source = source.replace("return 7", "return missing_candidate_value")
		var result := Validation.validate(Compiler.compile(source, "Named.gogo"), path)
		if not Validation.supports_isolated_path():
			assert(not result.ok and result.generated_script == null and not result.diagnostics.is_empty())
			print("SEMANTIC_ISOLATED_CONTEXT_BLOCKED")
		elif mode == "isolated_failure":
			assert(not result.ok and result.generated_script == null and not result.diagnostics.is_empty())
		else:
			assert(result.ok and result.generated_script != cached)
			assert(result.generated_script.new().candidate_value() == 7)
			for base in ["../../../addons/estragon/runtime/rect.gd", "res://addons/estragon/runtime/rect.gd"]:
				var inherited := Validation.validate(Compiler.compile('extends "' + base + '"\nvar marker: int = 7\n'), path)
				assert(inherited.ok and inherited.generated_script.new().marker == 7)
		assert(load(path) == cached and cached.source_code == original and cached.new().value == 3)
		assert(not cached.new().has_method("candidate_value"))
	print("ESTRAGON_SEMANTIC_BASELINE_OK")
	quit(0)
