@tool
extends RefCounted

var _checks: int = 0
var _failed: bool = false
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Gogo highlighting: " + message)

func _color(highlighter: SyntaxHighlighter, line: int, column: int) -> Color:
	var spans := highlighter.get_line_syntax_highlighting(line)
	var color := Color.WHITE
	var keys := spans.keys()
	keys.sort()
	for key in keys:
		if int(key) > column:
			break
		color = spans[key].color
	return color

func run() -> bool:
	var edit := CodeEdit.new()
	var highlighter := Highlighter.new()
	edit.syntax_highlighter = highlighter
	edit.text = "extends EstragonSurface\n# <Button ignored>\nfunc build():\n    return <Button text=\"label\" pressed={handler} disabled={false}/>\nvar message = \"\"\"<Text>\n# still a string\n\"\"\"\n<!-- comment\n<Text/> -->\nvar a = 1 < 2\n"
	_check(_color(highlighter, 0, 0) == Highlighter.KEYWORD, "GDScript declaration")
	_check(_color(highlighter, 1, 3) == Highlighter.COMMENT, "code comment ignores markup")
	_check(_color(highlighter, 2, 0) == Highlighter.KEYWORD, "function declaration")
	_check(_color(highlighter, 3, 11) == Highlighter.TAG, "component tag")
	_check(_color(highlighter, 3, 19) == Highlighter.PROPERTY, "property")
	_check(_color(highlighter, 3, 25) == Highlighter.STRING, "quoted property")
	_check(_color(highlighter, 3, 40) == Highlighter.EXPRESSION, "expression brace")
	_check(_color(highlighter, 3, 41) == Highlighter.CODE, "native expression body")
	_check(_color(highlighter, 5, 0) == Highlighter.STRING, "multiline string ignores comment and markup")
	_check(_color(highlighter, 8, 2) == Highlighter.COMMENT, "multiline markup comment")
	_check(_color(highlighter, 9, 10) == Highlighter.CODE, "comparison remains code")
	edit.text = "var updated = \"changed\""
	highlighter.clear_highlighting_cache()
	_check(_color(highlighter, 0, 0) == Highlighter.KEYWORD, "edit clears lexical cache")
	_check(highlighter._get_supported_languages() == PackedStringArray(["gogo"]), "extension association")
	_check(highlighter._create() != highlighter, "one highlighter per editor")
	edit.text = 'var nested = {"a": <Text text={"nested"}/>} # comment'
	highlighter.clear_highlighting_cache()
	_check(_color(highlighter, 0, edit.text.find("text=")) == Highlighter.PROPERTY, "markup nested in dictionary expression")
	_check(_color(highlighter, 0, edit.text.find("#")) == Highlighter.COMMENT, "code resumes after nested markup")
	edit.free()
	print("Highlighter checks: ", _checks)
	if not _failed:
		print("ESTRAGON_HIGHLIGHTER_OK")
	return not _failed
