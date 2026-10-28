extends SceneTree
## Native emit/map tests and fixture preparation. Requires no external compiler.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
var _checks: int = 0
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native generation: " + message)

func _write(path: String, code: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "open generated fixture " + path)
	if file != null: file.store_string(code)

func _run() -> void:
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-frontend.json"))
	for case in cases:
		var result := Compiler.compile(case.source, case.id)
		_check(result.ok == case.ok, "frontend parity " + case.id)
		if not result.ok:
			_check(result.code.is_empty() and result.source_map == null, "invalid source emits nothing")
			continue
		var repeated := Compiler.compile(case.source, case.id)
		_check(result.code == repeated.code and result.source_map.serialize() == repeated.source_map.serialize(), "deterministic code/map " + case.id)
		_maps(result)
	var outputs := {"examples/compiled/Layout.gogo": "examples/compiled/generated/Layout.gd", "examples/mixed/Mixed.gogo": "examples/mixed/generated/Mixed.gd", "examples/counter/Counter.gogo": "examples/counter/generated/Counter.gd", "tests/fixtures/hybrid-edges.gogo": "tests/godot/generated/HybridEdges.gd", "tests/fixtures/signal-edges.gogo": "tests/godot/generated/SignalEdges.gd", "tests/fixtures/native-named.gogo": "tests/godot/generated/NativeNamed.gd"}
	var reference = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-generation.json"))
	for case in reference:
		_check(FileAccess.get_file_as_string("res://" + case.name) == case.source, "reference source matches authored example " + case.name)
		var result := Compiler.compile(case.source, case.name)
		_check(result.ok, "reference example compiles " + case.name)
		_write("res://" + outputs[case.name], result.code)
		_write("res://" + outputs[case.name] + ".map.json", result.source_map.serialize())
		if result.mode == "hybrid":
			# These fixtures contain no special float spelling. Range-mapped
			# hybrid generation intentionally matches the established reference.
			_check(result.code == case.code, "hybrid reference output " + case.name)
			_check(JSON.stringify(result.source_map.to_dictionary(), "", false).sha256_text() == case.mapDigest, "hybrid reference source map " + case.name)
	for pair in [["Primitives", '<VBox><Text text="Literal text" font_size="21" color="#ff990080"/><Button text="Literal button" disabled="true"/></VBox>'], ["Numbers", '<Rect width="1e20" height="0" fill="#12345678"/>'], ["Empty", '<HBox width="auto" height="auto" gap="0" fill_width="false"/>']]:
		_write("res://tests/godot/generated/" + pair[0] + ".gd", Compiler.compile(pair[1]).code)
	# Verify source slicing uses Unicode scalar indexes while coordinates stay UTF-16.
	var unicode := Compiler.compile('extends RefCounted\r\n# 🦎\r\nfunc build():\r\n\treturn <Text text={"🦎"}/>\r\n', "Unicode.gogo")
	_maps(unicode)
	_check(unicode.source_map.original_position(2, 5).column == 5, "copied astral UTF-16 coordinate")
	_check(unicode.source_map.original_position(999) == null, "unmapped lines stay unmapped")
	if OS.get_cmdline_user_args().has("--require-no-bun"):
		for directory in OS.get_environment("PATH").split(":", false):
			_check(not FileAccess.file_exists(directory.path_join("bun")) and not FileAccess.file_exists(directory.path_join("node")), "Bun/Node unavailable")
		print("NATIVE_GENERATION_NO_BUN")
	print("Native generation assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_GENERATION_OK")
	quit(1 if _failed else 0)

func _maps(result: Compiler.Compilation) -> void:
	var generated := Source.new(result.code)
	var previous: int = 0
	for segment in result.source_map.segments:
		_check(segment.generated.start.index >= previous and segment.generated.end.index > segment.generated.start.index, "ordered nonempty generated ranges")
		previous = segment.generated.end.index
		_check(segment.original.start.index <= segment.original.end.index and segment.original.end.index <= result.source_map.source.text.length(), "original range in source")
		if segment.kind == "copied":
			_check(generated.slice(segment.generated) == result.source_map.source.slice(segment.original), "authored code copied byte-for-byte")
			var point := result.source_map.original_position(segment.generated.start.line, segment.generated.start.column)
			_check(point.offset == segment.original.start.offset, "copied range maps to authored start")
