extends RefCounted
## Native source -> typed frontend result. No emitter, subprocess or editor state.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const Parser = preload("res://addons/estragon/compiler/parser.gd")
const Validator = preload("res://addons/estragon/compiler/validator.gd")

static func analyze(text: String, source_name: String = "<source>") -> Model.Result:
	var file := Source.new(text, source_name)
	var parser := Parser.new(file)
	var result := Model.Result.new()
	var module := parser.parse()
	if module != null: Validator.new(file).validate(module)
	result.tokens = parser.lexer.tokens
	result.diagnostics = file.diagnostics
	result.module = module if result.diagnostics.is_empty() else null
	return result
