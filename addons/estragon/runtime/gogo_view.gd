extends Node
## Minimal prototype host. No Godot Control nodes or per-component Nodes.
##
## Stage 0 deliberately renders a tiny absolute-positioned subset of the Gogo
## IR through the low-level RenderingServer canvas API. Future renderers will
## implement a common backend interface and draw a display list.

@export_file("*.json") var document_path := "res://examples/hello/generated/Main.gogo.json"

var _canvas_item: RID


func _ready() -> void:
    # Attach one server-side canvas item directly to the viewport's 2D canvas.
    # We deliberately do not instantiate any Control/CanvasItem/Node2D widgets.
    _canvas_item = RenderingServer.canvas_item_create()
    RenderingServer.canvas_item_set_parent(
        _canvas_item, get_viewport().find_world_2d().canvas
    )
    render_document()


func _exit_tree() -> void:
    if _canvas_item.is_valid():
        RenderingServer.free_rid(_canvas_item)


func render_document() -> void:
    var file := FileAccess.open(document_path, FileAccess.READ)
    if file == null:
        push_error("Estragon: unable to open %s (error %s)" % [
            document_path, FileAccess.get_open_error()
        ])
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Estragon: expected JSON object in %s" % document_path)
        return

    var document: Dictionary = parsed
    if document.get("format") != "estragon.gogo.ir" or document.get("version") != 1:
        push_error("Estragon: unsupported Gogo IR format/version")
        return

    var root: Variant = document.get("root")
    if not (root is Dictionary):
        push_error("Estragon: IR has no root object")
        return

    RenderingServer.canvas_item_clear(_canvas_item)
    _render_node(root)


func _render_node(element: Dictionary) -> void:
    match str(element.get("type", "")):
        "View":
            pass
        "Rect":
            var props: Dictionary = element.get("props", {})
            RenderingServer.canvas_item_add_rect(
                _canvas_item,
                Rect2(
                    float(props.get("x", 0)),
                    float(props.get("y", 0)),
                    float(props.get("width", 0)),
                    float(props.get("height", 0))
                ),
                Color.html(str(props.get("fill", "#ffffffff")))
            )
        _:
            push_error("Estragon: unsupported IR component: %s" % element.get("type"))

    var children: Array = element.get("children", [])
    for child in children:
        if child is Dictionary:
            _render_node(child)
