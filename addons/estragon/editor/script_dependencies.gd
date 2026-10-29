@tool
extends RefCounted
## Static resource edges for ordering native validation/reloads. Reuses N01's
## lexer; Godot decodes string literals and remains the semantic authority.
const Lexer = preload("res://addons/estragon/compiler/lexer.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")

static func paths(code: String, output: String) -> PackedStringArray:
	var file := Source.new(code)
	var lexer := Lexer.new(file)
	var tokens: Array = []
	var cursor: int = 0
	while cursor < code.length():
		var token := lexer.next_token(cursor)
		if token == null: return [] # The full mapped semantic validator diagnoses it.
		cursor = token.span.end.index
		if token.kind not in ["whitespace", "comment", "newline", "continuation"]: tokens.append(token)
	var result: PackedStringArray = []
	for index in range(tokens.size()):
		var token = tokens[index]
		if token.kind != "identifier" or token.text not in ["extends", "preload"]: continue
		var next := index + (2 if token.text == "preload" else 1)
		if token.text == "preload" and (index + 1 >= tokens.size() or tokens[index + 1].text != "("): continue
		if next >= tokens.size(): continue
		var raw: bool = tokens[next].kind == "identifier" and tokens[next].text == "r"
		if raw: next += 1
		if next >= tokens.size(): continue
		if tokens[next].kind == "identifier" and token.text == "extends":
			for entry in ProjectSettings.get_global_class_list():
				if str(entry.class) == tokens[next].text: result.append(entry.path)
		elif tokens[next].kind == "string":
			# Only one lexer-proven literal is evaluated, never an authored
			# expression, component or application. This handles Godot escapes,
			# Unicode, raw and multiline strings without a second string grammar.
			var literal := GDScript.new()
			literal.source_code = "@tool\nextends RefCounted\nstatic func value() -> String:\n\treturn " + ("r" if raw else "") + tokens[next].text + "\n"
			if literal.reload() != OK: continue
			var path: String = literal.call("value")
			if path.begins_with("uid://"):
				var uid := ResourceUID.text_to_id(path)
				if not ResourceUID.has_id(uid): continue
				path = ResourceUID.get_id_path(uid)
			elif not path.is_absolute_path(): path = output.get_base_dir().path_join(path).simplify_path()
			result.append(path)
	return result
