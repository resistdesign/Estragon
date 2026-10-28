extends RefCounted
## Re-entrant token scanner: caller supplies the offset and lexical context.
## Regexes classify Unicode characters only; no source rewriting/evaluation.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const OPERATORS := ["**=", "<<=", ">>=", ":=", "==", "!=", "<=", ">=", "<<", ">>", "**", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "&&", "||", "->"]
var file: Source
var tokens: Array[Model.Token] = []
var _start := RegEx.new()
var _part := RegEx.new()

func _init(source: Source) -> void:
	file = source
	_start.compile("^[\\p{L}_]$")
	_part.compile("^[\\p{L}\\p{N}\\p{M}_]$")

func identifier_start(character: String) -> bool:
	return not character.is_empty() and _start.search(character) != null

func identifier_part(character: String) -> bool:
	return not character.is_empty() and _part.search(character) != null

func token(kind: String, start: int, end: int) -> Model.Token:
	var result := Model.Token.new()
	result.kind = kind
	result.text = file.text.substr(start, end - start)
	result.span = file.span(start, end)
	tokens.append(result)
	return result

func char_at(index: int) -> String:
	return file.text[index] if index < file.text.length() else ""

func next_token(start: int) -> Model.Token:
	var text := file.text
	var character := char_at(start)
	var end := start + 1
	if character.is_empty(): return token("eof", start, start)
	if character in [" ", "\t"]:
		while char_at(end) in [" ", "\t"]: end += 1
		return token("whitespace", start, end)
	if character in ["\n", "\r"]:
		if character == "\r" and char_at(end) == "\n": end += 1
		return token("newline", start, end)
	if character == "#":
		while not char_at(end) in ["", "\r", "\n"]: end += 1
		return token("comment", start, end)
	if character == "\\" and char_at(end) in ["\n", "\r"]:
		end += 2 if char_at(end) == "\r" and char_at(end + 1) == "\n" else 1
		return token("continuation", start, end)
	if character in ['"', "'"]:
		var delimiter := character.repeat(3) if text.substr(start, 3) == character.repeat(3) else character
		end = start + delimiter.length()
		while end < text.length():
			if text.substr(end, delimiter.length()) == delimiter:
				return token("string", start, end + delimiter.length())
			if text[end] == "\\":
				end += 1
				if char_at(end) == "\r" and char_at(end + 1) == "\n": end += 1
				end += 1
			else:
				if delimiter.length() == 1 and text[end] in ["\n", "\r"]:
					file.fail("Unterminated GDScript string", start, end)
					return null
				end += 1
		file.fail("Unterminated GDScript string", start, end)
		return null
	if identifier_start(character):
		while identifier_part(char_at(end)): end += 1
		return token("identifier", start, end)
	if character in "0123456789":
		while not char_at(end).is_empty() and char_at(end) in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.": end += 1
		return token("number", start, end)
	for operator in OPERATORS:
		if text.substr(start, operator.length()) == operator:
			return token("operator", start, start + operator.length())
	return token("delimiter" if character in "()[]{}" else "operator", start, end)
