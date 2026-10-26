class_name EstragonStack
extends EstragonContainer
## Shared stack algorithm. VBox/HBox fix the orientation.

var gap: float = 0.0:
	set(value):
		if not is_finite(value) or value < 0:
			push_error("Estragon: gap must be finite and nonnegative")
			return
		if not _disposed and gap != value:
			gap = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)

var _axis: int = 1


func _measure_content() -> Vector2:
	var result := Vector2.ZERO
	for child in _children:
		var child_size := child.measure()
		result[_axis] += child_size[_axis]
		result[1 - _axis] = maxf(result[1 - _axis], child_size[1 - _axis])
	result[_axis] += gap * maxi(0, _children.size() - 1)
	return result


func _arrange_children() -> void:
	var available := _layout_rect.size
	var fixed := gap * maxi(0, _children.size() - 1)
	var flexible: int = 0
	for child in _children:
		if _fills_main_axis(child):
			flexible += 1
		else:
			fixed += child._measured_size[_axis]
	var share := maxf(0, available[_axis] - fixed) / maxi(1, flexible)
	var cursor := Vector2.ZERO
	for child in _children:
		var size := child._resolve_size(available)
		if _fills_main_axis(child):
			size[_axis] = share
		child.arrange(Rect2(cursor, size))
		cursor[_axis] += size[_axis] + gap


func _fills_main_axis(child: EstragonDisplayObject) -> bool:
	return (child.width < 0 and child.fill_width) if _axis == 0 else (child.height < 0 and child.fill_height)
