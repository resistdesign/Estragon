@tool
extends EditorPlugin
## Native ScriptEditor authoring and direct Godot compilation before every Play.

const BuildService = preload("res://addons/estragon/editor/build_service.gd")
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const TEXT_EXTENSIONS_SETTING := "docks/filesystem/textfile_extensions"

var _highlighter: EditorSyntaxHighlighter
var _timer: Timer
var _diagnostics: RichTextLabel
var _building: bool = false
var _active: bool = false
var _extensions_pending: bool = true
var last_report: Dictionary = {}
var build_count: int = 0


func _enter_tree() -> void:
	_active = true
	_extensions_pending = true
	# Retire only Estragon-owned legacy setup; never rewrite user preferences.
	for key in ["estragon/editor/bun_executable", "estragon/editor/build_timeout_seconds"]:
		if ProjectSettings.has_setting(key): ProjectSettings.clear(key)
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
	_compile()
	if not _apply_extension_setting(): _schedule()


func _apply_extension_setting() -> bool:
	if not _extensions_pending: return true
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing(): return false
	var settings := EditorInterface.get_editor_settings()
	settings.mark_setting_changed(TEXT_EXTENSIONS_SETTING)
	# set_setting alone does not update EditorNode's cached text extensions.
	# Use the public notification consumed by Godot's own settings UI.
	get_tree().root.propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
	_extensions_pending = false
	return true


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
		if not _apply_extension_setting():
			_schedule()
			return
		_compile()


func _build() -> bool:
	if not _active or _building:
		return false
	# Includes native TextFile tabs, not only GDScript. Never compile old disk
	# contents when the author's buffer is newer, even with autosave disabled.
	var scripts := EditorInterface.get_script_editor()
	scripts.save_all_scripts()
	_timer.stop()
	for path in scripts.get_unsaved_files():
		if path.ends_with(".gogo"):
			last_report = {"ok": false, "changed": [], "outputs": [], "diagnostics": [path + ":1:1: Cannot save latest Gogo buffer; resolve the Save error before Play."]}
			_show_report()
			return false
	return _compile()


func _compile() -> bool:
	_building = true
	build_count += 1
	last_report = BuildService.run_build()
	_show_report()
	# Refresh paths without reimporting authored source. The child game's fresh
	# process reads these exact bytes; editor resources are synchronized as well.
	var filesystem := EditorInterface.get_resource_filesystem()
	var needs_scan := false
	for path in last_report.get("changed", []):
		var resource_path := "res://" + str(path)
		if filesystem.get_filesystem_path(resource_path.get_base_dir()) == null: needs_scan = true
		filesystem.update_file(resource_path)
	if needs_scan and not filesystem.is_scanning() and not filesystem.is_importing(): filesystem.scan()
	_building = false
	return last_report.ok


func _show_report() -> void:
	_diagnostics.text = "Gogo build succeeded." if last_report.ok else "\n\n".join(PackedStringArray(last_report.diagnostics))
	if not last_report.ok:
		make_bottom_panel_item_visible(_diagnostics)
		push_warning("Estragon: Gogo compilation failed; Play blocked.\n" + _diagnostics.text)


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
