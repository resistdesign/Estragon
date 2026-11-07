@tool
extends Node
## Owns only authenticated Gogo CodeEdit connections and a dedicated gutter.
signal diagnostics_changed(records, phase)
const Context = preload("lexical_context.gd")
const Acceptance = preload("completion_edit.gd")
const Catalog = preload("components.gd")
const Completion = preload("completion.gd")
const Source = preload("../compiler/source.gd")
const Parser = preload("../compiler/parser.gd")
const Bindable = preload("../compiler/bindable.gd")
const GUTTER := "Estragon diagnostics"
var interface: EditorInterface
var navigation: RefCounted
var entries: Dictionary = {}
var _timer: Timer
var _active := true
var _generation := 0
func _init(editor_interface: EditorInterface, navigator: RefCounted) -> void:
	interface = editor_interface
	navigation = navigator
func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.45
	_timer.timeout.connect(_analyze)
	add_child(_timer)
func attach(editor: ScriptEditorBase, code: CodeEdit, path: String) -> void:
	if not _active: return
	var id := code.get_instance_id()
	if entries.has(id):
		if entries[id].path == path: return
		_detach(id)
	if not path.ends_with(".gogo"): return
	entries[id] = {"code":weakref(code),"editor":weakref(editor),"path":path,"model":Completion.new(),"lexical":Context.new(),"records":[],"pending":true,"marked":[],"line_count":code.get_line_count(),"mutating":false,"snapshot":-1,"script":code.get_script(),"lookup_enabled":code.symbol_lookup_on_click,"lookup":_lookup.bind(id),"caret":_hint.bind(id),"enabled":code.code_completion_enabled,"prefixes":code.code_completion_prefixes,"request":_complete.bind(id),"edit":_changed.bind(id),"gutter":_gutter_clicked.bind(id),"theme":_theme_changed.bind(id),"closing":_closed.bind(id)}
	if code.get_script() == null:
		code.set_script(Acceptance)
		code.set("estragon_accept",_accept.bind(id))
	code.symbol_lookup_on_click = true
	code.symbol_lookup.connect(entries[id].lookup)
	code.caret_changed.connect(entries[id].caret)
	code.code_completion_enabled = true
	code.code_completion_prefixes = PackedStringArray([".","<","/","@","{"])
	code.code_completion_requested.connect(entries[id].request)
	code.text_changed.connect(entries[id].edit)
	code.text_set.connect(entries[id].edit)
	code.gutter_clicked.connect(entries[id].gutter)
	code.theme_changed.connect(entries[id].theme)
	code.tree_exiting.connect(entries[id].closing)
	# Native Text storage compares a removed gutter index to line count.
	# Index zero is valid even for empty/single-line tabs (4.0/4.7 bridge).
	code.add_gutter(0)
	var gutter := 0
	code.set_gutter_name(gutter,GUTTER)
	code.set_gutter_type(gutter,TextEdit.GUTTER_TYPE_STRING)
	code.set_gutter_width(gutter,20)
	code.set_gutter_draw(gutter,true)
	_timer.start()
func _gutter_index(code: CodeEdit) -> int:
	for index in range(code.get_gutter_count()):
		if code.get_gutter_name(index) == GUTTER: return index
	return -1
func _detach(id: int) -> void:
	var entry: Dictionary = entries[id]
	var code = entry.code.get_ref()
	if code != null:
		for pair in [["code_completion_requested","request"],["text_changed","edit"],["text_set","edit"],["gutter_clicked","gutter"],["theme_changed","theme"],["tree_exiting","closing"],["symbol_lookup","lookup"],["caret_changed","caret"]]:
			if code.is_connected(pair[0],entry[pair[1]]): code.disconnect(pair[0],entry[pair[1]])
		code.set_code_hint("")
		code.symbol_lookup_on_click = entry.lookup_enabled
		code.cancel_code_completion()
		code.code_completion_enabled = entry.enabled
		code.code_completion_prefixes = entry.prefixes
		var index := _gutter_index(code)
		if index >= 0: code.remove_gutter(index)
		if code.get_script() == Acceptance: code.set_script(entry.script)
	entries.erase(id)
func _closed(id: int) -> void:
	if entries.has(id): _detach(id)
func stop() -> void:
	_active = false
	_generation += 1
	if _timer != null: _timer.stop()
	for id in entries.keys(): _detach(id)
func invalidate() -> void:
	for entry in entries.values(): entry.model.invalidate()
func _theme_changed(id: int) -> void:
	if not entries.has(id): return
	var code = entries[id].code.get_ref()
	if code != null and code.syntax_highlighter != null: code.syntax_highlighter.update_cache()
	_mark(entries[id])
func _changed(id: int, request_completion: bool = true) -> void:
	if not _active or not entries.has(id) or entries[id].mutating: return
	var entry: Dictionary = entries[id]
	entry.pending = true
	entry.records = []
	_mark(entry)
	var code = entry.code.get_ref()
	if code != null and code.syntax_highlighter != null: code.syntax_highlighter.clear_highlighting_cache()
	_timer.start()
	if request_completion: _auto_complete.call_deferred(id)
func _auto_complete(id: int) -> void:
	if not _active or not entries.has(id): return
	var code = entries[id].code.get_ref()
	if code == null or not code.has_focus(): return
	var left: String = code.get_line(code.get_caret_line()).left(code.get_caret_column())
	if not left.is_empty() and (left[-1] in [".","<","/","@","{","("] or left.length() >= 2 and left[-1].is_valid_identifier()): code.request_code_completion(false)
func _complete(id: int) -> void:
	if not _active or not entries.has(id): return
	var entry: Dictionary = entries[id]
	var code = entry.code.get_ref()
	if code == null: return
	code.cancel_code_completion()
	entry.model.metadata = {}
	for script in interface.get_script_editor().get_open_scripts(): entry.model.metadata[script.resource_path] = script
	for item in Catalog.ITEMS: entry.model.metadata[Catalog.path(item)] = item.script
	entry.model.sources = {}
	for other in entries.values():
		var buffer = other.code.get_ref()
		if buffer != null: entry.model.sources[other.path] = buffer.text
	var options: Array = entry.model.candidates(code.text,entry.path,entry.lexical,code.get_caret_line(),code.get_caret_column())
	entry.snapshot = code.get_version()
	for option in options:
		if code.get_script() != Acceptance and not option.get("imports",[]).is_empty(): continue
		code.add_code_completion_option(option.kind,option.text,option.get("insert",option.text),code.get_theme_color("font_color"),null,option)
	code.update_code_completion_options(true)
	_hint(id)
func _apply_imports(code: CodeEdit, plan: Dictionary) -> void:
	if plan.text.is_empty(): return
	var row := code.get_caret_line()
	var column := code.get_caret_column()
	code.set_caret_line(plan.row)
	code.set_caret_column(0)
	code.insert_text_at_caret(plan.text)
	code.set_caret_line(row+plan.text.count("\n") if row >= plan.row else row)
	code.set_caret_column(column)
func _accept(replace: bool, id: int) -> void:
	if not _active or not entries.has(id): return
	var entry: Dictionary = entries[id]
	var code = entry.code.get_ref()
	if code == null: return
	var selected: int = code.get_code_completion_selected_index()
	if selected < 0 or code.get_caret_count() != 1 or entry.snapshot != code.get_version():
		code.cancel_code_completion()
		return
	var selected_option: Dictionary = code.get_code_completion_option(selected)
	var option = selected_option.get("default_value")
	if not option is Dictionary or not option.has("start"):
		code.cancel_code_completion()
		return
	var row: int = option.row
	var start: int = option.start
	var end: int = code.get_caret_column()
	if row != code.get_caret_line() or start < 0 or start > end: code.cancel_code_completion(); return
	var line: String = code.get_line(row)
	var insert: String = option.get("insert",option.text)
	var remaining := insert.substr(end-start)
	if replace and not option.get("path",false):
		while end < line.length() and (line[end].is_valid_identifier() or line[end].is_valid_int()): end += 1
	else:
		var matched := 0
		while end < line.length() and matched < remaining.length() and line[end] == remaining[matched]: end += 1; matched += 1
	if option.get("path",false) and insert[-1] in ['"',"'"] and end < line.length() and line[end] == insert[-1]: end += 1
	var requests: Array = option.get("imports",[])
	var plan: Dictionary = entry.model.import_plan(code.text,entry.path,requests) if not requests.is_empty() else {"row":0,"text":""}
	code.cancel_code_completion()
	entry.mutating = true
	code.begin_complex_operation()
	if code.has_selection():
		code.insert_text_at_caret(insert)
	else:
		code.remove_text(row,start,row,end)
		code.set_caret_line(row)
		code.set_caret_column(start)
		code.insert_text_at_caret(insert)
	_apply_imports(code,plan)
	code.end_complex_operation()
	entry.mutating = false
	_changed(id,false)
	if insert.ends_with("/"): code.request_code_completion(false)
func add_missing_imports() -> void:
	for id in entries:
		var entry: Dictionary = entries[id]
		var code = entry.code.get_ref()
		if code == null or not code.is_visible_in_tree(): continue
		var plan: Dictionary = entry.model.import_plan(code.text,entry.path)
		entry.mutating = true
		code.begin_complex_operation()
		_apply_imports(code,plan)
		code.end_complex_operation()
		entry.mutating = false
		_changed(id,false)
		return
func _hint(id: int) -> void:
	if not _active or not entries.has(id) or entries[id].mutating: return
	var entry: Dictionary = entries[id]
	var code = entry.code.get_ref()
	if code == null: return
	entry.hint = entry.model.call_hint(code.text,entry.path,entry.lexical,code.get_caret_line(),code.get_caret_column())
	code.set_code_hint(entry.hint)
func _lookup(symbol: String, _row: int, _column: int, id: int) -> void:
	if not entries.has(id): return
	var entry: Dictionary = entries[id]
	var code = entry.code.get_ref()
	if code == null: return
	var path: String = entry.model.definition(code.text,entry.path,symbol)
	if not path.is_empty(): navigation.open(path)
func _analyze() -> void:
	if not _active: return
	var records: Array = []
	for id in entries.keys():
		var entry: Dictionary = entries[id]
		var code = entry.code.get_ref()
		if code == null: entries.erase(id); continue
		if entry.pending:
			entry.pending = false
			var source := Source.new(code.text,entry.path)
			var module = Parser.new(source).parse()
			if module != null: Bindable.new(source).apply(module)
			entry.records = []
			for diagnostic in source.diagnostics:
				entry.records.append({"source":entry.path,"line":diagnostic.span.start.line,"column":diagnostic.span.start.column,"end_line":diagnostic.span.end.line,"end_column":diagnostic.span.end.column,"message":diagnostic.message})
			_mark(entry)
		records.append_array(entry.records)
	diagnostics_changed.emit(records,"Typing feedback — syntax only; save/Play validates semantics")
func report_build(report: Dictionary) -> void:
	for entry in entries.values():
		entry.records = []
		entry.pending = false
	for item in report.get("source_diagnostics",[]):
		var record: Dictionary = item.duplicate()
		if not record.source.begins_with("res://"): record.source = "res://"+record.source
		for entry in entries.values():
			if entry.path == record.source: entry.records.append(record)
	for entry in entries.values(): _mark(entry)
func _mark(entry: Dictionary) -> void:
	var code = entry.code.get_ref()
	if code == null: return
	var gutter := _gutter_index(code)
	if gutter < 0: return
	var stale: Array = entry.marked if entry.line_count == code.get_line_count() else range(code.get_line_count())
	for line in stale:
		code.set_line_gutter_text(line,gutter,"")
		code.set_line_gutter_metadata(line,gutter,null)
		code.set_line_gutter_clickable(line,gutter,false)
	entry.marked = []
	entry.line_count = code.get_line_count()
	for record in entry.records:
		var row := clampi(record.line-1,0,code.get_line_count()-1)
		if row not in entry.marked: entry.marked.append(row)
		code.set_line_gutter_text(row,gutter,"!")
		code.set_line_gutter_item_color(row,gutter,code.get_theme_color("error_color","Editor"))
		code.set_line_gutter_metadata(row,gutter,record)
		code.set_line_gutter_clickable(row,gutter,true)
func _gutter_clicked(line: int, gutter: int, id: int) -> void:
	if not entries.has(id): return
	var code = entries[id].code.get_ref()
	if code != null and _gutter_index(code) == gutter:
		var record = code.get_line_gutter_metadata(line,gutter)
		if record is Dictionary: navigate(record)
static func scalar_column(text: String, column: int) -> int:
	var units := 0
	var index := 0
	while index < text.length() and units < maxi(0,column-1):
		units += 2 if text.unicode_at(index) > 0xffff else 1
		index += 1
	return index
func navigate(record: Dictionary) -> void:
	var target := str(record.source)
	if not target.begins_with("res://"): target = "res://"+target
	var generation := _generation
	await navigation.open(target)
	var deadline := Time.get_ticks_msec()+5000
	while _active and generation == _generation and Time.get_ticks_msec() < deadline:
		for entry in entries.values():
			if entry.path != target: continue
			var code = entry.code.get_ref()
			if code == null or not code.is_visible_in_tree(): continue
			var row := clampi(int(record.line)-1,0,code.get_line_count()-1)
			var column := scalar_column(code.get_line(row),int(record.column))
			code.set_caret_line(row)
			code.set_caret_column(column)
			code.set_line_as_center_visible(row)
			code.grab_focus()
			return
		await get_tree().process_frame
