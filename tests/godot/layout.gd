extends SceneTree
## Deterministic geometry, paint boundary and automatic owner cleanup tests.

var _checks: int = 0
var _failed: bool = false


class CleanupRect extends EstragonRect:
	var cleanups: int = 0
	var rescue: EstragonDisplayObject
	var destination: EstragonContainer
	var rescue_result: Error = OK

	func _dispose_owned_resources() -> void:
		cleanups += 1
		if rescue != null:
			rescue_result = destination.add_child(rescue)


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Layout test: " + message)


func _rect(width: float, height: float) -> EstragonRect:
	var result := EstragonRect.new()
	result.width = width
	result.height = height
	return result


func _test_geometry() -> void:
	var column := EstragonVBox.new()
	column.gap = 4.5
	var row := EstragonHBox.new()
	row.gap = 3
	var a := _rect(10, 20)
	var b := _rect(30, 8)
	row.add_child(a)
	row.add_child(b)
	var c := _rect(12, 5)
	column.add_child(row)
	column.add_child(c)
	_check(column.measure() == Vector2(43, 29.5), "nested intrinsic measurement")
	column.arrange(Rect2(7, 9, 100, 80))
	_check(row.get_layout_rect() == Rect2(0, 0, 43, 20), "nested local row geometry")
	_check(b.get_layout_rect() == Rect2(13, 0, 30, 8), "horizontal spacing")
	_check(c.get_layout_rect() == Rect2(0, 24.5, 12, 5), "vertical fractional spacing")
	var paint := EstragonPaintList.new()
	column.append_paint(paint)
	_check(paint.rectangles.size() == 3, "one paint command per nonempty rectangle")
	_check(paint.rectangles[0].rect == Rect2(7, 9, 10, 20), "absolute paint origin")
	_check(paint.rectangles[1].rect == Rect2(20, 9, 30, 8), "nested paint offset")
	_check(paint.rectangles[2].rect == Rect2(7, 33.5, 12, 5), "paint order and vertical offset")
	row.fill_width = true
	b.width = -1
	b.fill_width = true
	b.height = -1
	b.fill_height = true
	column.measure()
	column.arrange(Rect2(0, 0, 100, 80))
	_check(b.get_layout_rect() == Rect2(13, 0, 87, 20), "fill consumes main-axis remainder and cross space")
	var d := _rect(-1, 4)
	d.fill_width = true
	row.add_child(d)
	column.measure()
	column.arrange(Rect2(0, 0, 100, 80))
	_check(b.get_layout_rect().size.x == 42 and d.get_layout_rect().position.x == 58, "fill siblings share remaining space equally")
	column.arrange(Rect2(0, 0, 5, 0))
	_check(a.get_layout_rect().size.x == 10 and b.get_layout_rect().size.x == 0, "overflow preserves fixed sizes and clamps fill to zero")
	var empty := EstragonHBox.new()
	empty.gap = 99
	_check(empty.measure() == Vector2.ZERO, "empty stack has no phantom gap")
	var overlay := EstragonContainer.new()
	overlay.add_child(_rect(12, 8))
	var fill := _rect(-1, -1)
	fill.fill_width = true
	fill.fill_height = true
	overlay.add_child(fill)
	_check(overlay.measure() == Vector2(12, 8), "base container overlay measurement")
	overlay.arrange(Rect2(0, 0, 40, 30))
	_check(fill.get_layout_rect() == Rect2(0, 0, 40, 30), "overlay allocation")
	var zero := _rect(0, 0)
	zero.measure()
	zero.arrange(Rect2(0, 0, 0, 0))
	paint = EstragonPaintList.new()
	zero.append_paint(paint)
	_check(paint.rectangles.is_empty(), "zero-area rectangles omitted")
	_check(not EstragonDisplayObject.is_valid_dimension(NAN), "NaN dimensions rejected")
	_check(not EstragonDisplayObject.is_valid_dimension(INF), "infinite dimensions rejected")
	_check(not EstragonDisplayObject.is_valid_dimension(-2), "negative dimensions other than auto rejected")
	_check(EstragonDisplayObject.is_valid_dimension(0), "zero size is legal")


func _test_automatic_cleanup() -> void:
	var owner := EstragonContainer.new()
	var other := EstragonContainer.new()
	var branch := EstragonContainer.new()
	var leaf := CleanupRect.new()
	branch.add_child(leaf)
	owner.add_child(branch)
	var identity := leaf.get_instance_id()
	_check(other.add_child(branch) == OK, "reparent subtree")
	_check(not leaf.is_disposed() and leaf.cleanups == 0, "moving components skips cleanup")
	_check(leaf.get_instance_id() == identity, "moving retains identity")
	_check(owner.get_child_count() == 0 and branch.get_parent() == other, "reparent preserves consistent owners")
	other.remove_child(branch)
	_check(branch.is_disposed() and leaf.is_disposed(), "removing branch automatically unmounts descendants")
	_check(leaf.cleanups == 1, "automatic cleanup exactly once with external reference")
	_check(other.remove_child(branch) == ERR_DOES_NOT_EXIST and leaf.cleanups == 1, "repeat removal does not repeat cleanup")
	var old := CleanupRect.new()
	var replacement := CleanupRect.new()
	owner.add_child(old)
	owner.add_child(_rect(1, 1))
	_check(owner.replace_child(old, replacement) == OK, "replace child")
	_check(old.cleanups == 1 and replacement.cleanups == 0, "replacement cleans old only")
	_check(owner.get_children()[0] == replacement, "replacement retains slot")
	_check(owner.replace_child(replacement, replacement) == OK and not replacement.is_disposed(), "same-child replacement no-op")
	_check(owner.replace_child(replacement, null) == ERR_INVALID_PARAMETER and not replacement.is_disposed(), "invalid replacement is atomic")
	var old_branch := EstragonContainer.new()
	var retained := CleanupRect.new()
	old_branch.add_child(retained)
	owner.add_child(old_branch)
	_check(owner.replace_child(old_branch, retained) == OK, "replacement may transfer descendant before cleanup")
	_check(old_branch.is_disposed() and retained.cleanups == 0, "transferred descendant survives replacement")
	var disposing := EstragonContainer.new()
	var cleanup_hook := CleanupRect.new()
	var pending_branch := EstragonContainer.new()
	var pending_leaf := CleanupRect.new()
	pending_branch.add_child(pending_leaf)
	disposing.add_child(cleanup_hook)
	disposing.add_child(pending_branch)
	cleanup_hook.rescue = pending_leaf
	cleanup_hook.destination = other
	owner.add_child(disposing)
	owner.remove_child(disposing)
	_check(cleanup_hook.rescue_result == ERR_UNAVAILABLE, "cleanup cannot adopt from a disposing ancestor")
	_check(pending_leaf.cleanups == 1 and other.get_child_count() == 0, "pending descendant cleanup remains owned")
	var surface := EstragonSurface.new()
	surface.set_root(owner)
	var new_root := CleanupRect.new()
	_check(surface.set_root(new_root) == OK, "replace surface root before entering tree")
	_check(owner.is_disposed() and replacement.cleanups == 1, "root replacement recursively cleans old tree")
	_check(not owner._invalidated.is_connected(surface._request_update), "old root subscription removed")
	_check(surface.set_root(new_root) == OK and new_root.cleanups == 0, "same surface root no-op")
	var competitor := EstragonSurface.new()
	_check(competitor.set_root(new_root) == ERR_ALREADY_IN_USE, "root cannot belong to two surfaces")
	_check(other.add_child(new_root) == ERR_ALREADY_IN_USE, "mounted root cannot also become a child")
	surface.free()
	_check(new_root.cleanups == 1, "freeing never-entered surface still cleans root")
	competitor.free()


func _run() -> void:
	_test_geometry()
	_test_automatic_cleanup()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 200)
	root.add_child(viewport)
	var surface := EstragonSurface.new()
	var column := EstragonVBox.new()
	column.gap = 10
	var header := _rect(-1, 20)
	header.fill_width = true
	var row := EstragonHBox.new()
	row.fill_width = true
	row.fill_height = true
	row.gap = 5
	var sidebar := _rect(50, -1)
	sidebar.fill_height = true
	var body := CleanupRect.new()
	body.fill_width = true
	body.fill_height = true
	row.add_child(sidebar)
	row.add_child(body)
	column.add_child(header)
	column.add_child(row)
	surface.set_root(column)
	viewport.add_child(surface)
	await process_frame
	_check(surface.get_child_count() == 0, "one surface host without component nodes")
	_check(surface._renderer._canvas_item.is_valid(), "surface allocates one canvas item")
	_check(body.get_layout_rect() == Rect2(55, 0, 245, 170), "initial viewport-driven nested layout")
	_check(column.get_dirty_flags() == 0 and body.get_dirty_flags() == 0, "layout/paint acknowledge dirty state")
	viewport.size = Vector2i(500, 260)
	await process_frame
	_check(body.get_layout_rect() == Rect2(55, 0, 445, 230), "viewport size signal recalculates automatically")
	body.width = 70
	await process_frame
	_check(body.get_layout_rect().size.x == 70, "explicit width overrides fill automatically")
	header.height = 30
	row.gap = 9
	await process_frame
	_check(body.get_layout_rect() == Rect2(59, 0, 70, 220), "size/gap setters invalidate automatic layout")
	body.fill = Color("663399")
	_check(column.get_dirty_flags() == EstragonDisplayObject.DIRTY_PAINT, "fill invalidates paint only")
	await process_frame
	_check(column.get_dirty_flags() == 0, "deferred repaint acknowledges paint")
	var list := EstragonPaintList.new()
	column.append_paint(list)
	_check(list.rectangles.size() == 3 and list.rectangles[2].color == Color("663399"), "typed paint list matches component color/order")
	_check(list.rectangles[2].rect == Rect2(59, 40, 70, 220), "render commands use surface coordinates")
	var renderer := surface._renderer
	var previous_rid := renderer._canvas_item
	var replacement := CleanupRect.new()
	surface.set_root(replacement)
	_check(body.cleanups == 1 and column.is_disposed(), "mounted root replacement cleans recursively")
	_check(renderer._canvas_item == previous_rid, "root replacement reuses surface canvas item")
	await process_frame
	viewport.remove_child(surface)
	_check(replacement.cleanups == 1 and surface.get_root() == null, "surface tree exit automatically unmounts root")
	_check(not renderer._canvas_item.is_valid(), "surface exit releases/reset canvas handle")
	_check(not viewport.size_changed.is_connected(surface._resized), "viewport subscription disconnected")
	viewport.add_child(surface)
	var reentered := CleanupRect.new()
	_check(surface.set_root(reentered) == OK, "surface can host a new root after re-entry")
	await process_frame
	_check(renderer._canvas_item.is_valid(), "re-entry reopens surface canvas")
	_check(surface.set_root(null) == OK and reentered.cleanups == 1, "explicit root unmount cleans automatically")
	var final_root := EstragonContainer.new()
	var moved := CleanupRect.new()
	final_root.add_child(moved)
	surface.set_root(final_root)
	var other_surface := EstragonSurface.new()
	var destination := EstragonContainer.new()
	other_surface.set_root(destination)
	viewport.add_child(other_surface)
	_check(destination.add_child(moved) == OK and moved.cleanups == 0, "cross-surface move does not dispose")
	surface.free()
	_check(replacement.cleanups == 1 and moved.cleanups == 0, "old surface destruction preserves transferred child")
	moved.width = 10
	other_surface.free()
	_check(moved.cleanups == 1, "new surface owns transferred cleanup even with queued work")
	viewport.free()
	await process_frame
	print("Layout checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_LAYOUT_OK")
		quit(0)
