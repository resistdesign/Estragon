extends SceneTree
## Runs with only Godot. JSON below is a checked test transcript, not UI IR.
const Frontend = preload("res://addons/estragon/compiler/frontend.gd")
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const Lexer = preload("res://addons/estragon/compiler/lexer.gd")
var _checks: int = 0
var _failed: bool = false

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Native frontend: " + message)

func _position(point: Model.Position) -> Dictionary:
	return {"offset": point.offset, "line": point.line, "column": point.column}

func _span(bounds: Model.Span) -> Dictionary:
	return {"start": _position(bounds.start), "end": _position(bounds.end)}

func _node(node: Model.SyntaxNode) -> Dictionary:
	var value := {"kind": node.kind, "span": _span(node.span)}
	if node is Model.Component:
		value.name = node.name
		value.attributes = []
		for attribute in node.attributes: value.attributes.append({"kind": attribute.kind, "name": attribute.name, "value": _node(attribute.value)})
		value.children = []
		for child in node.children: value.children.append(_node(child))
	elif node is Model.GdExpression:
		value.parts = []
		for part in node.parts: value.parts.append(_node(part))
	elif node is Model.Literal: value.value = node.value
	return value

func _module(module: Model.Module) -> Dictionary:
	var parts: Array[Dictionary] = []
	for part in module.parts: parts.append(_node(part))
	return {"mode": module.mode, "parts": parts, "identifiers": Array(module.identifiers), "indentation": module.indentation}

func _run() -> void:
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native-frontend.json"))
	_check(cases is Array and cases.size() > 90, "checked reference corpus loads")
	if not cases is Array:
		quit(1)
		return
	for case in cases:
		var result := Frontend.analyze(case.source, case.id)
		_check(result.ok == case.ok, "acceptance parity: " + case.id + (" " + result.diagnostics[0].format() if not result.diagnostics.is_empty() else ""))
		if result.ok and case.get("tree") != null:
			var actual := _module(result.module)
			# JSON numbers load as floats; canonicalize native integer positions.
			_check(JSON.parse_string(JSON.stringify(actual)) == case.tree, "typed tree/span parity: " + case.id)
			if JSON.parse_string(JSON.stringify(actual)) != case.tree:
				print("ACTUAL ", case.id, " ", JSON.stringify(actual))
		elif not result.ok and not case.ok:
			_check(JSON.parse_string(JSON.stringify(_position(result.diagnostics[0].span.start))) == case.position, "diagnostic location parity: " + case.id)
			_check(result.module == null and result.diagnostics.size() == 1, "failed result has no typed module: " + case.id)
			_check(result.diagnostics[0].format().begins_with(case.id + ":"), "diagnostic includes source name")
		if result.ok:
			var reconstructed := ""
			for token in result.tokens: reconstructed += token.text
			_check(reconstructed == case.source, "lossless token coverage: " + case.id)
	_test_native_contract()
	_test_boundaries()
	print("Native frontend cases: ", cases.size(), "; assertions: ", _checks)
	if not _failed: print("ESTRAGON_NATIVE_FRONTEND_OK")
	quit(1 if _failed else 0)

func _initialize() -> void:
	_run.call_deferred()

func _test_native_contract() -> void:
	var text := "extends RefCounted\r\n# 🦎\r\nfunc build():\r\n    return <Button text={\"🦎\"} pressed={handler}/>\r\n"
	var result := Frontend.analyze(text, "Native.gogo")
	_check(result.ok, "Unicode/CRLF module")
	var button: Model.Component = result.module.parts[1]
	_check(button.runtime_class == "EstragonButton", "resolved component contract")
	_check(button.attributes[0].type_name == "String" and button.attributes[1].type_name == "Callable", "typed property and signal")
	_check(button.attributes[1].kind == "signal", "event not property assignment")
	var file := Source.new(text)
	_check(file.slice(button.span).begins_with("<Button"), "code-point indexes slice source")
	_check(button.attributes[1].name_span.start.offset > button.attributes[1].name_span.start.index, "UTF-16 offset includes astral characters")
	var lexer := Lexer.new(Source.new('r"<Rect/>" # ignore\nvalue<<2'))
	var cursor: int = 0
	var kinds: PackedStringArray = []
	while cursor < lexer.file.text.length():
		var token := lexer.next_token(cursor)
		kinds.append(token.kind)
		_check(token.span.end.index > cursor, "token scanner makes progress")
		cursor = token.span.end.index
	_check(kinds.has("string") and kinds.has("comment") and kinds.has("operator"), "scanner lexical categories")
	# Caller-owned offsets permit restart without hidden lexer state.
	_check(lexer.next_token(0).text == "r", "token scanner supports explicit restart offset")
	if OS.get_cmdline_user_args().has("--require-no-bun"):
		for directory in OS.get_environment("PATH").split(":" if OS.get_name() != "Windows" else ";", false):
			_check(not FileAccess.file_exists(directory.path_join("bun")) and not FileAccess.file_exists(directory.path_join("bun.exe")), "Bun unavailable on test PATH")
		print("NATIVE_FRONTEND_NO_BUN")
	# Deliberately tiny TEST-ONLY lowering proof. N02 owns general emission/maps.
	var rectangle := Frontend.analyze('<Rect width="12" height="7"/>').module.parts[0] as Model.Component
	var proof := GDScript.new()
	proof.source_code = "extends RefCounted\nfunc dimensions() -> Vector2:\n\treturn Vector2(%s, %s)\n" % [str(rectangle.attributes[0].value.value), str(rectangle.attributes[1].value.value)]
	_check(proof.reload() == OK, "native typed literals lower to executable GDScript proof")
	_check(proof.new().dimensions() == Vector2(12, 7), "proof executes without external compiler")

func _test_boundaries() -> void:
	# Every truncation of a representative source must terminate with a typed
	# result or one diagnostic, never a partially validated module.
	var source := 'extends RefCounted\nfunc build():\n\treturn <VBox>{<Button text={"a}b"} pressed={handler}/>}</VBox>\n'
	for size in range(source.length() + 1):
		var result := Frontend.analyze(source.left(size), "Truncated.gogo")
		_check(result.ok or result.module == null and result.diagnostics.size() == 1, "truncation terminates at %d" % size)
		if result.ok:
			_check(result.diagnostics.is_empty(), "successful analysis has no diagnostics")
	var invalid := Frontend.analyze('<Text gap="1"/>')
	var valid := Frontend.analyze('<Text text="after failure"/>')
	_check(not invalid.ok and valid.ok, "analyses do not share failure state")
	var lines := Source.new("🦎\r\nX\rY\nZ")
	_check(lines.position(3).line == 2 and lines.position(3).column == 1 and lines.position(3).offset == 4, "CRLF and UTF-16 position")
	_check(lines.position(5).line == 3 and lines.position(7).line == 4, "lone CR and LF positions")
	var accepted := Frontend.analyze('extends RefCounted\nfunc build():\n\treturn ' + '<VBox>{'.repeat(255) + '<Rect/>' + '}</VBox>'.repeat(255))
	_check(accepted.ok, "256 hybrid islands are accepted")
	var nested := 'extends RefCounted\nfunc build():\n\treturn ' + '<VBox>{'.repeat(257) + '<Rect/>' + '}</VBox>'.repeat(257)
	var deep := Frontend.analyze(nested, "Deep.gogo")
	_check(not deep.ok and deep.diagnostics[0].message.contains("256"), "hybrid island recursion guard")
