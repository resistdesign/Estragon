extends RefCounted
## Source ranges use code-point indexes internally and compatible UTF-16 externally.
const Model = preload("res://addons/estragon/compiler/model.gd")
var text: String
var name: String
var diagnostics: Array[Model.Diagnostic] = []
var _lines: PackedInt32Array = [0]
var _utf16: PackedInt32Array = [0]

func _init(value: String, source_name: String = "<source>") -> void:
	text = value
	name = source_name
	for index in range(text.length()):
		_utf16.append(_utf16[-1] + (2 if text.unicode_at(index) > 0xffff else 1))
		if text[index] == "\n" or text[index] == "\r" and (index + 1 == text.length() or text[index + 1] != "\n"):
			_lines.append(index + 1)

func position(index: int) -> Model.Position:
	index = clampi(index, 0, text.length())
	var low: int = 0
	var high := _lines.size()
	while low + 1 < high:
		var middle := (low + high) >> 1
		if _lines[middle] <= index: low = middle
		else: high = middle
	var point := Model.Position.new()
	point.index = index
	point.offset = _utf16[index]
	point.line = low + 1
	point.column = _utf16[index] - _utf16[_lines[low]] + 1
	return point

func line_start(line: int) -> int:
	return _lines[line - 1] if line > 0 and line <= _lines.size() else text.length()

func span(start: int, end: int = -1) -> Model.Span:
	var result := Model.Span.new()
	result.start = position(start)
	result.end = position(start if end < 0 else end)
	return result

func fail(message: String, start: int, end: int = -1) -> void:
	if not diagnostics.is_empty(): return
	var diagnostic := Model.Diagnostic.new()
	diagnostic.source_name = name
	diagnostic.span = span(start, end)
	diagnostic.message = message
	diagnostics.append(diagnostic)

func slice(bounds: Model.Span) -> String:
	return text.substr(bounds.start.index, bounds.end.index - bounds.start.index)
