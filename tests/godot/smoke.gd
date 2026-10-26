extends SceneTree
## Headless lifecycle/API smoke test, not a pixel or GPU rendering assertion.


func _initialize() -> void:
	_run.call_deferred()


func _require(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Estragon smoke: " + message)
		quit(1)
	return condition


func _run() -> void:
	var scene := load("res://examples/hello/Hello.tscn") as PackedScene
	if not _require(scene != null, "Hello.tscn must load"):
		return
	var host := scene.instantiate()
	root.add_child(host)
	await process_frame
	if not _require(host.get_script() == load("res://addons/estragon/runtime/gogo_view.gd"),
			"scene must use the existing Estragon host"):
		host.free()
		return
	if not _require(host.get_child_count() == 0 and not host is Control,
			"demo must retain one host without per-element widgets"):
		host.free()
		return
	var canvas: RID = host.get("_canvas_item")
	if not _require(canvas.is_valid(), "host must allocate its canvas RID on ready"):
		host.free()
		return
	# Exercise redraw and _exit_tree cleanup through the existing prototype.
	host.call("render_document")
	host.free()
	await process_frame
	if not _require(root.get_child_count() == 0, "host must leave the tree on disposal"):
		return
	print("ESTRAGON_SMOKE_OK")
	quit(0)
