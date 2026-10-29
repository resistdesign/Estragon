@tool
extends EditorPlugin
const Loader = preload("loader.gd")
const Importer = preload("importer.gd")
const Capture = preload("capture.gd")
var failed: bool = false
var checks: int = 0
var loader: ResourceFormatLoader

func _enter_tree() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print("R01_EDITOR_CHECK ", message, ": ", condition)
	failed = failed or not condition

func _run() -> void:
	await get_tree().create_timer(1).timeout
	var original := FileAccess.get_file_as_bytes("res://model.gd")
	loader = Loader.new()
	ResourceLoader.add_resource_format_loader(loader, true)
	var script: GDScript = ResourceLoader.load("res://model.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	check(script != null and script.can_instantiate() and script.is_tool(), "loader creates valid tool script inside editor")
	if script != null:
		EditorInterface.edit_script(script)
		await get_tree().create_timer(1).timeout
		var editor := EditorInterface.get_script_editor().get_current_editor()
		check(editor != null, "native ScriptEditor opens resource")
		if editor != null:
			var code: CodeEdit = editor.get_base_editor()
			check(code.text == script.source_code and code.text != original.get_string_from_utf8(), "native editor opens generated resource text, not authored gd")
			code.text = original.get_string_from_utf8()
			await get_tree().create_timer(3).timeout
			var diagnostics: Array[String] = []
			for node in editor.find_children("*", "Control", true, false):
				if node is Label or node is RichTextLabel:
					if "Unrecognized annotation" in node.text:
						diagnostics.append(node.text)
			print("R01_EDITOR_DIAGNOSTICS ", diagnostics)
			check(not diagnostics.is_empty() and "Bindable" in str(diagnostics), "authored buffer rejected by native validation despite active loader")
			check("Line 5, column 1" in str(diagnostics), "editor diagnostic identifies authored annotation line and column")
			# Restore only the isolated unsaved test buffer to avoid a save dialog.
			code.text = script.source_code
			code.tag_saved_version()
	var registered := false
	for entry in ProjectSettings.get_global_class_list():
		if entry.class == "R01Model":
			registered = true
	print("R01_EDITOR_CLASS_DISCOVERY ", registered, " (discovery is error tolerant; not compilation proof)")
	check(FileAccess.get_file_as_bytes("res://model.gd") == original, "editor leaves authored source bytes unchanged")
	ResourceLoader.remove_resource_format_loader(loader)
	loader = null
	var importer := Importer.new()
	add_import_plugin(importer, true)
	EditorInterface.get_resource_filesystem().reimport_files(PackedStringArray(["res://model.gd"]))
	check(importer.calls == ["res://model.gd"], "custom gd importer executes")
	check(FileAccess.file_exists("res://model.gd.import"), "import remap created outside authored source")
	var capture := Capture.new()
	OS.add_logger(capture)
	var imported: GDScript = ResourceLoader.load("res://model.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	check(imported != null and not imported.can_instantiate(), "gd import sidecar alone does not replace native source loading")
	# Import metadata does not alter direct source compilation. The editor
	# validation above uses buffer text independently of ResourceLoader.
	var raw := GDScript.new()
	raw.set_path_cache("res://model.gd")
	raw.source_code = original.get_string_from_utf8()
	check(raw.reload() == ERR_PARSE_ERROR, "import remapping does not preprocess direct source compilation")
	OS.remove_logger(capture)
	var errors := capture.snapshot()
	print("R01_EDITOR_EXPECTED_ERRORS ", errors)
	check(errors.size() == 3, "only expected import and raw-source failures")
	for error in errors:
		check((error.file == "res://model.gd" and error.line == 5 and error.message == 'Parse Error: Unrecognized annotation: "@Bindable".') or (error.file == "modules/gdscript/gdscript_resource_format.cpp" and error.message == 'Failed to load script "res://model.gd" with error "Parse error".'), "precise expected import diagnostic")
	remove_import_plugin(importer)
	check(FileAccess.get_file_as_bytes("res://model.gd") == original, "import leaves authored gd bytes unchanged")
	print("R01_EDITOR_RESULT ", checks, " ", "FAIL" if failed else "OK")
	await get_tree().create_timer(1).timeout
	get_tree().quit(1 if failed else 0)
