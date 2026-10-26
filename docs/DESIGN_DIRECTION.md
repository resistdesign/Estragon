# Estragon design direction: Gogo, GDScript, and the component runtime

**Status:** Product direction captured 2026-10-26. **Not implemented.** The existing JSON-based demo is a disposable stage-0 prototype, not the intended production architecture.

This document records the next design direction. It is **not** a declaration that the listed language features, Godot integrations, or runtime classes already exist. It preserves genuine implementation questions, especially native-looking annotations and mixed-language authoring.

## The central correction: compile Gogo to GDScript

**Gogo is an XML-based declarative language that transpiles to real GDScript.** It is not intended to produce a persistent JSON UI description for a runtime XML/JSON interpreter.

Target pipeline:

~~~text
  User-authored *.gogo           User-authored GDScript + @Bindable (desired)
          |                                      |
    XML/semantic parser                 source-aware transformation
          |                                      |
   type, schema, events, bindings, source-location analysis
          |                                      |
          +---------- typed compiler model ------+
                             |
                   generated GDScript (*.gd)
                             |
                   Godot's GDScript compiler
                             |
              Estragon component instances + wiring
                             |
         Estragon-owned layout / state / events / paint
                             |
            Estragon renderer → Godot graphics APIs
~~~

- The compiler may use an **internal AST/IR** to separate parsing, validation, and code generation. An *internal* IR is not the previously assumed **serialized JSON runtime contract**.
- Generate readable, deterministic, type-aware GDScript with stable component references and source mappings. The generated code constructs **Estragon-owned objects**, not a scene full of Godot UI widgets.
- A Gogo document should be capable of defining a reusable component/class, much like an MXML document produces an ActionScript class in Flex 4. The exact generated inheritance and class-registration mechanism needs a prototype.
- Validate component/property/event names and types before or during generation; reject unsupported syntax instead of ignoring it.
- Rebuild on source changes and before running the project; do **not** require manual transpilation as the long-term user experience.
- **Migration:** Keep the existing \`tools/gogo.ts\` → \`*.gogo.json\` demo and its tests functioning until a new Gogo → GDScript vertical slice is demonstrably working. Replace it deliberately; do not describe the old JSON approach as the future plan.

## Gogo language: closely informed by Flex 4/MXML

The goal is to **mirror Flex 4's declarative authoring model closely where it makes sense**, adapted to GDScript and Estragon's own components. This is not a claim of full Flex source compatibility.

Design targets:

1. XML elements resolve to typed **Estragon component classes** and nested object construction, respecting namespaces.
2. Element attributes map to component properties, events, and expressions. Property elements, defaults, and metadata-driven schemas are candidates.
3. An element ID creates a stable, appropriately typed reference in the generated component class.
4. One-way and two-way binding expressions are compiler-recognized, type-checked, and connected to the reactive dependency system.
5. Event attributes can reference a method or contain a small handler expression; the compiler generates the necessary callback functions and signal connections.
6. Reusable custom components must participate in the same language model as built-in primitives.
7. The language needs a specified grammar **beyond XML validity**: namespaces, component resolution, property-element syntax, binding expressions, event expressions, embedded GDScript, and errors.
8. Preserve source positions, deterministic generated names, and helpful diagnostics. Don't use regex substitution or arbitrary JavaScript evaluation to interpret source programs.

**Open language details:** exact Gogo namespaces, tag naming, event attribute spelling, binding expression grammar, property-element semantics, component namespaces, and metadata format. Study Flex 4's rules before choosing alternatives. Syntax examples are proposals until tests prove they compile.

### Illustrative markup and generated wiring (not executable today)

~~~xml
<g:VBox xmlns:g="urn:estragon:gogo:1" gap="12">
    <g:Button id="saveButton"
              label="Save"
              click="on_save_clicked" />
</g:VBox>
~~~

Conceptually, the transpiler generates code equivalent to:

~~~gdscript
# Illustration, NOT an implemented API or literal promised output.
# EstragonVBox / EstragonButton are proposed runtime types.
extends EstragonVBox

var saveButton: EstragonButton

func _estragon_build() -> void:
    saveButton = EstragonButton.new()
    saveButton.label = "Save"
    add_child_component(saveButton)
    saveButton.pressed.connect(on_save_clicked)
~~~

The compiler must not rely on users writing that connection by hand. Specify handler arguments and scope, error on missing/incompatible handlers, and ensure that callbacks and subscriptions have appropriate lifetimes.

## A first-class Gogo editor experience inside Godot

The addon should make \`.gogo\` a real authoring language, not merely an extension displayed as plain text.

- Reliable file discovery, opening, and syntax coloring in Godot **4.7**.
- Highlight XML tags/namespaces, Estragon component/property names, bindings, events, and embedded code where applicable.
- Context-aware component/property/event completion, navigate-to-definition, and diagnostics that point back to original \`.gogo\` lines and columns.
- Save/build/run integration that regenerates GDScript and blocks runs on meaningful compile errors; never silently execute stale output after a failed build.
- Preview uses the **real Estragon renderer**, not Godot's \`Control\` UI system.
- Generated GDScript remains inspectable/debuggable without becoming the file that developers are expected to hand-edit.
- Editor settings must not be needlessly overwritten; clean install/disable behavior matters.

The current plugin only registers the text file extension. **Godot 4.7 editor syntax integration needs a concrete spike**, including verification of custom highlighter selection for non-GDScript text files. Investigate \`EditorSyntaxHighlighter\`, \`ScriptEditor\`, language extensions, and/or a dedicated authoring view. Keep Bun/TypeScript as the present tooling implementation; determine how it gets invoked and packaged without promising that a normal Godot player requires Bun.

## \`@Bindable\` in GDScript: required experience, unresolved mechanics

**Developer-experience requirement:** with Estragon's addon enabled, authors should be able to declare a property as bindable in familiar GDScript authoring and have the necessary property accessors/change notifications generated for them.

Conceptual authoring:

~~~gdscript
# Desired source ergonomics, NOT accepted stock GDScript today.
extends RefCounted

@Bindable
var player_name: String = "World"
~~~

Generated GDScript should implement the specified getter/setter and change-notification contract without requiring hand-written boilerplate. Observability must work for plain objects (\`RefCounted\`/\`Resource\`) without a per-object Godot \`Node\` requirement. Define equality, initialization, assignment, custom accessor, inheritance, nesting, and collections semantics before claiming full support.

**Critical technical constraint:** in stock Godot 4.7, installing an \`EditorPlugin\` does **not** register arbitrary new GDScript annotations. An unrecognized \`@Bindable\` in an ordinary \`.gd\` will not transparently become valid GDScript merely because the addon exists.

**Research, don't hand-wave:** determine whether there is a safe interception/preprocessing mechanism that preserves the visible \`.gd\` authoring experience *before Godot parses the source*. If not, evaluate an editor language/extension integration, separate source extension (previously proposed \`.bgd\`), or engine/parser change, and spell out the tradeoffs. An alternative extension is a possible fallback, **not** a silent substitute for the requested experience. Never rewrite the user's source in place or falsely advertise unsupported syntax as executable.

## Automatic signals and event handlers

The Gogo → GDScript compiler should create the code that developers would otherwise have to write manually:

- Instantiate the right Estragon component types and populate their properties.
- Generate typed component references from IDs.
- Generate handler methods when inline event expressions require them.
- Connect declared signals to explicit methods or generated handlers automatically.
- Generate binding observers, update callbacks, and invalidation hooks as needed.
- Validate missing handlers, incompatible signatures, duplicates, and collisions with user-defined methods.
- Avoid duplicated connections and stale subscriptions on rebuild or component disposal.
- Map generated code and runtime/compile errors back to original Gogo positions.

Direct, named handler methods and inline expressions can coexist if the grammar and scoping rules are made explicit. Avoid dynamic string-method dispatch where type-safe generated signal connections work.

## The actual Estragon runtime: primitives first

This framework also requires a **real component library**, separate from its transpiler. The runtime must own an independent hierarchy and rendering contract:

| Layer / example | Responsibility |
| --- | --- |
| \`DisplayObject\`-like base | identity, parent link, geometry, visibility, paint invalidation, lifecycle, hit-test basics |
| \`Container\`-like base | ordered children, ownership/reparenting, measurement/layout participation, clipping and invalidation propagation |
| \`VBox\` and \`HBox\` | vertical/horizontal layout, sizing, gaps, alignment, and nested measurement |
| Foundational visual components | rectangles, text, images, later buttons and input controls |
| UI services | styles, event propagation/signals, state/bindings, focus, scrolling, accessibility, localization |
| Renderer adapter | backend-neutral paint/display commands, subsequently implemented by Godot graphics APIs |

These are **Estragon** classes, not Godot's \`Control\`/\`Container\` widgets. Godot already has a \`Container\` class; choose runtime script identifiers/namespacing that avoid conflicts while keeping clean Gogo markup. A limited host \`Node\` is fine, but **no Godot node per Estragon component**. Clarify whether the base classes extend \`RefCounted\`, another Godot \`Object\` type, or a different representation after profiling and lifecycle experiments.

Layout must work with nested components and changing viewport sizes; it cannot be a series of hard-coded absolute positions. Source code generation and component-runtime development should progress together so the compiler has real target APIs.

## Mixing Gogo and GDScript: keep both possibilities open

Rejecting mixed markup/code out of hand would discard an important part of the Flex authoring experience. **Treat mixed-language authoring as a design question to prototype, not an impossibility or an already-decided grammar.**

**Option A — inline script blocks:** an MXML-style Gogo element containing GDScript, with CDATA for XML escaping. Example (illustrative only):

~~~xml
<g:VBox xmlns:g="urn:estragon:gogo:1">
    <g:Script><![CDATA[
        var clicks: int = 0

        func on_press() -> void:
            clicks += 1
    ]]></g:Script>
    <g:Button label="Press" click="on_press" />
</g:VBox>
~~~

This lets a Gogo document define its own behavior, but requires GDScript-aware parsing/validation, indentation handling, scope/hygiene rules, generated member collision checks, syntax highlighting within CDATA, and source maps for compiler/debugger errors.

**Option B — code-behind:** a \`.gogo\` view paired with a user-maintained \`.gd\` class/script. The Gogo compiler generates only what it owns and wires the view to explicit methods and model properties. Determine how the pairing maps to Godot's single-inheritance/script-loading model and how generated code remains separate from authored code.

Both could be supported; prototype the smallest useful example of each and compare editability, hot reload, class design, debugging, and source mapping. A mixed editor must not ask users to edit generated output.

## Dependency-aware implementation sequence

1. **Design and prove Gogo → GDScript:** use a minimal component and emit runnable GDScript with deterministic output, build errors, and source mapping. Retain the JSON sample during the transition.
2. **Build base runtime types:** \`DisplayObject\`-style object, \`Container\`-style object, then a working \`VBox\`/\`HBox\` layout. Demonstrate resize-driven relayout without Godot \`Control\` widgets.
3. **Wire editor compilation:** syntax support, diagnostics, generated-code location, and a save/build/run pipeline that can't accidentally run stale generated files.
4. **Prototype \`@Bindable\` feasibility:** test actual stock Godot 4.7 editor/parser behavior; decide the least intrusive sustainable authoring strategy with explicit tradeoffs.
5. **Generate signal handlers and connections;** add typed properties, IDs, and runtime lifetime tests.
6. **Implement binding expressions and observable state** with a dependency graph and cleanup semantics.
7. **Prototype mixed Gogo/GDScript** (inline and code-behind) before choosing a permanent grammar; then broaden the Flex 4-style component library and authoring ergonomics.

These tracks may overlap. A vertical slice through parser → generated GDScript → independent component → Godot renderer should guide every architectural decision.

## Proof requirements

The direction is realized only when a fresh project can:

- Open a \`.gogo\` document in Godot with useful language support.
- Compile it into runnable GDScript and show a responsive \`VBox\`/\`HBox\` layout of Estragon objects.
- Connect and invoke a declared event handler without manual signal wiring.
- Demonstrate observable updates and correct disposal without per-frame polling.
- Provide a credible solution (or clearly stated limitation) for \`@Bindable\` authoring in a \`.gd\` source file.
- Demonstrate whether inline and/or code-behind GDScript can coexist with Gogo.
- Run deterministically through the editor and through automated tests, with no runtime XML/JSON interpretation and no generated Godot UI node hierarchy.

Until then, keep product aspirations and current capabilities **explicitly distinguished**.

## References for implementation research

- Apache Flex: [MXML relationship to generated ActionScript classes, script blocks, and generated event handlers](https://flex.apache.org/doc/flex/using/flx_usingas_ua.html).
- Apache Flex: [MXML syntax and event-property conventions](https://flex.apache.org/doc/flex/using/flx_mxmlSyntax_sy.html).
- Godot 4.7: [EditorSyntaxHighlighter](https://docs.godotengine.org/en/4.7/classes/class_editorsyntaxhighlighter.html).
- Godot: [GDScript syntax and annotations](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html).
