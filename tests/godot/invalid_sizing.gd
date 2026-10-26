extends SceneTree
## Expected-error process, invoked separately by check-godot.ts.


func _initialize() -> void:
	var rect := EstragonRect.new()
	var stack := EstragonVBox.new()
	var probe := OS.get_cmdline_user_args()[0]
	match probe:
		"width": rect.width = INF
		"height": rect.height = NAN
		"negative": rect.width = -2
		"gap": stack.gap = -1
		"geometry": rect.arrange(Rect2(0, 0, -1, 2))
		_:
			quit(1)
			return
	if rect.width != -1 or rect.height != -1 or stack.gap != 0 or rect.get_layout_rect() != Rect2():
		quit(1)
		return
	print("ESTRAGON_INVALID_SIZE_REJECTED")
	quit(0)
