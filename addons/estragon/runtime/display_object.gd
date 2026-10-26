class_name EstragonDisplayObject
extends RefCounted
## Logical component foundation. No scene-tree or rendering resources.
## Use get_instance_id() for identity during this object's lifetime.

const DIRTY_TREE: int = 1
const DIRTY_LAYOUT: int = 2
const DIRTY_PAINT: int = 4
const DIRTY_ALL: int = DIRTY_TREE | DIRTY_LAYOUT | DIRTY_PAINT

var _parent_ref: WeakRef
var _disposed: bool = false
var _dirty_flags: int = DIRTY_ALL


func get_parent() -> EstragonContainer:
	if _parent_ref == null:
		return null
	return _parent_ref.get_ref() as EstragonContainer


func is_disposed() -> bool:
	return _disposed


func get_dirty_flags() -> int:
	return _dirty_flags


## Invalidations propagate even if already dirty: an ancestor may have cleared
## its own flags since the previous invalidation. No scheduler/polling is implied.
func invalidate(flags: int = DIRTY_ALL) -> void:
	if _disposed:
		return
	flags &= DIRTY_ALL
	_dirty_flags |= flags
	var parent := get_parent()
	if parent != null and flags != 0:
		parent.invalidate(flags)


## Acknowledge local work only; descendants keep their own outstanding flags.
func clear_invalidations(flags: int = DIRTY_ALL) -> void:
	_dirty_flags &= ~flags


## Terminal, idempotent cleanup. Retained external references remain disposed.
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	var parent := get_parent()
	if parent != null:
		parent.remove_child(self)
	_dispose_owned_resources()
	_dirty_flags = 0


## Internal extension point. Subclasses release owned resources here, and must
## not reattach this object. Containers implement recursive descendant cleanup.
func _dispose_owned_resources() -> void:
	pass


## Internal: only containers change membership; never assign this directly.
func _set_parent(parent: EstragonContainer) -> void:
	_parent_ref = weakref(parent) if parent != null else null
