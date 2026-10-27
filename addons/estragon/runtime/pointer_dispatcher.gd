class_name EstragonPointerDispatcher
extends RefCounted
## Independent single-primary-pointer state. Weak targets; no registrations.

var _hover: WeakRef
var _capture: WeakRef
var _down: bool = false
var _has_position: bool = false
var _position := Vector2.ZERO


func _button(reference: WeakRef) -> EstragonButton:
	return reference.get_ref() as EstragonButton if reference != null else null


func _target(root: EstragonDisplayObject) -> EstragonButton:
	return root.hit_test(_position) as EstragonButton if root != null else null


func _set_hover(target: EstragonButton) -> void:
	var previous := _button(_hover)
	var captured := _button(_capture)
	if previous != null and previous != target:
		previous._set_pointer_state(false, previous == captured)
	_hover = weakref(target) if target != null else null
	if target != null:
		target._set_pointer_state(true, target == captured)


func refresh(root: EstragonDisplayObject, bounds: Rect2) -> void:
	if _has_position:
		if not bounds.has_point(_position):
			cancel()
		else:
			_set_hover(_target(root))


## Surface coordinates have already been converted by Godot's Viewport input.
static func accepts(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)


func dispatch(root: EstragonDisplayObject, event: InputEvent) -> bool:
	if not accepts(event):
		return false
	_position = event.position
	_has_position = true
	var target := _target(root)
	_set_hover(target)
	if event is InputEventMouseMotion:
		return target != null or _button(_capture) != null
	if event.pressed:
		if _down:
			return _button(_capture) != null
		_down = true
		if target != null and not target.disabled:
			_capture = weakref(target)
			target._set_pointer_state(true, true)
		return target != null
	var captured := _button(_capture)
	# Clear before calling application code: handlers may rebuild/free the surface.
	_capture = null
	var was_down := _down
	_down = false
	if captured != null:
		captured._set_pointer_state(captured == target, false)
		if was_down and captured == target and not captured.is_disposed() and not captured.disabled:
			captured.pressed.emit()
	return captured != null or target != null


func cancel() -> void:
	var hovered := _button(_hover)
	var captured := _button(_capture)
	_hover = null
	_capture = null
	_down = false
	_has_position = false
	if hovered != null:
		hovered._set_pointer_state(false, false)
	if captured != null:
		captured._set_pointer_state(false, false)


func _within(target: EstragonDisplayObject, subtree: EstragonDisplayObject) -> bool:
	while target != null:
		if target == subtree:
			return true
		target = target.get_parent()
	return false


func cancel_subtree(subtree: EstragonDisplayObject) -> void:
	var hovered := _button(_hover)
	var captured := _button(_capture)
	if (hovered != null and _within(hovered, subtree)) or (captured != null and _within(captured, subtree)):
		cancel()
