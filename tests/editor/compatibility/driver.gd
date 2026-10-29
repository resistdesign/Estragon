@tool
extends EditorPlugin
## E01-only editor proof; deliberately does not preload the compiler/runtime.
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const Association = preload("res://addons/estragon/editor/highlighter_association.gd")
var interface: EditorInterface
var scripts: ScriptEditor
var association: RefCounted
var factory: EditorSyntaxHighlighter
var failed: bool = false
var checks: int = 0

func _enter_tree() -> void:
	interface = get_editor_interface()
	scripts = interface.get_script_editor()
	if FileAccess.file_exists("res://restart.txt") and OS.get_environment("E01_FULL_ADDON") != "1":
		_enable()
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	print("E01_COMPAT_CHECK ", message, ": ", condition)
	failed = failed or not condition

func wait() -> void:
	await get_tree().create_timer(0.5).timeout

func _enable() -> void:
	factory = Highlighter.new()
	scripts.register_syntax_highlighter(factory)
	association = Association.new()
	association.start(interface)

func _disable() -> void:
	association.stop()
	scripts.unregister_syntax_highlighter(factory)
	association = null
	factory = null

func _open(path: String) -> CodeEdit:
	var dock := interface.get_file_system_dock()
	dock.navigate_to_path(path)
	await wait()
	for tree in dock.find_children("*", "Tree", true, false):
		var selected: TreeItem = tree.get_selected()
		if selected != null and selected.get_metadata(0) is String and selected.get_metadata(0) == path:
			tree.item_activated.emit()
	await wait()
	var editor := scripts.get_current_editor()
	return editor.get_base_editor() as CodeEdit if editor != null else null

func _colored(code: CodeEdit, context: String) -> void:
	check(code != null, context + " editor exists")
	if code == null: return
	check(code.syntax_highlighter.get_script() == Highlighter, context + " Gogo attached automatically")
	var declaration := code.syntax_highlighter.get_line_syntax_highlighting(0)
	check(declaration.has(0) and declaration[0].color == Highlighter.KEYWORD, context + " declaration color")
	var tag_found := false
	for line in range(code.get_line_count()):
		var column := code.get_line(line).find("<VBox")
		if column >= 0:
			var spans := code.syntax_highlighter.get_line_syntax_highlighting(line)
			tag_found = spans.has(column) and spans[column].color == Highlighter.TAG
	check(tag_found, context + " markup color")

func _run() -> void:
	await wait()
	while interface.get_resource_filesystem().is_scanning(): await wait()
	await wait()
	print("E01_ENGINE ", Engine.get_version_info().string)
	check(OS.get_environment("PATH").ends_with("/no-tools"), "Bun/Node absent")
	if OS.get_environment("E01_FULL_ADDON") == "1":
		print("E01_API save_all_scripts=", scripts.has_method("save_all_scripts"), " get_unsaved_files=", scripts.has_method("get_unsaved_files"), " set_path_cache=", Resource.new().has_method("set_path_cache"), " Logger=", ClassDB.class_exists("Logger"))
		var addon: GDScript = load("res://addons/estragon/editor/plugin.gd")
		print("E01_FULL_ADDON_SCRIPT_VALID ", addon != null and addon.can_instantiate())
		var report_ok := false
		for node in get_tree().root.find_children("*", "EditorPlugin", true, false):
			if node.get_script() != null and node.get_script().resource_path == "res://addons/estragon/editor/plugin.gd":
				var report: Variant = node.get("last_report")
				report_ok = report is Dictionary and report.get("ok", false)
		print("E01_FULL_ADDON_REPORT_VALID ", report_ok)
		get_tree().quit()
		return
	if FileAccess.file_exists("res://restart.txt"):
		var restored := 0
		for editor in scripts.get_open_script_editors():
			var code := editor.get_base_editor() as CodeEdit
			if code == null: continue
			var path := str(code.get_meta("estragon_gogo_path", ""))
			if path in ["res://examples/counter/Counter.gogo", "res://examples/counter/Background.gogo"]:
				restored += 1
				_colored(code, "restored " + path)
		check(restored == 2, "both persisted plain tabs restored before navigation")
	else:
		var settings := interface.get_editor_settings()
		var key := "docks/filesystem/textfile_extensions"
		var previous := str(settings.get_setting(key))
		settings.set_setting(key, previous + ",gogo")
		if settings.has_method("mark_setting_changed"): settings.call("mark_setting_changed", key)
		get_tree().root.propagate_notification(EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED)
		await wait()
		var a := await _open("res://examples/counter/Counter.gogo")
		var b := await _open("res://examples/counter/Background.gogo")
		var other := await _open("res://examples/counter/Counter.gogo.txt")
		check(a != null and b != null and other != null, "native file opening")
		if a == null or b == null or other == null:
			get_tree().quit(1)
			return
		check(a.syntax_highlighter.get_script() == null and b.syntax_highlighter.get_script() == null, "untagged plain tabs before enable")
		var other_highlighter := other.syntax_highlighter
		var preference: Variant = settings.get_setting(key)
		# Negative capability probe: a never-associated tab hidden by a filter
		# has no exposed resource/path. Record the unmet case, do not certify it.
		var filter: LineEdit
		for edit in scripts.find_children("*", "LineEdit", true, false):
			if edit.placeholder_text == "Filter Scripts": filter = edit
		check(filter != null, "native script-list filter located")
		if filter != null:
			filter.text = "~e01-no-match~"
			filter.text_changed.emit(filter.text)
			await wait()
			var background_exposed := false
			for list in scripts.find_children("*", "ItemList", true, false):
				for index in range(list.item_count):
					if list.get_item_tooltip(index) == "res://examples/counter/Background.gogo": background_exposed = true
			check(not background_exposed, "background path genuinely excluded by filter")
		_enable()
		await wait()
		if b.syntax_highlighter.get_script() == Highlighter:
			_colored(b, "unassociated tab recovered despite filter")
			print("E01_FILTERED_UNASSOCIATED_RECOVERED")
		else:
			check(b.syntax_highlighter.get_script() == null, "negative probe: hidden unassociated tab is plain")
			print("E01_FILTERED_UNASSOCIATED_UNMET")
		if filter != null:
			filter.text = ""
			filter.text_changed.emit(filter.text)
		await _open("res://examples/counter/Counter.gogo")
		await _open("res://examples/counter/Background.gogo")
		_colored(a, "already open")
		_colored(b, "background")
		check(a.syntax_highlighter != b.syntax_highlighter, "independent highlighter instances")
		check(other.syntax_highlighter == other_highlighter, "Gogo-looking txt unchanged")
		_colored(await _open("res://examples/counter/New.gogo"), "new tab")
		# Exercise a filtered list without changing the user's filter in the addon.
		if filter != null:
			filter.text = "~e01-no-match~"
			filter.text_changed.emit(filter.text)
			await wait()
			_colored(b, "known background while filtered")
			check(filter.text == "~e01-no-match~", "adapter preserves active filter")
			filter.text = ""
			filter.text_changed.emit(filter.text)
		_disable()
		await wait()
		check(a.syntax_highlighter.get_script() == null, "disable detaches")
		_enable()
		await wait()
		_colored(a, "re-enabled")
		_colored(b, "re-enabled background")
		check(other.syntax_highlighter == other_highlighter, "re-enable preserves other file")
		check(settings.get_setting(key) == preference, "adapter preserves preferences")
		var marker := FileAccess.open("res://restart.txt", FileAccess.WRITE)
		marker.store_string("ready")
		marker.close()
	print("E01_COMPAT_RESULT ", checks, " ", "FAIL" if failed else "OK")
	get_tree().quit(1 if failed else 0)
