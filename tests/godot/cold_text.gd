extends SceneTree
## No component preloads/types here: the first resource edge MUST be Text.

func _initialize() -> void:
	var text = load("res://addons/estragon/runtime/text.gd").new()
	text.text = "Cold Text first"
	assert(text.measure().x > 0)
	var button = load("res://addons/estragon/runtime/button.gd").new()
	button.text = "Then Button"
	assert(button.measure().x > text.font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.font_size).x)
	var container = load("res://addons/estragon/runtime/vbox.gd").new()
	assert(container.add_child(text) == OK)
	assert(container.add_child(button) == OK)
	var surface = load("res://addons/estragon/runtime/surface.gd").new()
	assert(surface.set_root(container) == OK)
	assert(text.get_surface() == surface and button.get_surface() == surface)
	surface.free()
	assert(text.is_disposed() and button.is_disposed() and container.is_disposed())
	print("ESTRAGON_COLD_TEXT_OK")
	quit(0)
