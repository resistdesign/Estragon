extends RefCounted
## Native frontend data only. No Nodes, runtime components or editor services.

class Position extends RefCounted:
	var index: int # Godot Unicode scalar index for slicing.
	var offset: int # UTF-16 offset for cross-frontend diagnostics/maps.
	var line: int
	var column: int

class Span extends RefCounted:
	var start: Position
	var end: Position

class Diagnostic extends RefCounted:
	var source_name: String
	var span: Span
	var message: String

	func format() -> String:
		return "%s:%d:%d: %s" % [source_name, span.start.line, span.start.column, message]

class Token extends RefCounted:
	var kind: String
	var text: String
	var span: Span

class SyntaxNode extends RefCounted:
	var kind: String
	var span: Span

class Code extends SyntaxNode:
	func _init() -> void:
		kind = "gdscript-source"

class GdExpression extends SyntaxNode:
	var parts: Array[SyntaxNode] = []
	func _init() -> void:
		kind = "gdscript-expression"

class Literal extends SyntaxNode:
	var value: Variant
	var type_name: String
	func _init() -> void:
		kind = "raw-literal"

class Attribute extends RefCounted:
	var kind: String = "property"
	var name: String
	var name_span: Span
	var value: SyntaxNode
	var type_name: String

class Component extends SyntaxNode:
	var name: String
	var name_span: Span
	var runtime_class: String
	var attributes: Array[Attribute] = []
	var children: Array[SyntaxNode] = []
	func _init() -> void:
		kind = "component-expression"

class Module extends RefCounted:
	var mode: String
	var parts: Array[SyntaxNode] = []
	var identifiers: PackedStringArray = []
	var indentation: String = "\t"

class Result extends RefCounted:
	var module: Module
	var tokens: Array[Token] = []
	var diagnostics: Array[Diagnostic] = []
	var ok: bool:
		get: return module != null and diagnostics.is_empty()
