class_name EstragonContainer
extends EstragonDisplayObject
## Ordered ownership; plain containers overlay children at the local origin.

var _children: Array[EstragonDisplayObject] = []


func get_child_count() -> int:
	return _children.size()


func get_children() -> Array[EstragonDisplayObject]:
	return _children.duplicate()


func _can_adopt(child: EstragonDisplayObject) -> Error:
	if is_disposed():
		return ERR_UNAVAILABLE
	if child == null or child.is_disposed():
		return ERR_INVALID_PARAMETER
	if child._surface_ref != null and child._surface_ref.get_ref() != null:
		return ERR_ALREADY_IN_USE
	if child.get_parent() == self:
		return ERR_ALREADY_EXISTS
	var ancestor: EstragonDisplayObject = self
	while ancestor != null:
		if ancestor == child:
			return ERR_INVALID_PARAMETER
		ancestor = ancestor.get_parent()
	var previous_parent := child.get_parent()
	while previous_parent != null:
		if previous_parent.is_disposed():
			return ERR_UNAVAILABLE
		previous_parent = previous_parent.get_parent()
	return OK


## Move existing children directly here; never remove first to reparent.
func add_child(child: EstragonDisplayObject) -> Error:
	var error := _can_adopt(child)
	if error != OK:
		return error
	var previous_parent := child.get_parent()
	if previous_parent != null:
		previous_parent._detach_child(child)
	_children.append(child)
	child._set_parent(self)
	child.invalidate(DIRTY_ALL)
	return OK


## Removal is unmount: cleanup is automatic even with external references.
func remove_child(child: EstragonDisplayObject) -> Error:
	if is_disposed():
		return ERR_UNAVAILABLE
	if child == null:
		return ERR_INVALID_PARAMETER
	if not _children.has(child):
		return ERR_DOES_NOT_EXIST
	_detach_child(child)
	child._dispose()
	return OK


func replace_child(previous: EstragonDisplayObject, replacement: EstragonDisplayObject) -> Error:
	if is_disposed():
		return ERR_UNAVAILABLE
	var index := _children.find(previous)
	if index < 0:
		return ERR_DOES_NOT_EXIST
	if previous == replacement:
		return OK
	var error := add_child(replacement)
	if error != OK:
		return error
	_children.erase(replacement)
	_children.insert(index, replacement)
	return remove_child(previous)


## Internal detach transfers ownership without running cleanup hooks.
func _detach_child(child: EstragonDisplayObject) -> void:
	_children.erase(child)
	child._set_parent(null)
	invalidate(DIRTY_ALL)


func _measure_content() -> Vector2:
	var result := Vector2.ZERO
	for child in _children:
		result = result.max(child.measure())
	return result


func _arrange_children() -> void:
	for child in _children:
		child.arrange(Rect2(Vector2.ZERO, child._resolve_size(_layout_rect.size)))


func append_paint(list: EstragonPaintList, origin: Vector2 = Vector2.ZERO) -> void:
	for child in _children:
		child.append_paint(list, origin + _layout_rect.position)
	super.append_paint(list, origin)


func _dispose_owned_resources() -> void:
	var owned := _children
	_children = []
	for child in owned:
		child._set_parent(null)
		child._dispose()
