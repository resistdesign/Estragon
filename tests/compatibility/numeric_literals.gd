extends SceneTree
## Isolate the shipped emitter from unavailable runtime/Logger APIs. Ordinary
## native reload executes the emitted number; no Gogo syntax is rewritten.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Emitter = preload("res://addons/estragon/compiler/emitter.gd")

func _initialize() -> void:
	var failed := false
	for text in ["0", "-0", "1e20", "1e-20", "3.141592653589793", "1.0000000000000002", "16777217", "3.4028234e38"]:
		var value := Model.Literal.new()
		value.kind = "number-literal"
		value.value = text.to_float()
		var token := Emitter.literal(value)
		var candidate := GDScript.new()
		candidate.source_code = "extends RefCounted\nvar amount: float = " + token + "\n"
		var valid := candidate.reload() == OK
		var equal: bool = valid and candidate.new().amount == text.to_float()
		print("C01_NUMERIC_CASE ", JSON.stringify({"source": text, "token": token, "equal": equal}))
		if not equal:
			failed = true
			push_error("C01 numeric literal changed value: " + text + " -> " + token)
	if not failed: print("C01_NUMERIC_OK")
	quit(1 if failed else 0)
