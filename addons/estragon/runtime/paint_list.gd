class_name EstragonPaintList
extends RefCounted
## In-memory paint boundary: absolute surface coordinates, ordered rectangles.
## This is not a serialized UI format or a component tree.

class FillRect extends RefCounted:
	var rect: Rect2
	var color: Color

	func _init(bounds: Rect2, fill: Color) -> void:
		rect = bounds
		color = fill

var rectangles: Array[FillRect] = []


func add_rect(bounds: Rect2, fill: Color) -> void:
	rectangles.append(FillRect.new(bounds, fill))
