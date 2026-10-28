extends RefCounted
## Version-1 range maps, shared by native generation and diagnostic consumers.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
var source: Source
var code: String
var segments: Array[Dictionary] = []
var _pieces: PackedStringArray = []
var _length: int = 0

func _init(file: Source) -> void:
	source = file

func append(text: String, original: Model.Span = null, copied: bool = false) -> void:
	if original != null and not text.is_empty():
		segments.append({"from": _length, "to": _length + text.length(), "original": original, "kind": "copied" if copied else "generated"})
	_pieces.append(text)
	_length += text.length()

func finish() -> void:
	code = "".join(_pieces)
	var generated := Source.new(code)
	for segment in segments:
		segment.generated = generated.span(segment.from, segment.to)
	_pieces.clear()

func original_position(line: int, column: int = 1) -> Model.Position:
	var generated := Source.new(code)
	var offset := generated.offset(line, column)
	var selected: Dictionary = {}
	for segment in segments:
		if segment.generated.start.offset <= offset and offset < segment.generated.end.offset:
			selected = segment
			break
	if selected.is_empty():
		for segment in segments:
			if segment.generated.start.line <= line and line <= segment.generated.end.line:
				selected = segment
				break
	if selected.is_empty(): return null
	if selected.kind == "generated": return selected.original.start
	var delta: int = clampi(offset - selected.generated.start.offset, 0, selected.original.end.offset - selected.original.start.offset)
	return source.position(source.index_at_offset(selected.original.start.offset + delta))

static func _point(point: Model.Position) -> Dictionary:
	return {"offset": point.offset, "line": point.line, "column": point.column}

static func _span(span: Model.Span) -> Dictionary:
	return {"start": _point(span.start), "end": _point(span.end)}

func to_dictionary() -> Dictionary:
	var ranges: Array[Dictionary] = []
	for segment in segments:
		ranges.append({"generated": _span(segment.generated), "original": _span(segment.original), "kind": segment.kind})
	return {"format": "estragon.gogo.source-map", "version": 1, "sourceName": source.name, "sourceContent": source.text, "segments": ranges}

func serialize() -> String:
	return JSON.stringify(to_dictionary()) + "\n"
