class_name EstragonSurface
extends Node
## Single host: automatic root lifecycle, viewport layout and backend ownership.

var _pointer := EstragonPointerDispatcher.new()
var _root: EstragonDisplayObject
var _renderer := EstragonCanvasRenderer.new()
var _viewport: Viewport
var _window: Window
var _queued: bool = false
var _closing: bool = false
var _changing_root: bool = false


func get_root() -> EstragonDisplayObject:
	return _root


## Null unmounts; replacing cleans the previous root. Live roots have one owner.
func set_root(component: EstragonDisplayObject) -> Error:
	if _closing or _changing_root:
		return ERR_UNAVAILABLE
	if component == _root:
		return OK
	if component != null:
		if component.is_disposed() or component.get_parent() != null:
			return ERR_INVALID_PARAMETER
		if component._surface_ref != null and component._surface_ref.get_ref() != null:
			return ERR_ALREADY_IN_USE
	_changing_root = true
	_unmount_root()
	_root = component
	if _root != null:
		_root._surface_ref = weakref(self)
		_root._invalidated.connect(_request_update)
		_root.invalidate()
	_changing_root = false
	_request_update()
	return OK


func _enter_tree() -> void:
	_closing = false
	_viewport = get_viewport()
	_renderer.open(_viewport.find_world_2d().canvas)
	_viewport.size_changed.connect(_resized)
	_window = get_window()
	_window.mouse_exited.connect(_pointer.cancel)
	_window.focus_exited.connect(_pointer.cancel)
	_request_update()


func _resized() -> void:
	if _root != null:
		_root.invalidate(EstragonDisplayObject.DIRTY_LAYOUT | EstragonDisplayObject.DIRTY_PAINT)


func _request_update() -> void:
	if not is_inside_tree() or _closing or _queued:
		return
	_queued = true
	_flush.call_deferred()


func _flush() -> void:
	_queued = false
	if _closing or not is_inside_tree():
		return
	var list := EstragonPaintList.new()
	if _root != null:
		_layout_if_needed()
		_pointer.refresh(_root, _viewport.get_visible_rect())
		_root.append_paint(list)
	_renderer.render(list)


func _unmount_root() -> void:
	_pointer.cancel()
	var previous := _root
	_root = null
	if previous != null:
		previous._invalidated.disconnect(_request_update)
		previous._surface_ref = null
		previous._dispose()


func _exit_tree() -> void:
	_release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release()


func _release() -> void:
	_closing = true
	if is_instance_valid(_viewport) and _viewport.size_changed.is_connected(_resized):
		_viewport.size_changed.disconnect(_resized)
	if is_instance_valid(_window):
		if _window.mouse_exited.is_connected(_pointer.cancel):
			_window.mouse_exited.disconnect(_pointer.cancel)
		if _window.focus_exited.is_connected(_pointer.cancel):
			_window.focus_exited.disconnect(_pointer.cancel)
	_window = null
	_viewport = null
	_unmount_root()
	_renderer.close()


func _layout_if_needed() -> void:
	if _root != null and _root.get_dirty_flags() & (EstragonDisplayObject.DIRTY_TREE | EstragonDisplayObject.DIRTY_LAYOUT):
		_root.measure()
		var available := _viewport.get_visible_rect().size
		var size := Vector2(_root.width if _root.width >= 0 else available.x,
			_root.height if _root.height >= 0 else available.y)
		_root.arrange(Rect2(Vector2.ZERO, size))


## Public input adapter, also usable by integrations/tests with viewport events.
func dispatch_pointer(event: InputEvent) -> bool:
	if not EstragonPointerDispatcher.accepts(event):
		return false
	if _closing or not is_inside_tree() or is_queued_for_deletion() or _root == null:
		_pointer.cancel()
		return false
	if event is InputEventMouse and not _viewport.get_visible_rect().has_point(event.position):
		_pointer.cancel()
		return false
	_layout_if_needed()
	return _pointer.dispatch(_root, event)


func _input(event: InputEvent) -> void:
	var viewport := _viewport
	if dispatch_pointer(event) and is_instance_valid(viewport):
		viewport.set_input_as_handled()
