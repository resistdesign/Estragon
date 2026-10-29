@tool
extends RefCounted
## Explicit built-in contracts. GDScript syntax/types remain Godot's authority.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const CLASSES := {"VBox": "EstragonVBox", "HBox": "EstragonHBox", "Rect": "EstragonRect", "Text": "EstragonText", "Button": "EstragonButton"}
const TYPES := {"width": "float", "height": "float", "gap": "float", "fill_width": "bool", "fill_height": "bool", "fill": "Color", "text": "String", "font_size": "int", "color": "Color", "disabled": "bool"}
var file: Source
var _mode: String

func _init(source: Source) -> void:
	file = source

func validate(module: Model.Module) -> void:
	_mode = module.mode
	for part in module.parts: _node(part)

func _node(node: Model.SyntaxNode) -> void:
	if not file.diagnostics.is_empty(): return
	if node is Model.GdExpression:
		for part in node.parts: _node(part)
	elif node is Model.Component: _component(node)

func _error(message: String, span: Model.Span) -> void:
	file.fail(message, span.start.index, span.end.index)

func _component(node: Model.Component) -> void:
	if node.name.contains(":"):
		_error("Namespace-prefixed components are not supported", node.name_span)
		return
	if not CLASSES.has(node.name):
		_error("Unknown component %s; expected VBox, HBox, Rect, Text or Button" % JSON.stringify(node.name), node.name_span)
		return
	node.runtime_class = CLASSES[node.name]
	var seen: Dictionary = {}
	for attribute in node.attributes:
		var name := attribute.name
		if name == "xmlns" or name.contains(":"):
			_error("Namespaces and prefixed properties are not supported", attribute.name_span)
			return
		if seen.has(name):
			_error("Duplicate property or signal " + name, attribute.name_span)
			return
		seen[name] = true
		if node.name == "Button" and name == "pressed":
			if not attribute.value is Model.GdExpression:
				_error("pressed requires a {Callable expression} in a GDScript-first module" if _mode == "markup" else "pressed requires a {Callable expression}, not a quoted method name", attribute.value.span)
				return
			attribute.kind = "signal"
			attribute.type_name = "Callable"
		else:
			var valid := name in ["width", "height", "fill_width", "fill_height"]
			valid = valid or node.name in ["VBox", "HBox"] and name == "gap"
			valid = valid or node.name == "Rect" and name == "fill"
			valid = valid or node.name in ["Text", "Button"] and name in ["text", "font_size", "color"]
			valid = valid or node.name == "Button" and name == "disabled"
			if not valid:
				_error("Unsupported property or signal %s on %s" % [JSON.stringify(name), node.name], attribute.name_span)
				return
			attribute.type_name = TYPES[name]
		if attribute.value is Model.Literal: _literal(attribute.name, attribute.value)
		else: _node(attribute.value)
		if not file.diagnostics.is_empty(): return
	if node.name not in ["VBox", "HBox"] and not node.children.is_empty():
		var child := node.children[0]
		_error(node.name + " is a leaf and cannot contain components", child.name_span if child is Model.Component else child.span)
		return
	for child in node.children: _node(child)

func _literal(name: String, literal: Model.Literal) -> void:
	var value: String = literal.value
	literal.type_name = TYPES[name]
	if name == "text":
		literal.kind = "string-literal"
		return
	if name == "font_size":
		var number := value.to_float()
		if not _number(value) or not is_finite(number) or number != floor(number) or number <= 0 or number > 2147483647:
			_error("font_size requires a positive 32-bit integer", literal.span)
			return
		literal.kind = "integer-literal"
		literal.value = int(number)
		return
	if name in ["fill_width", "fill_height", "disabled"]:
		if value not in ["true", "false"]:
			_error(name + " requires true or false", literal.span)
			return
		literal.kind = "boolean-literal"
		literal.value = value == "true"
		return
	if name in ["fill", "color"]:
		var valid := value.length() in [7, 9] and value.begins_with("#")
		for character in value.substr(1):
			if not character in "0123456789abcdefABCDEF": valid = false
		if not valid:
			_error(name + " requires #RRGGBB or #RRGGBBAA", literal.span)
			return
		literal.kind = "color-literal"
		literal.value = value.to_lower() + ("ff" if value.length() == 7 else "")
		return
	literal.kind = "number-literal"
	if name in ["width", "height"] and value == "auto":
		literal.value = -1.0
		return
	if not _number(value):
		_error(name + " requires a finite nonnegative number" + ("" if name == "gap" else " or auto"), literal.span)
		return
	var number := value.to_float()
	if not is_finite(number) or not is_finite(PackedFloat32Array([number])[0]) or number < 0:
		_error(name + " must be nonnegative and finite in runtime geometry" + ("" if name == "gap" else "; use auto for intrinsic sizing"), literal.span)
		return
	literal.value = number if number != 0 else 0.0

## Decimal grammar, not Godot's more permissive numeric-string conversions.
func _number(value: String) -> bool:
	var index: int = 0
	if value.begins_with("+") or value.begins_with("-"): index += 1
	var digits: int = 0
	while index < value.length() and value[index] in "0123456789":
		index += 1
		digits += 1
	if index < value.length() and value[index] == ".":
		index += 1
		while index < value.length() and value[index] in "0123456789":
			index += 1
			digits += 1
	if digits == 0: return false
	if index < value.length() and value[index] in ["e", "E"]:
		index += 1
		if index < value.length() and value[index] in ["+", "-"]: index += 1
		var exponent := index
		while index < value.length() and value[index] in "0123456789": index += 1
		if exponent == index: return false
	return index == value.length()
