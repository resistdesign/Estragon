@tool
extends RefCounted
## Recursive-descent component islands composed with lexically retained GDScript.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const Lexer = preload("res://addons/estragon/compiler/lexer.gd")
const OPERANDS := ["return", "yield", "await", "if", "elif", "else", "while", "in", "and", "or", "not", "assert", "match"]
const OPEN := {"(": ")", "[": "]", "{": "}"}
var file: Source
var lexer: Lexer
var module := Model.Module.new()
var _cursor: int = 0
var _classes: Array[Dictionary] = []
var _indentation_seen: bool = false
var _island_depth: int = 0

func _init(source: Source) -> void:
	file = source
	lexer = Lexer.new(source)

func parse() -> Model.Module:
	var first: int = 0
	const TRIM := "\u0009\u000a\u000b\u000c\u000d \u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"
	while first < file.text.length() and file.text[first] in TRIM: first += 1
	module.mode = "markup" if first == file.text.length() or file.text[first] == "<" else "hybrid"
	if module.mode == "markup":
		var root := _component(0)
		_trivia()
		if file.diagnostics.is_empty() and _cursor != file.text.length():
			file.fail("Expected one component expression; trailing source is not supported in standalone markup", _cursor)
		if root != null: module.parts.append(root)
	else:
		var scanned := _scan(0, false)
		module.parts.assign(scanned.parts)
	return module if file.diagnostics.is_empty() else null

func _at(value: String) -> bool:
	return file.text.substr(_cursor, value.length()) == value

func _take(value: String) -> bool:
	if not _at(value):
		file.fail("Expected " + JSON.stringify(value), _cursor)
		return false
	lexer.token("markup-punctuation", _cursor, _cursor + value.length())
	_cursor += value.length()
	return true

func _whitespace() -> bool:
	var start := _cursor
	while lexer.char_at(_cursor) in [" ", "\t", "\r", "\n"]: _cursor += 1
	if _cursor > start: lexer.token("whitespace", start, _cursor)
	return _cursor > start

func _trivia() -> void:
	_whitespace()
	while _at("<!--") and file.diagnostics.is_empty():
		var start := _cursor
		var end := file.text.find("-->", start + 4)
		if end < 0:
			file.fail("Unterminated comment", start, file.text.length())
			return
		_cursor = end + 3
		lexer.token("markup-comment", start, _cursor)
		_whitespace()

func _name() -> Model.Token:
	var start := _cursor
	if lexer.char_at(_cursor).is_empty() or not lexer.char_at(_cursor) in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_":
		file.fail("Expected component or property name", start)
		return null
	_cursor += 1
	while not lexer.char_at(_cursor).is_empty() and lexer.char_at(_cursor) in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789.:-": _cursor += 1
	return lexer.token("markup-name", start, _cursor)

func _component(depth: int) -> Model.Component:
	_trivia()
	var start := _cursor
	if depth >= 256:
		file.fail("Component nesting exceeds 256", start)
		return null
	if not _take("<"): return null
	var name_token := _name()
	if name_token == null: return null
	var node := Model.Component.new()
	node.name = name_token.text
	node.name_span = name_token.span
	while file.diagnostics.is_empty():
		var separated := _whitespace()
		if _at("/>"):
			_take("/>")
			node.span = file.span(start, _cursor)
			return node
		if _at(">"):
			_take(">")
			break
		if not separated:
			file.fail("Expected whitespace before a property, or a tag terminator", _cursor)
			return null
		var attribute_name := _name()
		if attribute_name == null: return null
		_whitespace()
		if not _take("="): return null
		_whitespace()
		var attribute := Model.Attribute.new()
		attribute.name = attribute_name.text
		attribute.name_span = attribute_name.span
		if _at("{") and module.mode == "hybrid":
			attribute.value = _expression()
		else:
			var quote := lexer.char_at(_cursor)
			if quote not in ['"', "'"]:
				file.fail("Expected a quoted literal or {GDScript expression} property value" if module.mode == "hybrid" else "Expected a quoted literal property value; expressions require a GDScript-first module", _cursor)
				return null
			var quote_start := _cursor
			_cursor += 1
			var value_start := _cursor
			while lexer.char_at(_cursor) != quote:
				if _cursor >= file.text.length():
					file.fail("Unterminated property value", value_start, _cursor)
					return null
				if lexer.char_at(_cursor) in ["<", "&", "\\"]:
					file.fail("Markup delimiters, entities and escapes are not supported in literal values", _cursor)
					return null
				_cursor += 1
			var value := Model.Literal.new()
			value.value = file.text.substr(value_start, _cursor - value_start)
			value.span = file.span(value_start, _cursor)
			attribute.value = value
			_cursor += 1
			lexer.token("markup-string", quote_start, _cursor)
		if attribute.value == null: return null
		node.attributes.append(attribute)
	_trivia()
	while not _at("</") and file.diagnostics.is_empty():
		if _cursor >= file.text.length():
			file.fail("Missing closing tag </%s>" % node.name, _cursor)
			return null
		var child: Model.SyntaxNode
		if _at("{") and module.mode == "hybrid": child = _expression()
		elif _at("<"): child = _component(depth + 1)
		else:
			file.fail("Only component children are supported; use {...} for a component-valued GDScript expression" if module.mode == "hybrid" else "Only component children are supported; text requires a Text component", _cursor)
			return null
		if child == null: return null
		node.children.append(child)
		_trivia()
	if not file.diagnostics.is_empty() or not _take("</"): return null
	var closing := _name()
	if closing == null: return null
	if closing.text != node.name:
		file.fail("Expected </%s>, found </%s>" % [node.name, closing.text], closing.span.start.index, _cursor)
		return null
	_whitespace()
	if not _take(">"): return null
	node.span = file.span(start, _cursor)
	return node

func _expression() -> Model.GdExpression:
	var start := _cursor
	lexer.token("expression-open", start, start + 1)
	var scanned := _scan(start + 1, true)
	if not file.diagnostics.is_empty(): return null
	if not scanned.has_token:
		file.fail("Expected a GDScript expression inside braces", start, scanned.end)
		return null
	var expression := Model.GdExpression.new()
	expression.parts.assign(scanned.parts)
	_cursor = scanned.end + 1
	lexer.token("expression-close", scanned.end, _cursor)
	expression.span = file.span(start, _cursor)
	return expression

func _copy(parts: Array[Model.SyntaxNode], start: int, end: int) -> void:
	if start >= end: return
	var code := Model.Code.new()
	code.span = file.span(start, end)
	parts.append(code)

func _scan(start: int, braced: bool) -> Dictionary:
	var parts: Array[Model.SyntaxNode] = []
	var stack: Array[Dictionary] = []
	var offset := start
	var copied := start
	var operand := true
	var has_token := false
	while offset < file.text.length() and file.diagnostics.is_empty():
		var character := lexer.char_at(offset)
		if braced and stack.is_empty() and character == "}":
			_copy(parts, copied, offset)
			return {"parts": parts, "end": offset, "has_token": has_token}
		if character == "<" and operand and lexer.identifier_start(lexer.char_at(offset + 1)):
			_context(offset, braced, stack.is_empty())
			if not braced and stack.is_empty() and file.position(offset).column == 1:
				file.fail("Expected a GDScript expression context before component markup", offset)
				break
			if not _classes.is_empty():
				file.fail("Component expressions inside named inner classes are outside the supported hybrid subset; use an outer-class helper", offset)
				break
			_copy(parts, copied, offset)
			_cursor = offset
			_island_depth += 1
			if _island_depth > 256:
				file.fail("Hybrid expression nesting exceeds 256", offset)
				break
			var component := _component(0)
			_island_depth -= 1
			if component == null: break
			parts.append(component)
			offset = _cursor
			copied = offset
			operand = false
			has_token = true
			continue
		var token := lexer.next_token(offset)
		if token == null: break
		var from := offset
		offset = token.span.end.index
		if token.kind in ["whitespace", "comment", "continuation"]: continue
		if token.kind == "newline":
			if stack.is_empty() and not braced: operand = true
			continue
		has_token = true
		var context := _context(from, braced, stack.is_empty())
		var line: int = context.line
		var prefix: String = context.prefix
		var first_on_line: bool = context.first
		if token.kind == "string": operand = false
		elif token.kind == "identifier":
			if not module.identifiers.has(token.text): module.identifiers.append(token.text)
			if not braced and stack.is_empty() and first_on_line and token.text == "class": _classes.append({"indentation": prefix.length(), "line": line})
			operand = token.text in OPERANDS
		elif token.kind == "number": operand = false
		elif OPEN.has(character):
			stack.append({"close": OPEN[character], "start": from})
			operand = true
		elif character in [")", "]", "}"]:
			if stack.is_empty() or stack.pop_back().close != character:
				file.fail("Unmatched GDScript delimiter " + character, from)
				break
			operand = false
		else: operand = character != "."
	if file.diagnostics.is_empty():
		if not stack.is_empty(): file.fail("Unclosed GDScript delimiter; expected " + stack[-1].close, stack[-1].start, offset)
		elif braced: file.fail("Unterminated GDScript expression; expected }", start - 1, offset)
	_copy(parts, copied, offset)
	return {"parts": parts, "end": offset, "has_token": has_token}

func _context(offset: int, braced: bool, top: bool) -> Dictionary:
	var line := file.position(offset).line
	var prefix := file.text.substr(file.line_start(line), offset - file.line_start(line))
	var first := prefix.replace(" ", "").replace("\t", "").is_empty()
	if not braced and top and first:
		while not _classes.is_empty() and line > _classes[-1].line and prefix.length() <= _classes[-1].indentation: _classes.pop_back()
		if not prefix.is_empty() and not _indentation_seen:
			module.indentation = prefix
			_indentation_seen = true
	return {"line": line, "prefix": prefix, "first": first}
