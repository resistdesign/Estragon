extends SceneTree
const Context = preload("res://addons/estragon/editor/lexical_context.gd")
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const Completion = preload("res://addons/estragon/editor/completion.gd")
const Create = preload("res://addons/estragon/editor/new_script.gd")
const Build = preload("res://addons/estragon/editor/build_service.gd")
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
var failed := false
var checks := 0
func check(value: bool, label: String) -> void:
	checks += 1
	print("E02_PROBE_CHECK ",label,": ",value)
	if not value: failed = true
func _initialize() -> void:
	var lexical := Context.new()
	var text := 'extends Node2D\nfunc view():\n\treturn <Node name={"a" if 1 < 2 else "b"}>{[<Node />]}</Node>\nvar literal = "<Node />" # <fake>\nvar multi = """start\n<Node /> # text\n"""\n'
	lexical.update(text)
	check(lexical.line(2).state.mode == "gd" and lexical.line(2).state.frames.is_empty(),"nested GGX restores expression/code scope")
	check(lexical.line(3).tokens.any(func(t): return t.kind == "string" and t.text.contains("<Node")),"quoted markup is string")
	check(lexical.line(5).tokens[0].kind == "string","multiline string remains string")
	var before := lexical.scanned_lines
	lexical.update(text.replace('"a"','"changed"'))
	lexical.line(2)
	check(lexical.scanned_lines-before == 1,"unchanged prefix lines retained, changed lexical state rescanned")
	for body in ['func view(): return <No','func view(): return <Node name={self.','func view(): return <Node>\n<!-- partial\n<Node />','var x = "unterminated\nvar repaired: int = 1\n']:
		lexical.update(body)
		for row in range(lexical.lines.size()): lexical.line(row)
		check(not lexical.records.is_empty(),"partial source tolerated")
	for spatial in [false,true]:
		var path := "res://app/Screens/Template"+str(spatial)+".gogo"
		var source := Create.template(path,spatial)
		var compiled := Compiler.compile(source,path,Build.output_for(path))
		check(compiled.ok,"template compiles at current installed root")
		if compiled.ok:
			var output := Build.output_for(path)
			DirAccess.make_dir_recursive_absolute(output.get_base_dir())
			var file := FileAccess.open(output,FileAccess.WRITE)
			file.store_string(compiled.code)
			file.close()
			var script: GDScript = load(output)
			check(script != null and script.can_instantiate(),"template actual-path native load")
	check(not Build.creation_check("res://ignored/File.gogo").ok,"ignored source root rejected")
	check(not Build.creation_check("res://app/../escape.gogo").ok,"traversal rejected")
	check(not Build.creation_check("user://File.gogo").ok,"external path rejected")
	var capabilities: Dictionary = {"engine":Engine.get_version_info().string,"native_analyzer":{},"public_methods":{}}
	for name in ["CodeEdit","ScriptEditor","GDScript","Script","ScriptLanguage","ScriptLanguageExtension"]:
		if not ClassDB.class_exists(name):
			capabilities.native_analyzer[name] = "class unavailable"
			continue
		var methods: Array = []
		for method in ClassDB.class_get_method_list(name):
			if method.name in ["complete_code","_complete_code","get_language","get_script_method_list","get_script_property_list","_confirm_code_completion","set_code_hint","request_code_completion"]: methods.append(str(method.name))
		capabilities.public_methods[name] = methods
		capabilities.native_analyzer[name] = ClassDB.class_has_method(name,"complete_code")
	var capability_file := FileAccess.open("res://e03-capabilities.json",FileAccess.WRITE)
	capability_file.store_string(JSON.stringify(capabilities,"\t"))
	capability_file.close()
	print("E03_CAPABILITIES ",JSON.stringify(capabilities))
	for spatial in [false,true]:
		var path := "res://app/Screens/Imported"+str(spatial)+".gogo"
		var body := "extends "+("Node3D" if spatial else "Node2D")+"\nfunc build_view() -> Element:\n\treturn "+('<Entry3D name="World" />\n' if spatial else '<Entry2D name="UI"><VBox><Text text="Hello Gogo" /></VBox></Entry2D>\n')
		var plan := Completion.new().import_plan(body,path)
		var lines := body.split("\n")
		lines.insert(plan.row,plan.text.trim_suffix("\n"))
		var authored := "\n".join(lines)
		var result := Compiler.compile(authored,path,Build.output_for(path))
		check(result.ok,"E03 selected catalog imports compile at actual installed path")
		if not result.ok:
			print(authored)
			for diagnostic in result.diagnostics: print(diagnostic.format())
		if result.ok:
			var output := Build.output_for(path)
			DirAccess.make_dir_recursive_absolute(output.get_base_dir())
			var file := FileAccess.open(output,FileAccess.WRITE)
			file.store_string(result.code)
			file.close()
			var script: GDScript = load(output)
			check(script != null and script.can_instantiate(),"E03 imports actual-path native load")
	print("E02_PROBE_ASSERTIONS ",checks)
	if not failed: print("E02_PROBE_OK")
	quit(1 if failed else 0)
