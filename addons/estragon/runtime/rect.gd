class_name EstragonRect
extends EstragonDisplayObject

var fill: Color = Color.WHITE:
	set(value):
		if not _disposed and fill != value:
			fill = value
			invalidate(DIRTY_PAINT)


func append_paint(list: EstragonPaintList, origin: Vector2 = Vector2.ZERO) -> void:
	if not is_disposed() and _layout_rect.has_area():
		list.add_rect(Rect2(origin + _layout_rect.position, _layout_rect.size), fill)
	super.append_paint(list, origin)
