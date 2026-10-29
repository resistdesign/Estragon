extends SceneTree
## Test-only migration fixture: persisted pre-plugin Plain Text selections.
func _initialize() -> void:
	if OS.get_environment("ESTRAGON_EDITOR_TEST") != "1":
		quit(1)
		return
	var path := "res://.godot/editor/script_editor_cache.cfg"
	var cache := ConfigFile.new()
	if cache.load(path) != OK:
		quit(1)
		return
	for source in ["res://examples/counter/Counter.gogo", "res://examples/counter/Background.gogo"]:
		if not cache.has_section_key(source, "state"):
			quit(1)
			return
		var state: Dictionary = cache.get_value(source, "state")
		state.syntax_highlighter = "Plain Text"
		cache.set_value(source, "state", state)
	if cache.save(path) != OK:
		quit(1)
		return
	print("ESTRAGON_SEEDED_PLAIN_RESTORE")
	quit()
