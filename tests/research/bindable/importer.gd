@tool
extends EditorImportPlugin
## One fixed research fixture, not a production source transformer.
var calls: Array[String] = []
func _get_importer_name() -> String:
	return "estragon.r01.fixed_fixture"
func _get_visible_name() -> String:
	return "R01 fixed fixture"
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["gd"])
func _get_save_extension() -> String:
	return "gd"
func _get_resource_type() -> String:
	return "GDScript"
func _get_preset_count() -> int:
	return 1
func _get_preset_name(_index: int) -> String:
	return "Default"
func _get_import_options(_path: String, _index: int) -> Array[Dictionary]:
	return []
func _get_option_visibility(_path: String, _option: StringName, _options: Dictionary) -> bool:
	return true
func _import(source_file: String, save_path: String, _options: Dictionary, _variants: Array[String], _files: Array[String]) -> Error:
	calls.append(source_file)
	if source_file != "res://model.gd":
		return ERR_UNAVAILABLE
	var output := FileAccess.open(save_path + ".gd", FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string(FileAccess.get_file_as_string("res://generated.gd.txt"))
	return OK
