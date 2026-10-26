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
- **Migration:** Keep the existing `tools/gogo.ts` → `*.gogo.json` demo and its tests functioning until a new Gogo → GDScript vertical slice is demonstrably working. Replace it deliberately; do not describe the old JSON approach as the future plan.

## Gogo language: XML-like markup with TSX-style GDScript

**Accepted developer-experience direction:** Gogo keeps XML-like nested elements while taking its *language ergonomics* from TSX/JSX: unprefixed component names, markup expressions living among ordinary-looking GDScript, typed expression props, direct callback references, and compiler-generated classes. Borrow Flex 4's component model, observability, and automatic wiring without carrying forward XML namespace ceremony.

### No XML namespaces in authored markup

Write `<VBox>`, `<Button>`, `<Text>`, `<InventoryCard>` — **never mandatory `<fx:VBox>`, `<g:Button>`, or `xmlns` declarations.**

- PascalCase tags resolve to real Estragon component types through an explicit component registry/import system, not HTML elements or Godot `Control` widgets.
- The exact component import syntax and precedence remain to be defined. Unknown and ambiguous tags must produce source-located errors.
- Types/metadata should drive prop checking, allowed children, signal signatures and editor completion/go-to-definition.
- XML-like nesting is a *syntax shape*. A mixed code/markup file is not necessarily a valid standalone XML document; the existing strict XML parser cannot simply parse the future hybrid source unchanged.

~~~xml
<VBox gap={12}>
    <Text value={"Hello, " + player_name} />
    <Button label="Save" pressed={on_save} />
    <InventoryCard item={selected_item} />
</VBox>
~~~

**This does not compile today.** Braces contain **GDScript expressions**, not TypeScript expressions. Literal attributes, exact event property naming, bindings and component import rules need precise grammar and tests.

### The primary goal: GDScript and Gogo interleaved like TSX

A single authored `.gogo` file should ideally allow GDScript declarations and functions **alongside markup expressions**—not force every method into an XML CDATA block or an obligatory companion file.

~~~text
# Counter.gogo — PROPOSED hybrid syntax, NOT executable today
extends VBox

@Bindable var count: int = 0

func increment() -> void:
    count += 1

func render() -> DisplayObject:
    return (
        <VBox gap={12}>
            <Text value={"Count: %d" % count} />
            <Button label="+" pressed={increment} />
        </VBox>
    )
~~~

The compiler owns the `.gogo` source, processes both GDScript-shaped code and XML-like element expressions, and emits **valid `.gd` code** with typed references, signal connections, subscriptions and source maps. This sketch is not a decision about exact render method names, base classes, or generated code shape.

**Separate technical issue:** the Gogo compiler can handle `@Bindable` inside its *own* hybrid source, but that **does not solve the desired `@Bindable` annotation in ordinary user-authored `.gd` files**. Stock Godot parses those itself; addon-defined GDScript annotations are not simply registered by an `EditorPlugin`. Preserve both requirements and prove the mechanism for each.

### Grammar and semantics to specify

1. **Component expressions:** nested markup produces typed Estragon component values or construction descriptors, never Godot UI nodes.
2. **Typed props:** `gap={12}` passes a number; `value={"Hello, " + player_name}` evaluates GDScript-shaped expressions; quoted literals stay ergonomic.
3. **Children and identity:** nested components, expression children (`{make_heading()}`), conditional/iterated children, stable IDs and keyed reconciliation must have deliberate semantics.
4. **Signals:** `pressed={increment}` should generate checked signal wiring, with suitable handler arguments, scopes, disposal and duplicate-connection prevention.
5. **Reactive expressions:** a value expression is not automatically a reactive binding; specify dependency tracking, update/lifetime rules and two-way binding separately. Do not copy React's rerender semantics by accident.
6. **Component resolution:** decide how built-ins and user components are imported, type-checked and exposed as named references.
7. **Source maps and tooling:** parse both languages with precise locations, readable generated output, diagnostics, hybrid syntax highlighting and navigation.
8. **Real parser:** do not attempt to mix nested markup with GDScript through regex substitutions or by feeding the whole file to a strict XML parser. Investigate a coordinated lexer/parser and concrete ambiguity cases.

**Open syntax decisions:** whether to support markup-only `.gogo` shorthand, the component import syntax, direct callback versus inline lambdas, event naming, the value-versus-binding distinction, conditional/repeated rendering, and how much of TSX's expression syntax maps cleanly to GDScript.

### Conceptual generated signal wiring (not implemented)

~~~gdscript
# Illustration; component class names and methods are provisional.
extends EstragonVBox

var save_button: EstragonButton

func _estragon_build() -> void:
    save_button = EstragonButton.new()
    save_button.label = "Save"
    add_child_component(save_button)
    save_button.pressed.connect(on_save)
~~~

Gogo should generate construction, typed references, property assignments and event connections; developers should not hand-write the mechanical signal glue.

## A first-class Gogo editor experience inside Godot

The addon should make `.gogo` a real authoring language, not merely an extension displayed as plain text.

- Reliable file discovery, opening, and syntax coloring in Godot **4.7**.
- Highlight XML tags/namespaces, Estragon component/property names, bindings, events, and embedded code where applicable.
- Context-aware component/property/event completion, navigate-to-definition, and diagnostics that point back to original `.gogo` lines and columns.
- Save/build/run integration that regenerates GDScript and blocks runs on meaningful compile errors; never silently execute stale output after a failed build.
- Preview uses the **real Estragon renderer**, not Godot's `Control` UI system.
- Generated GDScript remains inspectable/debuggable without becoming the file that developers are expected to hand-edit.
- Editor settings must not be needlessly overwritten; clean install/disable behavior matters.

The current plugin only registers the text file extension. **Godot 4.7 editor syntax integration needs a concrete spike**, including verification of custom highlighter selection for non-GDScript text files. Investigate `EditorSyntaxHighlighter`, `ScriptEditor`, language extensions, and/or a dedicated authoring view. Keep Bun/TypeScript as the present tooling implementation; determine how it gets invoked and packaged without promising that a normal Godot player requires Bun.

## `@Bindable` in GDScript: required experience, unresolved mechanics

**Developer-experience requirement:** with Estragon's addon enabled, authors should be able to declare a property as bindable in familiar GDScript authoring and have the necessary property accessors/change notifications generated for them.

Conceptual authoring:

~~~gdscript
# Desired source ergonomics, NOT accepted stock GDScript today.
extends RefCounted

@Bindable
var player_name: String = "World"
~~~

Generated GDScript should implement the specified getter/setter and change-notification contract without requiring hand-written boilerplate. Observability must work for plain objects (`RefCounted`/`Resource`) without a per-object Godot `Node` requirement. Define equality, initialization, assignment, custom accessor, inheritance, nesting, and collections semantics before claiming full support.

**Critical technical constraint:** in stock Godot 4.7, installing an `EditorPlugin` does **not** register arbitrary new GDScript annotations. An unrecognized `@Bindable` in an ordinary `.gd` will not transparently become valid GDScript merely because the addon exists.

**Research, don't hand-wave:** determine whether there is a safe interception/preprocessing mechanism that preserves the visible `.gd` authoring experience *before Godot parses the source*. If not, evaluate an editor language/extension integration, separate source extension (previously proposed `.bgd`), or engine/parser change, and spell out the tradeoffs. An alternative extension is a possible fallback, **not** a silent substitute for the requested experience. Never rewrite the user's source in place or falsely advertise unsupported syntax as executable.

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
| `DisplayObject`-like base | identity, parent link, geometry, visibility, paint invalidation, lifecycle, hit-test basics |
| `Container`-like base | ordered children, ownership/reparenting, measurement/layout participation, clipping and invalidation propagation |
| `VBox` and `HBox` | vertical/horizontal layout, sizing, gaps, alignment, and nested measurement |
| Foundational visual components | rectangles, text, images, later buttons and input controls |
| UI services | styles, event propagation/signals, state/bindings, focus, scrolling, accessibility, localization |
| Renderer adapter | backend-neutral paint/display commands, subsequently implemented by Godot graphics APIs |

These are **Estragon** classes, not Godot's `Control`/`Container` widgets. Godot already has a `Container` class; choose runtime script identifiers/namespacing that avoid conflicts while keeping clean Gogo markup. A limited host `Node` is fine, but **no Godot node per Estragon component**. Clarify whether the base classes extend `RefCounted`, another Godot `Object` type, or a different representation after profiling and lifecycle experiments.

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

**Option B — code-behind:** a `.gogo` view paired with a user-maintained `.gd` class/script. The Gogo compiler generates only what it owns and wires the view to explicit methods and model properties. Determine how the pairing maps to Godot's single-inheritance/script-loading model and how generated code remains separate from authored code.

Both could be supported; prototype the smallest useful example of each and compare editability, hot reload, class design, debugging, and source mapping. A mixed editor must not ask users to edit generated output.

## Dependency-aware implementation sequence

1. **Design and prove Gogo → GDScript:** use a minimal component and emit runnable GDScript with deterministic output, build errors, and source mapping. Retain the JSON sample during the transition.
2. **Build base runtime types:** `DisplayObject`-style object, `Container`-style object, then a working `VBox`/`HBox` layout. Demonstrate resize-driven relayout without Godot `Control` widgets.
3. **Wire editor compilation:** syntax support, diagnostics, generated-code location, and a save/build/run pipeline that can't accidentally run stale generated files.
4. **Prototype `@Bindable` feasibility:** test actual stock Godot 4.7 editor/parser behavior; decide the least intrusive sustainable authoring strategy with explicit tradeoffs.
5. **Generate signal handlers and connections;** add typed properties, IDs, and runtime lifetime tests.
6. **Implement binding expressions and observable state** with a dependency graph and cleanup semantics.
7. **Prototype mixed Gogo/GDScript** (inline and code-behind) before choosing a permanent grammar; then broaden the Flex 4-style component library and authoring ergonomics.

These tracks may overlap. A vertical slice through parser → generated GDScript → independent component → Godot renderer should guide every architectural decision.

## Proof requirements

The direction is realized only when a fresh project can:

- Open a `.gogo` document in Godot with useful language support.
- Compile it into runnable GDScript and show a responsive `VBox`/`HBox` layout of Estragon objects.
- Connect and invoke a declared event handler without manual signal wiring.
- Demonstrate observable updates and correct disposal without per-frame polling.
- Provide a credible solution (or clearly stated limitation) for `@Bindable` authoring in a `.gd` source file.
- Demonstrate whether inline and/or code-behind GDScript can coexist with Gogo.
- Run deterministically through the editor and through automated tests, with no runtime XML/JSON interpretation and no generated Godot UI node hierarchy.

Until then, keep product aspirations and current capabilities **explicitly distinguished**.

## References for implementation research

- Apache Flex: [MXML relationship to generated ActionScript classes, script blocks, and generated event handlers](https://flex.apache.org/doc/flex/using/flx_usingas_ua.html).
- Apache Flex: [MXML syntax and event-property conventions](https://flex.apache.org/doc/flex/using/flx_mxmlSyntax_sy.html).
- Godot 4.7: [EditorSyntaxHighlighter](https://docs.godotengine.org/en/4.7/classes/class_editorsyntaxhighlighter.html).
- Godot: [GDScript syntax and annotations](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html).
