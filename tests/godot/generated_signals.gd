extends SceneTree
## Freshly compiled Counter and callable fixtures; no handwritten connections.

var _checks: int = 0
var _failed: bool = false
var _callback_values: Array = []

func _optional(value: String = "default") -> void:
	_callback_values.append(value)

static func _static_record(values: Array) -> void:
	values.append("static")


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Generated signals test: " + message)


# Godot 4.0 retains the get_ref() expression temporary until its function
# returns. Keep observation in its own frame so the test cannot retain payload.
func _weak_alive(reference: WeakRef) -> bool:
	return reference.get_ref() != null


func _event(position: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	return event


func _click(viewport: Viewport, button: EstragonButton) -> void:
	var position := button.get_surface_rect().get_center()
	viewport.push_input(_event(position, true), true)
	viewport.push_input(_event(position, false), true)


func _buttons(surface: EstragonSurface) -> Array[EstragonDisplayObject]:
	return (surface.get_root().get_children()[2] as EstragonHBox).get_children()


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 280)
	root.add_child(viewport)
	var counter: EstragonSurface = load("res://examples/counter/Counter.tscn").instantiate()
	viewport.add_child(counter)
	await process_frame
	_check(counter.get_child_count() == 0, "one host without component Nodes")
	var buttons := _buttons(counter)
	var first: EstragonButton = buttons[0]
	var reset: EstragonButton = buttons[1]
	_check(first.pressed.get_connections().size() == 1 and reset.pressed.get_connections().size() == 1, "exactly one generated connection per button")
	_check(reset.disabled and first.text == "+", "typed text and boolean properties")
	var title: EstragonText = counter.get_root().get_children()[0]
	_check(title.font_size == 26 and title.color == Color("bba2ef"), "Text literal integer/color properties")
	var old_label: EstragonText = counter.get_root().get_children()[1]
	_check(old_label.text == "Count: 0" and old_label.font_size == 24, "dynamic text and integer property")
	_check(first.get_layout_rect().size.x == 194, "compiled nested fill layout")
	_click(viewport, reset)
	_check(counter.count == 0 and counter.get_root().get_children()[1] == old_label, "disabled compiled button does not rebuild")
	_click(viewport, first)
	_check(counter.count == 1 and counter.get_root().get_children()[1].text == "Count: 1", "real input invokes authored increment and refreshes UI")
	_check(first.is_disposed() and old_label.is_disposed() and reset.is_disposed(), "rebuild automatically cleans replaced components")
	_check(first.pressed.get_connections().is_empty() and reset.pressed.get_connections().is_empty(), "rebuild disconnects generated handlers")
	first.pressed.emit()
	_check(counter.count == 1, "retained terminal source cannot invoke old handler")
	_check(counter._pointer._capture == null, "reentrant rebuild clears gesture")
	for value in range(2, 6):
		await process_frame
		var previous: EstragonButton = _buttons(counter)[0]
		_check(previous.pressed.get_connections().size() == 1, "repeated rebuild never duplicates connection")
		_click(viewport, previous)
		_check(counter.count == value, "one click increments exactly once")
		_check(previous.is_disposed() and previous.pressed.get_connections().is_empty(), "every previous source is disconnected")
	await process_frame
	buttons = _buttons(counter)
	reset = buttons[1]
	_check(not reset.disabled, "rebuild updates computed disabled state")
	_click(viewport, reset)
	_check(counter.count == 0 and counter.get_root().get_children()[1].text == "Count: 0", "second button invokes distinct reset handler")
	viewport.size = Vector2i(600, 320)
	await process_frame
	buttons = _buttons(counter)
	_check(buttons[0].get_layout_rect().size.x == 294, "Counter resizes nested button row")
	var paint := EstragonPaintList.new()
	counter.get_root().append_paint(paint)
	var label_drawn: bool = false
	for command in paint.commands:
		if command is EstragonPaintList.TextRun and command.text == "Count: 0":
			label_drawn = true
	_check(label_drawn, "updated count participates in real text paint")
	var last: EstragonButton = buttons[0]
	counter.set_root(null)
	_check(last.is_disposed() and last.pressed.get_connections().is_empty(), "explicit unmount cleans generated wiring")
	counter.free()
	# GDScript-first helper module exercises lexical scope, bind and lambda values.
	var module = load("res://tests/godot/generated/SignalEdges.gd").new()
	var tree: EstragonVBox = module.build()
	_check(module.events == ["first", "label"], "signal/property arguments evaluated once in authored order")
	var surface := EstragonSurface.new()
	surface.set_root(tree)
	viewport.add_child(surface)
	await process_frame
	var children := tree.get_children()
	_click(viewport, children[0])
	_click(viewport, children[1])
	_click(viewport, children[2])
	_check(module.events == ["first", "label", "first", "local", "lambda"], "computed bound/local/lambda callbacks preserve scope and distinct handlers")
	_check(children[1].font_size == 22 and children[1].color == Color.CORAL, "dynamic typed Button properties")
	var static_button: EstragonButton = module.build_static(module.record.bind("static"))
	surface.set_root(static_button)
	await process_frame
	_click(viewport, static_button)
	_check(module.events[-1] == "static", "static authored factory accepts native callable")
	_check(children[0].pressed.get_connections().is_empty(), "lambda/bound/local connections removed with old tree")
	# Optional parameters remain rejected unbound on modern engines; binding
	# every parameter is valid on every engine, including static methods.
	for callback in [_optional.bind("bound optional"), _static_record.bind(_callback_values)]:
		var bound_button: EstragonButton = module.build_static(callback)
		_check(bound_button.pressed.get_connections().size() == 1, "bound callback connects once")
		bound_button.pressed.emit()
		surface.set_root(bound_button)
		surface.set_root(null)
		_check(bound_button.pressed.get_connections().is_empty(), "bound callback owner cleanup")
	_check(_callback_values == ["bound optional", "static"], "optional bound and static callbacks execute once")
	# A direct callback target is a logical component, separate from its source.
	var owner := EstragonContainer.new()
	var destination := EstragonContainer.new()
	owner.add_child(module.receiver)
	var receiver_button: EstragonButton = module.build_receiver_button()
	surface.set_root(receiver_button)
	await process_frame
	_click(viewport, receiver_button)
	_check(module.receiver.calls == 1, "generated direct component-method callback")
	destination.add_child(module.receiver)
	_check(receiver_button.pressed.get_connections().size() == 1, "target transfer retains incoming generated connection")
	_click(viewport, receiver_button)
	_check(module.receiver.calls == 2, "transferred target still receives handler")
	destination.remove_child(module.receiver)
	_check(module.receiver.is_disposed() and receiver_button.pressed.get_connections().is_empty(), "target unmount disconnects incoming source connection automatically")
	_click(viewport, receiver_button)
	_check(module.receiver.calls == 2, "live source cannot callback disposed retained target")
	var payload := RefCounted.new()
	var payload_ref: WeakRef = weakref(payload)
	var capturing_button: EstragonButton = module.build_capture(payload)
	payload = null
	_check(_weak_alive(payload_ref), "generated lambda retains its captured payload while mounted")
	surface.set_root(capturing_button)
	surface.set_root(null)
	_check(capturing_button.pressed.get_connections().is_empty() and not _weak_alive(payload_ref), "unmount releases generated lambda and captured resources")
	surface.free()
	_check(receiver_button.is_disposed() and static_button.pressed.get_connections().is_empty(), "host destruction cleans all remaining wiring")
	# Standalone markup still works for literal-only primitive properties.
	var literals: EstragonSurface = load("res://tests/godot/generated/Primitives.gd").new()
	var literal_children := (literals.get_root() as EstragonVBox).get_children()
	_check(literal_children[0] is EstragonText and literal_children[0].font_size == 21 and literal_children[0].color == Color("ff990080"), "standalone Text literals compile/run")
	_check(literal_children[1] is EstragonButton and literal_children[1].disabled, "standalone Button literals compile/run")
	literals.free()
	viewport.free()
	await process_frame
	print("Generated signal checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_SIGNALS_OK")
		quit(0)
