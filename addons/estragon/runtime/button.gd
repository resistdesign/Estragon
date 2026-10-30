class_name EstragonButton
extends EstragonText
## Primary-pointer activation, emitted once on release over the captured button.

signal pressed

enum VisualState { NORMAL, HOVER, DOWN, DISABLED }

const PADDING := Vector2(14, 8)
const NORMAL_COLOR := Color("514174")
const HOVER_COLOR := Color("705a9e")
const DOWN_COLOR := Color("302440")
const DISABLED_COLOR := Color("38343f")

var disabled: bool = false:
	set(value):
		if not _disposed and disabled != value:
			disabled = value
			_cancel_pointer()
			_set_pointer_state(false, false)
			invalidate(DIRTY_PAINT)

var _hovered: bool = false
var _held: bool = false


func get_visual_state() -> VisualState:
	if disabled:
		return VisualState.DISABLED
	if _held and _hovered:
		return VisualState.DOWN
	return VisualState.HOVER if _hovered else VisualState.NORMAL


func get_background_color() -> Color:
	match get_visual_state():
		VisualState.HOVER: return HOVER_COLOR
		VisualState.DOWN: return DOWN_COLOR
		VisualState.DISABLED: return DISABLED_COLOR
	return NORMAL_COLOR


func _measure_content() -> Vector2:
	return super._measure_content() + PADDING * 2


func hit_test(position: Vector2) -> EstragonDisplayObject:
	# Disabled buttons still occlude lower buttons but cannot activate.
	return self if not is_disposed() and _layout_rect.has_point(position) else null


func append_paint(list: EstragonPaintList, origin: Vector2 = Vector2.ZERO) -> void:
	if not is_disposed() and _layout_rect.has_area():
		list.add_rect(Rect2(origin + _layout_rect.position, _layout_rect.size), get_background_color())
		var label_size := super._measure_content()
		var offset := (_layout_rect.size - label_size) / 2
		offset = Vector2(maxf(offset.x, 0.0), maxf(offset.y, 0.0))
		_append_text(list, origin + _layout_rect.position + offset, color * Color(1, 1, 1, 0.5) if disabled else color)
	clear_invalidations(DIRTY_TREE | DIRTY_PAINT)


func _set_pointer_state(hovered: bool, held: bool) -> void:
	if not _disposed and (_hovered != hovered or _held != held):
		_hovered = hovered
		_held = held
		invalidate(DIRTY_PAINT)


func _dispose_owned_resources() -> void:
	_hovered = false
	_held = false
	super._dispose_owned_resources()
