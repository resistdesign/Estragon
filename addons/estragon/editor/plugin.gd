@tool
extends EditorPlugin
## Native ScriptEditor authoring and direct Godot compilation before every Play.

const BuildService = preload("res://addons/estragon/editor/build_service.gd")
const HighlighterAssociation = preload("res://addons/estragon/editor/highlighter_association.gd")
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const TEXT_EXTENSIONS_SETTING := "docks/filesystem/textfile_extensions"

var _highlighter: EditorSyntaxHighlighter
var _interface: EditorInterface
var _highlighter_association: RefCounted
var _timer: Timer
var _diagnostics: RichTextLabel
var _building: bool = false
var _active: bool = false
var _extensions_pending: bool = true
var _rescan_pending: bool = false
var _generated_editors: Dictionary = {}
var last_report: Dictionary = {}
var build_count: int = 0


func _enter_tree() -> void:
	if _active: return
	_interface = get_editor_interface()
	_active = true
	_extensions_pending = true
	# Retire only Estragon-owned legacy setup; never rewrite user preferences.
	for key in ["estragon/editor/bun_executable", "estragon/editor/build_timeout_seconds"]:
		if ProjectSettings.has_setting(key): ProjectSettings.clear(key)
	var settings := _interface.get_editor_settings()
	if settings.has_setting(TEXT_EXTENSIONS_SETTING):
		var existing := str(settings.get_setting(TEXT_EXTENSIONS_SETTING))
		var registered := false
		for extension in existing.split(","):
			if extension == "gogo":
				registered = true
		if not registered:
			settings.set_setting(TEXT_EXTENSIONS_SETTING, existing + ("," if not existing.is_empty() else "") + "gogo")
	_highlighter = Highlighter.new()
	_interface.get_script_editor().register_syntax_highlighter(_highlighter)
	_highlighter_association = HighlighterAssociation.new()
	_highlighter_association.start(_interface)
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
	_interface.get_resource_filesystem().filesystem_changed.connect(_schedule)
	_interface.get_resource_filesystem().sources_changed.connect(_sources_changed)
	resource_saved.connect(_resource_saved)
	_interface.get_script_editor().editor_script_changed.connect(_script_changed)
	# Newer editors load class names before plugins but may still be scanning.
	# Publish before they restore scenes referring to generated scripts. Older
	# cold editors need the initial class registration before native validation.
	if _runtime_registered(): _compile()
	if last_report.is_empty() or not _apply_extension_setting(): _schedule()


func _runtime_registered() -> bool:
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == "EstragonSurface" and entry.path == "res://addons/estragon/runtime/surface.gd":
			return true
	return false


func _filesystem_busy() -> bool:
	var filesystem := _interface.get_resource_filesystem()
	if filesystem.is_scanning() or not _runtime_registered(): return true
	# Older editors expose scanning but not a separate import-status query.
	return filesystem.has_method("is_importing") and filesystem.call("is_importing")


func _apply_extension_setting() -> bool:
	if not _extensions_pending: return true
	if _filesystem_busy(): return false
	var settings := _interface.get_editor_settings()
	if settings.has_method("mark_setting_changed"):
		settings.call("mark_setting_changed", TEXT_EXTENSIONS_SETTING)
	# set_setting alone does not update EditorNode's cached text extensions.
	# Use the public notification consumed by Godot's own settings UI.
	get_tree().root.propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	_extensions_pending = false
	return true


func _schedule() -> void:
	if _active and not _building:
		_timer.start()


func _script_changed(script: Script) -> void:
	var scripts := _interface.get_script_editor()
	if script == null or scripts.get_current_script() != script: return
	var editor := scripts.get_current_editor()
	if editor == null: return
	_generated_editors[script.resource_path] = {"editor": weakref(editor), "script": weakref(script)}
	_schedule()


func _refresh_generated_editors() -> void:
	# Native ScriptEditor buffers otherwise write pre-build text back into the
	# Script cache and even disk on shutdown. Match only public signal/current
	# editor associations and paths this successful build owns. Never edit Gogo.
	var scripts := _interface.get_script_editor()
	var current := scripts.get_current_script()
	if current != null and scripts.get_current_editor() != null:
		_generated_editors[current.resource_path] = {"editor": weakref(scripts.get_current_editor()), "script": weakref(current)}
	for output in last_report.get("outputs", []):
		var path := "res://" + str(output)
		if not _generated_editors.has(path): continue
		var editor = _generated_editors[path].editor.get_ref()
		var script = _generated_editors[path].script.get_ref()
		if editor == null or script == null or script.resource_path != path:
			_generated_editors.erase(path)
			continue
		var code = editor.get_base_editor()
		if not code is CodeEdit: continue
		var text := FileAccess.get_file_as_string(path)
		if code.text != text:
			var line: int = code.get_caret_line()
			var column: int = code.get_caret_column()
			var vertical: float = code.scroll_vertical
			var horizontal: int = code.scroll_horizontal
			code.text = text
			code.set_caret_line(line)
			code.set_caret_column(column)
			code.scroll_vertical = vertical
			code.scroll_horizontal = horizontal
			code.tag_saved_version()


func _sources_changed(_changed: bool) -> void:
	_schedule()


func _resource_saved(resource: Resource) -> void:
	if resource.resource_path.ends_with(".gogo"):
		_schedule()


func _save_external_data() -> void:
	_schedule()


func _compile_saved() -> void:
	if _active:
		if _filesystem_busy() or not _apply_extension_setting():
			_schedule()
			return
		_timer.stop()
		_compile()


func _build() -> bool:
	if not _active or _building:
		return false
	# Includes native TextFile tabs, not only GDScript. Never compile old disk
	# contents when the author's buffer is newer, even with autosave disabled.
	var scripts := _interface.get_script_editor()
	scripts.save_all_scripts()
	_timer.stop()
	for path in scripts.get_unsaved_files():
		if path.ends_with(".gogo"):
			last_report = {"ok": false, "changed": [], "outputs": [], "diagnostics": [path + ":1:1: Cannot save latest Gogo buffer; resolve the Save error before Play."]}
			_show_report()
			return false
	return _compile()


func _compile() -> bool:
	if not _active or _building: return false
	_building = true
	build_count += 1
	last_report = BuildService.run_build()
	_show_report()
	if last_report.ok: _refresh_generated_editors()
	# Refresh paths without reimporting authored source. The child game's fresh
	# process reads these exact bytes; editor resources are synchronized as well.
	var filesystem := _interface.get_resource_filesystem()
	_rescan_pending = _rescan_pending or not last_report.get("changed", []).is_empty()
	if _rescan_pending and not _filesystem_busy():
		_rescan_pending = false
		filesystem.scan()
	_building = false
	return last_report.ok


func _show_report() -> void:
	_diagnostics.text = "Gogo build succeeded." if last_report.ok else "\n\n".join(PackedStringArray(last_report.diagnostics))
	if not last_report.ok:
		make_bottom_panel_item_visible(_diagnostics)
		push_warning("Estragon: Gogo compilation failed; Play blocked.\n" + _diagnostics.text)


func _exit_tree() -> void:
	_active = false
	_building = false
	_rescan_pending = false
	if is_instance_valid(_interface):
		var filesystem := _interface.get_resource_filesystem()
		if filesystem.filesystem_changed.is_connected(_schedule):
			filesystem.filesystem_changed.disconnect(_schedule)
		if filesystem.sources_changed.is_connected(_sources_changed):
			filesystem.sources_changed.disconnect(_sources_changed)
	if is_instance_valid(_interface):
		var scripts := _interface.get_script_editor()
		if scripts.editor_script_changed.is_connected(_script_changed):
			scripts.editor_script_changed.disconnect(_script_changed)
	_generated_editors.clear()
	if resource_saved.is_connected(_resource_saved):
		resource_saved.disconnect(_resource_saved)
	if _timer != null:
		_timer.stop()
		_timer.free()
		_timer = null
	if _highlighter_association != null:
		_highlighter_association.stop()
		_highlighter_association = null
	if _highlighter != null and is_instance_valid(_interface):
		_interface.get_script_editor().unregister_syntax_highlighter(_highlighter)
	_highlighter = null
	if _diagnostics != null:
		remove_control_from_bottom_panel(_diagnostics)
		_diagnostics.free()
		_diagnostics = null
	_interface = null
