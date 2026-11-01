@tool
extends EditorPlugin
## Real editor Play entry points and child-game proof, autosave disabled.
const SOURCE := "res://ui/Counter.gogo"
const BACKGROUND := "res://ui/Background.gogo"
const OUTPUT := "res://ui/generated/Counter.gd"
const PROOF := "res://.godot/estragon/play-proof.json"
var _interface: EditorInterface
var _failed := false
var _checks := 0
var _counter: CodeEdit
var _background: CodeEdit
var _source: String
var _background_source: String
var _plugin: EditorPlugin

func _enter_tree() -> void:
	_interface = get_editor_interface()
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	print("C01_G_CHECK ", message, ": ", value)
	if not value: _failed = true

func _wait(seconds: float = 0.1) -> void:
	await get_tree().create_timer(seconds).timeout

func _until(condition: Callable, message: String) -> bool:
	for _attempt in range(150):
		if condition.call(): return true
		await _wait()
	_check(false, message)
	return false

func _find_plugin() -> bool:
	for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://addons/estragon/editor/plugin.gd":
			_plugin = node
	return _plugin != null and _plugin.last_report.get("ok", false) and not _plugin._building and not _plugin._filesystem_busy()

func _open(path: String) -> CodeEdit:
	var dock := _interface.get_file_system_dock()
	dock.navigate_to_path(path)
	await _wait(0.5)
	for tree in dock.find_children("*", "Tree", true, false):
		var selected: TreeItem = tree.get_selected()
		if selected != null and selected.get_metadata(0) is String and selected.get_metadata(0) == path:
			tree.item_activated.emit()
	await _wait(0.5)
	var editor := _interface.get_script_editor().get_current_editor()
	return editor.get_base_editor() as CodeEdit if editor != null else null

func _uid() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(OUTPUT + ".uid") if FileAccess.file_exists(OUTPUT + ".uid") else PackedByteArray()

func _clear_proof() -> void:
	if FileAccess.file_exists(PROOF): DirAccess.remove_absolute(PROOF)

func _play(mode: String) -> void:
	if mode == "project": _interface.play_main_scene()
	else: _interface.play_current_scene()

func _stop() -> void:
	_interface.stop_playing_scene()
	await _wait(0.5)

func _success(mode: String, value: int, background: int) -> void:
	_clear_proof()
	_play(mode)
	var arrived := await _until(func(): return FileAccess.file_exists(PROOF), mode + " child executes current code")
	if arrived:
		var proof = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
		_check(_interface.is_playing_scene() and proof.count == value and proof.background == background, mode + " executes newest foreground/background buffers")
		_check(proof.label == "Count: %d" % value and proof.independent, mode + " current text and independent components")
	_check(not _interface.get_editor_settings().get_setting("run/auto_save/save_before_running"), "native pre-Play autosave stays disabled")
	await _stop()

func _blocked(mode: String, diagnostic: String) -> void:
	_clear_proof()
	var previous := FileAccess.get_file_as_bytes(OUTPUT)
	var map := FileAccess.get_file_as_bytes(OUTPUT + ".map.json")
	var timestamp := FileAccess.get_modified_time(OUTPUT)
	var uid := _uid()
	var cached = load(OUTPUT)
	var cached_source: String = cached.source_code
	_play(mode)
	await _wait(0.8)
	_check(not _interface.is_playing_scene() and not FileAccess.file_exists(PROOF), mode + " blocks stale child execution: " + diagnostic)
	_check(not _plugin.last_report.ok and diagnostic in str(_plugin.last_report.diagnostics), mode + " reports useful failure: " + diagnostic)
	_check(FileAccess.get_file_as_bytes(OUTPUT) == previous and FileAccess.get_file_as_bytes(OUTPUT + ".map.json") == map and FileAccess.get_modified_time(OUTPUT) == timestamp and _uid() == uid, "failed Play preserves generated code/map/UID/timestamp")
	_check(load(OUTPUT) == cached and cached.source_code == cached_source, "failed Play preserves Script identity/source")

func _run() -> void:
	if not await _until(_find_plugin, "cold native startup"):
		_finish(1)
		return
	await _wait(1.0)
	var settings := _interface.get_editor_settings()
	settings.set_setting("run/auto_save/save_before_running", false)
	settings.set_setting("text_editor/behavior/files/autosave_interval_secs", 0)
	_check(OS.get_environment("PATH").ends_with("/no-tools"), "no Bun/Node/tool PATH")
	_counter = await _open(SOURCE)
	_background = await _open(BACKGROUND)
	_check(_counter != null and _background != null and _counter != _background, "real native foreground/background Gogo editors")
	if _counter == null or _background == null:
		_finish(1)
		return
	_check(_plugin._build(), "clean native CRLF buffer remains valid")
	_source = FileAccess.get_file_as_string(SOURCE)
	_background_source = FileAccess.get_file_as_string(BACKGROUND)
	_interface.open_scene_from_path("res://ui/Counter.tscn")
	await _wait(0.5)
	if FileAccess.file_exists("res://play-restart.json"):
		_counter.text = _source.replace("var count: int = 0", "var count: int = 31")
		_background.text = _background_source.replace("return 0", "return 32")
		await _success("project", 31, 32)
		_counter.text = _source.replace("var count: int = 0", "var count: int = 33")
		await _success("current", 33, 32)
		_finish(2)
		return
	for mode in ["project", "current"]:
		_counter.text = _source.replace("var count: int = 0", "var count: int = 7")
		_background.text = _background_source.replace("return 0", "return 8")
		_check(FileAccess.get_file_as_string(SOURCE) != _counter.text and _counter.get_version() != _counter.get_saved_version(), "authored edit remains unsaved before Play")
		await _success(mode, 7, 8)
		_check(FileAccess.get_file_as_string(SOURCE) == _counter.text and FileAccess.get_file_as_string(BACKGROUND) == _background.text, "Play persists both authored snapshots")
		_counter.text = _source.replace("var count: int = 0", "var count: int = 9")
		_background.text = _background_source.replace("return 0", "return 10")
		await _success(mode, 9, 10)
		_counter.text = _source.replace('<Text text="Estragon Gogo Counter"', '<Unknown text="Estragon Gogo Counter"')
		await _blocked(mode, "Counter.gogo:")
		_counter.text = _source.replace("pressed={increment}", "pressed={missing_handler}")
		await _blocked(mode, "Counter.gogo:")
		_counter.text = _source.replace("var count: int = 0", 'var count: int = "wrong type"')
		await _blocked(mode, "Counter.gogo:")
		_counter.text = _source
		await _success(mode, 0, 10)
		# Inaccessible parent is a real open-buffer save failure, even as root.
		var moved := "res://ui/Counter.gogo.c01-g-backup"
		DirAccess.rename_absolute(SOURCE, moved)
		DirAccess.make_dir_absolute(SOURCE)
		_counter.text = _source.replace("var count: int = 0", "var count: int = 99")
		await _blocked(mode, "Counter.gogo:")
		DirAccess.remove_absolute(SOURCE)
		DirAccess.rename_absolute(moved, SOURCE)
		_counter.text = _source
		await _success(mode, 0, 10)
		# Repair sources for the other mode; preserve native buffer identities.
		_background.text = _background_source
		_check(_plugin._build(), "restore source for next mode")
	# TextFile is an internal virtual class on old editors. Use the genuine
	# native resource from an open tab and put it into a pathless/new-file state;
	# never substitute a fake CodeEdit or inject a successful guard result.
	_background = await _open(BACKGROUND)
	var new_resource: Resource = ResourceLoader.load(BACKGROUND) if ResourceLoader.has_cached(BACKGROUND) else null
	print("C01_G_PATHLESS_RESOURCE ", new_resource.get_class() if new_resource != null else "null", " ", new_resource.resource_path if new_resource != null else "")
	if new_resource != null and (new_resource.get_class() != "TextFile" or new_resource.resource_path != BACKGROUND): new_resource = null
	_check(new_resource != null, "native TextFile resource available for pathless probe")
	if new_resource != null:
		new_resource.resource_path = ""
		_interface.get_script_editor().get_current_editor().name_changed.emit()
		_background.text = '<Text text="new buffer"/>'
		await _wait(0.5)
		for mode in ["project", "current"]: await _blocked(mode, "buffer")
		new_resource.resource_path = "res://ui/New.gogo"
		_interface.get_script_editor().get_current_editor().name_changed.emit()
		await _wait(0.5)
		await _success("project", 0, 0)
		await _success("current", 0, 0)
		_check(FileAccess.get_file_as_string("res://ui/New.gogo") == _background.text, "new/pathless repair persists source")
		new_resource.resource_path = BACKGROUND
		_interface.get_script_editor().get_current_editor().name_changed.emit()
		_background.text = _background_source
		_check(_plugin._build(), "restore native source identity after pathless probe")
	var bytes := FileAccess.get_file_as_bytes(OUTPUT)
	var map := FileAccess.get_file_as_bytes(OUTPUT + ".map.json")
	var timestamp := FileAccess.get_modified_time(OUTPUT)
	var uid := _uid()
	var cached = load(OUTPUT)
	_check(_plugin._build() and FileAccess.get_file_as_bytes(OUTPUT) == bytes and FileAccess.get_file_as_bytes(OUTPUT + ".map.json") == map and FileAccess.get_modified_time(OUTPUT) == timestamp and load(OUTPUT) == cached and _uid() == uid, "no-op preserves output/map/UID/timestamp/cache identity")
	_interface.set_plugin_enabled("estragon/editor", false)
	await _wait(0.5)
	_interface.set_plugin_enabled("estragon/editor", true)
	await _until(_find_plugin, "re-enable native build")
	_counter.text = _source.replace("var count: int = 0", "var count: int = 21")
	_background.text = _background_source.replace("return 0", "return 22")
	await _success("project", 21, 22)
	_counter.text = _source
	_background.text = _background_source
	_check(_plugin._build(), "prepare valid restart state")
	var state := FileAccess.open("res://play-restart.json", FileAccess.WRITE)
	state.store_string("{}")
	state.close()
	_finish(1)

func _finish(phase: int) -> void:
	print("C01_G_ASSERTIONS ", _checks)
	if not _failed: print("C01_G_PLAY_PHASE_", phase, "_OK")
	get_tree().quit(1 if _failed else 0)
