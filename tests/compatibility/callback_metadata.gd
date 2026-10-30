extends SceneTree
## C01-C capability experiment; never calls a candidate during inspection.
var effects: Array[String] = []
signal probe_signal
var native_counter: GDScript

func zero() -> void:
	effects.append("zero")

func required(value: String) -> void:
	effects.append(value)

func optional(value: String = "default") -> void:
	effects.append(value)

static func static_zero() -> void:
	pass

func returned_lambda(with_argument: bool) -> Callable:
	if with_argument:
		return func(value: String) -> void: effects.append(value)
	return func() -> void: effects.append("returned")

func inspect_callback(name: String, callback: Callable) -> Dictionary:
	var target := callback.get_object()
	var method := str(callback.get_method())
	var methods: Array = []
	var script_methods: Array = []
	if is_instance_valid(target):
		for entry in target.get_method_list():
			if str(entry.name) == method: methods.append(entry)
		var script = target if target is Script else target.get_script()
		if script != null:
			for entry in script.get_script_method_list():
				if str(entry.name) == method: script_methods.append(entry)
	var connection_error: int = -1
	if callback.is_valid():
		connection_error = probe_signal.connect(callback)
		if connection_error == OK: probe_signal.disconnect(callback)
	return {"name": name, "valid": callback.is_valid(), "custom": callback.is_custom(),
		"null": callback.is_null(), "method": method, "target_id": callback.get_object_id(),
		"target_class": target.get_class() if is_instance_valid(target) else "none",
		"bound_count": callback.get_bound_arguments_count(), "bound_arguments": callback.get_bound_arguments(),
		"object_method_metadata": methods, "script_method_metadata": script_methods,
		"display": str(callback), "connect_error": connection_error,
		"native_count": native_counter.count(callback) if native_counter != null and callback.is_valid() else null}

func _initialize() -> void:
	if Engine.get_version_info().minor >= 3:
		# Fixed test-only query; never executes application expressions/callbacks.
		native_counter = GDScript.new()
		native_counter.source_code = "extends RefCounted\nstatic func count(value: Callable) -> int:\n\treturn value.get_argument_count()\n"
		if native_counter.reload() != OK:
			quit(1)
			return
	var captured := "captured"
	var named_zero := func same_name() -> void: effects.append("named zero")
	var named_required := func same_name(value: String) -> void: effects.append(value)
	var callbacks := [
		["method_zero", zero], ["method_required", required], ["method_optional", optional],
		["method_bound", required.bind("bound")], ["method_optional_bound", optional.bind("bound")],
		["method_unbound", zero.unbind(1)], ["static_zero", static_zero],
		["lambda_zero", func() -> void: effects.append("lambda")],
		["lambda_captureless", func() -> void: pass],
		["lambda_required", func(value: String) -> void: effects.append(value)],
		["lambda_optional", func(value: String = "default") -> void: effects.append(value)],
		["lambda_captured", func() -> void: effects.append(captured)],
		["named_lambda_zero", named_zero], ["named_lambda_required", named_required],
		["returned_lambda_zero", returned_lambda(false)], ["returned_lambda_required", returned_lambda(true)],
		["bound_lambda", named_required.bind("bound")], ["unbound_lambda", named_zero.unbind(1)],
		["empty", Callable()], ["missing", Callable(self, "missing")],
	]
	var rows: Array = []
	for item in callbacks:
		var row := inspect_callback(item[0], item[1])
		rows.append(row)
		print("C01_CALLBACK_METADATA ", JSON.stringify(row))
	if not effects.is_empty():
		push_error("Inspection invoked an authored callback")
		quit(1)
		return
	print("C01_CALLBACK_METADATA_OK")
	quit(0)
