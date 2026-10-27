extends SceneTree

var _failed: bool = false
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Hybrid Gogo test: " + message)


func _run() -> void:
	var scene := load("res://examples/mixed/Mixed.tscn") as PackedScene
	var surface := scene.instantiate() as EstragonSurface
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 240)
	root.add_child(viewport)
	viewport.add_child(surface)
	await process_frame
	_check(surface.get_child_count() == 0, "one surface without per-component Nodes")
	var column := surface.get_root() as EstragonVBox
	var header := column.get_children()[0] as EstragonRect
	var row := column.get_children()[1] as EstragonHBox
	var sidebar := row.get_children()[0] as EstragonRect
	var content := row.get_children()[1] as EstragonRect
	_check(surface.get("constructions") == 1, "component-valued helper evaluated exactly once")
	_check(column.gap == 12 and header.height == 56, "member/local expressions use GDScript values")
	_check(sidebar.width == 120 and sidebar.fill == Color("30c9b0"), "typed helper arguments and return component")
	_check(content.get_layout_rect() == Rect2(132, 0, 268, 172), "nested markup layout")
	_check(surface.get("DESCRIPTION") == "<Rect> is not markup inside a string", "authored string retained")
	viewport.size = Vector2i(600, 320)
	await process_frame
	_check(content.get_layout_rect().size == Vector2(468, 252), "normal surface resize works")
	surface.set("sidebar_width", 60.0)
	_check(sidebar.width == 120, "construction expressions are not reactive bindings")
	surface.call("rebuild")
	await process_frame
	_check(column.is_disposed() and content.is_disposed(), "explicit rebuild owns old root cleanup")
	column = surface.get_root() as EstragonVBox
	_check(column.gap == 6, "authored comparison/conditional control flow preserved")
	row = column.get_children()[1] as EstragonHBox
	sidebar = row.get_children()[0] as EstragonRect
	_check(sidebar.width == 60 and surface.get("constructions") == 2, "rebuild evaluates new values once")
	var backend := surface._renderer
	surface.free()
	_check(column.is_disposed() and sidebar.is_disposed() and not backend._canvas_item.is_valid(), "automatic hybrid lifecycle")
	var edges_script := load("res://tests/godot/generated/HybridEdges.gd") as Script
	var edges: RefCounted = edges_script.new()
	var initial: EstragonRect = edges.get("initial")
	_check(initial.width == 2, "markup in a typed member initializer")
	var edge_tree: EstragonVBox = edges.call("build")
	var edge_children := edge_tree.get_children()
	_check(edges.get("events") == [1, 2, 3], "dynamic arguments evaluate once in source traversal order")
	_check(edge_children.size() == 4, "nested markup inside a braced child")
	_check(edge_children[0].width == 4.0, "GDScript integer division semantics, not JavaScript division")
	_check(edge_children[0].height == 5 and edge_children[0].fill_width, "dictionary and multiline comparison expressions")
	_check(edge_children[1].width == 7 and edge_children[2].width == 1 and edge_children[3].width == 4, "helper/lambda/nested-expression children")
	_check(edges.get("MULTILINE").contains("# <HBox>") and edges.get("RAW").contains("<Rect>"), "triple and raw strings remain literal")
	_check(edges.call("_gogo_build_0") == 99, "authored helper-like name not overwritten")
	_check(edges.call("continued_comparison"), "continued less-than comparison not markup")
	var loop_tree: EstragonHBox = edges.call("loop_children")
	_check(loop_tree.get_child_count() == 2 and loop_tree.get_children()[1].width == 2, "for loop and inferred component variable preserved")
	var edge_surface := EstragonSurface.new()
	viewport.add_child(edge_surface)
	edge_surface.set_root(edge_tree)
	await process_frame
	_check(edge_tree.get_layout_rect().size == Vector2(600, 320), "RefCounted helper-produced tree mounts on a surface")
	edge_surface.set_root(loop_tree)
	_check(edge_tree.is_disposed(), "replacing helper-produced tree owns cleanup")
	var conditional: EstragonVBox = edges.call("conditional_child", true)
	edge_surface.set_root(conditional)
	_check(edges.get("events") == [1, 2, 3, 8], "GDScript conditional child evaluates only chosen branch")
	var alternate: EstragonVBox = edges.call("conditional_child", false)
	edge_surface.set_root(alternate)
	_check(conditional.is_disposed() and alternate.get_children()[0].width == 9, "conditional alternative and ownership transfer")
	var static_panel: EstragonRect = edges_script.call("static_panel")
	edge_surface.set_root(static_panel)
	_check(static_panel.width == 3 and alternate.is_disposed(), "markup inside authored static function")
	edge_surface.set_root(initial)
	_check(static_panel.is_disposed(), "member-created component mounts with framework ownership")
	edge_surface.free()
	_check(initial.is_disposed() and loop_tree.is_disposed() and static_panel.is_disposed(), "helper-produced replacement cleanup automatic")
	viewport.free()
	await process_frame
	print("Hybrid Gogo checks: %d" % _checks)
	if _failed:
		quit(1)
	else:
		print("ESTRAGON_HYBRID_GOGO_OK")
		quit(0)
