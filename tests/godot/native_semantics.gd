extends SceneTree
## Expected engine errors are counted explicitly; all other errors fail the test.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")
var _checks: int = 0
var _failed: bool = false
var _expected_errors: int = 0

class Capture extends Logger:
	var messages: Array[String] = []
	var _mutex := Mutex.new()
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		_mutex.lock()
		messages.append(code if rationale.is_empty() else rationale)
		_mutex.unlock()

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native semantics: " + message)

func _run() -> void:
	var all_errors := Capture.new()
	OS.add_logger(all_errors)
	var negatives := [
		["syntax", '<Rect width={1 +}/>'], ["type", '<Rect width={"wide"}/>'],
		["child", '<VBox>{42}</VBox>'], ["unknown", '<Rect width={missing_value}/>'],
		["callback-call", '<Button pressed={int(42)}/>'], ["callback-missing", '<Button pressed={missing_handler}/>'], ["callback-type", '<Button pressed={42}/>'],
		["text-type", '<Text text={42}/>'], ["disabled-type", '<Button disabled={"yes"}/>']
	]
	for item in negatives:
		var compilation := Compiler.compile("extends RefCounted\nfunc build():\n    return " + item[1] + "\n", item[0] + ".gogo")
		_check(compilation.ok, "dynamic semantics defer to Godot " + item[0])
		var logger := Capture.new()
		OS.add_logger(logger)
		var result := Validation.validate(compilation)
		OS.remove_logger(logger)
		_check(not result.ok and result.generated_script == null and not result.diagnostics.is_empty(), "semantic error exposes no executable " + item[0])
		_check(logger.messages.size() == result.diagnostics.size() and not logger.messages.is_empty(), "all Godot errors captured " + item[0])
		_expected_errors += logger.messages.size()
		_check(result.diagnostics[0].span.start.line == 3 and result.diagnostics[0].source_name == item[0] + ".gogo", "authored semantic location " + item[0])
		print("EXPECTED_NATIVE_DIAGNOSTIC ", result.diagnostics[0].format())
	# Invalid Callables are values requiring runtime metadata, not static rejection.
	for item in [["arity", "handler", "func handler(value: int) -> void: pass\n"], ["optional", "handler", "func handler(value: int = 1) -> void: pass\n"], ["empty", "Callable()", ""], ["invalid", 'Callable(self, "missing")', ""]]:
		var compilation := Compiler.compile("extends RefCounted\n" + item[2] + "func build():\n    return <Button pressed={" + item[1] + "}/>\n", item[0] + ".gogo")
		var result := Validation.validate(compilation)
		_check(result.ok, "callable value is statically valid " + item[0])
		var logger := Capture.new()
		OS.add_logger(logger)
		var module = result.generated_script.new()
		var button: EstragonButton = module.build()
		OS.remove_logger(logger)
		_check(logger.messages.size() == 1 and logger.messages[0].contains(item[0] + ".gogo:") and logger.messages[0].contains("zero-argument Callable"), "one authored runtime guard error " + item[0])
		_expected_errors += 1
		_check(button.pressed.get_connections().is_empty(), "invalid callback is never connected " + item[0])
		var surface := EstragonSurface.new()
		surface.set_root(button)
		surface.free()
		_check(button.is_disposed(), "invalid callback component uses owner cleanup")
		print("EXPECTED_NATIVE_CALLBACK_REJECTION ", item[0])
	_runtime_children()
	_literal_values()
	_validation_scope()
	OS.remove_logger(all_errors)
	_check(all_errors.messages.size() == _expected_errors, "no unexpected engine errors outside expected probes")
	print("Native semantic assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_SEMANTICS_OK")
	quit(1 if _failed else 0)

func _literal_values() -> void:
	for number in ["0", "-0", "1e20", "1e-20", "3.141592653589793", "1.0000000000000002", "16777217", "3.4028234e38"]:
		var result := Validation.validate(Compiler.compile('<Rect width="' + number + '"/>'))
		_check(result.ok, "float token compiles " + number)
		var surface: EstragonSurface = result.generated_script.new()
		_check(surface.get_root().width == number.to_float(), "double precision preserved " + number)
		surface.free()
	var text := 'café 🦎 "quote"\t\r\n\u0001\u001b'
	var result := Validation.validate(Compiler.compile("<Text text='" + text + "'/>"))
	_check(result.ok, "escaped native literal compiles")
	var surface: EstragonSurface = result.generated_script.new()
	_check(surface.get_root().text == text, "control/Unicode characters preserved")
	surface.free()

func _validation_scope() -> void:
	var malformed := Compiler.compile('<Unknown/>', "Bad.gogo")
	var rejected := Validation.validate(malformed)
	_check(not rejected.ok and rejected.diagnostics[0].source_name == "Bad.gogo", "frontend errors bypass Godot reload")
	# Relative source references resolve in the generated directory. Validation
	# must not replace or modify the resource already cached at the output path.
	var cached := load("res://examples/counter/generated/Counter.gd")
	var original: String = cached.source_code
	var source := 'extends RefCounted\nconst Runtime = preload("../../../addons/estragon/runtime/rect.gd")\nfunc build():\n    return <Rect width="2"/>\n'
	var compilation := Compiler.compile(source, "Relative.gogo")
	var result := Validation.validate(compilation, "res://examples/counter/generated/Counter.gd")
	_check(result.ok, "relative preload resolved from output directory")
	_check(load("res://examples/counter/generated/Counter.gd") == cached and cached.source_code == original, "validation never replaces cached application script")
	var root_component: EstragonRect = result.generated_script.new().build()
	var surface := EstragonSurface.new()
	surface.set_root(root_component)
	surface.free()
	var named_path := "res://tests/godot/generated/NativeNamed.gd"
	var named_cached := load(named_path)
	var named_source := FileAccess.get_file_as_string("res://tests/fixtures/native-named.gogo") + "\nfunc current_value() -> int:\n    return 7\n"
	var named := Validation.validate(Compiler.compile(named_source, "Named.gogo"), named_path)
	_check(named.ok and named.generated_script.new().current_value() == 7 and not named_cached.new().has_method("current_value"), "registered class_name identity validates at the actual output path")
	_check(load(named_path) == named_cached and named.generated_script != named_cached, "class_name validation preserves cached resource identity")
	# No capture remains installed between calls, and successful validation
	# returns a separately owned native Script without constructing an instance.
	var next := Validation.validate(Compiler.compile('extends RefCounted\nvar value: int = 9\n'))
	_check(next.ok and next.generated_script.new().value == 9, "validation recovers after prior failures")

func _runtime_children() -> void:
	var compilation := Compiler.compile("extends RefCounted\nfunc build():\n    return <VBox>{null}</VBox>\n", "NullChild.gogo")
	var validated := Validation.validate(compilation)
	_check(validated.ok, "null child needs runtime ownership validation")
	var logger := Capture.new()
	OS.add_logger(logger)
	var tree: EstragonVBox = validated.generated_script.new().build()
	OS.remove_logger(logger)
	_expected_errors += 1
	_check(logger.messages.size() == 1 and logger.messages[0].contains("NullChild.gogo:3:") and logger.messages[0].contains("live, uniquely owned"), "null child guard reports authored location")
	_check(tree.get_child_count() == 0, "invalid child is never mounted")
	var surface := EstragonSurface.new()
	surface.set_root(tree)
	surface.free()
	var disposed := Compiler.compile("extends RefCounted\nclass Receiver extends EstragonRect:\n    func receive() -> void: pass\nvar receiver := Receiver.new()\nfunc build():\n    var owner := EstragonContainer.new()\n    owner.add_child(receiver)\n    owner.remove_child(receiver)\n    return <Button pressed={receiver.receive}/>\n", "Disposed.gogo")
	validated = Validation.validate(disposed)
	_check(validated.ok, "retained terminal target is a runtime condition")
	logger = Capture.new()
	OS.add_logger(logger)
	var button: EstragonButton = validated.generated_script.new().build()
	OS.remove_logger(logger)
	_expected_errors += 1
	_check(logger.messages.size() == 1 and logger.messages[0].contains("Disposed.gogo:9:"), "disposed callback guard reports authored location")
	_check(button.pressed.get_connections().is_empty(), "terminal callback target never connected")
	surface = EstragonSurface.new()
	surface.set_root(button)
	surface.free()
