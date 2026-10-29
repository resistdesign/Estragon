@tool
extends EditorPlugin
## Only loaded by the self-contained, Godot-only editor integration harness.

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
	await _wait()
	if FileAccess.file_exists("res://.godot/estragon/restart.txt"):
		await _restart()
		return
	# Only this self-contained editor: prove our gate saves dirty TextFiles
	# even when Godot's own pre-run autosave is disabled.
	EditorInterface.get_editor_settings().set_setting("run/auto_save/save_before_running", false)
	var plugin := _find_plugin(get_tree().root)
	_check(plugin != null, "plugin enabled")
	_check(not DirAccess.dir_exists_absolute("res://tools") and not FileAccess.file_exists("res://package.json"), "fresh project has no repository toolchain")
	_check(not ProjectSettings.has_setting("estragon/editor/bun_executable"), "no executable configuration")
	for directory in OS.get_environment("PATH").split(":", false):
		_check(DirAccess.get_files_at(directory).is_empty(), "editor and games have no tool executables")
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
	var proof := FileAccess.get_file_as_string("res://tests/editor/game_proof.txt")
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
	await _wait_for_proof("7|Count: 7")
	print("PROOF_F5 ", FileAccess.file_exists("res://.godot/estragon/run-proof.txt"), " GENERATED_READY ", FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd").contains("func _ready"))
	_check(EditorInterface.is_playing_scene(), "F5 starts project")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "7|Count: 7", "F5 saves buffer and executes new generated expression")
	_check_interactions()
	_check(EditorInterface.get_edited_scene_root().get_script().source_code.contains("var count: int = 7"), "editor resource reflects newest generated source")
	EditorInterface.stop_playing_scene()
	await _wait()
	DirAccess.remove_absolute("res://.godot/estragon/run-proof.txt")
	code.text = source.replace("var count: int = 0", "var count: int = 9") + proof
	EditorInterface.play_current_scene()
	await _wait_for_proof("9|Count: 9")
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
	await _wait_for_proof("0|Count: 0")
	_check(EditorInterface.is_playing_scene(), "fix allows F6 recovery")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "0|Count: 0", "recovery runs fixed code")
	EditorInterface.stop_playing_scene()
	await _wait()
	# Both actual Play paths must reject native semantic errors as well.
	DirAccess.remove_absolute("res://.godot/estragon/run-proof.txt")
	var valid_output := FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd")
	code.text = source.replace("pressed={increment}", "pressed={missing_handler}")
	EditorInterface.play_main_scene()
	await _wait()
	_check(not EditorInterface.is_playing_scene() and not FileAccess.file_exists("res://.godot/estragon/run-proof.txt"), "semantic error blocks F5 without stale execution")
	_check("examples/counter/Counter.gogo:" in str(plugin.last_report.diagnostics), "Godot diagnostic mapped to Gogo")
	EditorInterface.play_current_scene()
	await _wait()
	_check(not EditorInterface.is_playing_scene() and not FileAccess.file_exists("res://.godot/estragon/run-proof.txt"), "semantic error blocks F6 without stale execution")
	_check(FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd") == valid_output, "semantic failure retains previous generated bytes")
	code.text = source + proof
	EditorInterface.play_main_scene()
	await _wait_for_proof("0|Count: 0")
	_check(EditorInterface.is_playing_scene(), "semantic repair allows F5 recovery")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "0|Count: 0", "semantic repair executes current code")
	_check_interactions()
	EditorInterface.stop_playing_scene()
	await _wait()
	code.text = source
	_check(plugin._build(), "restore after semantic repair")
	var external := FileAccess.open("res://examples/counter/Counter.gogo", FileAccess.WRITE)
	external.store_string(source.replace("var count: int = 0", "var count: int = 4"))
	external.close()
	EditorInterface.get_resource_filesystem().scan()
	await _wait()
	await _wait()
	_check(FileAccess.get_file_as_string("res://examples/counter/generated/Counter.gd").contains("var count: int = 4"), "external changed source compiles after filesystem scan")
	code.text = source
	_check(plugin._build(), "restore after external edit")
	# New and changed named output must preserve Godot resource/class identity.
	var named_path := "res://examples/counter/Named.gogo"
	var named_source := "class_name EstragonEditorNamedProbe\nextends RefCounted\nfunc build() -> EstragonRect:\n    return <Rect width=\"2\"/>\n"
	var named_file := FileAccess.open(named_path, FileAccess.WRITE)
	named_file.store_string(named_source)
	named_file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _wait()
	await _wait()
	_check(FileAccess.file_exists("res://examples/counter/generated/Named.gd"), "new Gogo file compiles automatically")
	var named_script := load("res://examples/counter/generated/Named.gd") as GDScript
	_check(named_script.get_global_name() == "EstragonEditorNamedProbe", "generated class identity recognized")
	_check(ProjectSettings.get_global_class_list().any(func(entry: Dictionary) -> bool: return entry.class == "EstragonEditorNamedProbe" and entry.path == "res://examples/counter/generated/Named.gd"), "new generated class registered at its resource path")
	named_file = FileAccess.open(named_path, FileAccess.WRITE)
	named_file.store_string(named_source.replace('width="2"', 'width="4"'))
	named_file.close()
	EditorInterface.get_resource_filesystem().scan()
	await _wait()
	await _wait()
	_check(load("res://examples/counter/generated/Named.gd") == named_script and named_script.source_code.contains("4.0"), "named Script identity retained with current generated code")
	var settings := EditorInterface.get_editor_settings()
	var extensions = settings.get_setting("docks/filesystem/textfile_extensions")
	EditorInterface.set_plugin_enabled("estragon/editor", false)
	await _wait()
	_check(_find_plugin(get_tree().root) == null, "plugin disables")
	_check(code.syntax_highlighter.get_script() == null, "disable detaches highlighter")
	_check(settings.get_setting("docks/filesystem/textfile_extensions") == extensions, "disable preserves user extension settings")
	# Preserve imperfect existing CSV entries while adding the exact extension
	# Godot recognizes; its native extension cache does not trim these entries.
	settings.set_setting("docks/filesystem/textfile_extensions", "txt,md, .gogo")
	EditorInterface.set_plugin_enabled("estragon/editor", true)
	await _wait()
	plugin = _find_plugin(get_tree().root)
	_check(plugin != null and plugin._build(), "plugin re-enables cleanly")
	_check(settings.get_setting("docks/filesystem/textfile_extensions") == "txt,md, .gogo,gogo", "extension registration preserves existing CSV verbatim")
	_check(code.syntax_highlighter.get_script() == load("res://addons/estragon/editor/highlighter.gd"), "known Gogo tab regains highlighting on re-enable")
	await _wait()
	await _wait()
	var quiet_count: int = plugin.build_count
	await _wait()
	_check(plugin.build_count == quiet_count, "no endless generated-file rebuild loop")
	code.text = source.replace("var count: int = 0", "var count: int = 3") + proof
	_check(plugin._build(), "prepare restart with latest source")
	var marker := FileAccess.open("res://.godot/estragon/restart.txt", FileAccess.WRITE)
	marker.store_string("ready")
	marker.close()
	print("Editor checks: ", _checks)
	print("ESTRAGON_EDITOR_PHASE_1_OK" if not _failed else "ESTRAGON_EDITOR_FAILED")
	get_tree().quit(1 if _failed else 0)

func _restart() -> void:
	var plugin := _find_plugin(get_tree().root)
	_check(plugin != null and plugin._build(), "editor restart builds with Godot alone")
	DirAccess.remove_absolute("res://.godot/estragon/run-proof.txt")
	EditorInterface.play_main_scene()
	await _wait_for_proof("3|Count: 3")
	_check(EditorInterface.is_playing_scene(), "restart F5 runs")
	_check(FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == "3|Count: 3", "restart executes current generated code")
	_check_interactions()
	EditorInterface.stop_playing_scene()
	await _wait()
	print("ESTRAGON_EDITOR_PHASE_2_OK" if not _failed else "ESTRAGON_EDITOR_FAILED")
	get_tree().quit(1 if _failed else 0)

func _check_interactions() -> void:
	var flags: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://.godot/estragon/interaction-proof.json"))
	_check(flags is Dictionary and flags.size() == 7, "launched game reports all interaction assertions")
	if flags is Dictionary:
		for key in flags:
			_check(flags[key] == true, "launched Counter " + key)

func _wait_for_proof(expected: String) -> void:
	for attempt in range(50):
		if FileAccess.file_exists("res://.godot/estragon/run-proof.txt") and FileAccess.get_file_as_string("res://.godot/estragon/run-proof.txt") == expected: return
		await get_tree().create_timer(0.2).timeout
