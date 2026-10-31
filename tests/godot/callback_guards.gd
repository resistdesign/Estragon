extends SceneTree
## Expected diagnostics are checked exactly by the compatibility collector.
var values: Array = []
var failed := false

func required(value: int) -> void:
	values.append(value)

func optional(value: int = 7) -> void:
	values.append(value)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("CALLBACK_PROBE_ASSERTION " + message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mode := OS.get_cmdline_user_args()[0]
	var module = load("res://tests/godot/generated/SignalEdges.gd").new()
	var callback: Callable
	var target: Object
	match mode:
		"empty": callback = Callable()
		"missing": callback = Callable(self, "missing_method")
		"freed":
			target = Node.new()
			callback = Callable(target, "get_name")
			target.free()
		"disposed":
			var owner := EstragonContainer.new()
			owner.add_child(module.receiver)
			owner.remove_child(module.receiver)
			callback = module.receiver.receive
		"required": callback = required
		"optional": callback = optional
		"lambda_required": callback = func(value: int) -> void: values.append(value)
		"lambda_optional": callback = func(value: int = 7) -> void: values.append(value)
		"unbound": callback = optional.bind(7).unbind(1)
	var button: EstragonButton = module.build_static(callback)
	var early: bool = Engine.get_version_info()["minor"] >= 3
	var invalid: bool = mode in ["empty", "missing", "freed", "disposed"]
	_check(values.is_empty(), "construction never invokes callback")
	_check(button.pressed.get_connections().size() == (0 if early or invalid else 1), "expected connection state")
	if not early and not invalid:
		button.pressed.emit()
		_check(values == ([7] if mode in ["optional", "lambda_optional"] else []), "normal invocation semantics")
	var surface := EstragonSurface.new()
	surface.set_root(button)
	surface.free()
	_check(button.is_disposed() and button.pressed.get_connections().is_empty(), "owner cleanup")
	if not failed: print("C01_CALLBACK_GUARD_OK ", mode)
	quit(1 if failed else 0)
