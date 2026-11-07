@tool
extends EditorSyntaxHighlighter
## Native theme palette + edit-invalidated tolerant line contexts.
const Context = preload("lexical_context.gd")
const CODE := Color("dedede")
const KEYWORD := Color("ff7085")
const TAG := Color("8bd5ff")
const PROPERTY := Color("c6a0f6")
const STRING := Color("a6da95")
const COMMENT := Color("808790")
const EXPRESSION := Color("eed49f")
var settings: EditorSettings
var lexical = Context.new()
var _version := -1
var _preview: TextEdit
var _native: SyntaxHighlighter
const PALETTE := {"code":["text_color",CODE], "keyword":["keyword_color",KEYWORD], "tag":["user_type_color",TAG], "property":["member_variable_color",PROPERTY], "string":["string_color",STRING], "comment":["comment_color",COMMENT], "expression":["symbol_color",EXPRESSION], "symbol":["symbol_color",EXPRESSION], "number":["number_color",Color("a1ffe0")], "type":["base_type_color",TAG], "function":["function_color",Color("57b3ff")], "annotation":["annotation_color",KEYWORD]}

func _init(editor_settings: EditorSettings = null) -> void:
	settings = editor_settings
func _create() -> EditorSyntaxHighlighter:
	return get_script().new(settings)
func _get_name() -> String: return "Gogo"
func _get_supported_languages() -> PackedStringArray: return PackedStringArray(["gogo"])
func _clear_highlighting_cache() -> void:
	_version = -1
	if _native != null: _native.update_cache()
func color(kind: String) -> Color:
	var entry: Array = PALETTE.get(kind,PALETTE.code)
	var key: String = "text_editor/theme/highlighting/"+entry[0]
	return settings.get_setting(key) if settings != null and settings.has_setting(key) else entry[1]
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_preview):
		_preview.free()
		_preview = null
func uses_native() -> bool: return _native != null
func _ensure_native() -> void:
	if _native != null or not Engine.is_editor_hint(): return
	if ClassDB.class_exists("GDScriptSyntaxHighlighter") and ClassDB.can_instantiate("GDScriptSyntaxHighlighter"):
		_native = ClassDB.instantiate("GDScriptSyntaxHighlighter")
		_preview = TextEdit.new()
		_preview.syntax_highlighter = _native
func _native_color(colors: Dictionary, column: int) -> Color:
	var result := color("code")
	var keys := colors.keys()
	keys.sort()
	for key in keys:
		if key > column: break
		result = colors[key].color
	return result
func _get_line_syntax_highlighting(index: int) -> Dictionary:
	var edit := get_text_edit()
	if edit == null: return {}
	_ensure_native()
	if _version != edit.get_version():
		lexical.update(edit.text)
		_version = edit.get_version()
		if _native != null:
			var masked: Array = []
			for row in range(lexical.lines.size()):
				var line: String = lexical.lines[row]
				# Keep all code-point columns/newlines; markup cannot poison native
				# GDScript string/comment state across a GGX island. No compilation.
				for token in lexical.line(row).tokens:
					if not token.native: line = line.left(token.start)+" ".repeat(token.end-token.start)+line.substr(token.end)
				masked.append(line)
			_preview.text = "\n".join(masked)
			_native.update_cache()
	var native_colors: Dictionary = _native.get_line_syntax_highlighting(index) if _native != null else {}
	var result: Dictionary = native_colors.duplicate(true) if _native != null else {0:{"color":color("code")}}
	for token in lexical.line(index).tokens:
		if _native != null and token.native and not (token.kind == "annotation" and token.text == "bindable"): continue
		result[token.start] = {"color":color(token.kind)}
		result[token.end] = {"color":_native_color(native_colors,token.end) if _native != null else color("code")}
	return result
