class_name EstragonCanvasRenderer
extends RefCounted
## RenderingServer adapter. One canvas item per UI surface, none per component.

var _canvas_item: RID


func open(canvas: RID) -> void:
	close()
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, canvas)


func render(list: EstragonPaintList) -> void:
	if not _canvas_item.is_valid():
		return
	RenderingServer.canvas_item_clear(_canvas_item)
	for command in list.rectangles:
		RenderingServer.canvas_item_add_rect(_canvas_item, command.rect, command.color)


func close() -> void:
	if _canvas_item.is_valid():
		RenderingServer.free_rid(_canvas_item)
		_canvas_item = RID()
