class_name EstragonDisplayObject
extends RefCounted
## Logical component: geometry and lifecycle, without Nodes or graphics RIDs.

signal _invalidated

const DIRTY_TREE: int = 1
const DIRTY_LAYOUT: int = 2
const DIRTY_PAINT: int = 4
const DIRTY_ALL: int = DIRTY_TREE | DIRTY_LAYOUT | DIRTY_PAINT

var width: float = -1.0:
	set(value):
		if not is_valid_dimension(value):
			push_error("Estragon: width must be -1 (auto) or finite and nonnegative")
			return
		if not _disposed and width != value:
			width = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var height: float = -1.0:
	set(value):
		if not is_valid_dimension(value):
			push_error("Estragon: height must be -1 (auto) or finite and nonnegative")
			return
		if not _disposed and height != value:
			height = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var fill_width: bool = false:
	set(value):
		if not _disposed and fill_width != value:
			fill_width = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var fill_height: bool = false:
	set(value):
		if not _disposed and fill_height != value:
			fill_height = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)

var _parent_ref: WeakRef
var _surface_ref: WeakRef
var _disposed: bool = false
var _dirty_flags: int = DIRTY_ALL
var _measured_size: Vector2 = Vector2.ZERO
var _layout_rect: Rect2 = Rect2()


static func is_valid_dimension(value: float) -> bool:
	return is_finite(value) and (value == -1.0 or value >= 0.0)


func get_parent() -> EstragonContainer:
	return _parent_ref.get_ref() as EstragonContainer if _parent_ref != null else null


func is_disposed() -> bool:
	return _disposed


func get_dirty_flags() -> int:
	return _dirty_flags


func get_layout_rect() -> Rect2:
	return _layout_rect


func measure() -> Vector2:
	if _disposed:
		return Vector2.ZERO
	var natural := _measure_content()
	_measured_size = Vector2(width if width >= 0 else natural.x,
		height if height >= 0 else natural.y)
	return _measured_size


func _measure_content() -> Vector2:
	return Vector2.ZERO


## Geometry is local to the parent. Called by layout/surface, not a Godot GUI.
func arrange(rect: Rect2) -> void:
	if _disposed:
		return
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x < 0 or rect.size.y < 0:
		push_error("Estragon: arranged geometry must be finite with nonnegative size")
		return
	_layout_rect = rect
	_arrange_children()
	clear_invalidations(DIRTY_LAYOUT)


func _arrange_children() -> void:
	pass


func _resolve_size(available: Vector2) -> Vector2:
	return Vector2(width if width >= 0 else (available.x if fill_width else _measured_size.x),
		height if height >= 0 else (available.y if fill_height else _measured_size.y))


func append_paint(_list: EstragonPaintList, _origin: Vector2 = Vector2.ZERO) -> void:
	clear_invalidations(DIRTY_TREE | DIRTY_PAINT)


func invalidate(flags: int = DIRTY_ALL) -> void:
	if _disposed:
		return
	flags &= DIRTY_ALL
	_dirty_flags |= flags
	if flags == 0:
		return
	var parent := get_parent()
	if parent != null:
		parent.invalidate(flags)
	else:
		_invalidated.emit()


func clear_invalidations(flags: int = DIRTY_ALL) -> void:
	_dirty_flags &= ~flags


## Internal only. Framework owners unmount/dispose; application code never must.
func _dispose() -> void:
	if _disposed:
		return
	_cancel_pointer()
	_disposed = true
	var parent := get_parent()
	if parent != null:
		parent._detach_child(self)
	_dispose_owned_resources()
	_dirty_flags = 0


func _dispose_owned_resources() -> void:
	# External references may retain terminal components. Release connected
	# Callables now, including closures capturing application objects.
	# A live source may reference a retained terminal component's method.
	for connection in get_incoming_connections():
		# Index the keyword key explicitly; `.signal` fails parsing on Godot 4.0.
		var source_signal: Signal = connection["signal"]
		if source_signal.is_connected(connection.callable):
			source_signal.disconnect(connection.callable)
	for entry in get_signal_list():
		for connection in get_signal_connection_list(entry.name):
			disconnect(entry.name, connection.callable)


func _set_parent(parent: EstragonContainer) -> void:
	_cancel_pointer()
	_parent_ref = weakref(parent) if parent != null else null


func get_surface() -> EstragonSurface:
	var ancestor: EstragonDisplayObject = self
	while ancestor != null:
		if ancestor._surface_ref != null:
			return ancestor._surface_ref.get_ref() as EstragonSurface
		ancestor = ancestor.get_parent()
	return null


func get_surface_rect() -> Rect2:
	var position := _layout_rect.position
	var ancestor := get_parent()
	while ancestor != null:
		position += ancestor.get_layout_rect().position
		ancestor = ancestor.get_parent()
	return Rect2(position, _layout_rect.size)


## Input coordinates are relative to the parent, just like arranged geometry.
## Noninteractive decoration passes through. No clipping is implied by parents.
func hit_test(_position: Vector2) -> EstragonDisplayObject:
	return null


func _cancel_pointer() -> void:
	var surface := get_surface()
	if surface != null:
		surface._pointer.cancel_subtree(self)
