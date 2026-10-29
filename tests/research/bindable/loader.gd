@tool
extends ResourceFormatLoader
## Fixed fixture substitution ONLY. Not a parser or proposed preprocessor.
var calls: Array[String] = []
var generic_type: bool = false

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["gd"])

func _handles_type(type: StringName) -> bool:
	return type == &"" or type == &"Script" or type == &"GDScript"

func _get_resource_type(path: String) -> String:
	return ("Script" if generic_type else "GDScript") if path == "res://model.gd" else ""

func _recognize_path(path: String, _type: StringName) -> bool:
	return path == "res://model.gd"

func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	calls.append(path)
	var script := GDScript.new()
	script.set_path_cache(path)
	script.source_code = FileAccess.get_file_as_string("res://generated.gd.txt")
	var error := script.reload()
	if error != OK:
		return error
	script.take_over_path(path)
	return script
