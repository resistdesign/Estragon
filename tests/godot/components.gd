extends SceneTree
## Component assertions use ordinary RefCounted objects, without scene nodes.

const DisplayObject = preload("res://addons/estragon/runtime/display_object.gd")
const ComponentContainer = preload("res://addons/estragon/runtime/container.gd")

var _checks: int = 0
var _failed: bool = false


class DisposalProbe extends EstragonDisplayObject:
	var cleanup_count: int = 0
	var sibling_to_adopt: EstragonDisplayObject
	var destination: EstragonContainer
	var adoption_result: Error = OK

	func _dispose_owned_resources() -> void:
		cleanup_count += 1
		if sibling_to_adopt != null:
			adoption_result = destination.add_child(sibling_to_adopt)


class SignalSource extends RefCounted:
	signal changed


class SignalTarget extends EstragonDisplayObject:
	var calls: int = 0

	func receive() -> void:
		calls += 1


func _initialize() -> void:
	_test_membership()
	_test_invalid_operations()
	_test_invalidation()
	_test_disposal()
	_test_incoming_cleanup()
	_test_reference_ownership()
	print("Component checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_COMPONENTS_OK")
		quit(0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		push_error("Component test: " + message)
		_failed = true


func _test_membership() -> void:
	var first := ComponentContainer.new()
	var second := ComponentContainer.new()
	var branch := ComponentContainer.new()
	var leaf := DisplayObject.new()
	var sibling := DisplayObject.new()
	var identity := leaf.get_instance_id()
	var leaf_object: Object = leaf
	var container_object: Object = first
	_check(leaf_object is RefCounted and not leaf_object is Node, "leaf is not a Node")
	_check(container_object is RefCounted and not container_object is Node, "container is not a Node")
	_check(first.get_instance_id() != identity, "instance identities are distinct")
	_check(leaf.get_parent() == null and first.get_child_count() == 0, "initial detachment")
	_check(first.add_child(branch) == OK, "add branch")
	_check(branch.add_child(leaf) == OK, "add nested leaf")
	_check(branch.add_child(sibling) == OK, "append sibling")
	_check(branch.get_children() == [leaf, sibling], "insertion order")
	var snapshot := branch.get_children()
	snapshot.clear()
	_check(branch.get_child_count() == 2, "child list is a snapshot")
	_check(second.add_child(branch) == OK, "reparent subtree")
	_check(first.get_child_count() == 0 and second.get_children() == [branch], "old/new owners")
	_check(branch.get_parent() == second and leaf.get_parent() == branch, "nested parent consistency")
	_check(leaf.get_instance_id() == identity, "reparent preserves identity")
	_check(branch.remove_child(leaf) == OK, "remove leaf")
	_check(leaf.get_parent() == null and leaf.is_disposed(), "removal unmounts automatically")
	_check(first.add_child(leaf) == ERR_INVALID_PARAMETER, "unmounted leaf cannot reattach")
	_check(leaf.get_instance_id() == identity, "unmount preserves identity of external reference")
	first._dispose()
	second._dispose()


func _test_invalid_operations() -> void:
	var root := ComponentContainer.new()
	var nested := ComponentContainer.new()
	var leaf := DisplayObject.new()
	root.add_child(nested)
	nested.add_child(leaf)
	root.clear_invalidations()
	nested.clear_invalidations()
	_check(root.add_child(null) == ERR_INVALID_PARAMETER, "null add rejected")
	_check(root.remove_child(null) == ERR_INVALID_PARAMETER, "null removal rejected")
	_check(root.add_child(root) == ERR_INVALID_PARAMETER, "self cycle rejected")
	_check(nested.add_child(root) == ERR_INVALID_PARAMETER, "ancestor cycle rejected")
	_check(root.add_child(nested) == ERR_ALREADY_EXISTS, "duplicate rejected")
	_check(root.remove_child(leaf) == ERR_DOES_NOT_EXIST, "non-child removal rejected")
	_check(root.get_children() == [nested] and nested.get_children() == [leaf], "failed operations preserve order")
	_check(nested.get_parent() == root and leaf.get_parent() == nested, "failed operations preserve links")
	_check(root.get_dirty_flags() == 0 and nested.get_dirty_flags() == 0, "failed operations do not invalidate")
	var dead := ComponentContainer.new()
	dead._dispose()
	_check(dead.add_child(leaf) == ERR_UNAVAILABLE, "disposed destination rejected")
	_check(leaf.get_parent() == nested, "failed reparent keeps old owner")
	_check(root.add_child(dead) == ERR_INVALID_PARAMETER, "disposed child rejected")
	_check(dead.remove_child(leaf) == ERR_UNAVAILABLE, "disposed removal rejected")
	root._dispose()


func _test_invalidation() -> void:
	var root := ComponentContainer.new()
	var branch := ComponentContainer.new()
	var leaf := DisplayObject.new()
	_check(leaf.get_dirty_flags() == DisplayObject.DIRTY_ALL, "new objects start dirty")
	root.add_child(branch)
	branch.add_child(leaf)
	root.clear_invalidations()
	branch.clear_invalidations()
	leaf.clear_invalidations()
	leaf.invalidate(DisplayObject.DIRTY_PAINT)
	_check(root.get_dirty_flags() == DisplayObject.DIRTY_PAINT, "paint reaches root")
	_check(branch.get_dirty_flags() == DisplayObject.DIRTY_PAINT, "paint reaches parent")
	leaf.invalidate(DisplayObject.DIRTY_LAYOUT)
	_check(leaf.get_dirty_flags() == (DisplayObject.DIRTY_LAYOUT | DisplayObject.DIRTY_PAINT), "flags accumulate")
	root.clear_invalidations(DisplayObject.DIRTY_PAINT)
	_check(root.get_dirty_flags() == DisplayObject.DIRTY_LAYOUT, "selective local clearing")
	leaf.invalidate(DisplayObject.DIRTY_PAINT)
	_check(root.get_dirty_flags() == (DisplayObject.DIRTY_LAYOUT | DisplayObject.DIRTY_PAINT), "repeat invalidation reaches cleared ancestor")
	root.clear_invalidations()
	leaf.invalidate(0)
	leaf.invalidate(8)
	_check(root.get_dirty_flags() == 0, "empty/unknown flags ignored")
	branch.remove_child(leaf)
	_check(root.get_dirty_flags() == DisplayObject.DIRTY_ALL, "removal dirties old ancestors")
	_check(leaf.is_disposed() and leaf.get_dirty_flags() == 0, "unmount cleans removed child")
	var destination := ComponentContainer.new()
	destination.clear_invalidations()
	root.clear_invalidations()
	destination.add_child(branch)
	_check(root.get_dirty_flags() == DisplayObject.DIRTY_ALL, "reparent dirties old parent")
	_check(destination.get_dirty_flags() == DisplayObject.DIRTY_ALL, "reparent dirties destination")
	root.clear_invalidations()
	branch.clear_invalidations()
	leaf.clear_invalidations()
	leaf.invalidate(DisplayObject.DIRTY_PAINT)
	_check(root.get_dirty_flags() == 0 and branch.get_dirty_flags() == 0, "detached invalidation stays local")
	root._dispose()
	destination._dispose()
	leaf._dispose()


func _test_disposal() -> void:
	var root := ComponentContainer.new()
	var branch := ComponentContainer.new()
	var leaf := DisposalProbe.new()
	root.add_child(branch)
	branch.add_child(leaf)
	root.clear_invalidations()
	leaf._dispose()
	leaf._dispose()
	_check(leaf.cleanup_count == 1, "cleanup hook called once")
	_check(leaf.is_disposed() and leaf.get_parent() == null, "disposed leaf is detached")
	_check(branch.get_child_count() == 0, "direct disposal removes membership")
	_check(root.get_dirty_flags() == DisplayObject.DIRTY_ALL, "direct disposal invalidates ancestors")
	var owned := DisposalProbe.new()
	branch.add_child(owned)
	root._dispose()
	root._dispose()
	_check(root.is_disposed() and branch.is_disposed() and owned.is_disposed(), "recursive disposal")
	_check(root.get_child_count() == 0 and branch.get_child_count() == 0, "disposed containers release children")
	_check(branch.get_parent() == null and owned.get_parent() == null, "recursive links cleared")
	_check(owned.cleanup_count == 1, "descendant cleanup once")
	var disposing := ComponentContainer.new()
	var probe := DisposalProbe.new()
	var pending := DisplayObject.new()
	var destination := ComponentContainer.new()
	probe.sibling_to_adopt = pending
	probe.destination = destination
	disposing.add_child(probe)
	disposing.add_child(pending)
	disposing._dispose()
	_check(probe.adoption_result == ERR_UNAVAILABLE, "cleanup cannot adopt pending sibling")
	_check(pending.is_disposed() and pending.get_parent() == null, "pending sibling still disposed")
	_check(destination.get_child_count() == 0, "failed cleanup adoption leaves no stale membership")
	destination._dispose()
	owned.invalidate()
	_check(root.get_dirty_flags() == 0 and owned.get_dirty_flags() == 0, "disposed objects stay clean")


func _test_incoming_cleanup() -> void:
	var source := SignalSource.new()
	var target := SignalTarget.new()
	var owner := ComponentContainer.new()
	var destination := ComponentContainer.new()
	owner.add_child(target)
	source.changed.connect(target.receive)
	source.changed.emit()
	_check(target.calls == 1, "incoming signal invokes live component target")
	var identity := target.get_instance_id()
	destination.add_child(target)
	_check(target.get_instance_id() == identity and not target.is_disposed(), "transfer preserves incoming target identity")
	source.changed.emit()
	_check(target.calls == 2 and source.changed.is_connected(target.receive), "transfer preserves incoming connection")
	destination.remove_child(target)
	_check(target.is_disposed() and not source.changed.is_connected(target.receive), "owner unmount disconnects incoming native signal")
	source.changed.emit()
	_check(target.calls == 2, "live source cannot invoke disposed target")


func _test_reference_ownership() -> void:
	var parent := ComponentContainer.new()
	var child := DisplayObject.new()
	var parent_weak: WeakRef = weakref(parent)
	var child_weak: WeakRef = weakref(child)
	parent.add_child(child)
	child = null
	_check(child_weak.get_ref() != null, "parent strongly retains child")
	parent = null
	_check(parent_weak.get_ref() == null and child_weak.get_ref() == null, "weak parent avoids reference cycle")
	parent = ComponentContainer.new()
	child = DisplayObject.new()
	parent.add_child(child)
	parent = null
	_check(child.get_parent() == null and not child.is_disposed(), "unmounted raw objects remain independent of surface lifetime")
	child._dispose()
	parent = ComponentContainer.new()
	child = DisplayObject.new()
	child_weak = weakref(child)
	parent.add_child(child)
	parent.remove_child(child)
	child = null
	_check(child_weak.get_ref() == null, "removal releases strong ownership")
	parent._dispose()
