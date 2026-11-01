@tool
extends RefCounted
## Synchronous pre-Play boundary. No compiler, subprocess or widget hierarchy.

static func _failure(path: String, message: String) -> Dictionary:
	return {"ok": false, "diagnostics": [path + ":1:1: " + message], "buffers": []}

static func _snapshot(scripts: ScriptEditor, resolve_path: Callable) -> Dictionary:
	var buffers: Array[Dictionary] = []
	for editor in scripts.get_open_script_editors():
		var code = editor.get_base_editor()
		if not code is TextEdit:
			return _failure("<editor buffer>", "Cannot verify this editor buffer before Play; save or close it first.")
		var path := ""
		var resource: Resource
		# The existing, engine-tested E01 adapter supplies exact identity, never
		# a filename/content guess. Prefer its native resource capability.
		if code.syntax_highlighter is EditorSyntaxHighlighter and code.syntax_highlighter.has_method("_get_edited_resource"):
			resource = code.syntax_highlighter.call("_get_edited_resource") as Resource
		if resource != null:
			path = resource.resource_path
			if path.is_empty():
				return _failure("<unsaved editor buffer>", "Save this new/pathless buffer to a project file before Play.")
		else:
			path = resolve_path.call(editor, code)
		if path.is_empty():
			return _failure("<unidentified editor buffer>", "Cannot identify this buffer safely; save or close it before Play.")
		if path.get_extension() != "gogo": continue
		if resource == null:
			# Baseline ResourceLoader returns the already-cached native TextFile;
			# no text loader is required or invoked. Missing identity is a failure,
			# not permission to trust a possibly stale tab tooltip/meta path.
			if not ResourceLoader.has_cached(path):
				return _failure(path, "Cannot verify this Gogo buffer identity; save or close it before Play.")
			resource = ResourceLoader.load(path)
			if resource == null or resource.resource_path != path or resource.get_class() != "TextFile":
				return _failure(path, "Cannot verify this Gogo buffer identity; save or close it before Play.")
		if not path.begins_with("res://") or path.contains("::"):
			return _failure(path, "Gogo buffers must have a project file path before Play.")
		buffers.append({"path": path, "code": code, "text": code.text,
			"dirty": code.get_version() != code.get_saved_version()})
	return {"ok": true, "diagnostics": [], "buffers": buffers}

static func save_and_verify(scripts: ScriptEditor, resolve_path: Callable) -> Dictionary:
	var snapshot := _snapshot(scripts, resolve_path)
	if not snapshot.ok: return snapshot
	if scripts.has_method("save_all_scripts"):
		# Preserve the newer editor's ordinary save/normalization behavior.
		scripts.call("save_all_scripts")
		snapshot = _snapshot(scripts, resolve_path)
		if not snapshot.ok: return snapshot
	else:
		for buffer in snapshot.buffers:
			if not buffer.dirty: continue
			var file := FileAccess.open(buffer.path, FileAccess.WRITE)
			if file == null:
				return _failure(buffer.path, "Cannot save latest Gogo buffer (" + error_string(FileAccess.get_open_error()) + "); Play blocked.")
			file.store_string(buffer.text)
			file.flush()
			var error := file.get_error()
			file.close()
			if error != OK:
				return _failure(buffer.path, "Cannot persist latest Gogo buffer (" + error_string(error) + "); Play blocked.")
	for buffer in snapshot.buffers:
		var file := FileAccess.open(buffer.path, FileAccess.READ)
		if file == null:
			return _failure(buffer.path, "Cannot read saved Gogo source; Play blocked.")
		var bytes := file.get_buffer(file.get_length())
		var error := file.get_error()
		file.close()
		if error != OK or bytes != str(buffer.text).to_utf8_buffer() or buffer.code.text != buffer.text:
			return _failure(buffer.path, "Saved source does not match the latest Gogo buffer; save/reload it before Play.")
	# Mark only after every persisted snapshot has been independently verified.
	for buffer in snapshot.buffers: buffer.code.tag_saved_version()
	if scripts.has_method("get_unsaved_files"):
		for path in scripts.call("get_unsaved_files"):
			if str(path).get_extension() == "gogo":
				return _failure(str(path), "Cannot save latest Gogo buffer; resolve the Save error before Play.")
	return snapshot
