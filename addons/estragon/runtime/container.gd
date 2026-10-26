class_name EstragonContainer
extends EstragonDisplayObject
## Ordered, strongly owned logical children; parent links are weak.

var _children: Array[EstragonDisplayObject] = []


func get_child_count() -> int:
	return _children.size()


## Return a snapshot, so callers cannot mutate membership through the array.
func get_children() -> Array[EstragonDisplayObject]:
	return _children.duplicate()


## Append or reparent atomically after validation. Same-parent adds are errors,
## not implicit reorders. Removal preserves the child's lifetime and state.
func add_child(child: EstragonDisplayObject) -> Error:
	if is_disposed():
		return ERR_UNAVAILABLE
	if child == null or child.is_disposed():
		return ERR_INVALID_PARAMETER
	if child.get_parent() == self:
		return ERR_ALREADY_EXISTS
	var ancestor: EstragonDisplayObject = self
	while ancestor != null:
		if ancestor == child:
			return ERR_INVALID_PARAMETER
		ancestor = ancestor.get_parent()
	var previous_parent := child.get_parent()
	if previous_parent != null:
		# A cleanup hook cannot rescue a sibling from a disposing owner.
		if previous_parent.is_disposed():
			return ERR_UNAVAILABLE
		previous_parent.remove_child(child)
	_children.append(child)
	child._set_parent(self)
	child.invalidate(DIRTY_ALL)
	return OK


func remove_child(child: EstragonDisplayObject) -> Error:
	if is_disposed():
		return ERR_UNAVAILABLE
	if child == null:
		return ERR_INVALID_PARAMETER
	var index := _children.find(child)
	if index < 0:
		return ERR_DOES_NOT_EXIST
	_children.remove_at(index)
	child._set_parent(null)
	child.invalidate(DIRTY_ALL)
	invalidate(DIRTY_ALL)
	return OK


func _dispose_owned_resources() -> void:
	# Release the list before callbacks; pending children keep their parent link
	# until their turn, preventing adoption out of a disposing owner.
	var owned := _children
	_children = []
	for child in owned:
		child._set_parent(null)
		child.dispose()
