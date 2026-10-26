@tool
extends EditorPlugin

# This is intentionally NOT a Godot Control-based UI importer. It only teaches
# the editor to treat .gogo as text. A dedicated language service comes later.
# Note: EditorSettings are global (not project-scoped) and persist on disable.
const TEXT_EXTENSIONS_SETTING := "docks/filesystem/textfile_extensions"


func _enter_tree() -> void:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(TEXT_EXTENSIONS_SETTING):
		push_warning("Estragon: textfile_extensions setting is unavailable.")
		return

	var extensions := PackedStringArray()
	for raw_extension in str(settings.get_setting(TEXT_EXTENSIONS_SETTING)).split(","):
		var extension := raw_extension.strip_edges().trim_prefix(".")
		if not extension.is_empty():
			extensions.append(extension)

	if not extensions.has("gogo"):
		extensions.append("gogo")
		settings.set_setting(TEXT_EXTENSIONS_SETTING, ",".join(extensions))
