class_name EstragonPaintList
extends RefCounted
## In-memory paint boundary: absolute surface coordinates, ordered rectangle/text commands.
## This is not a serialized UI format or a component tree.

class FillRect extends RefCounted:
	var rect: Rect2
	var color: Color

	func _init(bounds: Rect2, fill: Color) -> void:
		rect = bounds
		color = fill

class TextRun extends RefCounted:
	var position: Vector2
	var text: String
	var font: Font
	var font_size: int
	var color: Color

	func _init(baseline: Vector2, value: String, face: Font, size: int, tint: Color) -> void:
		position = baseline
		text = value
		font = face
		font_size = size
		color = tint

# Ordered mixed commands are authoritative; rectangles remains an inspection view.
var commands: Array[RefCounted] = []
var rectangles: Array[FillRect] = []


func add_rect(bounds: Rect2, fill: Color) -> void:
	var command := FillRect.new(bounds, fill)
	commands.append(command)
	rectangles.append(command)


func add_text(baseline: Vector2, value: String, face: Font, size: int, tint: Color) -> void:
	commands.append(TextRun.new(baseline, value, face, size, tint))
