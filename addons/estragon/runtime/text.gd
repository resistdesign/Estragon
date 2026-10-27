class_name EstragonText
extends EstragonDisplayObject
## Plain explicit-line text. No wrapping, clipping, rich text or widget theme.

var text: String = "":
	set(value):
		if not _disposed and text != value:
			text = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var _font: Font = ThemeDB.fallback_font
var font: Font:
	get:
		return _font
	set(value):
		if value == null:
			push_error("Estragon: font must not be null")
			return
		if not _disposed:
			_font = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var font_size: int = 20:
	set(value):
		if value <= 0:
			push_error("Estragon: font_size must be positive")
			return
		if not _disposed and font_size != value:
			font_size = value
			invalidate(DIRTY_LAYOUT | DIRTY_PAINT)
var color: Color = Color.WHITE:
	set(value):
		if not _disposed and color != value:
			color = value
			invalidate(DIRTY_PAINT)


func _measure_content() -> Vector2:
	var size := Vector2.ZERO
	for line in text.split("\n"):
		size.x = maxf(size.x, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		size.y += font.get_height(font_size)
	return size


func _append_text(list: EstragonPaintList, position: Vector2, tint: Color) -> void:
	for line in text.split("\n"):
		if not line.is_empty():
			list.add_text(position + Vector2(0, font.get_ascent(font_size)), line, font, font_size, tint)
		position.y += font.get_height(font_size)


func append_paint(list: EstragonPaintList, origin: Vector2 = Vector2.ZERO) -> void:
	if not is_disposed() and _layout_rect.has_area():
		_append_text(list, origin + _layout_rect.position, color)
	super.append_paint(list, origin)


func _dispose_owned_resources() -> void:
	_font = null
	super._dispose_owned_resources()
