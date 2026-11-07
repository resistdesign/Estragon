@tool
extends RefCounted
## Tolerant, line-cached editor contexts. Shares native identifier/operator and
## expression-start rules; never substitutes source or executes authored code.
const Lexer = preload("../compiler/lexer.gd")
const Source = preload("../compiler/source.gd")
const Parser = preload("../compiler/parser.gd")
const KEYWORDS := ["extends", "class_name", "class", "func", "static", "var", "const", "return", "if", "elif", "else", "for", "in", "while", "await", "signal", "true", "false", "null", "pass", "and", "or", "not", "as", "is", "self", "match", "break", "continue", "assert", "enum", "preload", "load", "super", "get", "set", "when", "void"]
var lines: PackedStringArray = []
var records: Array = []
var scanned_lines := 0

func update(text: String) -> void:
	var next := text.split("\n")
	var same := 0
	while same < mini(lines.size(), next.size()) and lines[same] == next[same]: same += 1
	records.resize(mini(same, records.size()))
	lines = next

static func initial() -> Dictionary:
	return {"mode":"gd", "quote":"", "comment":false, "tags":[], "islands":[], "frames":[], "operand":true, "depth":0, "declared":[], "tag":"", "closing":false, "name_pending":false}

func line(index: int) -> Dictionary:
	while records.size() <= index and records.size() < lines.size():
		var state: Dictionary = initial() if records.is_empty() else records[-1].state.duplicate(true)
		records.append(scan(lines[records.size()], state))
		scanned_lines += 1
	return records[index] if index >= 0 and index < records.size() else {"tokens":[], "state":initial()}

func context(index: int, column: int) -> Dictionary:
	if index > 0: line(index - 1)
	var state: Dictionary = initial() if index == 0 else records[index - 1].state.duplicate(true)
	var result := scan(lines[index].left(column), state, false)
	var end: Dictionary = result.state
	end["tokens"] = result.tokens
	end["suppressed"] = end.comment or not end.quote.is_empty()
	return end

static func _add(tokens: Array, kind: String, start: int, end: int, word: String, native: bool = true) -> void:
	if end > start: tokens.append({"kind":kind, "start":start, "end":end, "text":word,"native":native})

func scan(text: String, state: Dictionary, newline: bool = true) -> Dictionary:
	var tokens: Array = []
	var lexer := Lexer.new(Source.new(text))
	var i := 0
	var previous := ""
	while i < text.length():
		var start := i
		var ch := text[i]
		if state.comment:
			var end := text.find("-->", i)
			i = text.length() if end < 0 else end + 3
			_add(tokens,"comment",start,i,text.substr(start,i-start),false)
			if end >= 0: state.comment = false
			continue
		if not state.quote.is_empty():
			var delimiter: String = state.quote
			while i < text.length():
				if text[i] == "\\": i = mini(text.length(), i + 2)
				elif text.substr(i,delimiter.length()) == delimiter:
					i += delimiter.length()
					state.quote = ""
					break
				else: i += 1
			_add(tokens,"string",start,i,text.substr(start,i-start),state.mode == "gd")
			state.operand = false
			continue
		if ch in [" ","\t","\r"]: i += 1; continue
		if state.mode != "gd" and text.substr(i,4) == "<!--":
			state.comment = true
			i += 4
			_add(tokens,"comment",start,i,"<!--",false)
			continue
		if state.mode == "gd" and ch == "#":
			_add(tokens,"comment",i,text.length(),text.substr(i))
			if not newline: state.comment = true
			i = text.length()
			continue
		if ch in ['"',"'"]:
			state.quote = ch.repeat(3) if text.substr(i,3) == ch.repeat(3) else ch
			i += state.quote.length()
			_add(tokens,"string",start,i,text.substr(start,i-start))
			continue
		if ch == "<" and (state.mode == "body" or state.mode == "gd" and state.operand and (i+1 == text.length() or lexer.identifier_start(lexer.char_at(i+1)))):
			if state.mode == "gd": state.islands.append(state.tags.size())
			state.mode = "tag"
			state.closing = text.substr(i,2) == "</"
			state.tag = ""
			state.name_pending = true
			i += 2 if state.closing else 1
			_add(tokens,"tag",start,i,text.substr(start,i-start),false)
			continue
		if state.mode == "tag":
			if text.substr(i,2) == "/>" or ch == ">":
				var self_closing := text.substr(i,2) == "/>"
				i += 2 if self_closing else 1
				_add(tokens,"tag",start,i,text.substr(start,i-start))
				if state.closing:
					if not state.tags.is_empty(): state.tags.pop_back()
				elif not self_closing: state.tags.append(state.tag)
				if not state.islands.is_empty() and state.tags.size() == state.islands[-1]:
					state.islands.pop_back()
					state.mode = "gd"
				else: state.mode = "body" if not state.tags.is_empty() else "gd"
				state.operand = false
				continue
			if lexer.identifier_start(ch):
				i += 1
				while i < text.length() and (lexer.identifier_part(text[i]) or text[i] in [".",":","-"]): i += 1
				var name := text.substr(start,i-start)
				_add(tokens,"tag" if state.name_pending else "property",start,i,name,false)
				if state.name_pending: state.tag = name; state.name_pending = false
				continue
		if state.mode != "gd" and ch == "{":
			state.frames.append({"mode":state.mode,"depth":state.depth,"tag":state.tag,"closing":state.closing,"name_pending":state.name_pending})
			state.mode = "gd"
			state.depth = 0
			state.operand = true
			_add(tokens,"expression",i,i+1,ch,false)
			i += 1
			continue
		if state.mode == "gd" and ch == "}" and state.depth == 0 and not state.frames.is_empty():
			var frame: Dictionary = state.frames.pop_back()
			state.mode = frame.mode
			state.depth = frame.depth
			state.tag = frame.tag
			state.closing = frame.closing
			state.name_pending = frame.name_pending
			_add(tokens,"expression",i,i+1,ch)
			i += 1
			continue
		if state.mode == "body":
			_add(tokens,"code",i,i+1,ch,false)
			i += 1
			continue
		var token = lexer.next_token(i)
		if token == null: i += 1; continue
		i = token.span.end.index
		var word: String = token.text
		var kind := "symbol"
		if token.kind == "identifier":
			kind = "keyword" if word in KEYWORDS else "code"
			if previous == "@": kind = "annotation"
			elif previous in ["func","signal"] or text.substr(i).strip_edges().begins_with("(") and kind == "code": kind = "function"
			elif kind == "code" and (ClassDB.class_exists(word) or word in state.declared or word in ["int","float","bool","String","Array","Dictionary","Vector2","Vector3","Color","Callable","StringName","NodePath"] or previous in [":","->","extends","class_name","class"]): kind = "type"
			if previous in ["class_name","class"] or previous == "const" and text.substr(i).strip_edges().begins_with("= preload("):
				if word not in state.declared: state.declared.append(word)
			state.operand = word in Parser.OPERANDS
		elif token.kind == "number": kind = "number"; state.operand = false
		else:
			if word in ["(","[","{"]: state.depth += 1
			elif word in [")","]","}"]: state.depth = maxi(0,state.depth-1)
			state.operand = word not in [".",")","]","}"]
		_add(tokens,kind,start,i,word,state.mode == "gd")
		previous = word
	if newline:
		if state.quote.length() == 1: state.quote = ""
		if state.mode == "gd" and state.depth == 0 and state.frames.is_empty(): state.operand = true
	return {"tokens":tokens,"state":state}
