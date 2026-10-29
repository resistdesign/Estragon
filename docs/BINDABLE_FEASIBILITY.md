# R01: ordinary `.gd` `@Bindable` feasibility

**Research result, 2026-10-29:** No supported complete path was found for the
requested ordinary `.gd` + stock GDScript editor experience in Godot
`4.7.stable.official.5b4e0cb0f`, using only a GDScript addon. Runtime interception
has partial successes, but none of the tested mechanisms intercepts the native
editor's source validation. This is an evidence-backed limitation of the public
integration paths examined, not a claim that every imaginable editor replacement
or future engine version is impossible.

Tracking: [R01 #4](https://github.com/resistdesign/Estragon/issues/4), related
[T09 #5](https://github.com/resistdesign/Estragon/issues/5). N03 is merged in
[PR #36](https://github.com/resistdesign/Estragon/pull/36). **No alternate syntax,
source extension, engine fork or production preprocessor is selected by R01.**

## Reproduce

```sh
GODOT_BIN=/absolute/path/to/Godot sh tools/check-bindable.sh
```

The harness checks the pinned version and creates fresh temporary projects for
12 runtime modes and one real headless editor session. Godot processes receive
an empty executable PATH, with no Bun/Node, production addon, compiler toolchain or shell
invocations inside the experiments. The editor binary is copied into a
self-contained workspace (ad-hoc signed on macOS); its preferences do not touch
the owner's editor. Set `ESTRAGON_KEEP_BINDABLE_TEST=1` to retain logs/projects.
A final `ESTRAGON_BINDABLE_RESEARCH_OK` means **expected outcomes were verified**,
including expected failures; it does not mean annotations are supported.

`tests/research/bindable/authored.gd.txt` is copied verbatim to `model.gd` only
inside these projects. It contains `@tool`, `class_name R01Model`,
`extends RefCounted`, typed int/String annotated fields and an ordinary
`count += 1` method. Each probe verifies the authored bytes remain unchanged.
The fixed generated counterpart is deliberately hand-written. The loader and
importer substitute only that fixture; they are not source transformers or
framework features. Invalid source stays `.txt` in the repository so normal
Godot import/every-script validation remains valid.

## Observed results

| Experiment | Stock 4.7 result |
| --- | --- |
| `GDScript.new()`, authored `source_code`, `reload()` with front loader registered | `ERR_PARSE_ERROR` (43), `model.gd:5`, `Unrecognized annotation: "@Bindable"`; loader never called. |
| Explicit `ResourceLoader.load()` with front-priority custom `.gd` loader | Executes the fixed generated script, including `@tool`. Typed `RefCounted` initialization and ordinary assignments work. |
| Notification control | Initial count 7/title `initial` produce zero setter notifications; increment, `set("count", 9)` and title assignment emit exactly three property/old/new notifications; identical assignments emit none. This proves generated accessor semantics, not annotation compilation. |
| Repeated explicit loads in this minimal loader | Two generated script identities, despite `take_over_path()`. Loader cache handling alone does not establish native GDScript dependency-parser identity. An owned cache could improve this narrow result; it would not intercept direct validation. |
| Native `preload("res://model.gd")` | Reload fails at consumer line 2; no loader invocation. Warming the explicit resource first still fails. |
| Native `extends "res://model.gd"` | Reload fails at consumer line 1; no loader invocation. Warming first still fails. |
| Advertise generic `Script` instead of `GDScript` | Preload invokes the loader once, then fails script resolution. Inheritance still bypasses it. |
| Export-style `model.gd.remap` → fixed generated `lowered.gd` | Native preload compiles and executes. Cold inheritance reload returns OK but its base cannot instantiate; explicitly loading the remapped base first permits execution. A successful reload alone is insufficient evidence. |
| Custom `EditorImportPlugin` for `.gd` | Importer runs and writes generated code plus `.gd.import` metadata. Normal native `.gd` loading still rejects the authored annotation. `.import` and `.remap` are distinct mechanisms. |
| `ScriptLanguageExtension` claiming `.gd` | `Engine.register_script_language()` returns `ERR_ALREADY_EXISTS`; the built-in extension is already registered. No built-in language is removed by the experiment. |
| Real `ScriptEditor` opening the intercepted script | Displays generated resource source, not authored text. Restoring authored text in its unsaved buffer causes native validation error at **line 5, column 1**, with the loader still active. No file is saved. |
| Global class discovery | Finds `R01Model` despite invalid annotations. The class-discovery parser is intentionally error tolerant; class listing does not prove compile/execute support. |

Runtime negative cases capture and assert native Logger messages, paths, lines
and loader call counts. The editor test reads the actual error-label contents;
it does not infer diagnostics from a highlighter. Unexpected errors, missing
completion markers and leaked-resource/aborted-scan warnings fail the harness.

## Why the public hooks do not compose into a transparent frontend

These links pin the exact engine revision used in the probes:

- [Annotation registry and parser](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_parser.cpp#L144),
  [private registration declaration](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_parser.h#L1558):
  annotations are registered inside the native parser. The registration function
  is private C++, not an addon-callable registration or preprocessing API.
- [Dependency parser source acquisition](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_cache.cpp#L72),
  [GDScript preload branch](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_analyzer.cpp#L4755):
  GDScript dependencies use their own parser/cache, reading source via
  FileAccess after path remapping. They do not universally call a custom
  ResourceFormatLoader. Faking the advertised resource type does not replace
  GDScript's semantic dependency analysis.
- [Native resource loader](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_resource_format.cpp#L39),
  [path versus import remapping](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/io/resource_loader.cpp#L1491):
  loading uses the original script path and GDScriptCache. Export-style remaps
  affect file acquisition; imports alone are not a source-validation callback.
- [ScriptTextEditor validation](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/script/script_text_editor.cpp#L842),
  [GDScript language validation](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript_editor.cpp#L146):
  the native editor directly supplies buffer text to the script's language.
  That language constructs a native parser. No resource-load/import/build
  callback runs between the text and this parser. A build hook is too late for
  ordinary editing diagnostics, including unsaved buffers.
- [Global class discovery](https://github.com/godotengine/godot/blob/5b4e0cb0f/modules/gdscript/gdscript.cpp#L2717)
  separately reads authored files and parses tolerantly. Custom annotations
  cannot be inferred to work from a class appearing in the editor.
- [Language registration](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/object/script_language.cpp#L239)
  rejects duplicate extensions, names and types. ScriptLanguageExtension is a
  separate-language implementation interface, not a wrapper around GDScript's
  parser. Removing the running built-in language would still not change the
  language returned by native GDScript resources and is not an acceptable hook.
- [Native script editor factory](https://github.com/godotengine/godot/blob/5b4e0cb0f/editor/script/script_editor_plugin.cpp#L3652)
  is a C++ registration function; the bound ScriptEditor API exposes highlighter
  registration, not replacement of GDScript validation or this editor factory.
  Highlighting, EditorPlugin object handling and filesystem notifications do
  not supply a source-returning pre-parse callback. A separate custom source
  editor would be a different workflow requiring its own design and proof.

Public contracts: [ResourceFormatLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceformatloader.html),
[EditorImportPlugin](https://docs.godotengine.org/en/4.7/classes/class_editorimportplugin.html),
[ScriptLanguageExtension](https://docs.godotengine.org/en/4.7/classes/class_scriptlanguageextension.html),
[EditorPlugin](https://docs.godotengine.org/en/4.7/classes/class_editorplugin.html).
None specifies an addon pre-parse transformation hook for native GDScript.

## Recommendation and decision required before T09

**Keep the current native workflow intact and do not ship an annotation shim for
ordinary `.gd`.** Under the current constraints there is no demonstrated
supported implementation that meets runtime loading *and* native editor/source
diagnostics. Preserve the requested experience as an unmet requirement. Ask the
owner which constraint may change before implementing T09's annotation path.

| Option requiring owner decision | Benefit | Explicit cost / uncertainty |
| --- | --- | --- |
| Seek an upstream Godot pre-parse/annotation extension API; wait for a supported stock release | Retains ordinary `.gd`, native editor and exact syntax | No such hook exists in the tested release; timing and acceptance unknown. An engine fork/custom binary would violate current requirements. |
| Author observable models in compiler-owned Gogo source | Reuses the bundled native lexer, emission/maps, semantic validator and N03 build gate; can generate typed accessors and signals | Changes the ordinary `.gd` authoring requirement. Code-only model modules/annotation parsing need an explicit contract and tests; not implemented by R01. |
| Investigate a dedicated source editor plus controlled generated-script/remap interface | Could retain `.gd` filenames on disk with addon-owned source handling | Replaces native GDScript editing/validation; remap/cache/class/tool/export behavior remains substantial unproven work. No complete supported path established here. |
| Separate source extension such as `.bgd`, or hand-written setters | Straightforward compilation boundary, or valid native source | Both change the requested developer experience. Neither is adopted. Manual setters do not meet automatic authoring requirements. |

If compiler-owned source is explicitly accepted later, extend the existing
native frontend with a typed observable declaration model and deliberate setter
lowering, not regex rewriting. Reuse source spans/maps and Godot semantic
validation. N01's lexer already preserves strings/comments/declaration tokens;
it is not a full GDScript property/accessor parser. N02/N03's generated-file
publication/identity and diagnostics can be reused at a **compiler-owned**
boundary, not assumed to intercept authored `.gd`.

Define initialization, typed equality, custom setters, inheritance and collection
mutation before production lowering. A future dependency graph should subscribe
to generated property notifications, replace nested subscriptions and clean them
through surface/container ownership. Batch invalidation; do not poll expressions
per frame. R01 adds no binding graph or runtime component changes.

## Limits and follow-up

The fixtures prove simple int/String properties on a RefCounted tool class and
specific dependency/cache sequences. They do not establish general property
transformation, Resource subclasses, custom accessor composition, cyclic
inheritance/dependencies, export correctness, debugger remapping or production
hot reload. No visual or physical-keyboard smoke test was run: this is headless
runtime execution plus a real headless ScriptEditor diagnostic test, not rendering
work. Re-run the probes when upgrading Godot; private cache behavior is not a
supported addon contract.

[E01 #37](https://github.com/resistdesign/Estragon/issues/37) remains a standalone
highlighter activation fix. Schedule it before T09's final integrated authoring
milestone; R01 does not implement or certify that fix.
