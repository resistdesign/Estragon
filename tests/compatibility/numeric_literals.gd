extends SceneTree
## Expected bytes are checked-in independent binary64 oracles, not to_float().
const Frontend = preload("res://addons/estragon/compiler/frontend.gd")
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Emitter = preload("res://addons/estragon/compiler/emitter.gd")

func bits(value: float) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_double(0, value)
	return bytes.hex_encode()

func evaluate(token: String) -> String:
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nvar amount: float = " + token + "\n"
	if script.reload() != OK: return "RELOAD_FAILED"
	return bits(script.new().amount)

func inspect_case(item: Dictionary) -> Dictionary:
	var text: String = item.source
	var source := '<Rect width="' + text + '"/>'
	var front := Frontend.analyze(source, "Numeric.gogo")
	var octets: Array[String] = []
	for index in range(0, item.expected_bits.length(), 2):
		octets.append("0x" + item.expected_bits.substr(index, 2))
	var storage := evaluate("PackedByteArray([" + ",".join(octets) + "]).decode_double(0)")
	var row := {"source": text, "expected_bits": item.expected_bits,
		"storage_bits": storage,
		"raw_conversion_bits": bits(text.to_float()), "direct_literal_bits": evaluate(text)}
	if not front.ok:
		row["status"] = "FAIL"
		return row
	var value = front.module.parts[0].attributes[0].value
	row["model_bits"] = bits(value.value)
	row["token"] = Emitter.literal(value)
	row["runtime_bits"] = evaluate(row.token)
	var compilation := Compiler.compile(source, "Numeric.gogo")
	var repeated := Compiler.compile(source, "Numeric.gogo")
	var mapped := false
	for segment in compilation.source_map.segments:
		var generated: String = compilation.code.substr(segment.generated.start.index, segment.generated.end.index - segment.generated.start.index)
		if generated.contains(".width = " + row.token):
			mapped = segment.original.start.offset == value.span.start.offset and segment.original.end.offset == value.span.end.offset
	row["deterministic_and_mapped"] = compilation.ok and compilation.code == repeated.code and compilation.source_map.serialize() == repeated.source_map.serialize() and mapped
	row["status"] = "PASS" if row.model_bits == item.expected_bits and row.runtime_bits == item.expected_bits and row.deterministic_and_mapped else "FAIL"
	return row

func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://numeric_cases.json"))
	var failed := false
	for item in fixture.cases:
		var row := inspect_case(item)
		print("C01_NUMERIC_CASE ", JSON.stringify(row))
		if row.status != "PASS":
			failed = true
	# Existing native parsing limitations are reported separately, never greened
	# by comparing two uses of the same broken conversion as an oracle.
	for item in fixture.native_parser_limits:
		var row := inspect_case(item)
		row["native_value_preserved"] = row.model_bits == row.runtime_bits and row.model_bits == row.raw_conversion_bits and row.model_bits == row.direct_literal_bits
		if not row.native_value_preserved:
			failed = true
			row.status = "FAIL"
		elif row.status == "FAIL": row.status = "BLOCKED"
		print("C01_NUMERIC_NATIVE_LIMIT ", JSON.stringify(row))
	for text in fixture.rejected_cases:
		var result := Compiler.compile('<Rect width="' + text + '"/>', "NumericInvalid.gogo")
		var located := not result.diagnostics.is_empty() and result.diagnostics[0].source_name == "NumericInvalid.gogo" and result.diagnostics[0].span.start.line == 1
		var diagnostic: String = result.diagnostics[0].message if not result.diagnostics.is_empty() else ""
		var row := {"source": text, "rejected": not result.ok, "no_output": result.code.is_empty(), "source_located": located, "finite_domain_diagnostic": diagnostic.contains("finite"), "diagnostic": diagnostic}
		print("C01_NUMERIC_REJECTION ", JSON.stringify(row))
		if not row.rejected or not row.no_output or not row.source_located or not row.finite_domain_diagnostic: failed = true
	if failed: push_error("C01 numeric literal differs from the independent binary64 oracle")
	else: print("C01_NUMERIC_OK")
	quit(1 if failed else 0)
