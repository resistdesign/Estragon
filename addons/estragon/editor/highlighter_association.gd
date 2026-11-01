@tool
extends RefCounted
## Repair extension association after native tab creation / cached state restore.
## Kept separate from compilation; no timer, file writes or editor preferences.
const Highlighter = preload("res://addons/estragon/editor/highlighter.gd")
const PATH_META := "estragon_gogo_path"
var _scripts: ScriptEditor
var _tree: SceneTree
var _active: bool = false
var _pending: bool = false
var _tested_adapter: bool = false

func start(interface: EditorInterface) -> void:
	var version := Engine.get_version_info()
	_tested_adapter = version.major == 4 and version.minor >= 0 and version.minor <= 7
	if not _tested_adapter:
		push_warning("Estragon E01: native tab-path adapter is unverified on this engine; UI fallback disabled. See C01 compatibility requirements.")
	_scripts = interface.get_script_editor()
	_tree = _scripts.get_tree()
	_active = true
	_tree.node_added.connect(_node_added)
	_queue_refresh()

func stop() -> void:
	_active = false
	_tree.node_added.disconnect(_node_added)
	for editor in _scripts.get_open_script_editors():
		if editor.visibility_changed.is_connected(_queue_refresh):
			editor.visibility_changed.disconnect(_queue_refresh)
		var code := editor.get_base_editor() as TextEdit
		if code != null and code.syntax_highlighter != null and code.syntax_highlighter.get_script() == Highlighter:
			code.syntax_highlighter = EditorSyntaxHighlighter.new()

func _node_added(node: Node) -> void:
	if node is ScriptEditorBase and _scripts.is_ancestor_of(node):
		_queue_refresh()

func _queue_refresh() -> void:
	if _active and not _pending:
		_pending = true
		_refresh.call_deferred()

func _refresh() -> void:
	_pending = false
	if not _active: return
	for editor in _scripts.get_open_script_editors():
		if not editor.visibility_changed.is_connected(_queue_refresh):
			editor.visibility_changed.connect(_queue_refresh)
		var code := editor.get_base_editor() as TextEdit
		if code == null: continue
		var path := _path(editor, code)
		if path.get_extension() != "gogo": continue
		code.set_meta(PATH_META, path)
		if code.syntax_highlighter != null and code.syntax_highlighter.get_script() == Highlighter:
			continue
		# A fresh instance per CodeEdit. Do not add duplicate native menu entries
		# or rewrite the per-file cache; normal editor persistence handles state.
		code.syntax_highlighter = Highlighter.new()

func _path(editor: ScriptEditorBase, code: TextEdit, allow_cached: bool = true) -> String:
	if code.syntax_highlighter is EditorSyntaxHighlighter and code.syntax_highlighter.has_method("_get_edited_resource"):
		# Capability-check the bound getter; it is not a published API contract.
		var resource: Resource = code.syntax_highlighter.call("_get_edited_resource") as Resource
		if resource != null: return resource.resource_path
	# A never-associated Plain Text tab has a null highlighter resource, and
	# ScriptEditorBase exposes no resource getter. Stock 4.7's script list
	# supplies exact path tooltips and tab indices (not filtered-list indices).
	# Validate both against the tab's actual parent; never guess from contents
	# or a basename. Pinned-engine adapter covered by real editor regressions.
	if not _tested_adapter: return str(code.get_meta(PATH_META, "")) if allow_cached else ""
	var tabs := editor.get_parent() as TabContainer
	if tabs == null: return ""
	for list in _scripts.find_children("*", "ItemList", true, false):
		for item in range(list.item_count):
			var index: Variant = list.get_item_metadata(item)
			if not (index is int) or index < 0 or index >= tabs.get_tab_count(): continue
			if tabs.get_tab_control(index) != editor: continue
			var path: String = list.get_item_tooltip(item)
			if path.begins_with("res://"): return path
	return str(code.get_meta(PATH_META, "")) if allow_cached else ""
