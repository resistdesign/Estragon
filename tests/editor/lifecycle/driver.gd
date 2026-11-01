@tool
extends EditorPlugin
## C01-F only: real plugin lifecycle and saved-disk builds, never unsaved Play.
const PLUGIN_PATH := "res://addons/estragon/editor/plugin.gd"
const SOURCE := "res://ui/Counter.gogo"
const OUTPUT := "res://ui/generated/Counter.gd"
const SETTING := "docks/filesystem/textfile_extensions"
const PREFERENCE := "c01_owner_extension,md,gogo"
var _interface: EditorInterface
var _failed := false
var _checks := 0
var _imported_image := false
var _output_path: String = OUTPUT

func _enter_tree() -> void:
	_interface = get_editor_interface()
	if not FileAccess.file_exists("res://lifecycle-state.json"):
		_interface.get_editor_settings().set_setting(SETTING, "c01_owner_extension,md")
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	print("C01_F_CHECK ", message, ": ", value)
	if not value: _failed = true

func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds).timeout

func _until(condition: Callable, message: String) -> bool:
	for _attempt in range(150):
		if condition.call(): return true
		await _wait()
	_check(false, message)
	return false

func _plugin() -> EditorPlugin:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if node.get_script() != null and node.get_script().resource_path == PLUGIN_PATH:
			return node
	return null

func _ready_plugin() -> bool:
	var plugin = _plugin()
	return plugin != null and plugin.last_report.get("ok", false) and not plugin._building

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _saved_notice(plugin: EditorPlugin) -> void:
	# Exercise the saved-resource signal contract without borrowing unavailable
	# old-engine buffer save APIs (those are specifically C01-G).
	var resource := Resource.new()
	resource.resource_path = "res://ui/SavedNotification.gogo"
	plugin.resource_saved.emit(resource)
	resource.resource_path = ""

func _hooks(plugin: EditorPlugin) -> void:
	var fs := _interface.get_resource_filesystem()
	for item in [[fs.filesystem_changed, "_schedule"], [fs.sources_changed, "_sources_changed"], [plugin.resource_saved, "_resource_saved"], [_interface.get_script_editor().editor_script_changed, "_script_changed"]]:
		var count := 0
		for connection in item[0].get_connections():
			var callback = connection["callable"]
			if callback.get_object() == plugin and callback.get_method() == item[1]: count += 1
		_check(count == 1, "exactly one " + item[1] + " hook")
	_check(is_instance_valid(plugin._diagnostics) and plugin._diagnostics.is_inside_tree(), "diagnostics panel attached")
	_check(plugin.get_children().filter(func(child): return child is Timer).size() == 1, "one coalescing timer")

func _quiet(plugin: EditorPlugin) -> void:
	# Initial imports/class indexing may finish after the first valid build.
	# Require bounded quiescence, then prove notifications do not loop at idle.
	var stable := 0
	var count: int = plugin.build_count
	for _attempt in range(150):
		await _wait()
		if plugin.build_count == count and plugin._timer.is_stopped() and not plugin._filesystem_busy():
			stable += 1
		else:
			count = plugin.build_count
			stable = 0
		if stable == 12: break
	_check(stable == 12, "filesystem/build notifications settle within 15 seconds")
	count = plugin.build_count
	await _wait(1.2)
	_check(plugin.build_count == count, "no idle build loop")

func _count_is(value: int) -> bool:
	if not _ready_plugin(): return false
	var script = load(_output_path)
	# Non-tool application scripts cannot instantiate in an editor process.
	# The runner separately executes these published bytes in a fresh runtime.
	return script != null and script.source_code == FileAccess.get_file_as_string(OUTPUT) and script.source_code.contains("var count: int = " + str(value))

func _image_imported(paths) -> void:
	for path in paths:
		if path == "res://ui/Imported.png": _imported_image = true

func _highlight() -> void:
	var dock := _interface.get_file_system_dock()
	dock.navigate_to_path(SOURCE)
	await _wait(0.5)
	for tree in dock.find_children("*", "Tree", true, false):
		var selected: TreeItem = tree.get_selected()
		if selected != null and selected.get_metadata(0) is String and selected.get_metadata(0) == SOURCE:
			tree.item_activated.emit()
	await _wait(0.5)
	var editor := _interface.get_script_editor().get_current_editor()
	_check(editor != null, "normal Gogo tab opens")
	if editor != null:
		var code := editor.get_base_editor() as CodeEdit
		_check(code != null and code.syntax_highlighter != null and code.syntax_highlighter.get_script().resource_path == "res://addons/estragon/editor/highlighter.gd", "normal automatic highlighting preserved")

func _run() -> void:
	_check(OS.get_environment("PATH").ends_with("/no-tools"), "empty executable PATH")
	if not await _until(_ready_plugin, "real plugin startup/native build"):
		_finish(1)
		return
	var plugin = _plugin()
	var fs := _interface.get_resource_filesystem()
	_check(FileAccess.file_exists(OUTPUT), "native output published")
	_check(_interface.get_editor_settings().get_setting(SETTING) == PREFERENCE, "existing preference values preserved/additive registration")
	_hooks(plugin)
	await _quiet(plugin)
	if FileAccess.file_exists("res://lifecycle-state.json"):
		_check(_count_is(4), "restart builds current saved source")
		await _highlight()
		_interface.set_plugin_enabled("estragon/editor", false)
		await _wait(0.5)
		_interface.set_plugin_enabled("estragon/editor", true)
		await _until(_ready_plugin, "restart re-enable build")
		_hooks(_plugin())
		await _quiet(_plugin())
		_finish(2)
		return

	_check(_count_is(0), "cold startup replaces stale generated default")
	var source := FileAccess.get_file_as_string(SOURCE)
	var cached = load(_output_path)
	var before: int = plugin.build_count
	for _index in range(8): plugin._schedule()
	await _wait(1.2)
	_check(plugin.build_count == before + 1, "schedule burst coalesces into one build")
	_write(SOURCE, source.replace("var count: int = 0", "var count: int = 1"))
	for _index in range(8): _saved_notice(plugin)
	await _until(func(): return _count_is(1), "saved-source signal compiles current disk bytes")
	_check(load(_output_path) == cached, "saved update preserves cached Script identity")
	_write(SOURCE, source.replace("var count: int = 0", "var count: int = 2"))
	fs.scan()
	await _until(func(): return _count_is(2), "external rescan compiles current source")
	_check(load(_output_path) == cached, "external update preserves Script identity")
	await _quiet(plugin)
	var previous := FileAccess.get_file_as_string(OUTPUT)
	_write(SOURCE, "<Unknown/>")
	fs.scan()
	await _until(func(): return not plugin.last_report.get("ok", true), "invalid saved source rejected")
	_check(not plugin.last_report.diagnostics.is_empty() and FileAccess.get_file_as_string(OUTPUT) == previous, "failure reports diagnostics/preserves last valid file")
	_write(SOURCE, source.replace("var count: int = 0", "var count: int = 3"))
	fs.scan()
	await _until(func(): return _count_is(3), "saved-source recovery publishes valid output")
	fs.resources_reimported.connect(_image_imported)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.CORNFLOWER_BLUE)
	_check(image.save_png("res://ui/Imported.png") == OK, "real import fixture created")
	_write("res://ui/Created.gogo", '<Text text="created"/>')
	fs.scan()
	await _until(func(): return _imported_image and FileAccess.file_exists("res://ui/generated/Created.gd") and _ready_plugin(), "asset import/new source notifications complete")
	await _quiet(plugin)
	var timer_ref: WeakRef = weakref(plugin._timer)
	var panel_ref: WeakRef = weakref(plugin._diagnostics)
	plugin._schedule()
	_interface.set_plugin_enabled("estragon/editor", false)
	await _wait(0.6)
	_check(_plugin() == null and timer_ref.get_ref() == null, "disable cancels queued work/releases timer")
	_check(panel_ref.get_ref() == null, "disable frees diagnostics panel")
	_check(_interface.get_editor_settings().get_setting(SETTING) == PREFERENCE, "disable preserves extension preference")
	_write(SOURCE, source.replace("var count: int = 0", "var count: int = 4"))
	fs.scan()
	await _wait(1.2)
	_check(FileAccess.get_file_as_string(OUTPUT).contains("var count: int = 3"), "disabled plugin does not build filesystem changes")
	for _cycle in range(2):
		_interface.set_plugin_enabled("estragon/editor", true)
		await _until(_ready_plugin, "re-enable native build")
		_check(_count_is(4), "re-enable rebuilds saved state")
		_hooks(_plugin())
		await _quiet(_plugin())
		if _cycle == 0:
			_interface.set_plugin_enabled("estragon/editor", false)
			await _wait(0.5)
	await _highlight()
	_write("res://lifecycle-state.json", JSON.stringify({"expected_count": 4, "preference": PREFERENCE}))
	_finish(1)

func _finish(phase: int) -> void:
	print("C01_F_ASSERTIONS ", _checks)
	if not _failed: print("C01_F_LIFECYCLE_PHASE_", phase, "_OK")
	get_tree().quit(1 if _failed else 0)
