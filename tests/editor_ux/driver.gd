@tool
extends EditorPlugin
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const Services = preload("res://addons/estragon/editor/language_services.gd")
var interface: EditorInterface
var plugin: EditorPlugin
var home: CodeEdit
var original := ""
var e03_screen := ""
var failed := false
var checks := 0
const HOME := "res://app/Screens/Home.gogo"
const OUTPUT := "res://app/Screens/generated/Home.gd"
const PLUGIN := "res://addons/estragon/editor/plugin.cfg"
func _enter_tree() -> void:
	interface = get_editor_interface()
	_run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	print("E02_EDITOR_CHECK ",label,": ",value)
	if not value: failed = true
func until(condition: Callable, label: String, seconds: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await get_tree().process_frame
	check(false,label)
	return false
func frames(count: int = 3) -> void:
	for index in range(count): await get_tree().process_frame
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://e02-"+label+".png")
func find_plugin() -> bool:
	for node in get_tree().root.find_children("*","EditorPlugin",true,false):
		if node.get_script() != null and node.get_script().resource_path == PLUGIN.get_base_dir().path_join("plugin.gd"): plugin = node
	return plugin != null and plugin.last_report.get("ok",false) and not plugin._filesystem_busy() and not plugin._extensions_pending
func current(path: String) -> CodeEdit:
	if plugin == null or plugin._services == null: return null
	for entry in plugin._services.entries.values():
		var code = entry.code.get_ref()
		if entry.path == path and code != null and code.is_visible_in_tree(): return code
	return null
func tools_action() -> bool:
	for menu in interface.get_base_control().find_children("*","PopupMenu",true,false):
		for index in range(menu.item_count):
			if menu.get_item_text(index) == "New Gogo Script…":
				menu.index_pressed.emit(index)
				return true
	return false
func create(path: String, spatial: bool = false) -> CodeEdit:
	check(tools_action(),"Project > Tools native action exists")
	if not await until(func(): return plugin._new_script.dialog.visible,"native file dialog visible"): return null
	if path == HOME: await capture("creation")
	var dialog = plugin._new_script.dialog
	plugin._new_script.dimension.select(1 if spatial else 0)
	dialog.current_path = path
	dialog.get_line_edit().text = path.get_file()
	dialog.get_ok_button().pressed.emit()
	if not await until(func(): return FileAccess.file_exists(path) and current(path) != null,"created source opens in stock ScriptEditor"): return null
	return current(path)
func set_source(code: CodeEdit, text: String) -> void:
	var marker := text.find("§")
	var left := text.left(marker)
	code.text = text.replace("§","")
	code.set_caret_line(left.count("\n"))
	code.set_caret_column(left.get_slice("\n",left.count("\n")).length())
	code.grab_focus()
func complete(text: String, option: String, inserted: String, label: String, selected_prefix: bool = false) -> void:
	set_source(home,text)
	if selected_prefix: home.select(home.get_caret_line(),home.get_caret_column()-2,home.get_caret_line(),home.get_caret_column())
	await frames()
	home.request_code_completion(true)
	if not await until(func(): return not home.get_code_completion_options().is_empty(),label+" popup opens"): return
	var options := home.get_code_completion_options()
	var selected := -1
	for index in range(options.size()):
		if options[index].display_text == option or options[index].display_text.begins_with(option+" "): selected = index
	check(selected >= 0,label+" native popup contains expected candidate")
	if selected < 0: return
	if label == "imported tag": await capture("completion")
	var before := home.text
	var before_row := home.get_caret_line()
	var before_column := home.get_caret_column()
	home.set_code_completion_selected_index(selected)
	if label == "E03 Text import":
		await action("ui_down")
		check(home.get_code_completion_selected_index()!=selected,"native popup keyboard navigation")
		await action("ui_up")
		check(home.get_code_completion_selected_index()==selected,"native popup keyboard selection restored")
		await action("ui_text_completion_accept")
	else: home.confirm_code_completion()
	check(home.text.contains(inserted),label+" native confirmation inserts correct text")
	home.undo()
	check(home.text == before,label+" insertion/imports are one undoable operation")
	check(home.get_caret_line()==before_row and home.get_caret_column()==before_column,label+" undo restores caret")
	if selected_prefix: check(home.has_selection() and home.get_selected_text()=="Te","undo restores selected prefix")
	home.redo()
	check(home.text.contains(inserted),label+" insertion redo")
func color(code: CodeEdit, row: int, column: int) -> Color:
	var colors: Dictionary = code.syntax_highlighter.get_line_syntax_highlighting(row)
	var keys := colors.keys()
	keys.sort()
	var result := Color.WHITE
	for key in keys:
		if key <= column: result = colors[key].color
	return result
func native_reference(text: String, row: int, column: int) -> Color:
	var edit := TextEdit.new()
	edit.text = text
	edit.syntax_highlighter = ClassDB.instantiate("GDScriptSyntaxHighlighter")
	var colors := edit.syntax_highlighter.get_line_syntax_highlighting(row)
	var keys := colors.keys()
	keys.sort()
	var result := Color.WHITE
	for key in keys:
		if key <= column: result = colors[key].color
	edit.free()
	return result
func proof() -> bool:
	if not FileAccess.file_exists("res://.godot/e02-game.json"): return false
	var json := JSON.new()
	return json.parse(FileAccess.get_file_as_string("res://.godot/e02-game.json")) == OK and json.data is Dictionary and json.data.get("text") == "Hello Gogo"
func play(mode: String) -> void:
	if FileAccess.file_exists("res://.godot/e02-game.json"): DirAccess.remove_absolute("res://.godot/e02-game.json")
	if mode == "main": interface.play_main_scene()
	else: interface.play_current_scene()
	print("E03_PLAY_ELEMENT ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	if not plugin.last_report.ok: print("E03_PLAY_SOURCE ",FileAccess.get_file_as_string(HOME))
	if await until(proof,mode+" child game runs created Gogo",20): check(interface.is_playing_scene(),mode+" native child active")
	interface.stop_playing_scene()
	await until(func(): return not interface.is_playing_scene(),"child stopped")
func blocked(mode: String, unsavable: bool = false) -> void:
	if unsavable: print("E02_EXPECTED_UNSAVABLE_BEGIN")
	var bytes := FileAccess.get_file_as_bytes(OUTPUT)
	var maps := FileAccess.get_file_as_bytes(OUTPUT+".map.json")
	var stamp := FileAccess.get_modified_time(OUTPUT)
	var uid := FileAccess.get_file_as_bytes(OUTPUT+".uid") if FileAccess.file_exists(OUTPUT+".uid") else PackedByteArray()
	var cached = load(OUTPUT)
	var source: String = cached.source_code
	home.text = original+"\n# edited unsavable buffer\n" if unsavable else original.replace('</Entry>','</Wrong>').replace('</Entry2D>','</Wrong>')
	if mode == "main": interface.play_main_scene()
	else: interface.play_current_scene()
	await get_tree().create_timer(0.8).timeout
	check(not interface.is_playing_scene() and not plugin.last_report.ok,mode+(" unsavable" if unsavable else " invalid")+" source blocks Play")
	check(FileAccess.get_file_as_bytes(OUTPUT)==bytes and FileAccess.get_file_as_bytes(OUTPUT+".map.json")==maps and FileAccess.get_modified_time(OUTPUT)==stamp,"failed Play preserves bytes/maps/timestamp")
	check((FileAccess.get_file_as_bytes(OUTPUT+".uid") if FileAccess.file_exists(OUTPUT+".uid") else PackedByteArray())==uid and load(OUTPUT)==cached and cached.source_code==source,"failed Play preserves UID/Script identity")
	if unsavable: print("E02_EXPECTED_UNSAVABLE_END")
func action(name: String) -> void:
	for event in InputMap.action_get_events(name):
		if event is InputEventKey:
			var key = event.duplicate()
			key.pressed = true
			Input.parse_input_event(key)
			await frames()
			key.pressed = false
			Input.parse_input_event(key)
			return
	check(false,"native key binding available: "+name)
func _e03() -> String:
	color(home,0,0)
	var capabilities := {"engine":Engine.get_version_info().string,"native_highlighter_class":ClassDB.class_exists("GDScriptSyntaxHighlighter"),"native_highlighter_available":ClassDB.class_exists("GDScriptSyntaxHighlighter") and ClassDB.can_instantiate("GDScriptSyntaxHighlighter"),"native_highlighter_used":home.syntax_highlighter.uses_native(),"acceptance_virtual_attached":home.get_script()!=null,"native_analyzer":ClassDB.class_has_method("GDScript","complete_code"),"cached_reference_api":ResourceLoader.has_method("get_cached_ref"),"symlink_api":DirAccess.open("res://").has_method("is_link")}
	var file := FileAccess.open("res://e03-editor-capabilities.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(capabilities,"\t"))
	file.close()
	print("E03_EDITOR_CAPABILITIES ",JSON.stringify(capabilities))
	check(capabilities.native_highlighter_used==capabilities.native_highlighter_available,"native GDScript highlighter reused where exposed")
	var blank := 'extends Node2D\n\nfunc build_view() -> Element:\n\treturn <Te§ name="Greeting" text="Hello Gogo" />\n'
	set_source(home,blank)
	await frames()
	var unchanged := home.text
	home.request_code_completion(true)
	if await until(func(): return not home.get_code_completion_options().is_empty(),"E03 installed Text discoverable before any import"):
		check(home.get_code_completion_options().any(func(o): return o.display_text.begins_with("Text — EstragonText")),"Text catalog identifies actual Estragon widget")
		check(home.text == unchanged and not home.text.contains("preload("),"candidate display never inserts imports")
		home.cancel_code_completion()
		check(home.text == unchanged,"cancel never edits source")
	var source := 'extends Node2D\n\nfunc build_view() -> Element:\n\treturn <Ent§ name="UI" viewport_width_scale={0.9}>\n\t\t<VB name="Box">\n\t\t\t<Te name="Greeting" text="Hello Gogo" />\n\t\t</VBox>\n\t</Entry2D>\n'
	await complete(source,"Entry2D","<Entry2D name=","E03 entry and Element automatic imports")
	check(home.text.contains("const Entry2D = preload(") and home.text.contains("const Element = preload("),"entry acceptance imports real layout and Element")
	await complete(home.text.replace('<VB name=','<VB§ name='),"VBox","<VBox name=","E03 VBox import")
	await complete(home.text.replace('<Te name=','<Te§ name='),"Text","<Text name=","E03 Text import")
	var screen := home.text
	check(screen.count("const Text = preload(")==1 and screen.count("const Element = preload(")==1 and not screen.contains('res://addons/estragon'),"first screen resolves installed resources without manual paths")
	await capture("imports")
	await complete(screen.replace('</VBox>','<Te§ name="Second" text="Again" />\n\t\t</VBox>'),"Text","<Text name=\"Second\"","E03 repeated component")
	check(home.text.count("const Text = preload(")==1,"repeated acceptance reuses import")
	home.symbol_lookup.emit("Text",0,0)
	if await until(func(): return interface.get_script_editor().get_current_script()!=null and interface.get_script_editor().get_current_script().resource_path.ends_with("/runtime/node/text.gd"),"E03 alias lookup opens its real Script"):
		check(interface.get_script_editor().get_current_script().resource_path.contains("node_modules/"),"alias navigation targets direct installation")
	await plugin._navigation.open(HOME)
	await until(func(): return current(HOME)!=null,"return from alias definition")
	home = current(HOME)
	var manual := screen.replace('const Text =','const FancyText =').replace('<Text name=','<FancyText name=')
	await complete(manual.replace('<FancyText name=','<Te§ name='),"Text","<FancyText name=","E03 manual alias reuse")
	check(home.text.count("const FancyText = preload(")==1 and not home.text.contains("const Text ="),"manual preload reused without duplicate")
	await complete(blank.replace('func build_view()', 'var Text: int = 1\nfunc build_view()'),"Text","<EstragonText name=","E03 collision chooses explicit canonical alias")
	check(home.text.contains("var Text: int = 1") and home.text.contains("const EstragonText = preload("),"collision preserves authored declaration")
	await complete('extends Node2D\nfunc build_view() -> Ele§:\n\treturn null\n',"Element","-> Element:","E03 explicit Element type import")
	set_source(home,'extends Node2D\nfunc view():\n\treturn <Bu§ />\n')
	home.request_code_completion(true)
	if await until(func(): return not home.get_code_completion_options().is_empty(),"native Button catalog"):
		check(home.get_code_completion_options().any(func(o): return o.display_text.begins_with("Button — Godot")),"Godot Button remains native, not UiButton")
	home.cancel_code_completion()
	await complete('extends Node2D\nconst Example = preload("res://app/Ord§")\n', '"res://app/Ordinary.gd"','preload("res://app/Ordinary.gd")',"E03 real resource path")
	set_source(home,'extends Node2D\nvar arbitrary = "res://app/Ord§"\n')
	home.request_code_completion(true)
	check(home.get_code_completion_options().is_empty(),"ordinary strings do not get resource candidates")
	set_source(home,'extends Node2D\nfunc demo():\n\trotate(§)\n')
	await frames()
	check(plugin._services.entries[home.get_instance_id()].hint.contains("radians: float"),"native ClassDB callable signature displayed")
	await capture("call-hint")
	await complete('extends Node2D\nvar offset: Vec§\n',"Vector2","offset: Vector2","E03 engine builtin type names")
	await complete('extends Node2D\nfunc demo(camera: Camera2D):\n\tvar local: Camera2D\n\tlocal.zo§\n',"zoom","local.zoom","E03 typed local variable")
	# Other authenticated unsaved Gogo source is authoritative, without new().
	var model := await create("res://app/Screens/LiveModel.gogo")
	if model != null:
		model.text = 'extends Node2D\n@export var unsaved_speed: float = 1.0\nfunc _init():\n\tpush_error("AUTHORED_MODEL_MUST_NOT_EXECUTE_FOR_COMPLETION")\n'
		await plugin._navigation.open(HOME)
		await until(func(): return current(HOME)!=null,"return from live model")
		home = current(HOME)
		await complete('extends Node2D\nconst Model = preload("LiveModel.gd")\nvar model: Model\nfunc demo():\n\tmodel.uns§\n',"unsaved_speed","model.unsaved_speed","E03 other unsaved Gogo metadata")
		await complete('extends Node2D\nconst Custom = preload("LiveModel.gd")\nfunc build_view() -> Element:\n\treturn <Cu§ />\n',"Custom","<Custom />","E03 explicit custom Node tag without constructor execution")
		# Restore a harmless valid source before the existing save/Play checks.
		model.text = 'extends Node2D\nvar saved_speed: float = 1.0\n'
	await complete('@tool\nextends Node2D\n# copyright café 😀\nfunc build_view() -> Element:\n\treturn <Te§ text="Unicode" />\n',"Text","<Text text=","E03 Unicode selection/import placement",true)
	check(home.text.begins_with("@tool\nextends Node2D\nconst Element") and home.text.contains("# copyright café 😀"),"imports preserve annotations/header/comments")
	set_source(home,blank)
	await frames()
	# Explicit public Tools action also repairs typed, unbound component names.
	home.text = blank.replace("§","").replace("<Te ","<Text ")
	var before_fix := home.text
	for menu in interface.get_base_control().find_children("*","PopupMenu",true,false):
		for index in range(menu.item_count):
			if menu.get_item_text(index)=="Add Missing Gogo Imports": menu.index_pressed.emit(index)
	check(home.text.contains("const Text = preload(") and home.text.contains("const Element = preload("),"explicit missing-import action")
	home.undo()
	check(home.text==before_fix,"explicit import repair is one undoable operation")
	home.text = screen
	return screen
func _run() -> void:
	if not await until(find_plugin,"installed addon activated"): finish(); return
	var editor_settings := interface.get_editor_settings()
	if editor_settings.has_setting("run/window_placement/game_embed_mode"):
		editor_settings.set_setting("run/window_placement/game_embed_mode",-1)
		get_tree().root.propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
		await frames()
	if FileAccess.file_exists("res://.godot/e02-restart.request"):
		await plugin._navigation.open(HOME)
		if await until(func(): return current(HOME)!=null,"restart authenticates restored Gogo tab"):
			home = current(HOME)
			original = home.text
			await complete(original.replace('return <Entry','self.glo§\n\treturn <Entry'),"global_position","self.global_position","restart completion")
			home.text = original
			await play("main")
		finish()
		return
	interface.get_editor_settings().set_setting("run/auto_save/save_before_running",false)
	home = await create(HOME)
	if home == null: finish(); return
	original = home.text
	e03_screen = await _e03()
	home.text = original
	check(original.contains('build_view() -> Element') and not original.contains('res://addons/estragon'),"valid template imports actual installation relatively")
	# Cancel and rejected paths exercise the native dialog without touching source.
	check(tools_action(),"creation menu can be reopened")
	plugin._new_script.dialog.current_path = "res://app/Screens/Cancelled.gogo"
	plugin._new_script.dialog.get_cancel_button().pressed.emit()
	await frames()
	check(not FileAccess.file_exists("res://app/Screens/Cancelled.gogo"),"cancel creates no source")
	for rejected in ["res://app/Existing.gogo","res://tests/Rejected.gogo"]:
		var existing := FileAccess.get_file_as_string("res://app/Existing.gogo")
		tools_action()
		plugin._new_script.dialog.current_path = rejected
		plugin._new_script.dialog.get_line_edit().text = rejected.get_file()
		plugin._new_script.dialog.get_ok_button().pressed.emit()
		await frames()
		# 4.0 FileDialog lacks the overwrite-warning toggle. Accept its native
		# warning and prove Estragon still refuses to write existing source.
		if rejected.ends_with("Existing.gogo") and plugin._new_script.dialog is FileDialog:
			for warning in plugin._new_script.dialog.find_children("*","ConfirmationDialog",true,false):
				if warning.visible: warning.get_ok_button().pressed.emit()
			await frames()
		check(plugin._new_script.error.visible,"existing/ignored creation visibly rejected")
		check(FileAccess.get_file_as_string("res://app/Existing.gogo")==existing and not FileAccess.file_exists("res://tests/Rejected.gogo"),"rejected creation preserves source")
		plugin._new_script.error.hide()
		plugin._new_script.dialog.hide()
	var model := original.replace('func build_view()', 'var greeting: String = "Hello"\nvar camera: Camera2D\nsignal accepted\nfunc build_view()')
	await complete(model.replace('<Text name=', '<Te§ name='),"Text","<Text name=","imported tag")
	await complete(model.replace('viewport_width_scale','view§'),"viewport_width_scale","viewport_width_scale","known attribute")
	await complete(model.replace('return <Entry', 'self.glo§\n\treturn <Entry'),"global_position","self.global_position","self native member")
	await complete(model.replace('text="Hello Gogo"','text={self.gree§}'),"greeting","self.greeting","GGX expression member")
	await complete(model.replace('return <Entry','camera.zo§\n\treturn <Entry'),"zoom","camera.zoom","typed native member")
	await complete(model.replace('</Entry>','</Ent§>'),"/Entry","</Entry>","closing tag")
	set_source(home,model.replace('return <Entry','self.glo§\n\treturn <Entry'))
	await frames()
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_SPACE
	shortcut.ctrl_pressed = true
	shortcut.pressed = true
	Input.parse_input_event(shortcut)
	await until(func(): return not home.get_code_completion_options().is_empty(),"native Ctrl+Space requests completion")
	home.cancel_code_completion()
	for source in ['# <Node self.§','var text = "self.§"']:
		set_source(home,source)
		home.request_code_completion(true)
		check(home.get_code_completion_options().is_empty(),"comments/strings suppress popup")
	set_source(home,model.replace('return <Entry','self§\n\treturn <Entry'))
	home.insert_text_at_caret(".")
	if await until(func(): return not home.get_code_completion_options().is_empty(),"automatic dot completion"): home.cancel_code_completion()
	home.text = original
	await frames()
	# Live replacement, editing and undo must update the actual tab's palette.
	set_source(home,'extends Node2D\n@bindable\nvar café: Vector2 = Vector2.ZERO\nfunc view():\n\treturn <Node name={1 < 2}>{[<Node />]}<!-- comment\ncontinued --></Node>\nvar literal = "<Node />"\nvar multi = """start\n<Node />\n"""\n§')
	await frames()
	var live = home.syntax_highlighter
	var type_color: Color = native_reference("var café: Vector2 = Vector2.ZERO",0,10) if live.uses_native() else live.color("type")
	check(color(home,1,1)==live.color("annotation") and color(home,2,10)==type_color,"annotation and native/fallback type-hint theme colors")
	check(color(home,4,22)==live.color("symbol") and color(home,5,0)==live.color("comment"),"comparison remains code; multiline GGX comment")
	check(color(home,6,16)==live.color("string") and color(home,8,0)==live.color("string"),"quoted markup and multiline string stay strings")
	home.set_caret_line(8)
	home.set_caret_column(0)
	home.insert_text_at_caret('"""')
	await frames()
	check(color(home,8,3)!=live.color("string"),"live closing quote changes following scope")
	home.undo()
	await frames()
	check(color(home,8,0)==live.color("string"),"undo restores multiline scope")
	home.redo()
	await frames()
	check(color(home,8,3)!=live.color("string"),"redo updates scope again")
	home.text = original
	await frames()
	var highlighter = home.syntax_highlighter
	check(highlighter.get_script()==Highlighter,"stock authenticated tab uses Gogo highlighter")
	check(color(home,0,0)==highlighter.color("keyword"),"GDScript theme keyword color")
	check(plugin._services.entries[home.get_instance_id()].model.metadata_reads>0,"already-held Script metadata reused without authored load/new")
	var settings := interface.get_editor_settings()
	var old_color: Color = settings.get_setting("text_editor/theme/highlighting/keyword_color")
	settings.set_setting("text_editor/theme/highlighting/keyword_color",Color(0.9,0.2,0.1))
	highlighter.update_cache()
	check(color(home,0,0)==Color(0.9,0.2,0.1),"theme setting changes reflected")
	settings.set_setting("text_editor/theme/highlighting/keyword_color",old_color)
	highlighter.update_cache()
	home.text = original.replace('</Entry>','</Wrong>')
	if await until(func(): return home.get_line_gutter_text(home.get_line_count()-2,plugin._services._gutter_index(home))=="!","authored syntax diagnostic gutter"):
		await capture("diagnostic")
		var record: Dictionary = plugin._services.entries[home.get_instance_id()].records[0]
		plugin._diagnostics.meta_clicked.emit(record)
		await frames()
		check(home.get_caret_line()==record.line-1,"panel link navigates authored Gogo line")
	check(FileAccess.get_file_as_string(HOME)==original,"idle analysis never writes incomplete buffer")
	home.text = original
	await get_tree().create_timer(0.6).timeout
	check(plugin._services.entries[home.get_instance_id()].records.is_empty(),"repair clears markers")
	home.text = 'extends Node2D\nfunc view():\n\treturn <Node name="😀"></Wrong>\n'
	if await until(func(): return not plugin._services.entries[home.get_instance_id()].records.is_empty(),"Unicode syntax diagnostic"):
		var record: Dictionary = plugin._services.entries[home.get_instance_id()].records[0]
		await plugin._services.navigate(record)
		check(home.get_caret_column()==Services.scalar_column(home.get_line(record.line-1),record.column),"UTF-16 span navigates Unicode CodeEdit column")
		check(home.get_caret_column()<record.column-1,"non-BMP source position is converted")
	home.text = original
	interface.edit_script(load("res://app/Ordinary.gd"))
	await frames(8)
	var ordinary: CodeEdit = interface.get_script_editor().get_current_editor().get_base_editor()
	check(ordinary != home and ordinary.syntax_highlighter.get_script()!=Highlighter,"ordinary gd retains native highlighter")
	check(not plugin._services.entries.has(ordinary.get_instance_id()) and plugin._services._gutter_index(ordinary)<0,"ordinary gd has no Gogo services/gutter")
	var spatial := await create("res://app/Screens/Spatial.gogo",true)
	check(spatial != null and spatial.text.begins_with('extends Node3D'),"second Gogo tab / spatial template")
	await plugin._navigation.open(HOME)
	await until(func(): return current(HOME)!=null,"return to Home tab")
	home = current(HOME)
	original = e03_screen
	var attached := original+'\nfunc _ready() -> void:\n\tif not Engine.is_editor_hint(): _game_proof.call_deferred()\nfunc _game_proof() -> void:\n\tawait get_tree().process_frame\n\tawait get_tree().process_frame\n\tawait RenderingServer.frame_post_draw\n\tget_viewport().get_texture().get_image().save_png(\"res://e03-game.png\")\n\tvar output := FileAccess.open("res://.godot/e02-game.json",FileAccess.WRITE)\n\toutput.store_string(JSON.stringify({"text":get_node("UI").find_child("Greeting",true,false).text}))\n\toutput.close()\n'
	home.text = attached
	print("E03_BEFORE_BUILD ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	check(plugin._build(),"native save/build before scene attachment")
	print("E03_AFTER_BUILD ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	if preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path.is_empty():
		check(false,"framework Script path preserved after build")
		finish()
		return

	original = attached
	var host := Node2D.new()
	host.name = "Home"
	var executable = load(OUTPUT)
	print("E03_AFTER_LOAD ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	host.set_script(executable)
	print("E03_AFTER_ATTACH ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)

	var packed := PackedScene.new()
	packed.pack(host)
	print("E03_BEFORE_PACK_ELEMENT ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	ResourceSaver.save(packed,"res://app/Home.tscn")
	print("E03_AFTER_PACK_ELEMENT ",preload("res://addons/estragon/editor/components.gd").named("Element").script.resource_path)
	host.free()
	ProjectSettings.set_setting("application/run/main_scene","res://app/Home.tscn")
	ProjectSettings.save()
	interface.open_scene_from_path("res://app/Home.tscn")
	await until(func(): return interface.get_edited_scene_root()!=null and interface.get_edited_scene_root().scene_file_path=="res://app/Home.tscn","attached scene opens")
	for mode in ["main","current"]:
		await play(mode)
		await blocked(mode)
		home.text = original
		await play(mode)
		DirAccess.rename_absolute(HOME,HOME+".backup")
		DirAccess.make_dir_absolute(HOME)
		await blocked(mode,true)
		DirAccess.remove_absolute(HOME)
		DirAccess.rename_absolute(HOME+".backup",HOME)
		home.text = original
		await play(mode)
	var count := home.code_completion_requested.get_connections().size()
	interface.set_plugin_enabled(PLUGIN,false)
	await frames()
	check(not home.code_completion_enabled and home.code_completion_requested.get_connections().size()<count,"disable removes Gogo handlers/completion")
	var gutter_exists := false
	for index in range(home.get_gutter_count()): gutter_exists = gutter_exists or home.get_gutter_name(index)==Services.GUTTER
	check(not gutter_exists,"disable removes only own diagnostic gutter")
	plugin = null
	interface.set_plugin_enabled(PLUGIN,true)
	if await until(find_plugin,"re-enable reattaches editor services"):
		await plugin._navigation.open(HOME)
		await until(func(): return current(HOME)!=null,"visible Gogo tab reauthenticated")
		check(home.code_completion_enabled,"re-enabled completion")
	if not failed:
		var restart := FileAccess.open("res://.godot/e02-restart.request",FileAccess.WRITE)
		restart.store_string("restart")
		restart.close()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://e02-editor.png")
	finish()
func finish() -> void:
	print("E02_EDITOR_ASSERTIONS ",checks," failed=",failed)
	if not failed: print("E02_EDITOR_OK")
	get_tree().quit(1 if failed else 0)
