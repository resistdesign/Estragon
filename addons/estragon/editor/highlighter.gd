@tool
extends EditorSyntaxHighlighter
## Presentation-only lexical coloring. The TypeScript compiler owns diagnostics.

const CODE := Color("dedede")
const KEYWORD := Color("ff7085")
const TAG := Color("8bd5ff")
const PROPERTY := Color("c6a0f6")
const STRING := Color("a6da95")
const COMMENT := Color("808790")
const EXPRESSION := Color("eed49f")
const KEYWORDS := ["extends", "class_name", "class", "func", "static", "var", "const", "return", "if", "elif", "else", "for", "in", "while", "await", "signal", "true", "false", "null", "pass", "and", "or", "not", "as", "is", "self"]
var _lines: Array[Dictionary] = []


func _create() -> EditorSyntaxHighlighter:
	return load("res://addons/estragon/editor/highlighter.gd").new()


func _get_name() -> String:
	return "Gogo"


func _get_supported_languages() -> PackedStringArray:
	return PackedStringArray(["gogo"])


func _clear_highlighting_cache() -> void:
	_lines.clear()


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	if _lines.is_empty():
		_scan()
	return _lines[line] if line < _lines.size() else {}


func _scan() -> void:
	var edit := get_text_edit()
	if edit == null:
		return
	var quote := ""
	var xml_comment := false
	var tag_depths: Array[int] = []
	var braces: int = 0
	for line_index in range(edit.get_line_count()):
		var text := edit.get_line(line_index)
		var colors: Dictionary = {0: {"color": CODE}}
		var i: int = 0
		while i < text.length():
			if xml_comment:
				colors[i] = {"color": COMMENT}
				var end := text.find("-->", i)
				if end < 0:
					break
				i = end + 3
				xml_comment = false
				colors[i] = {"color": CODE}
				continue
			if not quote.is_empty():
				colors[i] = {"color": STRING}
				while i < text.length():
					if text[i] == "\\":
						i += 2
						continue
					if text.substr(i, quote.length()) == quote:
						i += quote.length()
						quote = ""
						break
					i += 1
				colors[i] = {"color": CODE}
				continue
			var character := text[i]
			if text.substr(i, 4) == "<!--":
				xml_comment = true
				continue
			if character == "#" and (tag_depths.is_empty() or braces > tag_depths[-1]):
				colors[i] = {"color": COMMENT}
				break
			if character == '"' or character == "'":
				quote = character.repeat(3) if text.substr(i, 3) == character.repeat(3) else character
				colors[i] = {"color": STRING}
				i += quote.length()
				continue
			if character == "<" and i + 1 < text.length() and (text[i + 1] == "/" or text[i + 1].to_upper() == text[i + 1] and text[i + 1].to_lower() != text[i + 1]):
				tag_depths.append(braces)
				var end := i + 1
				while end < text.length() and text[end] not in [" ", "\t", ">"]:
					end += 1
				colors[i] = {"color": TAG}
				i = end
				colors[i] = {"color": CODE}
				continue
			if character == ">" and not tag_depths.is_empty() and braces == tag_depths[-1]:
				colors[i] = {"color": TAG}
				tag_depths.pop_back()
				colors[i + 1] = {"color": CODE}
			if character == "{" or character == "}":
				braces += 1 if character == "{" else -1
				braces = maxi(0, braces)
				colors[i] = {"color": EXPRESSION}
				colors[i + 1] = {"color": CODE}
			if character.is_valid_identifier() and not character.is_valid_int():
				var end := i + 1
				while end < text.length() and (text[end].is_valid_identifier() or text[end].is_valid_int()):
					end += 1
				var word := text.substr(i, end - i)
				if word in KEYWORDS or not tag_depths.is_empty() and braces == tag_depths[-1]:
					colors[i] = {"color": KEYWORD if word in KEYWORDS else PROPERTY}
					colors[end] = {"color": CODE}
				i = end
				continue
			i += 1
		if quote.length() == 1:
			quote = ""
		_lines.append(colors)
