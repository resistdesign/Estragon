extends SceneTree
## Real fonts/renderer/input, independent target selection and automatic cleanup.

var _checks: int = 0
var _failed: bool = false
var _counts: Array[int] = [0, 0]


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Interaction test: " + message)


func _button(label: String) -> EstragonButton:
	var button := EstragonButton.new()
	button.text = label
	button.fill_width = true
	return button


func _event(position: Vector2, down: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = index
	event.pressed = down
	return event


func _motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _click(surface: EstragonSurface, position: Vector2) -> void:
	surface.dispatch_pointer(_event(position, true))
	surface.dispatch_pointer(_event(position, false))


func _test_text() -> void:
	var text := EstragonText.new()
	text.text = "Hello"
	var size := text.measure()
	_check(size.x > 0 and size.y > 0, "real font measures nonempty text")
	_check(size.x == text.font.get_string_size("Hello", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, "measurement uses shaped string metrics")
	text.arrange(Rect2(Vector2(4, 6), size))
	var list := EstragonPaintList.new()
	text.append_paint(list, Vector2(10, 12))
	_check(list.commands.size() == 1 and list.rectangles.is_empty(), "text paint without component rectangles/RIDs")
	var command: EstragonPaintList.TextRun = list.commands[0]
	_check(command.text == "Hello" and command.font == text.font and command.font_size == 20, "typed text snapshot")
	_check(command.position == Vector2(14, 18 + text.font.get_ascent(20)), "absolute baseline includes local and parent offsets")
	text.color = Color.CORAL
	_check(text.get_dirty_flags() == EstragonDisplayObject.DIRTY_PAINT, "color invalidates paint only")
	text.clear_invalidations()
	text.text = "Longer string\nsecond line"
	_check(text.get_dirty_flags() == (EstragonDisplayObject.DIRTY_LAYOUT | EstragonDisplayObject.DIRTY_PAINT), "text change invalidates measurement and paint")
	_check(text.measure().y == size.y * 2 and text.measure().x > size.x, "explicit lines measure width and height")
	text.arrange(Rect2(Vector2.ZERO, text.measure()))
	list = EstragonPaintList.new()
	text.append_paint(list)
	_check(list.commands.size() == 2, "one text command per explicit nonempty line")
	_check(list.commands[1].position.y - list.commands[0].position.y == text.font.get_height(20), "line baseline advance")
	text.font_size = 30
	_check(text.measure().y > size.y * 2, "font size participates in natural layout")
	text.width = 12
	_check(text.measure().x == 12, "explicit sizing overrides text natural width")
	text.text = ""
	text.width = -1
	_check(text.measure() == Vector2(0, text.font.get_height(30)), "empty text reserves one line height")
	text.arrange(Rect2(0, 0, 0, 0))
	list = EstragonPaintList.new()
	text.append_paint(list)
	_check(list.commands.is_empty(), "empty/zero-area text emits no drawing")
	var button := _button("Button")
	text.text = "Button"
	text.font_size = button.font_size
	_check(button.measure() == text.measure() + EstragonButton.PADDING * 2, "button intrinsic label plus padding")
	button.arrange(Rect2(Vector2(7, 9), button.measure() + Vector2(50, 20)))
	list = EstragonPaintList.new()
	button.append_paint(list)
	_check(list.commands.size() == 2 and list.commands[0] is EstragonPaintList.FillRect and list.commands[1] is EstragonPaintList.TextRun, "background before centered label")
	_check(list.rectangles[0].color == EstragonButton.NORMAL_COLOR, "normal appearance")
	_check(list.commands[1].position.x == 7 + 14 + 25, "center label in extra allocation")
	button.disabled = true
	list = EstragonPaintList.new()
	button.append_paint(list)
	_check(list.rectangles[0].color == EstragonButton.DISABLED_COLOR and list.commands[1].color.a == 0.5, "disabled background and label appearance")
	# Shared canvas preserves text/rect interleaving (old separate arrays would fail).
	var rect := EstragonRect.new()
	rect.arrange(Rect2(0, 0, 10, 10))
	rect.append_paint(list)
	_check(list.commands[2] is EstragonPaintList.FillRect, "later rectangle remains above earlier text")


func _test_button_center_clamp() -> void:
	var button := _button("Clamp")
	var label_size := button.measure() - EstragonButton.PADDING * 2
	var position := Vector2(7.25, 9.5)
	var origin := Vector2(13.5, 19.25)
	var cases := [
		[Vector2(10.5, -2.5), Vector2(5.25, 0)],
		[Vector2(-2.5, 6.5), Vector2(0, 3.25)],
		[Vector2.ZERO, Vector2.ZERO],
		[Vector2(3.5, 5.5), Vector2(1.75, 2.75)],
		[Vector2(-2.5, -2.5), Vector2.ZERO],
	]
	for item in cases:
		var size: Vector2 = label_size + item[0]
		button.arrange(Rect2(position, size))
		var list := EstragonPaintList.new()
		button.append_paint(list, origin)
		_check(list.commands.size() == 2, "clamped button retains background and label for surplus %s" % item[0])
		if list.commands.size() != 2: continue
		var expected: Vector2 = origin + position + item[1] + Vector2(0, button.font.get_ascent(button.font_size))
		_check(list.commands[1].position.is_equal_approx(expected), "button centers positive surplus and clamps negative surplus independently: %s" % item[0])
		_check(list.rectangles[0].rect == Rect2(origin + position, size), "label clamping preserves fractional button background: %s" % item[0])
	for size in [Vector2(0, 20), Vector2(20, 0), Vector2.ZERO]:
		button.arrange(Rect2(position, size))
		var list := EstragonPaintList.new()
		button.append_paint(list, origin)
		_check(list.commands.is_empty(), "zero-area button paints neither background nor label: %s" % size)
	var surface := EstragonSurface.new()
	surface.set_root(button)
	surface.free()


func _test_transfers_and_exit() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 200)
	root.add_child(viewport)
	var first := EstragonSurface.new()
	var second := EstragonSurface.new()
	var a := EstragonVBox.new()
	var b := EstragonVBox.new()
	var button := _button("Transfer")
	var count: Array[int] = [0]
	button.pressed.connect(func() -> void: count[0] += 1)
	a.add_child(button)
	first.set_root(a)
	second.set_root(b)
	viewport.add_child(first)
	viewport.add_child(second)
	first.dispatch_pointer(_event(Vector2(10, 10), true))
	b.add_child(button)
	_check(first._pointer._capture == null and not button.is_disposed(), "cross-surface move cancels old capture without disposal")
	second.dispatch_pointer(_event(Vector2(10, 10), false))
	_check(count[0] == 0, "cross-surface transfer does not transfer press")
	_click(second, Vector2(10, 10))
	_check(count[0] == 1 and button.pressed.get_connections().size() == 1, "transferred button keeps exactly one handler")
	second.dispatch_pointer(_event(Vector2(10, 10), true))
	var window := second._window
	var pointer: EstragonPointerDispatcher = second._pointer
	viewport.remove_child(second)
	_check(button.is_disposed() and not button._held and not button._hovered, "surface exit clears active component state")
	_check(pointer._capture == null and pointer._hover == null, "surface exit releases pointer weak targets")
	_check(not window.mouse_exited.is_connected(pointer.cancel) and not window.focus_exited.is_connected(pointer.cancel), "surface exit disconnects window input subscriptions")
	_check(not second.dispatch_pointer(_event(Vector2(10, 10), false)) and count[0] == 1, "exited surface cannot dispatch")
	viewport.add_child(second)
	var fresh := _button("Fresh")
	second.set_root(fresh)
	_click(second, Vector2(10, 10))
	_check(fresh.get_visual_state() == EstragonButton.VisualState.HOVER and not fresh.is_disposed(), "reentered surface starts fresh")
	second.set_root(null)
	_check(fresh.is_disposed() and pointer._hover == null, "explicit root unmount clears hover and lifecycle")
	viewport.free()


func _run() -> void:
	_test_text()
	_test_button_center_clamp()
	_test_transfers_and_exit()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 260)
	root.add_child(viewport)
	var surface := EstragonSurface.new()
	var column := EstragonVBox.new()
	column.gap = 10
	var heading := EstragonText.new()
	heading.text = "Header"
	heading.height = 30
	column.add_child(heading)
	var row := EstragonHBox.new()
	row.gap = 8
	row.fill_width = true
	var left := _button("Left")
	var right := _button("Right")
	left.pressed.connect(func() -> void: _counts[0] += 1)
	right.pressed.connect(func() -> void: _counts[1] += 1)
	row.add_child(left)
	row.add_child(right)
	column.add_child(row)
	surface.set_root(column)
	viewport.add_child(surface)
	await process_frame
	_check(surface.get_child_count() == 0, "no component Nodes")
	_check(surface._renderer._canvas_item.is_valid(), "text/rectangle renderer open")
	_check(left.get_surface_rect().position == Vector2(0, 40) and right.get_surface_rect().position == Vector2(204, 40), "nested absolute geometry")
	var lp := Vector2(20, 50)
	var rp := Vector2(220, 50)
	_check(column.hit_test(lp) == left and column.hit_test(rp) == right, "nested hit selection")
	_check(column.hit_test(Vector2(199, 50)) == null, "gap is not a target")
	_check(column.hit_test(Vector2(0, 40)) == left and column.hit_test(Vector2(196, 50)) == null, "half-open hit bounds")
	surface.dispatch_pointer(_motion(lp))
	_check(left.get_visual_state() == EstragonButton.VisualState.HOVER, "hover state")
	surface.dispatch_pointer(_event(lp, true))
	_check(left.get_visual_state() == EstragonButton.VisualState.DOWN, "press state")
	surface.dispatch_pointer(_event(lp, true))
	surface.dispatch_pointer(_event(lp, false))
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [1, 0], "repeat down/up cannot duplicate click")
	_click(surface, rp)
	_check(_counts == [1, 1], "distinct button handlers")
	surface.dispatch_pointer(_event(lp, true))
	surface.dispatch_pointer(_motion(rp))
	_check(left.get_visual_state() == EstragonButton.VisualState.NORMAL, "moving outside removes down appearance")
	surface.dispatch_pointer(_event(rp, false))
	_check(_counts == [1, 1], "release over different button does not click either")
	surface.dispatch_pointer(_event(lp, true))
	surface.dispatch_pointer(_motion(Vector2(390, 230)))
	surface.dispatch_pointer(_motion(lp))
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [2, 1], "leave/reenter captured button activates once")
	surface.dispatch_pointer(_event(Vector2(390, 230), true))
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [2, 1], "press outside then release inside does not activate")
	surface.dispatch_pointer(_event(lp, true, MOUSE_BUTTON_RIGHT))
	surface.dispatch_pointer(_event(lp, false, MOUSE_BUTTON_RIGHT))
	_check(_counts == [2, 1], "secondary mouse ignored")
	var key := InputEventKey.new()
	_check(not surface.dispatch_pointer(key), "keyboard outside this event model")
	surface.dispatch_pointer(_event(lp, true))
	surface.dispatch_pointer(_event(Vector2(-1, -1), false, MOUSE_BUTTON_RIGHT))
	_check(left.get_visual_state() == EstragonButton.VisualState.DOWN, "unrelated button events do not cancel primary capture")
	left.disabled = true
	_check(surface._pointer._capture == null and left.get_visual_state() == EstragonButton.VisualState.DISABLED, "disable cancels press immediately")
	surface.dispatch_pointer(_event(lp, false))
	_click(surface, lp)
	_check(_counts == [2, 1], "disabled never activates")
	left.disabled = false
	surface.dispatch_pointer(_event(lp, true))
	surface._window.focus_exited.emit()
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [2, 1] and surface._pointer._capture == null, "focus loss cancels capture")
	surface.dispatch_pointer(_event(lp, true))
	surface._window.mouse_exited.emit()
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [2, 1], "window/viewport mouse exit cancels")
	surface.dispatch_pointer(_event(lp, true))
	surface.dispatch_pointer(_event(Vector2(-1, 50), false))
	_check(_counts == [2, 1] and surface._pointer._capture == null, "release outside viewport cancels")
	# Intrinsic text changes also reflow mounted nested layouts immediately.
	heading.height = -1
	heading.text = "Header\nSecond line"
	surface.dispatch_pointer(_motion(lp))
	_check(row.get_layout_rect().position.y == heading.font.get_height(heading.font_size) * 2 + 10, "mounted multiline text reflows following components")
	heading.font_size = 26
	surface.dispatch_pointer(_motion(lp))
	_check(row.get_layout_rect().position.y == heading.font.get_height(26) * 2 + 10, "mounted font-size change remeasures layout")
	# A layout mutation must affect the very next event, before deferred paint.
	heading.text = "Header"
	heading.height = 100
	_click(surface, lp)
	_check(_counts == [2, 1], "input synchronously uses current layout")
	lp = Vector2(20, 120)
	_click(surface, lp)
	_check(_counts == [3, 1], "new nested position activates")
	viewport.size = Vector2i(600, 300)
	_click(surface, Vector2(250, 120))
	_check(_counts == [4, 1] and left.get_layout_rect().size.x == 296, "resize affects hit testing immediately")
	await process_frame
	viewport.size = Vector2i(200, 260)
	await process_frame
	_check(surface._pointer._hover == null, "resize outside last pointer position clears stationary hover")
	viewport.size = Vector2i(600, 300)
	heading.height = 30
	await process_frame
	lp = Vector2(20, 50)
	rp = Vector2(330, 50)
	# Push actual Godot viewport events to exercise the surface _input bridge.
	viewport.push_input(_event(rp, true), true)
	viewport.push_input(_event(rp, false), true)
	_check(_counts == [4, 2], "Godot input bridge dispatches viewport-local coordinates")
	# Ownership transfers cancel the gesture without disposing the moved button.
	surface.dispatch_pointer(_event(lp, true))
	var destination := EstragonVBox.new()
	column.add_child(destination)
	destination.add_child(left)
	_check(not left.is_disposed() and surface._pointer._capture == null, "reparent cancels capture and preserves component")
	_check(left.get_visual_state() == EstragonButton.VisualState.NORMAL, "reparent clears interaction state")
	surface.dispatch_pointer(_event(lp, false))
	_check(_counts == [4, 2], "reparent does not finish old click")
	var moved_ref: WeakRef = weakref(left)
	destination.remove_child(left)
	_check(left.is_disposed() and left.pressed.get_connections().is_empty(), "remove disposes and disconnects application signal closures")
	_check(left.font == null, "unmount releases font reference")
	_check(left.hit_test(lp) == null, "disposed component never hit")
	left = null
	_check(moved_ref.get_ref() == null, "dispatcher weak references do not retain removed component")
	# Replacement under active pointer resets capture and terminal old state.
	var replacement := _button("Replacement")
	surface.dispatch_pointer(_event(rp, true))
	row.replace_child(right, replacement)
	_check(right.is_disposed() and right.pressed.get_connections().is_empty(), "replacement cleans old connections")
	_check(surface._pointer._capture == null and not right._held and not right._hovered, "replacement cancels input immediately")
	surface.dispatch_pointer(_event(rp, false))
	_check(_counts == [4, 2], "replacement cannot inherit unfinished press")
	# Overlays resolve in reverse paint order; disabled top button occludes.
	var overlay := EstragonContainer.new()
	var lower := _button("Lower")
	var upper := _button("Upper")
	overlay.add_child(lower)
	overlay.add_child(upper)
	surface.set_root(overlay)
	_check(column.is_disposed() and replacement.is_disposed(), "root replacement cleans remaining subtree")
	surface.dispatch_pointer(_motion(Vector2(10, 10)))
	_check(overlay.hit_test(Vector2(10, 10)) == upper, "topmost interactive painted sibling wins")
	upper.disabled = true
	var overlap_counts: Array[int] = [0]
	lower.pressed.connect(func() -> void: overlap_counts[0] += 1)
	_click(surface, Vector2(10, 10))
	_check(overlap_counts[0] == 0, "disabled top target blocks lower button")
	# No implicit parent clipping: overflow follows existing paint semantics.
	upper.width = 100
	lower.width = 100
	overlay.width = 1
	overlay.height = 1
	surface.dispatch_pointer(_motion(Vector2(10, 10)))
	_check(overlay.hit_test(Vector2(10, 10)) == upper, "overflow remains hit-testable like paint")
	upper.disabled = false
	upper.pressed.connect(func() -> void: surface.set_root(EstragonText.new()))
	_click(surface, Vector2(10, 10))
	_check(upper.is_disposed() and surface._pointer._capture == null, "reentrant pressed handler can replace root safely")
	# Signal emission resets state before a handler queues native host teardown.
	var final_button := _button("Destroy")
	surface.set_root(final_button)
	final_button.pressed.connect(surface.queue_free)
	_click(surface, Vector2(10, 10))
	_check(surface._pointer._capture == null, "state cleared before deferred host teardown")
	_check(not surface.dispatch_pointer(_event(Vector2(10, 10), true)), "queued host cannot accept new input")
	await process_frame
	await process_frame
	_check(final_button.is_disposed() and final_button.pressed.get_connections().is_empty(), "queued host teardown cleans state/connections")
	viewport.free()
	# The ordinary authored demo really invokes respective GDScript handlers.
	var demo_viewport := SubViewport.new()
	demo_viewport.size = Vector2i(640, 360)
	root.add_child(demo_viewport)
	var demo: EstragonSurface = load("res://examples/interactive/Interactive.tscn").instantiate()
	demo_viewport.add_child(demo)
	await process_frame
	var demo_row: EstragonContainer = demo.get_root().get_children()[2]
	var buttons := demo_row.get_children()
	_click(demo, buttons[0].get_surface_rect().get_center())
	_check(demo._count == 1 and "Add one handler ran" in demo._status.text, "demo Add one handler updates text")
	_click(demo, buttons[1].get_surface_rect().get_center())
	_check(demo._count == 0 and "Reset handler ran" in demo._status.text, "demo Reset handler updates text")
	demo_viewport.free()
	await process_frame
	print("Interaction checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_INTERACTION_OK")
		quit(0)
