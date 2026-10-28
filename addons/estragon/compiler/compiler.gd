extends RefCounted
## Pure native compilation. Semantic validation/loading is an explicit next step.
const Model = preload("res://addons/estragon/compiler/model.gd")
const Source = preload("res://addons/estragon/compiler/source.gd")
const Frontend = preload("res://addons/estragon/compiler/frontend.gd")
const Emitter = preload("res://addons/estragon/compiler/emitter.gd")
const SourceMap = preload("res://addons/estragon/compiler/source_map.gd")

class Compilation extends RefCounted:
	var mode: String
	var code: String
	var source_map: SourceMap
	var diagnostics: Array[Model.Diagnostic] = []
	var ok: bool:
		get: return diagnostics.is_empty() and source_map != null

static func compile(source: String, source_name: String = "<source>") -> Compilation:
	var result := Compilation.new()
	var frontend := Frontend.analyze(source, source_name)
	result.diagnostics = frontend.diagnostics
	if not frontend.ok: return result
	result.mode = frontend.module.mode
	result.source_map = Emitter.new(frontend.module, Source.new(source, source_name)).emit()
	result.code = result.source_map.code
	return result
