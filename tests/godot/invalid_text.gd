extends SceneTree
## Expected errors must retain the last valid property value.

func _initialize() -> void:
	var text := EstragonText.new()
	var mode := OS.get_cmdline_user_args()[0]
	if mode == "font":
		var previous := text.font
		text.font = null
		if text.font != previous:
			quit(1)
			return
	else:
		text.font_size = 0
		if text.font_size != 20:
			quit(1)
			return
	print("ESTRAGON_INVALID_TEXT_REJECTED")
	quit(0)
