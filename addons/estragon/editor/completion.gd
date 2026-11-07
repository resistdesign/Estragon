@tool
extends RefCounted
## Lexical declarations + public ClassDB metadata. No authored Script loads/new().
const Validator = preload("../compiler/validator.gd")
const Source = preload("../compiler/source.gd")
const Context = preload("lexical_context.gd")
const Catalog = preload("components.gd")
const Imports = preload("imports.gd")
const Build = preload("build_service.gd")
var sources: Dictionary = {}
var metadata: Dictionary = {}
var metadata_reads := 0
var _script_cache: Dictionary = {}
var _classes: PackedStringArray = []
var _text := ""
var _path := ""
var _symbols: Dictionary = {}
var _aliases: Dictionary = {}
var _owners: Dictionary = {}
var _base := "Node"
var _native_cache: Dictionary = {}
var _types = Validator.new(Source.new(""))

func _init() -> void:
	_classes = ClassDB.get_class_list()
func invalidate() -> void:
	_text = ""
	_native_cache.clear()
	_script_cache.clear()
	metadata.clear()
func _tokens(text: String) -> Array:
	var context := Context.new()
	context.update(text)
	var result: Array = []
	for index in range(context.lines.size()):
		for token in context.line(index).tokens:
			if token.kind in ["comment","tag","property"]: continue
			if token.kind == "string" and not result.is_empty() and result[-1].kind == "string" and result[-1].row == index and result[-1].end == token.start:
				result[-1].text += token.text
				result[-1].end = token.end
			else:
				var item: Dictionary = token.duplicate()
				item.row = index
				item.indent = context.lines[index].length()-context.lines[index].strip_edges(true,false).length()
				result.append(item)
	return result
func _resolve_path(raw: String, source: String) -> String:
	if raw.length() < 2: return ""
	var value := raw.substr(1,raw.length()-2).c_unescape()
	if value.is_absolute_path(): return value.simplify_path()
	var output := Build.output_for(source) if source.ends_with(".gogo") else source
	return output.get_base_dir().path_join(value).simplify_path()
func _declarations(text: String, source: String) -> Dictionary:
	var tokens := _tokens(text)
	var symbols: Dictionary = {}
	var aliases: Dictionary = {}
	var base := ""
	var owner := ""
	var owners: Dictionary = {}
	var required_initializer := false
	for index in range(tokens.size()):
		var word: String = tokens[index].text
		if tokens[index].indent == 0: owners[tokens[index].row] = ""
		elif not owners.has(tokens[index].row): owners[tokens[index].row] = owner
		if word == "extends" and tokens[index].indent == 0 and index+1 < tokens.size():
			base = _resolve_path(tokens[index+1].text,source) if tokens[index+1].kind == "string" else tokens[index+1].text
		if word not in ["var","const","func","signal","class_name","class"] or index+1 >= tokens.size(): continue
		var name: String = tokens[index+1].text
		if not name.is_valid_identifier(): continue
		var scope: String = owner if tokens[index].indent > 0 else ""
		if word == "func" and tokens[index].indent == 0:
			owner = name
			owners[tokens[index].row] = owner
			if name == "_init" and index+3 < tokens.size() and tokens[index+3].text != ")": required_initializer = true
		var type := ""
		if index+3 < tokens.size() and tokens[index+2].text == ":": type = tokens[index+3].text
		symbols[name] = {"type":type,"owner":scope,"writable":true,"kind":CodeEdit.KIND_FUNCTION if word == "func" else (CodeEdit.KIND_SIGNAL if word == "signal" else (CodeEdit.KIND_CONSTANT if word == "const" else (CodeEdit.KIND_CLASS if word in ["class","class_name"] else (CodeEdit.KIND_VARIABLE if not scope.is_empty() else CodeEdit.KIND_MEMBER))))}
		if word == "func": symbols[name].hint = text.split("\n")[tokens[index].row].strip_edges().trim_prefix("func ").trim_suffix(":")
		if word == "signal":
			var args: Array = []
			for cursor in range(index+2,mini(index+28,tokens.size()-1)):
				if tokens[cursor].text == ")": break
				if tokens[cursor].text == ":": args.append(tokens[cursor+1].text)
			symbols[name].args = args
		if word == "var":
			var getter := false
			var setter := false
			for cursor in range(index+2,tokens.size()-1):
				if tokens[cursor].row > tokens[index].row and tokens[cursor].indent <= tokens[index].indent: break
				if tokens[cursor].text == "get" and tokens[cursor+1].text == ":": getter = true
				if tokens[cursor].text == "set": setter = true
			symbols[name].writable = not getter or setter
		if word == "const" and scope.is_empty():
			for cursor in range(index+2,mini(index+7,tokens.size()-2)):
				if tokens[cursor].text == "preload" and tokens[cursor+1].text == "(" and tokens[cursor+2].kind == "string": aliases[name] = _resolve_path(tokens[cursor+2].text,source)
	# Typed arguments/local declarations also contribute names, never inferred values.
	for index in range(1,tokens.size()-2):
		if tokens[index].text == ":" and tokens[index-1].text.is_valid_identifier() and tokens[index+1].text.is_valid_identifier() and tokens[index+1].kind != "keyword" and tokens[index].row == tokens[index+1].row:
			var name: String = tokens[index-1].text
			if not symbols.has(name): symbols[name] = {"type":tokens[index+1].text,"owner":owners.get(tokens[index].row,""),"kind":CodeEdit.KIND_VARIABLE}
	return {"symbols":symbols,"aliases":aliases,"base":base,"owners":owners,"required_initializer":required_initializer}
func _index(text: String, source: String) -> void:
	if text == _text and source == _path: return
	_text = text
	_path = source
	var declarations := _declarations(text,source)
	_symbols = declarations.symbols
	_owners = declarations.owners
	_aliases = declarations.aliases
	_base = declarations.base
func _script(path: String) -> Dictionary:
	var text: String = sources[path] if sources.has(path) else FileAccess.get_file_as_string(path)
	if not _script_cache.has(path) or _script_cache[path].text != text:
		_script_cache[path] = {"text":text,"declarations":_declarations(text,path)}
	return _script_cache[path].declarations
func _type_name(info: Dictionary) -> String:
	var class_name_value: String = str(info.get("class_name",""))
	if not class_name_value.is_empty(): return class_name_value
	if info.get("type",TYPE_NIL) == TYPE_NIL: return "Variant" if int(info.get("usage",0)) & PROPERTY_USAGE_NIL_IS_VARIANT else "void"
	var normalized := info.duplicate()
	normalized.type = info.get("type",TYPE_NIL)
	return _types._native_type(normalized)
func _method_hint(method: Dictionary) -> String:
	var args: Array = []
	for arg in method.get("args",[]): args.append(str(arg.name)+": "+_type_name(arg))
	return str(method.name)+"("+", ".join(args)+") -> "+_type_name(method.get("return",{}))
func call_hint(text: String, source: String, lexical: RefCounted, row: int, column: int) -> String:
	_index(text,source)
	lexical.update(text)
	var state: Dictionary = lexical.context(row,column)
	if state.suppressed or state.mode != "gd": return ""
	var tokens := _tokens(lexical.lines[row].left(column))
	var depth := 0
	for index in range(tokens.size()-1,-1,-1):
		if tokens[index].text == ")": depth += 1
		if tokens[index].text != "(": continue
		if depth > 0: depth -= 1; continue
		if index == 0: return ""
		var name: String = tokens[index-1].text
		var members := _members(_base,_aliases)
		if index >= 3 and tokens[index-2].text == ".":
			var receiver: String = tokens[index-3].text
			if receiver != "self": members = _members(str(_symbols.get(receiver,{}).get("type",receiver)),_aliases)
		else: members.merge(_symbols,true)
		return str(members.get(name,{}).get("hint",""))
	return ""
func _members(type: String, aliases: Dictionary, visited: Array = []) -> Dictionary:
	var name: String = aliases.get(type,type)
	if name.is_empty() or name in visited or visited.size() >= 12: return {}
	if ClassDB.class_exists(name):
		if _native_cache.has(name): return _native_cache[name]
		var result: Dictionary = {}
		for prop in ClassDB.class_get_property_list(name):
			if str(prop.name).is_valid_identifier() and not (int(prop.usage) & (PROPERTY_USAGE_CATEGORY|PROPERTY_USAGE_GROUP|PROPERTY_USAGE_SUBGROUP)):
				result[prop.name] = {"type":_type_name(prop),"kind":CodeEdit.KIND_MEMBER,"value_type":prop.type,"writable":not (int(prop.usage)&PROPERTY_USAGE_READ_ONLY)}
		for method in ClassDB.class_get_method_list(name): result[method.name] = {"type":_type_name(method.get("return",{})),"kind":CodeEdit.KIND_FUNCTION,"hint":_method_hint(method)}
		for sig in ClassDB.class_get_signal_list(name): result[sig.name] = {"type":"","kind":CodeEdit.KIND_SIGNAL,"args":sig.args.map(func(arg): return arg.type)}
		_native_cache[name] = result
		return result
	if not name.begins_with("res://"):
		for entry in ProjectSettings.get_global_class_list():
			if entry["class"] == name: return _members(str(entry.path),{},visited+[name])
		return {}
	var authored := name.get_base_dir().get_base_dir().path_join(name.get_file().get_basename()+".gogo")
	if name.get_base_dir().get_file() == "generated" and FileAccess.file_exists(authored): name = authored
	if not FileAccess.file_exists(name): return {}
	var declarations := _script(name)
	var result := _members(declarations.base,declarations.aliases,visited+[name])
	# Existing cached metadata only; never reload/new authored scripts.
	if not sources.has(name):
		var cached = metadata.get(name)
		if cached == null and ResourceLoader.has_method("get_cached_ref"): cached = ResourceLoader.call("get_cached_ref",name)
		if cached is Script and cached.source_code == _script_cache[name].text:
			metadata_reads += 1
			for prop in cached.get_script_property_list():
				if str(prop.name).is_valid_identifier() and not (int(prop.usage) & (PROPERTY_USAGE_CATEGORY|PROPERTY_USAGE_GROUP|PROPERTY_USAGE_SUBGROUP)): result[prop.name] = {"type":_type_name(prop),"kind":CodeEdit.KIND_MEMBER,"writable":not (int(prop.usage)&PROPERTY_USAGE_READ_ONLY)}
			for method in cached.get_script_method_list(): result[method.name] = {"type":_type_name(method.get("return",{})),"kind":CodeEdit.KIND_FUNCTION,"hint":_method_hint(method)}
	for field in declarations.symbols:
		if declarations.symbols[field].owner.is_empty(): result[field] = declarations.symbols[field]
	return result
func _node_type(type: String, aliases: Dictionary, visited: Array = []) -> bool:
	var name: String = aliases.get(type,type)
	if name in visited or visited.size() >= 12: return false
	if ClassDB.class_exists(name): return ClassDB.is_parent_class(name,"Node") and ClassDB.can_instantiate(name)
	if not name.begins_with("res://"):
		for entry in ProjectSettings.get_global_class_list():
			if entry["class"] == name: return _node_type(str(entry.path),{},visited+[name])
		return false
	var authored := name.get_base_dir().get_base_dir().path_join(name.get_file().get_basename()+".gogo")
	if name.get_base_dir().get_file() == "generated" and FileAccess.file_exists(authored): name = authored
	if not FileAccess.file_exists(name): return false
	var declarations := _script(name)
	return not declarations.required_initializer and _node_type(declarations.base,declarations.aliases,visited+[name])
func _catalog_options(prefix: String, tags: bool) -> Dictionary:
	var result: Dictionary = {}
	var dimension := 3 if _base == "Node3D" or ClassDB.class_exists(_base) and ClassDB.is_parent_class(_base,"Node3D") else (2 if _base == "Node2D" or ClassDB.class_exists(_base) and ClassDB.is_parent_class(_base,"Node2D") else 0)
	for item in Catalog.ITEMS:
		if tags and (item.dimension == 0 or dimension != 0 and item.dimension != dimension): continue
		if not tags and item.dimension != 0: continue
		var alias: String = Imports.alias_for(item,_symbols,_aliases)
		var label: String = item.canonical if str(item.canonical).begins_with(prefix) and not str(item.alias).begins_with(prefix) else item.alias
		if not label.begins_with(prefix) and not alias.begins_with(prefix): continue
		if alias != item.alias: label += " (as "+alias+")"
		result[label+" — "+item.canonical+" ("+item.origin+")"] = {"kind":CodeEdit.KIND_CLASS,"insert":alias,"import":{"alias":alias,"path":Catalog.path(item)},"match":prefix}
	return result
func _path_options(left: String, context: Dictionary, source: String, row: int, column: int) -> Array:
	if context.quote.length() != 1: return []
	var start := -1
	for token in context.tokens:
		if token.kind == "string" and token.text == context.quote: start = token.start
	if start < 0: return []
	var before := left.left(start).strip_edges()
	var tokens := _tokens(before)
	if tokens.is_empty(): return []
	var allowed: bool = tokens[-1].text == "extends" or tokens.size() >= 2 and tokens[-1].text == "(" and tokens[-2].text in ["load","preload"]
	if not allowed: return []
	var value := left.substr(start+1)
	if "\\" in value or value.contains("\"") or value.contains("'") or value.begins_with("user://") or value.is_absolute_path() and not value.begins_with("res://"): return []
	var base := Build.output_for(source).get_base_dir()
	var slash := value.rfind("/")
	var directory := value.left(slash+1) if slash >= 0 else ""
	var prefix := value.substr(slash+1)
	var target := directory if directory.begins_with("res://") else base.path_join(directory).simplify_path()
	if not target.begins_with("res://") or target.contains("/../"): return []
	for part in target.trim_prefix("res://").split("/"):
		if part.begins_with("."): return []
	if target != "res://":
		var containment := Build.new()
		containment._project = ProjectSettings.globalize_path("res://").trim_suffix("/")
		if not containment._safe(ProjectSettings.globalize_path(target).trim_suffix("/")): return []
	var access := DirAccess.open(target)
	if access == null: return []
	var result: Array = []
	var extensions := ResourceLoader.get_recognized_extensions_for_type("")
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty() and result.size() < 256:
		if not name.begins_with(".") and name.begins_with(prefix) and (not access.has_method("is_link") or not access.call("is_link",name)) and (access.current_is_dir() or name.get_extension() in extensions):
			var is_dir := access.current_is_dir()
			var insert: String = context.quote+directory+name+("/" if is_dir else context.quote)
			result.append({"text":insert,"insert":insert,"kind":CodeEdit.KIND_FILE_PATH,"row":row,"start":start,"column":column,"path":true})
		name = access.get_next()
	access.list_dir_end()
	return result
func import_plan(text: String, source: String, requests: Array = []) -> Dictionary:
	_index(text,source)
	if requests.is_empty():
		var lexical := Context.new()
		lexical.update(text)
		for row in range(lexical.lines.size()):
			for token in lexical.line(row).tokens:
				if token.kind != "tag" or not token.text.is_valid_identifier(): continue
				var item := Catalog.named(token.text)
				if not item.is_empty() and item.dimension != 0 and not _symbols.has(token.text): requests.append({"alias":token.text,"path":Catalog.path(item)})
	return Imports.plan(text,source,requests,_symbols,_aliases,_tokens(text))
func definition(text: String, source: String, symbol: String) -> String:
	_index(text,source)
	return _aliases.get(symbol,"")
func candidates(text: String, source: String, lexical: RefCounted, row: int, column: int) -> Array:
	_index(text,source)
	lexical.update(text)
	var context: Dictionary = lexical.context(row,column)
	if context.suppressed: return _path_options(lexical.lines[row].left(column),context,source,row,column)
	var left: String = lexical.lines[row].left(column)
	var prefix := ""
	var cursor := left.length()-1
	while cursor >= 0 and (left[cursor].is_valid_identifier() or left[cursor].is_valid_int() or left[cursor] == ":"):
		prefix = left[cursor]+prefix
		cursor -= 1
	if context.mode == "tag" and context.closing: prefix = "/"+prefix
	var offered: Dictionary = {}
	if context.mode == "tag":
		if context.closing:
			if not context.tags.is_empty(): offered["/"+context.tags[-1]] = {"kind":CodeEdit.KIND_CLASS}
		elif context.name_pending or not left.substr(maxi(0,left.rfind("<"))+1).contains(" ") and not left.substr(maxi(0,left.rfind("<"))+1).contains("\t"):
			for name in _classes:
				if ClassDB.is_parent_class(name,"Node") and ClassDB.can_instantiate(name): offered[name] = {"kind":CodeEdit.KIND_CLASS}
			for name in _aliases:
				if _node_type(name,_aliases): offered[name] = {"kind":CodeEdit.KIND_CLASS,"origin":"explicit Node preload"}
			for entry in ProjectSettings.get_global_class_list():
				if Catalog.named(str(entry["class"])).is_empty() and str(entry["class"]).begins_with(prefix) and _node_type(str(entry["class"]),{}): offered[entry["class"]] = {"kind":CodeEdit.KIND_CLASS,"origin":"project Node"}
			for item in Catalog.ITEMS:
				for alias in _aliases:
					if _aliases[alias] == Catalog.path(item): offered.erase(alias)
			offered.merge(_catalog_options(prefix,true))
		else:
			if not _node_type(context.tag,_aliases): return []
			var members := _members(context.tag,_aliases)
			for name in members:
				if members[name].kind in [CodeEdit.KIND_MEMBER,CodeEdit.KIND_SIGNAL] and members[name].get("writable",true) and name not in ["owner","script"]: offered[name] = members[name]
			if _node_type(context.tag,_aliases): offered.key = {"kind":CodeEdit.KIND_MEMBER}
			if members.has("value") and (members.value.get("value_type") == TYPE_BOOL or members.value.get("type") == "bool") and members.has("value_changed") and members.value_changed.get("args",[]).size() == 1 and members.value_changed.args[0] in ["bool",TYPE_BOOL]: offered["bind:value"] = {"kind":CodeEdit.KIND_MEMBER}
	elif context.mode == "body": return []
	elif cursor >= 0 and left[cursor] == ".":
		var begin := cursor-1
		while begin >= 0 and (left[begin].is_valid_identifier() or left[begin].is_valid_int() or left[begin] == "."): begin -= 1
		var receiver := left.substr(begin+1,cursor-begin-1)
		var chain := receiver.split(".")
		var members: Dictionary = {}
		if chain[0] == "self":
			for field in _symbols:
				if _symbols[field].owner.is_empty(): members[field] = _symbols[field]
		if chain[0] == "self": members.merge(_members(_base,_aliases),false)
		elif _symbols.has(chain[0]): members = _members(_symbols[chain[0]].type,_aliases)
		else: members = _members(chain[0],_aliases)
		for index in range(1,chain.size()): members = _members(str(members.get(chain[index],{}).get("type","")),_aliases)
		offered = members
	else:
		for word in Context.KEYWORDS: offered[word] = {"kind":CodeEdit.KIND_PLAIN_TEXT}
		for name in _classes: offered[name] = {"kind":CodeEdit.KIND_CLASS}
		for native_type in range(1,TYPE_MAX):
			var type_name: String = _types._native_type({"type":native_type})
			if not type_name.is_empty(): offered[type_name] = {"kind":CodeEdit.KIND_CLASS}
		offered.Variant = {"kind":CodeEdit.KIND_CLASS}
		for entry in ProjectSettings.get_global_class_list(): offered[entry["class"]] = {"kind":CodeEdit.KIND_CLASS}
		for field in _symbols:
			if _symbols[field].owner.is_empty() or _symbols[field].owner == _owners.get(row,""): offered[field] = _symbols[field]
		offered.merge(_members(_base,_aliases),false)
		offered.merge(_catalog_options(prefix,false))
		if cursor >= 0 and left[cursor] == "@":
			offered.clear()
			for name in ["bindable","tool","export","export_range","onready","warning_ignore"]: offered[name] = {"kind":CodeEdit.KIND_PLAIN_TEXT}
	var result: Array = []
	for name in offered:
		if (str(name).begins_with(prefix) or offered[name].has("match")) and (not str(name).begins_with("_") or prefix.begins_with("_") or _symbols.has(name)):
			var item: Dictionary = offered[name]
			var insert: String = item.get("insert",str(name).trim_prefix("bind:") if prefix.begins_with("bind:") else str(name))
			var display: String = str(name) if item.has("import") else (insert+" — "+str(item.origin) if item.has("origin") else insert)
			if context.mode == "tag" and not item.has("import") and ClassDB.class_exists(insert): display += " — Godot "+ClassDB.get_parent_class(insert)
			result.append({"text":display,"insert":insert,"kind":item.kind,"row":row,"start":cursor if context.mode == "tag" and context.closing else cursor+1,"column":column,"hint":item.get("hint",""),"imports":[item["import"]] if item.has("import") else []})
	result.sort_custom(func(a,b): return a.text < b.text)
	return result
