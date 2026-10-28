@tool
extends EditorPlugin
## Native ScriptEditor authoring; synchronous bounded build gate for every Play.

const BuildService = preload("res://addons/estragon/editor/build_service.gd")
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const TEXT_EXTENSIONS_SETTING := "docks/filesystem/textfile_extensions"

var _highlighter: EditorSyntaxHighlighter
var _timer: Timer
var _diagnostics: RichTextLabel
var _building: bool = false
var _active: bool = false
var last_report: Dictionary = {}
var build_count: int = 0


func _enter_tree() -> void:
	_active = true
	_register_settings()
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(TEXT_EXTENSIONS_SETTING):
		var existing := str(settings.get_setting(TEXT_EXTENSIONS_SETTING))
		var registered := false
		for extension in existing.split(","):
			if extension.strip_edges().trim_prefix(".") == "gogo":
				registered = true
		if not registered:
			settings.set_setting(TEXT_EXTENSIONS_SETTING, existing + ("," if not existing.is_empty() else "") + "gogo")
	_highlighter = Highlighter.new()
	EditorInterface.get_script_editor().register_syntax_highlighter(_highlighter)
	for editor in EditorInterface.get_script_editor().get_open_script_editors():
		var code := editor.get_base_editor() as TextEdit
		if code != null and code.has_meta("estragon_gogo"):
			code.syntax_highlighter = Highlighter.new()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.4
	_timer.timeout.connect(_compile_saved)
	add_child(_timer)
	_diagnostics = RichTextLabel.new()
	_diagnostics.name = "EstragonDiagnostics"
	_diagnostics.custom_minimum_size = Vector2(0, 120)
	_diagnostics.selection_enabled = true
	add_control_to_bottom_panel(_diagnostics, "Gogo")
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_schedule)
	EditorInterface.get_resource_filesystem().sources_changed.connect(_sources_changed)
	resource_saved.connect(_resource_saved)
	_schedule()


func _register_settings() -> void:
	if not ProjectSettings.has_setting(BuildService.BUN_SETTING):
		ProjectSettings.set_setting(BuildService.BUN_SETTING, "")
	ProjectSettings.set_initial_value(BuildService.BUN_SETTING, "")
	ProjectSettings.add_property_info({"name": BuildService.BUN_SETTING, "type": TYPE_STRING, "hint": PROPERTY_HINT_GLOBAL_FILE, "hint_string": ""})
	if not ProjectSettings.has_setting(BuildService.TIMEOUT_SETTING):
		ProjectSettings.set_setting(BuildService.TIMEOUT_SETTING, 30.0)
	ProjectSettings.set_initial_value(BuildService.TIMEOUT_SETTING, 30.0)
	ProjectSettings.add_property_info({"name": BuildService.TIMEOUT_SETTING, "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1,120,1"})


func _schedule() -> void:
	if _active and not _building:
		_timer.start()


func _sources_changed(_changed: bool) -> void:
	_schedule()


func _resource_saved(resource: Resource) -> void:
	if resource.resource_path.ends_with(".gogo"):
		_schedule()


func _save_external_data() -> void:
	_schedule()


func _compile_saved() -> void:
	if _active:
		_compile(false)


func _build() -> bool:
	if not _active or _building:
		return false
	# Includes native TextFile tabs, not only GDScript. Never compile old disk
	# contents when the author's buffer is newer, even with autosave disabled.
	EditorInterface.get_script_editor().save_all_scripts()
	_timer.stop()
	return _compile(true)


func _compile(validate: bool) -> bool:
	_building = true
	build_count += 1
	last_report = BuildService.run_build(validate)
	_diagnostics.text = "Gogo build succeeded." if last_report.ok else "\n\n".join(PackedStringArray(last_report.diagnostics))
	if not last_report.ok:
		make_bottom_panel_item_visible(_diagnostics)
		push_warning("Estragon: Gogo compilation failed; Play blocked.\n" + _diagnostics.text)
	# Refresh paths without reimporting authored source. The child game's fresh
	# process reads these exact bytes; editor resources are synchronized as well.
	var filesystem := EditorInterface.get_resource_filesystem()
	for path in last_report.get("changed", []):
		filesystem.update_file("res://" + str(path))
	_building = false
	return last_report.ok


func _exit_tree() -> void:
	_active = false
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_schedule):
		filesystem.filesystem_changed.disconnect(_schedule)
	if filesystem.sources_changed.is_connected(_sources_changed):
		filesystem.sources_changed.disconnect(_sources_changed)
	if resource_saved.is_connected(_resource_saved):
		resource_saved.disconnect(_resource_saved)
	if _timer != null:
		_timer.stop()
		_timer.free()
		_timer = null
	# Godot retains highlighters on already-open files after unregistering.
	# Detach our instances first so disable/re-enable never leaves stale ones.
	for editor in EditorInterface.get_script_editor().get_open_script_editors():
		var text_edit := editor.get_base_editor() as TextEdit
		if text_edit != null and text_edit.syntax_highlighter != null and text_edit.syntax_highlighter.get_script() == Highlighter:
			text_edit.set_meta("estragon_gogo", true)
			text_edit.syntax_highlighter = EditorSyntaxHighlighter.new()
	EditorInterface.get_script_editor().unregister_syntax_highlighter(_highlighter)
	_highlighter = null
	if _diagnostics != null:
		remove_control_from_bottom_panel(_diagnostics)
		_diagnostics.free()
		_diagnostics = null
