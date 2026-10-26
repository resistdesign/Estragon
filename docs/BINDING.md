# Bindable properties and reactivity

**Status: planned.** No custom annotation or expression binding compiles today. Read the [design direction](DESIGN_DIRECTION.md) for the TSX-like Gogo/GDScript authoring goal.

## Developer experience

The desired experience is **`@Bindable` on normal GDScript properties in the Godot editor**, generating typed getters/setters, change notifications and binding plumbing automatically. Flex 4's `[Bindable]` is a conceptual precedent, not a drop-in implementation.

~~~gdscript
# Desired authoring experience — NOT valid stock Godot 4.7 syntax today.
extends RefCounted

@Bindable var player_name: String = "World"
@Bindable var score: int = 0

func add_point() -> void:
    score += 1
~~~

Gogo should recognize observable state as typed GDScript expressions inside markup:

~~~text
# UI.gogo — proposed mixed-language source, NOT executable today
extends VBox

func render() -> DisplayObject:
    return <VBox gap={8}>
        <Text value={"Score: %d" % score} />
        <Button label="+" pressed={add_point} />
    </VBox>
~~~

The sample intentionally leaves model scope/imports and exact binding syntax unspecified. A value expression is **not automatically reactive** just because it uses braces; the compiler must establish dependency tracking and update semantics, including safe handling of nested paths, collections and disposal.

## Godot parser integration: a hard prerequisite

An `EditorPlugin` cannot register arbitrary new annotations in ordinary `.gd` source. The GDScript parser will reject an unknown annotation unless source is transformed **before** it parses, or the engine/parser is extended. Therefore the specific requested experience—`@Bindable` directly in regular authored `.gd` files—**has not been proven possible with stock addon extension points**.

Investigate the supported editor/parser source lifecycle and interception points. A custom compiler can recognize `@Bindable` in its **own** mixed `.gogo` source, but that does not automatically solve ordinary `.gd` files. If a reliable stock-editor interception path does not exist, document the trade-offs of a custom source extension, controlled generated script interface, and engine/parser change **before** changing the promised UX. The old `.bgd` suggestion is only a fallback candidate, not an accepted replacement.

Never rewrite user-authored `.gd` files in place, hide persistent parser errors, or claim custom annotations work because syntax highlighting accepts them.

## Required compiler and runtime semantics

- Typed property get/set behavior, equality/change suppression, initialization, inherited and custom accessors.
- A consistent generated change-notification contract for `RefCounted`, `Resource` and other relevant object bases without forcing Godot `Node` objects.
- Nested dependency paths, replacement of intermediate objects, collection mutation and unsubscribe/dispose behavior.
- One-way expressions; assignable two-way bindings, event adapters and feedback/cycle protection.
- Batched/coalesced invalidation tied to Estragon component layout/paint, not frame polling.
- Source-location-aware errors, generated-to-authored source maps and tests for edge cases.

First prove actual parse/compile behavior in the target Godot version, then define the observable semantics and add a source-aware transformer, binding graph and reproducible tests.
