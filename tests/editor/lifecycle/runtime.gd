extends SceneTree
## Execute the editor's published bytes in a fresh runtime, not an editor Play
## shortcut. Unsaved Play/save APIs remain separately scoped to C01-G.
func _initialize() -> void:
	var script = load("res://ui/generated/Counter.gd")
	var surface = script.new()
	assert(surface.count == 4)
	assert(surface.get_root().get_children()[1].text == "Count: 4")
	surface.increment()
	assert(surface.count == 5 and surface.get_root().get_children()[1].text == "Count: 5")
	assert(surface.get_child_count() == 0)
	surface.free()
	print("C01_F_PUBLISHED_RUNTIME_OK")
	quit(0)
