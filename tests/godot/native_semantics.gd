extends SceneTree
## Expected engine errors are counted explicitly; all other errors fail the test.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")
var _checks: int = 0
var _failed: bool = false
var _expected_errors: int = 0

class Capture extends RefCounted:
	var native: Object
	var messages: Array[String]:
		get: return native.messages if native != null else []
	func start() -> void:
		if not ClassDB.class_exists("Logger"): return
		var factory := GDScript.new()
		factory.source_code = FileAccess.get_file_as_string("res://tests/godot/semantic_capture.gd.txt")
		if factory.reload() == OK:
			native = factory.new()
			OS.call("add_logger", native)
	func stop() -> void:
		if native != null: OS.call("remove_logger", native)

var _candidate_index := 0

func _validate(compilation: Compiler.Compilation, path: String = "res://Generated.gd") -> Validation.Validation:
	if Validation.supports_isolated_path(): return Validation.validate(compilation, path)
	# Explicit fresh actual-path test publication. This is NOT an isolated
	# cached-path fallback; that capability is checked as unavailable below.
	_candidate_index += 1
	var script := GDScript.new()
	script.resource_path = "res://semantic-fixtures/Candidate%d.gd" % _candidate_index
	return Validation.reload_script(compilation, script)

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native semantics: " + message)

func _run() -> void:
	var all_errors := Capture.new()
	all_errors.start()
	var negatives := [
		["syntax", '<Rect width={1 +}/>', 1], ["type", '<Rect width={"wide"}/>', 2],
		["child", '<VBox>{42}</VBox>', 1], ["unknown", '<Rect width={missing_value}/>', 1],
		["callback-call", '<Button pressed={int(42)}/>', 2], ["callback-missing", '<Button pressed={missing_handler}/>', 1], ["callback-type", '<Button pressed={42}/>', 2],
		["text-type", '<Text text={42}/>', 2], ["disabled-type", '<Button disabled={"yes"}/>', 2]
	]
	for item in negatives:
		var compilation := Compiler.compile("extends RefCounted\nfunc build():\n    return " + item[1] + "\n", item[0] + ".gogo")
		_check(compilation.ok, "dynamic semantics defer to Godot " + item[0])
		var logger := Capture.new()
		logger.start()
		var result := _validate(compilation)
		logger.stop()
		_check(not result.ok and result.generated_script == null and not result.diagnostics.is_empty(), "semantic error exposes no executable " + item[0])
		if logger.native != null:
			_check(logger.messages.size() == result.diagnostics.size() and not logger.messages.is_empty(), "all Godot errors captured " + item[0])
			_check(logger.messages.size() == item[2], "exact native semantic error count " + item[0])
			_check(result.diagnostics[0].span.start.line == 3, "authored semantic location " + item[0])
		else:
			_check(result.diagnostics[0].message.contains("exact authored location unavailable"), "honest baseline native diagnostic " + item[0])
		_expected_errors += item[2]
		_check(result.diagnostics[0].source_name == item[0] + ".gogo", "authored semantic source " + item[0])
		print("EXPECTED_NATIVE_DIAGNOSTIC ", result.diagnostics[0].format())
	# Invalid Callables are values requiring runtime metadata, not static rejection.
	for item in [["arity", "handler", "func handler(value: int) -> void: pass\n"], ["optional", "handler", "func handler(value: int = 1) -> void: pass\n"], ["empty", "Callable()", ""], ["invalid", 'Callable(self, "missing")', ""]]:
		var compilation := Compiler.compile("extends RefCounted\n" + item[2] + "func build():\n    return <Button pressed={" + item[1] + "}/>\n", item[0] + ".gogo")
		var result := _validate(compilation)
		_check(result.ok, "callable value is statically valid " + item[0])
		var logger := Capture.new()
		logger.start()
		var module = result.generated_script.new()
		var button: EstragonButton = module.build()
		logger.stop()
		var rejected: bool = item[0] not in ["arity", "optional"] or Engine.get_version_info()["minor"] >= 3
		if logger.native != null:
			_check(logger.messages.size() == (1 if rejected else 0), "exact runtime callback diagnostic count " + item[0])
			if rejected: _check(logger.messages[0].contains(item[0] + ".gogo:") and logger.messages[0].contains("zero-argument Callable"), "authored runtime guard error " + item[0])
		_expected_errors += 1 if rejected else 0
		_check(button.pressed.get_connections().size() == (0 if rejected else 1), "version-appropriate callback contract " + item[0])
		var surface := EstragonSurface.new()
		surface.set_root(button)
		surface.free()
		_check(button.is_disposed(), "invalid callback component uses owner cleanup")
		print("EXPECTED_NATIVE_CALLBACK_REJECTION " if rejected else "EXPECTED_NATIVE_CALLBACK_DEFERRED ", item[0])
	_runtime_children()
	_literal_values()
	_validation_scope()
	all_errors.stop()
	if all_errors.native != null:
		_check(all_errors.messages.size() == _expected_errors, "no unexpected engine errors outside expected probes")
	print("EXPECTED_NATIVE_ERROR_COUNT ", _expected_errors)
	print("Native semantic assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_SEMANTICS_OK")
	quit(1 if _failed else 0)

func _literal_values() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://numeric_cases.json"))
	for item in fixture.cases + fixture.native_parser_limits:
		var number: String = item.source
		var result := _validate(Compiler.compile('<Rect width="' + number + '"/>'))
		_check(result.ok, "float token compiles " + number)
		var surface: EstragonSurface = result.generated_script.new()
		var bytes := PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, surface.get_root().width)
		if fixture.cases.has(item):
			_check(bytes.hex_encode() == item.expected_bits, "independent double precision preserved " + number)
		else:
			# Owner-approved native parsing semantics; the isolated probe retains
			# the separate IEEE mismatch as BLOCKED, not a conversion success.
			_check(surface.get_root().width == number.to_float(), "native parsed value preserved " + number)
		surface.free()
	var text := 'café 🦎 "quote"\t\r\n\u0001\u001b'
	var result := _validate(Compiler.compile("<Text text='" + text + "'/>"))
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
	if not Validation.supports_isolated_path():
		var unavailable := Validation.validate(compilation, "res://examples/counter/generated/Counter.gd")
		_check(not unavailable.ok and unavailable.generated_script == null and not unavailable.diagnostics.is_empty(), "isolated cached identity is explicitly unavailable")
		_check(load("res://examples/counter/generated/Counter.gd") == cached and cached.source_code == original, "unavailable preflight never modifies cached application source")
	else:
		var result := _validate(compilation, "res://examples/counter/generated/Counter.gd")
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
	var next := _validate(Compiler.compile('extends RefCounted\nvar value: int = 9\n'))
	_check(next.ok and next.generated_script.new().value == 9, "validation recovers after prior failures")

func _runtime_children() -> void:
	var compilation := Compiler.compile("extends RefCounted\nfunc build():\n    return <VBox>{null}</VBox>\n", "NullChild.gogo")
	var validated := _validate(compilation)
	_check(validated.ok, "null child needs runtime ownership validation")
	var logger := Capture.new()
	logger.start()
	var tree: EstragonVBox = validated.generated_script.new().build()
	logger.stop()
	_expected_errors += 1
	if logger.native != null: _check(logger.messages.size() == 1 and logger.messages[0].contains("NullChild.gogo:3:") and logger.messages[0].contains("live, uniquely owned"), "null child guard reports authored location")
	_check(tree.get_child_count() == 0, "invalid child is never mounted")
	var surface := EstragonSurface.new()
	surface.set_root(tree)
	surface.free()
	var disposed := Compiler.compile("extends RefCounted\nclass Receiver extends EstragonRect:\n    func receive() -> void: pass\nvar receiver := Receiver.new()\nfunc build():\n    var owner := EstragonContainer.new()\n    owner.add_child(receiver)\n    owner.remove_child(receiver)\n    return <Button pressed={receiver.receive}/>\n", "Disposed.gogo")
	validated = _validate(disposed)
	_check(validated.ok, "retained terminal target is a runtime condition")
	logger = Capture.new()
	logger.start()
	var button: EstragonButton = validated.generated_script.new().build()
	logger.stop()
	_expected_errors += 1
	if logger.native != null: _check(logger.messages.size() == 1 and logger.messages[0].contains("Disposed.gogo:9:"), "disposed callback guard reports authored location")
	_check(button.pressed.get_connections().is_empty(), "terminal callback target never connected")
	surface = EstragonSurface.new()
	surface.set_root(button)
	surface.free()
