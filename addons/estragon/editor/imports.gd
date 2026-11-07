@tool
extends RefCounted
## Pure bounded edit plans. No saves, generated writes or authored Script loads.
const Build = preload("build_service.gd")
const Source = preload("../compiler/source.gd")
const Catalog = preload("components.gd")
static func occupied(name: String, resource: String, symbols: Dictionary) -> bool:
	if symbols.has(name) or ClassDB.class_exists(name): return true
	for entry in ProjectSettings.get_global_class_list():
		if str(entry["class"]) == name and str(entry.path) != resource: return true
	return false
static func alias_for(item: Dictionary, symbols: Dictionary, aliases: Dictionary) -> String:
	for name in aliases:
		if aliases[name] == Catalog.path(item): return name
	var name: String = item.alias
	if occupied(name,Catalog.path(item),symbols): name = item.canonical
	var stem := name
	var suffix := 2
	while occupied(name,Catalog.path(item),symbols):
		name = stem+str(suffix)
		suffix += 1
	return name
static func declaration(name: String, resource: String, source: String) -> String:
	return "const "+name+" = preload("+JSON.stringify(Source.relative_path(Build.output_for(source).get_base_dir(),resource))+")\n"
static func plan(text: String, source: String, requested: Array, symbols: Dictionary, aliases: Dictionary, tokens: Array) -> Dictionary:
	var declarations: Array = []
	var names: Dictionary = aliases.duplicate()
	for request in requested:
		if names.get(request.alias) == request.path: continue
		# Caller resolves collisions explicitly; never replace an authored name.
		if occupied(request.alias,request.path,symbols) or names.has(request.alias): continue
		declarations.append(declaration(request.alias,request.path,source))
		names[request.alias] = request.path
	# A first build_view()->Element needs the explicit composition resource too.
	if not occupied("Element",Catalog.path(Catalog.named("Element")),symbols) and not names.has("Element"):
		for index in range(tokens.size()-1):
			if tokens[index].text == "->" and tokens[index+1].text == "Element":
				declarations.push_front(declaration("Element",Catalog.path(Catalog.named("Element")),source))
				break
	var row := 0
	for token in tokens:
		if token.indent == 0 and token.text in ["extends","class_name"]: row = maxi(row,int(token.row)+1)
	# Preserve file-level tool/icon annotations when no extends header exists yet.
	if row == 0:
		var lines := text.split("\n")
		while row < lines.size() and (lines[row].strip_edges().is_empty() or lines[row].strip_edges().begins_with("#") or lines[row].begins_with("@tool") or lines[row].begins_with("@icon")): row += 1
	return {"row":mini(row,text.count("\n")),"text":"".join(declarations)}
