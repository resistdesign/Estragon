extends SceneTree
## Loaded only after check-godot.ts freshly transpiles Gogo in its isolated copy.

var _failed: bool = false
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Generated Gogo test: " + message)


func _run() -> void:
	var packed := load("res://examples/compiled/Compiled.tscn") as PackedScene
	var surface := packed.instantiate() as EstragonSurface
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 240)
	root.add_child(viewport)
	viewport.add_child(surface)
	await process_frame
	_check(surface != null and surface.get_child_count() == 0, "one generated surface without component Nodes")
	var column := surface.get_root() as EstragonVBox
	_check(column != null and column.gap == 16, "VBox resolves to real runtime class with gap")
	var header := column.get_children()[0] as EstragonRect
	var row := column.get_children()[1] as EstragonHBox
	_check(row != null and row.gap == 12 and row.fill_width and row.fill_height, "HBox class and typed properties")
	var sidebar := row.get_children()[0] as EstragonRect
	var content := row.get_children()[1] as EstragonRect
	_check(header.height == 64 and header.fill == Color("8566e0"), "fixed size and normalized color")
	_check(sidebar.width == 160 and content.fill_width and content.fill_height, "sizing/fill booleans")
	_check(column.get_layout_rect() == Rect2(0, 0, 400, 240), "generated root mounts to surface viewport")
	_check(content.get_layout_rect() == Rect2(172, 0, 228, 160), "generated nested component geometry")
	var paint := EstragonPaintList.new()
	column.append_paint(paint)
	_check(paint.rectangles.size() == 3, "compiled hierarchy produces rectangle commands")
	_check(paint.rectangles[2].rect == Rect2(172, 80, 228, 160), "generated output has correct absolute paint geometry")
	_check(paint.rectangles[2].color == Color("50466f"), "generated paint color")
	viewport.size = Vector2i(600, 320)
	await process_frame
	_check(content.get_layout_rect() == Rect2(172, 0, 428, 240), "generated hierarchy resizes without manual refresh")
	var backend := surface._renderer
	_check(backend._canvas_item.is_valid(), "generated surface has one backend canvas")
	column.remove_child(header)
	_check(header.is_disposed(), "unmount of generated component cleans automatically")
	surface.free()
	_check(column.is_disposed() and row.is_disposed() and content.is_disposed(), "generated surface owns recursive cleanup")
	_check(not backend._canvas_item.is_valid(), "generated surface frees rendering resource")

	# Freshly emitted numeric edge case and empty-root variant must parse/run too.
	var numeric_script := load("res://tests/godot/generated/Numbers.gd") as Script
	var numeric: EstragonSurface = numeric_script.new()
	viewport.add_child(numeric)
	await process_frame
	var number_rect := numeric.get_root() as EstragonRect
	_check(is_equal_approx(number_rect.width, 1e20), "large float literal avoids GDScript integer overflow")
	_check(number_rect.height == 0 and number_rect.fill == Color("12345678"), "zero size and explicit RGBA")
	numeric.free()
	_check(number_rect.is_disposed(), "numeric root cleanup automatic")
	var empty_script := load("res://tests/godot/generated/Empty.gd") as Script
	var empty: EstragonSurface = empty_script.new()
	viewport.add_child(empty)
	await process_frame
	var empty_root := empty.get_root() as EstragonHBox
	_check(empty_root != null and empty_root.get_child_count() == 0, "empty generated container works")
	_check(empty_root.get_layout_rect().size == Vector2(600, 320), "empty auto root uses viewport size")
	empty.set_root(null)
	_check(empty_root.is_disposed(), "generated root unmount automatic")
	empty.free()
	viewport.free()
	await process_frame
	print("Generated Gogo checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_GENERATED_GOGO_OK")
		quit(0)
