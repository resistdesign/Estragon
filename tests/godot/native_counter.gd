extends SceneTree
## Direct native compile -> validate -> Counter; --visual also captures pixels.
const Compiler = preload("res://addons/estragon/compiler/compiler.gd")
const Validation = preload("res://addons/estragon/compiler/script_validation.gd")
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	if not value:
		_failed = true
		push_error("Native Counter: " + message)

func _click(button: EstragonButton) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_surface_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"): return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://native-counter-" + name + ".png"
	_check(root.get_texture().get_image().save_png(path) == OK, "capture " + name)
	print("NATIVE_COUNTER_IMAGE ", ProjectSettings.globalize_path(path))

func _run() -> void:
	root.size = Vector2i(640, 360)
	var source := FileAccess.get_file_as_string("res://examples/counter/Counter.gogo")
	var compilation := Compiler.compile(source, "examples/counter/Counter.gogo")
	_check(compilation.ok, "real authored source compiled")
	var validated := Validation.validate(compilation, "res://examples/counter/generated/NativeCounter.gd")
	_check(validated.ok, "generated GDScript validated by Godot")
	if not validated.ok:
		quit(1)
		return
	var surface: EstragonSurface = validated.generated_script.new()
	root.add_child(surface)
	await process_frame
	_check(surface.count == 0 and surface.get_root().get_children()[1].text == "Count: 0", "initial counter")
	_check(surface.get_child_count() == 0, "surface owns independent component hierarchy")
	await _capture("zero")
	var row: EstragonHBox = surface.get_root().get_children()[2]
	var previous: EstragonButton = row.get_children()[0]
	_click(previous)
	await process_frame
	_check(surface.count == 1 and surface.get_root().get_children()[1].text == "Count: 1", "generated increment handler")
	_check(previous.is_disposed() and previous.pressed.get_connections().is_empty(), "replacement releases old generated wiring")
	await _capture("one")
	row = surface.get_root().get_children()[2]
	_click(row.get_children()[1])
	await process_frame
	_check(surface.count == 0 and surface.get_root().get_children()[1].text == "Count: 0", "generated reset handler")
	root.size = Vector2i(800, 400)
	await process_frame
	_check(surface.get_root().get_layout_rect().size == Vector2(800, 400), "native-generated responsive root")
	await _capture("reset-resized")
	var terminal: EstragonButton = surface.get_root().get_children()[2].get_children()[0]
	var renderer := surface._renderer
	surface.free()
	_check(terminal.is_disposed() and terminal.pressed.get_connections().is_empty() and not renderer._canvas_item.is_valid(), "surface destruction cleans components, signals and renderer")
	if not _failed: print("ESTRAGON_NATIVE_COUNTER_OK")
	quit(1 if _failed else 0)
