@tool
extends EditorPlugin
## Only loaded by check-editor.ts in its self-contained, disposable editor.

var _failed: bool = false
var _checks: int = 0

func _enter_tree() -> void:
	if OS.get_environment("ESTRAGON_EDITOR_TEST") == "1":
		_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	print("EDITOR_CHECK ", message, ": ", condition)
	if not condition:
		_failed = true

func _wait() -> void:
	await get_tree().create_timer(1.0).timeout

func _find_plugin(node: Node) -> EditorPlugin:
	if node.get_script() == load("res://addons/estragon/editor/plugin.gd"):
		return node
	for child in node.get_children():
		var found := _find_plugin(child)
		if found != null:
			return found
	return null

func _run() -> void:
	ProjectSettings.set_setting("estragon/editor/bun_executable", OS.get_environment("ESTRAGON_TEST_BUN"))
	await _wait()
	var plugin := _find_plugin(get_tree().root)
	_check(plugin != null, "plugin enabled")
	if plugin == null:
		get_tree().quit(1)
		return
	_check(load("res://tests/editor/highlighter_tests.gd").new().run(), "mixed-language token highlighting")
	_check(plugin._build(), "build passes")
	print("BUILD_REPORT ", plugin.last_report)
	var dock := EditorInterface.get_file_system_dock()
	dock.navigate_to_path("res://examples/counter/Counter.gogo")
	await _wait()
	for tree in dock.find_children("*", "Tree", true, false):
		var selected: TreeItem = tree.get_selected()
		if selected != null and selected.get_metadata(0) is String and str(selected.get_metadata(0)).ends_with("Counter.gogo"):
			print("SELECTED ", tree.name, " ", selected.get_metadata(0))
			tree.item_activated.emit()
	await _wait()
	var editor := EditorInterface.get_script_editor().get_current_editor()
	_check(editor != null, "native text editor opens gogo")
	if editor != null:
		var code: CodeEdit = editor.get_base_editor()
		print("HIGHLIGHTER ", code.syntax_highlighter)
		_check(code.syntax_highlighter != null and code.syntax_highlighter.get_script() == load("res://addons/estragon/editor/highlighter.gd"), "automatic extension highlighter")
	if editor == null:
		get_tree().quit(1)
		return
	var code: CodeEdit = editor.get_base_editor()
	if OS.get_environment("ESTRAGON_EDITOR_NATIVE") == "1":
		EditorInterface.set_main_screen_editor("Script")
		await _wait()
		await RenderingServer.frame_post_draw
		get_tree().root.get_texture().get_image().save_png("res://.godot/estragon/editor-highlight.png")
	var source := FileAccess.get_file_as_string("res://examples/counter/Counter.gogo")
	var proof := "\n\nfunc _ready() -> void:\n    var file := FileAccess.open(\"res://.godot/estragon/run-proof.txt\", FileAccess.WRITE)\n    file.store_string(str(count) + \"|\" + get_root().get_children()[1].text)\n    file.close()\n"
	if OS.get_environment("ESTRAGON_EDITOR_NATIVE") == "1":
		proof += "    await get_tree().process_frame\n    await RenderingServer.frame_post_draw\n    get_viewport().get_texture().get_image().save_png(\"res://.godot/estragon/game-\" + str(count) + \".png\")\n"
	code.text = source.replace("var count: int = 0", "var count: int = 5") + proof
	EditorInterface.get_script_editor().save_all_scripts()
	await _wait()
	await _wait()
	_check(FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd").contains("var count: int = 5"), "saved source compiles automatically before Play")
	code.text = source.replace("var count: int = 0", "var count: int = 7") + proof
	await _wait()
	print("BUFFER_PROOF ", code.text.contains("func _ready"))
	EditorInterface.open_scene_from_path("res://examples/counter/Counter.tscn")
	await _wait()
	EditorInterface.play_main_scene()
	await _wait()
	await _wait()
	print("PROOF_F5 ", FileAccess.file_exists("res://.godot/estragon/run-proof.txt"), " GENERATED_READY ", FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd").contains("func _ready"))
	_check(EditorInterface.is_playing_scene(), "F5 starts project")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "7|Count: 7", "F5 saves buffer and executes new generated expression")
	EditorInterface.stop_playing_scene()
	await _wait()
	DirAccess.remove_absolute("res://.godot/estragon/run-proof.txt")
	code.text = source.replace("var count: int = 0", "var count: int = 9") + proof
	EditorInterface.play_current_scene()
	await _wait()
	await _wait()
	_check(EditorInterface.is_playing_scene(), "F6 starts current scene")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "9|Count: 9", "F6 executes newest generated state/text")
	EditorInterface.stop_playing_scene()
	await _wait()
	DirAccess.remove_absolute("res://.godot/estragon/run-proof.txt")
	code.text = source.replace('<Text text="Estragon Gogo Counter"', '<Bogus text="Estragon Gogo Counter"') + proof
	EditorInterface.play_main_scene()
	await _wait()
	_check(not EditorInterface.is_playing_scene() and not FileAccess.file_exists("res://.godot/estragon/run-proof.txt"), "invalid Gogo blocks F5 and stale execution")
	_check(not plugin.last_report.ok and "Counter.gogo:" in str(plugin.last_report.diagnostics), "authored diagnostic shown")
	EditorInterface.play_current_scene()
	await _wait()
	_check(not EditorInterface.is_playing_scene(), "invalid Gogo blocks F6")
	code.text = source + proof
	EditorInterface.play_current_scene()
	await _wait()
	await _wait()
	_check(EditorInterface.is_playing_scene(), "fix allows F6 recovery")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "0|Count: 0", "recovery runs fixed code")
	EditorInterface.stop_playing_scene()
	await _wait()
	# Native compiler errors must block too, not merely Gogo syntax errors.
	code.text = source.replace("pressed={increment}", "pressed={missing_handler}")
	_check(not plugin._build(), "GDScript semantic error blocks Play")
	_check("Gogo source: examples/counter/Counter.gogo:" in str(plugin.last_report.diagnostics), "Godot diagnostic mapped to Gogo")
	code.text = source
	_check(plugin._build(), "semantic fix recovers")
	var service = load("res://addons/estragon/editor/build_service.gd")
	ProjectSettings.set_setting(service.BUN_SETTING, "/nonexistent/bun")
	_check(not plugin._build() and "Bun" in str(plugin.last_report.diagnostics), "missing Bun blocks build with actionable error")
	ProjectSettings.set_setting(service.BUN_SETTING, OS.get_environment("ESTRAGON_TEST_BUN"))
	var external := FileAccess.open("res://examples/counter/Counter.gogo", FileAccess.WRITE)
	external.store_string(source.replace("var count: int = 0", "var count: int = 4"))
	external.close()
	EditorInterface.get_resource_filesystem().scan()
	await _wait()
	await _wait()
	_check(FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd").contains("var count: int = 4"), "external changed source compiles after filesystem scan")
	code.text = source
	_check(plugin._build(), "restore after external edit")
	var previous := FileAccess.get_file_as_string(service.COMPILER)
	var file := FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string("process.exit(17);\n")
	file.close()
	_check(not plugin._build() and "report" in str(plugin.last_report.diagnostics), "compiler crash without report blocks Play")
	file = FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string(previous)
	file.close()
	_check(plugin._build(), "compiler restore recovers")
	file = FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string('import { writeFileSync } from "node:fs"; writeFileSync(process.argv[5], JSON.stringify({ok:true,diagnostics:[]}));\n')
	file.close()
	_check(not plugin._build() and "invalid compiler report" in str(plugin.last_report.diagnostics), "malformed success report cannot bypass build gate")
	file = FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string(previous)
	file.close()
	file = FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string("await new Promise(() => {});\n")
	file.close()
	ProjectSettings.set_setting(service.TIMEOUT_SETTING, 1.0)
	_check(not plugin._build() and "timed out" in str(plugin.last_report.diagnostics), "hung compiler times out and blocks Play")
	ProjectSettings.set_setting(service.TIMEOUT_SETTING, 30.0)
	file = FileAccess.open(service.COMPILER, FileAccess.WRITE)
	file.store_string(previous)
	file.close()
	_check(plugin._build(), "timeout recovery succeeds")
	var settings := EditorInterface.get_editor_settings()
	var extensions = settings.get_setting("docks/filesystem/textfile_extensions")
	EditorInterface.set_plugin_enabled("estragon/editor", false)
	await _wait()
	_check(_find_plugin(get_tree().root) == null, "plugin disables")
	_check(code.syntax_highlighter.get_script() == null, "disable detaches highlighter")
	_check(settings.get_setting("docks/filesystem/textfile_extensions") == extensions, "disable preserves user extension settings")
	EditorInterface.set_plugin_enabled("estragon/editor", true)
	await _wait()
	plugin = _find_plugin(get_tree().root)
	_check(plugin != null and plugin._build(), "plugin re-enables cleanly")
	_check(code.syntax_highlighter.get_script() == load("res://addons/estragon/editor/highlighter.gd"), "known Gogo tab regains highlighting on re-enable")
	await _wait()
	await _wait()
	var quiet_count: int = plugin.build_count
	await _wait()
	_check(plugin.build_count == quiet_count, "no endless generated-file rebuild loop")
	print("Editor checks: ", _checks)
	print("ESTRAGON_EDITOR_OK" if not _failed else "ESTRAGON_EDITOR_FAILED")
	get_tree().quit(1 if _failed else 0)
